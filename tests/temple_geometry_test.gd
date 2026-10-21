extends SceneTree
var arena: Node3D
var checks: int = 0
var failures: Array[String] = []
var measurements: Dictionary = {}

func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok:
		failures.append(caption)
		print("FAIL ",caption)

func ray(a: Vector3, b: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a,b,1)
	return arena.get_world_3d().direct_space_state.intersect_ray(query)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	arena = load("res://scenes/temple/sakura_veil.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var session: TempleMatch = arena.match_controller
	session.freeze_ai = true
	arena.player.controller.active = false
	var start: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec()-start < 60000: await process_frame
	check(session.navigation_ready,"navigation bake registered")
	await physics_frame
	var builder: TempleBuilder = arena.builder
	var d: TempleMapDefinition = arena.definition
	var map: RID = arena.get_world_3d().navigation_map
	measurements["bake_ms"] = builder.bake_milliseconds
	measurements["polygon_count"] = builder.navigation_region.navigation_mesh.get_polygon_count()
	var minimum := Vector3.INF
	var maximum := -Vector3.INF
	for vertex: Vector3 in builder.floor_triangles:
		minimum = minimum.min(vertex)
		maximum = maximum.max(vertex)
	measurements["physical_floor_footprint_m"] = [maximum.x-minimum.x,maximum.z-minimum.z]
	check(maximum.x-minimum.x >= 319.9 and maximum.z-minimum.z >= 287.9,"measured floors occupy the 320 by 288 m envelope")
	check(builder.point_labels.size() == 5,"all five courts finish building")
	check(session.actors.size() == 12 and session.bots.size() == 11,"6v6 population")
	check(session.pickups.size() == 18,"all health packs instantiated")
	for pickup: CityHealthPack in session.pickups:
		check(not ray(pickup.position+Vector3.UP*.5,pickup.position-Vector3.UP*.5).is_empty(),"pickup has real floor support at "+str(pickup.position))
	for index: int in 5:
		var at: Vector3 = d.POINTS[index]
		check(not ray(at+Vector3.UP,at-Vector3.UP).is_empty(),"point %d is supported" % index)
		for other: int in 5:
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map,at,d.POINTS[other],true)
			check(not path.is_empty() and path[-1].distance_to(d.POINTS[other]) < 2,"ordinary path point %d to %d" % [index,other])
	var blocked_travel: int = 0
	var travel_samples: int = 0
	var shielded_samples: int = 0
	var sight_samples: int = 0
	var blocked_capsules: int = 0
	var capsule := CapsuleShape3D.new()
	capsule.radius = .3
	capsule.height = 1.8
	for entry: Dictionary in builder.routes:
		var points: Array = entry.points
		check(entry.width >= (24 if entry.kind == "main" else 16),"route width %s sector %d" % [entry.kind,entry.sector])
		for index: int in range(1,points.size()):
			var a: Vector3 = points[index-1]
			var b: Vector3 = points[index]
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map,a,b,true)
			if path.is_empty() or path[-1].distance_to(b) >= 3: print("BAD LEG ",entry.kind," ",entry.sector," ",index," ",a," -> ",b," projected ",NavigationServer3D.map_get_closest_point(map,b)," ends ",path[-1] if not path.is_empty() else Vector3.INF)
			check(not path.is_empty() and path[-1].distance_to(b) < 3,"route connected %s %d leg %d" % [entry.kind,entry.sector,index])
			# Actor-center rays expose intersecting roofs, walls and floors along paths.
			for fraction: float in [.2,.4,.6,.8]:
				var at: Vector3 = a.lerp(b,fraction)
				var floor_hit: Dictionary = ray(at+Vector3.UP*2.1,at-Vector3.UP)
				if not floor_hit.is_empty() and floor_hit.normal.y > .65: at.y = floor_hit.position.y
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = capsule
				query.collision_mask = 1
				var floor_y: float = floor_hit.get("normal",Vector3.UP).y
				var lift: float = .1+.3*(1/maxf(.67,floor_y)-1)
				query.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*(.9+lift))
				var contacts: Array[Dictionary] = arena.get_world_3d().direct_space_state.intersect_shape(query,1)
				if not contacts.is_empty():
					blocked_capsules += 1
					print("CAPSULE BLOCKED ",entry.kind," ",entry.sector," ",at)
					if contacts[0].collider == builder.architecture.collision_body:
						var obstruction: CollisionShape3D = builder.architecture.collision_body.get_child(contacts[0].shape)
						print("CAPSULE SHAPE ",obstruction.position," ",obstruction.shape)
				travel_samples += 1
				var hit: Dictionary = ray(at+Vector3.UP*.4,at+Vector3.UP*1.9)
				if not hit.is_empty():
					blocked_travel += 1
					print("BLOCKED ",entry.kind," ",entry.sector," leg ",index," at ",at," hit ",hit.position," normal ",hit.normal," shape ",hit.shape)
					var collider: CollisionShape3D = builder.architecture.collision_body.get_child(hit.shape)
					print("OBSTRUCTION ",collider.position," ",collider.shape)
					if collider.shape is ConcavePolygonShape3D and hit.face_index >= 0:
						var triangles: PackedVector3Array = collider.shape.get_faces()
						print("FACE ",triangles[hit.face_index*3]," ",triangles[hit.face_index*3+1]," ",triangles[hit.face_index*3+2])
						for source: Dictionary in builder.routes:
							if hit.face_index >= source.face_begin and hit.face_index < source.face_end: print("FROM ",source.kind," ",source.sector)
				if entry.kind in ["lower","upper"]:
					sight_samples += 1
					var court: Vector3 = d.POINTS[entry.sector+1]+Vector3.UP*1.6
					if not ray(court,at+Vector3.UP*1.6).is_empty(): shielded_samples += 1
	check(blocked_travel == 0,"no route center headroom obstruction (%d/%d blocked)" % [blocked_travel,travel_samples])
	check(blocked_capsules == 0,"standing capsules clear all authored route centers (%d blocked)" % blocked_capsules)
	check(shielded_samples >= sight_samples*.5,"majority of flank transit screened from destination court")
	measurements["route_samples"] = travel_samples
	measurements["blocked_route_samples"] = blocked_travel
	measurements["blocked_capsule_samples"] = blocked_capsules
	measurements["flank_sight_samples"] = sight_samples
	measurements["flank_screened_samples"] = shielded_samples
	for team: int in 2:
		for stage: int in 3:
			var center: Vector3 = d.room_center(team,stage)
			var goal: Vector3 = d.POINTS[0 if team == 0 else 4] if stage == 0 else d.POINTS[1 if team == 0 else 3] if stage == 1 else d.POINTS[2]
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map,center,goal,true)
			check(not path.is_empty() and path[-1].distance_to(goal) < 2,"spawn ordinary egress team %d stage %d" % [team,stage])
	# Eye-height visibility from plausible defensive positions: all three ingress
	# families must never be visible from a single sample position.
	var omniscient: int = 0
	for sector: int in 4:
		var exits: Array[Vector3] = []
		for entry: Dictionary in d.connections():
			if entry.sector == sector: exits.append(entry.points[-2]+Vector3.UP*1.6)
		var center: Vector3 = d.POINTS[sector+1]
		for offset: Vector3 in [Vector3.ZERO,Vector3(-14,0,-12),Vector3(14,0,12),Vector3(-14,0,12),Vector3(14,0,-12)]:
			var visible: int = 0
			for exit: Vector3 in exits:
				if ray(center+offset+Vector3.UP*1.6,exit).is_empty(): visible += 1
			if visible == 3: omniscient += 1
	check(omniscient == 0,"no sampled defender sees main plus both flank approaches")
	measurements["all_ingress_visible_positions"] = omniscient
	measurements["checks"] = checks
	measurements["failures"] = failures
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/temple"))
	var file := FileAccess.open("res://artifacts/temple/geometry.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(measurements,"\t"))
	file.close()
	print("TEMPLE GEOMETRY: %d checks, %d failures / %d of %d flank samples screened" % [checks,failures.size(),shielded_samples,sight_samples])
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
