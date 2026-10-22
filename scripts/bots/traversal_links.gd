class_name TraversalLinks
extends RefCounted
## Bakes physical shortcuts that a walking navmesh cannot express (ledge drops, mantles,
## railing hops and gap jumps) into one-way navigation links, so bot paths use the same
## parkour a player would. Every link is checked against real collision using the shared
## movement numbers; executing it later uses ordinary jump/move inputs and the real motor.
## Links that bots repeatedly fail are disabled at runtime (self-healing).

const SAMPLE_SPACING: float = 2.0
const MAX_DROP: float = 6.5
const MIN_RISE: float = .6
const DEDUPE_CELL: float = 3.0
const FAILURES_TO_DISABLE: int = 3
## Bump when candidate or validation rules change; invalidates on-disk caches.
const VERSION: int = 3
## Highest ledge a wall kick plus upward air dash plus mantle is tried for.
const WALL_CLIMB_MAX: float = 5.8
## Navigation layer bit for links that spend a dash charge.
const DASH_LAYER: int = 1 << 9
## Per-frame work budget for the asynchronous bake (microseconds).
const FRAME_BUDGET_USEC: int = 4000
const CACHE_DIR: String = "user://bot_links"

## link RID -> {"type","start","end","failures","failed_total","uses"}
static var registry: Dictionary = {}
## navigation map RID -> build report (present once finished)
static var built: Dictionary = {}
static var building: Dictionary = {}

static func meta(rid: RID) -> Dictionary:
	return registry.get(rid,{})

static func report_for(map: RID) -> Dictionary:
	return built.get(map,{})

static func ready_for(map: RID) -> bool:
	return built.has(map)

## Starts the bake once per navigation map; returns immediately. Bots walk normally
## until links appear. A cached bake for an identical navmesh registers instantly.
static func ensure(region: NavigationRegion3D, tuning: HeroTuning) -> void:
	if not is_instance_valid(region) or region.navigation_mesh == null: return
	var map: RID = region.get_navigation_map()
	if built.has(map) or building.has(map): return
	building[map] = true
	region.tree_exiting.connect(func() -> void: clear_map(map),CONNECT_ONE_SHOT)
	build(region,tuning)

static func clear_map(map: RID) -> void:
	for rid: RID in registry.keys():
		if NavigationServer3D.link_get_map(rid) == map or not map.is_valid():
			NavigationServer3D.free_rid(rid)
			registry.erase(rid)
	built.erase(map)
	building.erase(map)

static func cache_path(mesh: NavigationMesh, t: HeroTuning) -> String:
	var key: int = hash([VERSION,mesh.get_vertices().to_byte_array(),mesh.get_polygon_count(),t.jump_impulse,t.gravity,t.mantle_height])
	return "%s/%x.json" % [CACHE_DIR,key]

static func load_cache(path: String) -> Array:
	if not FileAccess.file_exists(path): return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Array else []

static func save_cache(path: String, entries: Array) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(entries))

static func vec(value: Array) -> Vector3:
	return Vector3(float(value[0]),float(value[1]),float(value[2]))

## Coroutine: yields a physics frame whenever this frame's budget is spent.
## Returns false when the region disappeared while waiting.
static func pace(region: NavigationRegion3D, clock: Dictionary) -> bool:
	if Time.get_ticks_usec()-int(clock.start) < FRAME_BUDGET_USEC: return is_instance_valid(region)
	if not is_instance_valid(region) or not region.is_inside_tree(): return false
	await region.get_tree().physics_frame
	clock.start = Time.get_ticks_usec()
	return is_instance_valid(region) and region.is_inside_tree()

