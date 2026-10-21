extends SceneTree
var arena: Node3D
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok:
		failures.append(caption)
		print("FAIL ",caption)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	arena = load("res://scenes/temple/sakura_veil.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.match_controller.freeze_ai = true
	arena.player.controller.active = false
	var start: int = Time.get_ticks_msec()
	while not arena.match_controller.navigation_ready and Time.get_ticks_msec()-start<60000: await process_frame
	check(arena.match_controller.navigation_ready,"navigation ready")
	for door: MuseumSpawnDoor in arena.builder.spawn_gates: door.queue_free()
	await physics_frame
	var builder: TempleBuilder = arena.builder
	check(builder.floor_conflicts.is_empty(),"authored surfaces join without height conflicts: "+str(builder.floor_conflicts.slice(0,8)))
	var minimum := Vector3.INF
	var maximum := -Vector3.INF
	var winding_errors: int = 0
	var steep_faces: int = 0
	for index: int in range(0,builder.floor_triangles.size(),3):
		var a: Vector3 = builder.floor_triangles[index]
		var b: Vector3 = builder.floor_triangles[index+1]
		var c: Vector3 = builder.floor_triangles[index+2]
		for vertex: Vector3 in [a,b,c]:
			minimum = minimum.min(vertex)
			maximum = maximum.max(vertex)
		var normal: Vector3 = (c-a).cross(b-a).normalized()
		if normal.y<=0: winding_errors += 1
		if rad_to_deg(normal.angle_to(Vector3.UP))>25.01: steep_faces += 1
	check(winding_errors==0,"all visible floor faces point upward")
	check(steep_faces==0,"ordinary ramps are at most 25 degrees")
	check(is_equal_approx(maximum.x-minimum.x,320) and is_equal_approx(maximum.z-minimum.z,288),"320 by 288 m playable envelope")
	var map: RID = arena.get_world_3d().navigation_map
	for route: Dictionary in builder.walk_routes:
		var from: Vector3 = route.points[0]
		var to: Vector3 = route.points[-1]
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map,from,to,true)
		check(not path.is_empty() and path[0].distance_to(from)<1.5 and path[-1].distance_to(to)<1.5,"navigation reaches authored route "+route.id)
	check(builder.pads.size()==8,"eight directional pads")
	check(builder.point_labels.size()==5,"five courts")
	check(arena.match_controller.pickups.size()==18,"eighteen health packs")
	var capsule: CapsuleShape3D = arena.player.motor.standing_capsule.duplicate()
	var space := arena.get_world_3d().direct_space_state
	var blocked: int = 0
	var unsupported: int = 0
	var samples: int = 0
	var blocked_sweeps: int = 0
	var sweep_count: int = 0
	for route: Dictionary in builder.walk_routes:
		var previous: Dictionary = {}
		for i: int in range(1,route.points.size()-1):
			var center: Vector3 = route.points[i]
			var tangent: Vector3 = (route.points[i+1]-route.points[i-1])*Vector3(1,0,1)
			var side: Vector3 = tangent.normalized().cross(Vector3.UP)
			for lateral: float in [-1,0,1]:
				var at: Vector3 = center+side*lateral*(route.width/2-1)
				var floor_query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.5,at-Vector3.UP*.5,1)
				var floor_hit: Dictionary = space.intersect_ray(floor_query)
				if floor_hit.is_empty():
					unsupported += 1
					if unsupported<16: print("UNSUPPORTED ",route.id," ",at)
				if not floor_hit.is_empty(): at.y = floor_hit.position.y
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.collision_mask = 1
				query.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*(capsule.height/2+.14))
				var hits: Array[Dictionary] = space.intersect_shape(query,4)
				if not hits.is_empty():
					blocked += 1
					if blocked<35:
						print("BLOCKED ",route.id," ",at)
						for hit: Dictionary in hits:
							if hit.collider==builder.architecture.collision_body:
								var shape = hit.collider.shape_owner_get_owner(hit.collider.shape_find_owner(hit.shape))
								print("  SHAPE ",shape.position," ",shape.shape)
				if previous.has(lateral):
					var segment_start: Vector3 = previous[lateral]
					var sweep_from: Vector3 = segment_start
					var subdivisions: int = maxi(1,ceili(segment_start.distance_to(at)/.5))
					for part: int in range(1,subdivisions+1):
						var sweep_to: Vector3 = segment_start.lerp(at,float(part)/subdivisions)
						if route.kind != "gallery": sweep_to = builder.authored_floor(sweep_to)
						query.transform.origin = sweep_from+Vector3.UP*(capsule.height/2+.14)
						query.motion = sweep_to-sweep_from
						var fractions: PackedFloat32Array = space.cast_motion(query)
						sweep_count += 1
						if fractions[0]<.999:
							blocked_sweeps += 1
							if blocked_sweeps<12: print("SWEEP BLOCKED ",route.id," ",sweep_from," -> ",sweep_to)
						sweep_from = sweep_to

				previous[lateral] = at
				samples += 1
	check(blocked_sweeps==0,"continuous capsule sweeps across walking bands")
	check(unsupported==0,"supported walking bands: %d/%d missing" % [unsupported,samples])
	check(blocked==0,"clear walking bands: %d/%d blocked" % [blocked,samples])
	var court_samples: int = 0
	var court_obstructions: int = 0
	for court: Vector3 in arena.definition.POINTS:
		for x: int in range(-34,35,4):
			for z: int in range(-30,31,4):
				var at: Vector3 = court+Vector3(x,0,z)
				var intentional_solid: bool = false
				for bounds: AABB in builder.furnished_bounds:
					if bounds.grow(.4).has_point(at+Vector3.UP*.95): intentional_solid = true
				if intentional_solid: continue
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.collision_mask = 1
				query.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*(capsule.height/2+.14))
				court_samples += 1
				if not space.intersect_shape(query,1).is_empty():
					court_obstructions += 1
					if court_obstructions<12: print("COURT BLOCKED ",at)
	check(court_obstructions==0,"court grid clearance outside intentional cover and stairs")
	for pad: TempleJumpPad in builder.pads:
		var from: Vector3 = pad.spec.position+Vector3.UP*.08
		var duration: float = pad.spec.flight_time
		var v: Vector3 = (Vector3(pad.spec.destination)-from)/duration+Vector3.UP*22*duration/2
		var clear: bool = true
		for frame: int in range(2,int(duration*60)-2):
			var time: float = frame/60.0
			var at: Vector3 = from+v*time+Vector3.DOWN*11*time*time
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.collision_mask = 1
			query.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*(capsule.height/2+.05))
			if not space.intersect_shape(query,1).is_empty():
				print("PAD BLOCKED ",pad.spec.id," ",at)
				clear = false
				break
		check(clear,"clear launch arc "+pad.spec.id)
	var file := FileAccess.open("res://artifacts/temple/geometry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"route_sweeps":sweep_count,"blocked_sweeps":blocked_sweeps,"route_samples":samples,"court_grid_samples":court_samples,"court_grid_obstructions":court_obstructions,"blocked_capsule_samples":blocked,"unsupported_samples":unsupported,"floor_conflicts":builder.floor_conflicts,"bake_ms":builder.bake_milliseconds,"physical_floor_footprint_m":[maximum.x-minimum.x,maximum.z-minimum.z],"polygon_count":builder.navigation_region.navigation_mesh.get_polygon_count(),"winding_errors":winding_errors,"steep_faces":steep_faces},"\t"))
	print("TEMPLE GEOMETRY ",checks," checks / ",failures.size()," failures")
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
