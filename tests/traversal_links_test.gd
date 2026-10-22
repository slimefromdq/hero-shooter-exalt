extends SceneTree
## Traversal links: baked shortcuts match what the real motor can do, and a body executes them.
var world: Node3D
var resolver: CombatResolver
var region: NavigationRegion3D
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")
	# Fail fast instead of hanging if a script error stops run() midway.
	create_timer(240.0).timeout.connect(func() -> void:
		print("FAIL  traversal test timed out")
		quit(1))

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func step(count: int = 1) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func solid(size: Vector3, at: Vector3) -> void:
	var body: Node3D = Geometry.box(world,size,at,Color.GRAY)
	body.add_to_group("link_test_geometry")

func links_between(from: AABB, to: AABB, type: String = "") -> int:
	var count: int = 0
	for rid: RID in TraversalLinks.registry:
		var entry: Dictionary = TraversalLinks.registry[rid]
		if type != "" and entry.type != type: continue
		if from.has_point(entry.start) and to.has_point(entry.end): count += 1
	return count

func top_of(center: Vector3, size: Vector3) -> AABB:
	return AABB(center+Vector3(-size.x/2-.2,size.y/2-.4,-size.z/2-.2),Vector3(size.x+.4,1.2,size.z+.4))

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	solid(Vector3(80,1,40),Vector3(0,-.5,0))
	# Three plateaus: standing mantle, jump+mantle, and one too tall for any link.
	var low_size := Vector3(8,2.0,8)
	var mid_size := Vector3(8,3.2,8)
	var tall_size := Vector3(8,4.5,8)
	var low := Vector3(-20,1.0,0)
	var mid := Vector3(0,1.6,0)
	var tall := Vector3(20,2.25,0)
	solid(low_size,low)
	solid(mid_size,mid)
	solid(tall_size,tall)
	region = NavigationRegion3D.new()
	var nav := NavigationMesh.new()
	nav.cell_size = .25
	nav.cell_height = .25
	nav.agent_radius = .75
	nav.agent_height = 2.0
	nav.agent_max_climb = .5
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav.geometry_source_group_name = &"link_test_geometry"
	region.navigation_mesh = nav
	world.add_child(region)
	await step(2)
	region.bake_navigation_mesh(false)
	var map: RID = region.get_navigation_map()
	for i: int in 120:
		await step(1)
		NavigationServer3D.map_force_update(map)
		if NavigationServer3D.map_get_closest_point_owner(map,Vector3(0,0,15)) == region.get_rid(): break
	check(region.navigation_mesh.get_polygon_count() > 0,"test navmesh bakes")
	var ground := AABB(Vector3(-40,-.3,-20),Vector3(80,.8,40))
	var walk: PackedVector3Array = NavigationServer3D.map_get_path(map,Vector3(-20,0,8),low+Vector3(0,1,0),true)
	check(walk.is_empty() or walk[-1].distance_to(low+Vector3(0,1,0)) > 1.0,"plateaus are unreachable by walking before links")
	var started: int = Time.get_ticks_msec()
	TraversalLinks.ensure(region,HeroRoster.tuning_for("nimbus"))
	while not TraversalLinks.ready_for(map) and Time.get_ticks_msec()-started < 120000: await step(1)
	var report: Dictionary = TraversalLinks.report_for(map)
	print("LINKS ",JSON.stringify(report))
	check(TraversalLinks.ready_for(map),"asynchronous bake finishes")
	check(links_between(ground,top_of(low,low_size),"mantle") > 0,"2.0 m ledge gets a mantle link")
	check(links_between(ground,top_of(mid,mid_size),"mantle") > 0,"3.2 m ledge gets a jump-and-mantle link")
	check(links_between(ground,top_of(tall,tall_size),"wall_climb") > 0 and links_between(ground,top_of(tall,tall_size),"mantle") == 0,"4.5 m wall gets a wall-kick climb, not a plain mantle")
	check(links_between(top_of(low,low_size),ground,"drop") > 0,"plateau edges get drop links")
	await step(2)
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map,Vector3(-20,0,8),low+Vector3(0,1,0),true)
	check(not path.is_empty() and path[-1].distance_to(low+Vector3(0,1,0)) < 1.0,"navigation paths now reach the plateau through a link")
	# A real body executes a link with the shared driver and real motor.
	var body := HeroActor.new()
	body.tuning = HeroRoster.tuning_for("marshal")
	body.actor_id = "climber"
	world.add_child(body)
	body.set_physics_process(false)
	await step(1)
	var chosen: Dictionary = {}
	for rid: RID in TraversalLinks.registry:
		var entry: Dictionary = TraversalLinks.registry[rid]
		if entry.type == "mantle" and top_of(mid,mid_size).has_point(entry.end): chosen = entry
	if not chosen.is_empty():
		body.reset_actor(Vector3(chosen.start)+Vector3.UP*.05)
		var state: Dictionary = {"type":"mantle","exit":chosen.end,"started":0.0,"jumped":false,"retry_at":0.0}
		var result: String = "running"
		var time: float = 0.0
		for tick: int in 300:
			var intent := CombatIntent.new()
			intent.aim = ((Vector3(chosen.end)-body.global_position)*Vector3(1,0,1)).normalized()
			intent.aim_origin = body.body_point(1.45)
			result = TraversalLinks.drive(state,body,intent,time)
			if result != "running": break
			body.intent = intent
			body._physics_process(1.0/60.0)
			time += 1.0/60.0
		check(result == "done" and body.global_position.y > mid.y+mid_size.y/2-.3,"slowest hero climbs the 3.2 m ledge with ordinary inputs")
	else:
		check(false,"slowest hero climbs the 3.2 m ledge with ordinary inputs")
	var climb: Dictionary = {}
	for rid: RID in TraversalLinks.registry:
		var entry: Dictionary = TraversalLinks.registry[rid]
		if entry.type == "wall_climb" and top_of(tall,tall_size).has_point(entry.end): climb = entry
	var climbed: bool = false
	if not climb.is_empty():
		body.reset_actor(Vector3(climb.start)+Vector3.UP*.05)
		var climb_state: Dictionary = {"type":"wall_climb","exit":climb.end,"started":0.0,"jumped":false,"retry_at":0.0}
		var climb_time: float = 0.0
		var events: Dictionary = {"wall_jump":0}
		body.movement_confirmed.connect(func(kind: String, _a: Vector3, _d: Vector3, _n: Vector3, _s: float) -> void:
			if kind == "wall_jump": events.wall_jump += 1)
		for tick: int in 300:
			var intent := CombatIntent.new()
			intent.aim_origin = body.body_point(1.45)
			var outcome: String = TraversalLinks.drive(climb_state,body,intent,climb_time)
			if outcome != "running":
				climbed = outcome == "done"
				break
			body.intent = intent
			body._physics_process(1.0/60.0)
			climb_time += 1.0/60.0
		check(int(events.wall_jump) > 0,"the climb uses a real wall kick")
	check(climbed and body.global_position.y > tall.y+tall_size.y/2-.3,"slowest hero reaches the 4.5 m roof: jump, wall kick, air dash, mantle")
	if not TraversalLinks.registry.is_empty():
		var rid_any: RID = TraversalLinks.registry.keys()[0]
		for i: int in TraversalLinks.FAILURES_TO_DISABLE: TraversalLinks.record(rid_any,false)
		NavigationServer3D.map_force_update(map)
		await step(1)
		check(not NavigationServer3D.link_get_enabled(rid_any),"repeatedly failed links disable themselves")
	var cache: String = TraversalLinks.cache_path(region.navigation_mesh,HeroRoster.tuning_for("nimbus"))
	check(FileAccess.file_exists(cache),"validated links are cached for the next load")
	var count: int = int(report.links)
	TraversalLinks.clear_map(map)
	check(TraversalLinks.registry.is_empty(),"clearing a map frees its links")
	TraversalLinks.ensure(region,HeroRoster.tuning_for("nimbus"))
	check(TraversalLinks.ready_for(map) and bool(TraversalLinks.report_for(map).cached) and TraversalLinks.registry.size() == count,"cached links register instantly")
	TraversalLinks.clear_map(map)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cache))
	world.queue_free()
	await step(3)
	print("TRAVERSAL LINKS: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