static func build(region: NavigationRegion3D, t: HeroTuning) -> void:
	var map: RID = region.get_navigation_map()
	var cache: String = cache_path(region.navigation_mesh,t)
	var cached: Array = load_cache(cache)
	if not cached.is_empty():
		var counts_cached: Dictionary = {}
		for entry: Dictionary in cached:
			register(map,vec(entry.start),vec(entry.end),str(entry.type),region.navigation_layers)
			counts_cached[entry.type] = int(counts_cached.get(entry.type,0))+1
		counts_cached["pad"] = register_pads(region)
		built[map] = {"links":cached.size(),"by_type":counts_cached,"cached":true,"milliseconds":0}
		building.erase(map)
		return
	var report: Dictionary = await bake(region,t)
	if not is_instance_valid(region) or not building.has(map): return
	report.by_type["pad"] = register_pads(region)
	built[map] = report
	building.erase(map)
	save_cache(cache,report.entries)
	report.erase("entries")

static func bake(region: NavigationRegion3D, t: HeroTuning) -> Dictionary:
	var started: int = Time.get_ticks_msec()
	var mesh: NavigationMesh = region.navigation_mesh
	var map: RID = region.get_navigation_map()
	var space: PhysicsDirectSpaceState3D = region.get_world_3d().direct_space_state
	var xf: Transform3D = region.global_transform
	var vertices: PackedVector3Array = mesh.get_vertices()
	var edges: Dictionary = {}
	for index: int in mesh.get_polygon_count():
		var polygon: PackedInt32Array = mesh.get_polygon(index)
		var centroid := Vector3.ZERO
		for v: int in polygon: centroid += vertices[v]
		centroid /= maxf(1,polygon.size())
		for corner: int in polygon.size():
			var a: int = polygon[corner]
			var b: int = polygon[(corner+1)%polygon.size()]
			var key := Vector2i(mini(a,b),maxi(a,b))
			if edges.has(key): edges[key].count += 1
			else: edges[key] = {"count":1,"a":a,"b":b,"centroid":centroid}
	var radius: float = mesh.agent_radius
	var apex: float = t.jump_impulse*t.jump_impulse/(2.0*t.gravity)
	var max_rise: float = minf(apex+t.mantle_height-.1,3.6)
	var air_time: float = 2.0*t.jump_impulse/t.gravity
	var max_gap: float = air_time*t.ground_speed*.85
	var capsule := CapsuleShape3D.new()
	capsule.radius = .45
	capsule.height = 1.8
	var seen: Dictionary = {}
	var counts: Dictionary = {"drop":0,"hop_drop":0,"mantle":0,"gap":0,"wall_climb":0}
	var rejected: Dictionary = {"drop":0,"hop_drop":0,"mantle":0,"gap":0,"wall_climb":0}
	var stand_in: HeroActor = make_probe(region)
	var entries: Array = []
	var clock: Dictionary = {"start":Time.get_ticks_usec()}
	var samples: int = 0
	var path_queries: int = 0
	for key: Vector2i in edges:
		var edge: Dictionary = edges[key]
		if int(edge.count) != 1: continue
		var a: Vector3 = xf*vertices[int(edge.a)]
		var b: Vector3 = xf*vertices[int(edge.b)]
		var along: Vector3 = (b-a)*Vector3(1,0,1)
		var length: float = along.length()
		if length < .6: continue
		var normal: Vector3 = Vector3(along.z,0,-along.x).normalized()
		var middle: Vector3 = (a+b)*.5
		if normal.dot((middle-xf*Vector3(edge.centroid))*Vector3(1,0,1)) < 0: normal = -normal
		var steps: int = maxi(1,int(length/SAMPLE_SPACING))
		for s: int in steps:
			var p: Vector3 = a.lerp(b,(s+.5)/steps)
			if not await pace(region,clock): return {"links":0,"aborted":true,"entries":[]}
			p = NavigationServer3D.map_get_closest_point(map,p)
			samples += 1
			var candidates: Array[Dictionary] = probe(space,p,normal,radius,max_rise,max_gap,capsule)
			for found: Dictionary in candidates:
				var dedupe: String = "%s|%s|%s" % [str((Vector3(found.start)/DEDUPE_CELL).floor()),str((Vector3(found.end)/DEDUPE_CELL).floor()),found.type]
				if seen.has(dedupe): continue
				var start: Vector3 = NavigationServer3D.map_get_closest_point(map,found.start)
				var end: Vector3 = NavigationServer3D.map_get_closest_point(map,found.end)
				if start.distance_to(found.start) > .8 or end.distance_to(found.end) > .8: continue
				# Only a link that beats walking is worth a stunt.
				var direct: float = start.distance_to(end)
				var path: PackedVector3Array = NavigationServer3D.map_get_path(map,start,end,true)
				path_queries += 1
				var walked: float = INF
				if not path.is_empty() and path[-1].distance_to(end) < 1.0:
					walked = 0.0
					for i: int in range(1,path.size()): walked += path[i-1].distance_to(path[i])
				if walked < maxf(direct*2.5,direct+6.0): continue
				seen[dedupe] = true
				# Stunts must actually work with the real motor; plain drops are ballistic.
				if str(found.type) != "drop" and is_instance_valid(stand_in) and not dry_run(stand_in,start,end,str(found.type)):
					rejected[found.type] += 1
					continue
				register(map,start,end,str(found.type),region.navigation_layers)
				entries.append({"type":found.type,"start":[start.x,start.y,start.z],"end":[end.x,end.y,end.z]})
				counts[found.type] += 1
	if is_instance_valid(stand_in): stand_in.free()
	var total: int = 0
	for kind: String in counts: total += int(counts[kind])
	return {"links":total,"by_type":counts,"rejected_by_dry_run":rejected,"samples":samples,"path_queries":path_queries,"milliseconds":Time.get_ticks_msec()-started,"entries":entries,"cached":false}

