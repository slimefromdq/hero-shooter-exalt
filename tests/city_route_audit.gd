extends "res://tests/city_traversal_test.gd"
## Full-map route seams: every authored flight, both ways, including side clearance.

func ray(from: Vector3, to: Vector3) -> Dictionary:
	return arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))

func inspect_flight(shell: MeshInstance3D, number: int) -> void:
	var low: Vector3 = shell.get_meta("low")
	var high: Vector3 = shell.get_meta("high")
	var width: float = shell.get_meta("width")
	var along := Vector3(high.x-low.x, 0, high.z-low.z).normalized()
	var side := along.cross(Vector3.UP)
	var shape := CapsuleShape3D.new()
	shape.radius = .35
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	# Check usable width independently of navigation, which can route around a
	# building or cover intruding into one edge of a flight.
	var blocked: Array[String] = []
	for fraction: float in [.06, .5, .94]:
		for lane: float in [-1.0, 0.0, 1.0]:
			var foot: Vector3 = low.lerp(high, fraction) + side * lane * (width*.5-.65)
			query.transform = Transform3D(Basis.IDENTITY, foot + Vector3.UP * 1.04)
			if not arena.get_world_3d().direct_space_state.intersect_shape(query).is_empty():
				blocked.append(str(foot))
	check(blocked.is_empty(), "Flight %d has clear standing lanes: %s" % [number, str(blocked)])
	await walk_route("Flight %d ascent %s" % [number, str(low)], low-along*.8, high+along*.8)
	await walk_route("Flight %d descent %s" % [number, str(high)], high+along*.8, low-along*.8)

func run() -> void:
	arena = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	session = arena.match_controller
	session.freeze_ai = true
	session.player.controller.active = false
	session.player.controller = null
	var started: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec()-started < 30000: await step(1)
	check(session.navigation_ready, "full-map navigation finishes baking")
	session.set_physics_process(false)
	session.player.collision_mask = 1
	var number: int = 0
	for shell: MeshInstance3D in arena.builder.architecture.custom_surfaces:
		if not shell.has_meta("stair_shell"): continue
		number += 1
		await inspect_flight(shell, number)
	check(number == 18, "all eighteen stair flights were audited")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			await walk_route("Promenade corner join %s" % str(Vector2(sx,sz)), Vector3(sx*42,6.5,sz*20), Vector3(sx*23,6.5,sz*15))
			# Floor and continuous guard at the formerly open inside corner.
			check(not ray(Vector3(sx*21.8,7,sz*21.7), Vector3(sx*21.8,6,sz*21.7)).is_empty(), "promenade corner has continuous deck support")
			check(not ray(Vector3(sx*21.8,7,sz*21.9), Vector3(sx*21.8,7,sz*22.6)).is_empty(), "promenade corner has a closing guardrail")
			await walk_route("Approach arcade join %s" % str(Vector2(sx,sz)),Vector3(sx*24,0,sz*36),Vector3(sx*24,0,sz*20))
	await walk_route("Study north-to-south through route", Vector3(47,0,12), Vector3(47,0,45))
	await walk_route("Study south-to-north through route", Vector3(47,0,45), Vector3(47,0,12))
	print("RESULT: ", checks, " checks, ", failures.size(), " failures")
	var file := FileAccess.open("res://artifacts/city-route-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"flights":number,"routes":routes}, "\t"))
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