## Physical candidates from one boundary sample. Returns [{type,start,end}].
static func probe(space: PhysicsDirectSpaceState3D, p: Vector3, n: Vector3, radius: float, max_rise: float, max_gap: float, capsule: CapsuleShape3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var near_ground: Dictionary = ray(space,p+n*(radius+.45)+Vector3.UP*.6,p+n*(radius+.45)-Vector3.UP*.45)
	if not near_ground.is_empty():
		# Floor continues: either a wall (mantle candidate) or a low obstacle.
		var wall: Dictionary = ray(space,p+Vector3.UP*.5,p+Vector3.UP*.5+n*(radius+1.3))
		if wall.is_empty() or absf(Vector3(wall.normal).y) > .2: return result
		var over: Vector3 = Vector3(wall.position)-Vector3(wall.normal)*.6
		var top: Dictionary = ray(space,Vector3(over.x,p.y+WALL_CLIMB_MAX+.1,over.z),Vector3(over.x,p.y+.3,over.z))
		if top.is_empty() or Vector3(top.normal).y < .85: return result
		var rise: float = Vector3(top.position).y-p.y
		if rise < MIN_RISE or rise > WALL_CLIMB_MAX: return result
		# The face must be a real wall all the way up for a kick to find it.
		if rise > max_rise and ray(space,p+Vector3.UP*1.4,p+Vector3.UP*1.4+n*(radius+1.3)).is_empty(): return result
		var landing: Vector3 = Vector3(top.position)-Vector3(wall.normal)*.35
		if not standing_clear(space,landing,capsule): return result
		result.append({"type":"mantle" if rise <= max_rise else "wall_climb","start":p,"end":landing})
		return result
	var low_blocked: bool = not ray(space,p+Vector3.UP*.35,p+Vector3.UP*.35+n*(radius+1.0)).is_empty()
	var high_blocked: bool = not ray(space,p+Vector3.UP*1.7,p+Vector3.UP*1.7+n*(radius+1.0)).is_empty()
	if high_blocked: return result
	var first_gap: bool = true
	for distance: float in [radius+.7,radius+1.5,radius+2.5,radius+3.5]:
		var q: Vector3 = p+n*distance
		if not ray(space,p+Vector3.UP*(1.1 if low_blocked else .5),q+Vector3.UP*(1.1 if low_blocked else .5)).is_empty(): break
		var ground: Dictionary = ray(space,q+Vector3.UP*.6,q-Vector3.UP*(MAX_DROP+.5))
		if ground.is_empty() or Vector3(ground.normal).y < .85:
			first_gap = false
			continue
		var g: Vector3 = ground.position
		var drop: float = p.y-g.y
		if drop >= MIN_RISE and drop <= MAX_DROP:
			if not standing_clear(space,g,capsule): break
			result.append({"type":"hop_drop" if low_blocked else "drop","start":p,"end":g+n*.4})
			# The same ledge is a mantle from below when a wall face is reachable.
			if drop <= WALL_CLIMB_MAX and not low_blocked:
				var face: Dictionary = ray(space,g+Vector3.UP*.5,g+Vector3.UP*.5-n*(distance+.4))
				if not face.is_empty() and absf(Vector3(face.normal).y) < .2:
					var base: Vector3 = Vector3(face.position)+Vector3(face.normal)*(radius+.15)
					base.y = g.y
					result.append({"type":"mantle" if drop <= max_rise else "wall_climb","start":base,"end":p})
			break
		if absf(drop) < .6 and not first_gap and distance <= max_gap and not low_blocked:
			if standing_clear(space,g,capsule): result.append({"type":"gap","start":p,"end":g+n*.5})
			break
		break
	return result

## A hidden stand-in hero used to try each stunt with the real motor at bake time.
## Uses the slowest roster hero so a validated link works for everyone.
static func make_probe(region: NavigationRegion3D) -> HeroActor:
	if region.get_tree().get_first_node_in_group("combat_resolver") == null: return null
	var slowest: String = HeroRoster.IDS[0]
	for id: String in HeroRoster.IDS:
		if HeroRoster.tuning_for(id).ground_speed < HeroRoster.tuning_for(slowest).ground_speed: slowest = id
	var probe := HeroActor.new()
	probe.tuning = HeroRoster.tuning_for(slowest)
	probe.actor_id = "traversal_link_probe"
	probe.team = 0
	probe.name = "TraversalLinkProbe"
	region.add_child(probe)
	probe.remove_from_group("actors")
	probe.set_physics_process(false)
	probe.set_process(false)
	if is_instance_valid(probe.presentation): probe.presentation.visible = false
	return probe

static func dry_run(probe: HeroActor, start: Vector3, end: Vector3, type: String) -> bool:
	probe.reset_actor(start+Vector3.UP*.05)
	var direction: Vector3 = ((end-start)*Vector3(1,0,1)).normalized()
	probe.aim_direction = direction
	var state: Dictionary = {"type":type,"exit":end,"started":0.0,"jumped":false,"retry_at":0.0}
	var time: float = 0.0
	for tick: int in 260:
		var intent := CombatIntent.new()
		intent.aim = direction
		intent.aim_origin = probe.body_point(1.45)
		var result: String = drive(state,probe,intent,time)
		if result != "running": return result == "done"
		probe.intent = intent
		probe._physics_process(1.0/60.0)
		time += 1.0/60.0
		if probe.global_position.y < end.y-8.0 or not probe.alive: return false
	return false

## Shared stunt driver for live bots and bake-time validation. Uses only ordinary inputs.
## state: {"type","exit","started","jumped","retry_at"}. Returns "running", "done" or "failed".
static func drive(state: Dictionary, a: HeroActor, intent: CombatIntent, now: float) -> String:
	var exit: Vector3 = state.exit
	var flat: Vector3 = (exit-a.global_position)*Vector3(1,0,1)
	var grounded: bool = a.motor.grounded()
	intent.move = flat.normalized() if flat.length() > .2 else Vector3.ZERO
	if str(state.type) == "pad":
		# Step onto the pad; once launched, steer the flight toward the landing.
		if a.motor.pad_flight_left > 0: state.flying = true
		if not bool(state.get("flying",false)):
			var to_pad: Vector3 = (Vector3(state.get("entry",a.global_position))-a.global_position)*Vector3(1,0,1)
			intent.move = to_pad.normalized() if to_pad.length() > .15 else Vector3.ZERO
			return "failed" if now-float(state.started) > 4.0 else "running"
		if grounded and a.motor.pad_flight_left <= 0 and flat.length() < 6.0: return "done"
		return "failed" if now-float(state.started) > 9.0 else "running"
	match str(state.type):
		"hop_drop":
			if grounded and not bool(state.jumped):
				intent.jump = true
				state.jumped = true
			intent.jump_held = not grounded
		"gap":
			# Jump from the lip, not from the inset navmesh edge.
			if grounded and not bool(state.jumped) and not intent.move.is_zero_approx():
				var ahead: Vector3 = a.global_position+intent.move*.5
				var floor_ahead: bool = not a.resolver.ray(ahead+Vector3.UP*.3,ahead-Vector3.UP*.7,[a.get_rid()],1).is_empty()
				if not floor_ahead or now-float(state.started) > 1.2:
					intent.jump = true
					state.jumped = true
		"mantle":
			intent.jump_held = true
			if grounded and now >= float(state.retry_at) and a.state == "ready":
				intent.jump = true
				state.retry_at = now+.9
		"wall_climb":
			# Jump at the wall, kick off it near the apex, air-dash forward and up back
			# over the lip, then hold jump into the ledge so the motor mantles.
			var into: Vector3 = intent.move if not intent.move.is_zero_approx() else Vector3(state.get("into",Vector3.FORWARD))
			if not state.has("into"): state.into = into
			into = state.into
			intent.move = into
			intent.aim = into
			intent.jump_held = true
			var phase: String = str(state.get("phase","approach"))
			match phase:
				"approach":
					if not a.motor.can_dash():
						if now-float(state.started) > 1.5: return "aborted"
					elif grounded and a.state == "ready":
						var wall_ahead: bool = not a.resolver.ray(a.body_point(1.0),a.body_point(1.0)+into*.6,[a.get_rid()],1).is_empty()
						if wall_ahead or now-float(state.started) > 1.0:
							intent.jump = true
							state.phase = "rise"
				"rise":
					if not grounded and a.velocity.y < 2.0:
						intent.jump = true
						intent.jump_held = false
						state.phase = "kicked"
					elif grounded and now-float(state.started) > 1.6: return "failed"
				"kicked":
					intent.jump_held = false
					if a.motor.can_dash():
						intent.dash = true
						var pitch: float = deg_to_rad(a.tuning.dash_up_angle)
						intent.aim = (into*cos(pitch)+Vector3.UP*sin(pitch)).normalized()
						state.phase = "dash"
					elif grounded or a.velocity.y < 0: return "aborted"
				"dash":
					var pitch: float = deg_to_rad(a.tuning.dash_up_angle)
					intent.aim = (into*cos(pitch)+Vector3.UP*sin(pitch)).normalized()
					if grounded and a.motor.mode not in ["dash","dash_windup"] and a.state != "mantle" and absf(a.global_position.y-exit.y) > 1.3: return "failed"
	var arrived: bool = flat.length() < 1.2 and absf(a.global_position.y-exit.y) < 1.3 and grounded and a.state != "mantle"
	if str(state.type) in ["drop","hop_drop"] and grounded and a.global_position.y < exit.y+.6 and flat.length() < 2.5 and now-float(state.started) > .2: arrived = true
	if arrived: return "done"
	if a.state == "mantle": state.mantled = true
	if str(state.type) == "mantle" and not bool(state.get("mantled",false)) and now-float(state.started) > 2.0: return "failed"
	if str(state.type) == "wall_climb" and now-float(state.started) > 3.0: return "failed"
	if now-float(state.started) > 3.5: return "failed"
	return "running"

## Jump pads (any node in "temple_jump_pads" or "jump_pads" with a spec destination)
## become links from the pad to its landing, so path planning uses them as shortcuts.
static func register_pads(region: NavigationRegion3D) -> int:
	var map: RID = region.get_navigation_map()
	var count: int = 0
	var pads: Array[Node] = region.get_tree().get_nodes_in_group("temple_jump_pads")
	pads.append_array(region.get_tree().get_nodes_in_group("jump_pads"))
	for node: Node in pads:
		var pad := node as Node3D
		if pad == null or not "spec" in pad: continue
		var spec: Dictionary = pad.get("spec")
		if not spec.has("destination"): continue
		var start: Vector3 = NavigationServer3D.map_get_closest_point(map,pad.global_position)
		var end: Vector3 = NavigationServer3D.map_get_closest_point(map,Vector3(spec.destination))
		if start.distance_to(pad.global_position) > 2.5 or end.distance_to(Vector3(spec.destination)) > 3.0: continue
		var rid: RID = register(map,start,end,"pad",region.navigation_layers)
		registry[rid]["pad"] = weakref(pad)
		count += 1
	return count

static func ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from,to,1)
	return space.intersect_ray(query)

static func standing_clear(space: PhysicsDirectSpaceState3D, feet: Vector3, capsule: CapsuleShape3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY,feet+Vector3.UP*(capsule.height*.5+.08))
	query.collision_mask = 1
	query.margin = .01
	return space.intersect_shape(query,1).is_empty()

static func register(map: RID, start: Vector3, end: Vector3, type: String, layers: int) -> RID:
	var rid: RID = NavigationServer3D.link_create()
	NavigationServer3D.link_set_map(rid,map)
	NavigationServer3D.link_set_bidirectional(rid,false)
	NavigationServer3D.link_set_start_position(rid,start)
	NavigationServer3D.link_set_end_position(rid,end)
	# Wall climbs need a dash charge; they live on their own layer so a bot only plans
	# through them while it has one (see CityBotController path updates).
	NavigationServer3D.link_set_navigation_layers(rid,DASH_LAYER if type == "wall_climb" else layers)
	NavigationServer3D.link_set_enter_cost(rid,{"drop":.5,"hop_drop":1.5,"mantle":2.5,"gap":2.0,"wall_climb":5.0,"pad":2.0}.get(type,2.0))
	NavigationServer3D.link_set_travel_cost(rid,1.0)
	registry[rid] = {"type":type,"start":start,"end":end,"failures":0,"failed_total":0,"uses":0}
	return rid

static func record(rid: RID, success: bool) -> void:
	if not registry.has(rid): return
	var entry: Dictionary = registry[rid]
	if success:
		entry.uses += 1
		entry.failures = maxi(0,int(entry.failures)-1)
		return
	entry.failures += 1
	entry.failed_total += 1
	if int(entry.failures) >= FAILURES_TO_DISABLE: NavigationServer3D.link_set_enabled(rid,false)

static func stats() -> Dictionary:
	var uses: int = 0
	var failures: int = 0
	var disabled: int = 0
	var by_type: Dictionary = {}
	for rid: RID in registry:
		var entry: Dictionary = registry[rid]
		uses += int(entry.uses)
		failures += int(entry.failed_total)
		if not NavigationServer3D.link_get_enabled(rid): disabled += 1
		if not by_type.has(entry.type): by_type[entry.type] = {"uses":0,"failures":0}
		by_type[entry.type].uses += int(entry.uses)
		by_type[entry.type].failures += int(entry.failed_total)
	return {"links":registry.size(),"uses":uses,"failures":failures,"disabled":disabled,"by_type":by_type}
