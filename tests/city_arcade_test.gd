extends "res://tests/city_traversal_test.gd"
## Physical acceptance for the shopping concourse and repaired architecture.

func cast(from: Vector3, to: Vector3) -> Dictionary:
	return arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))

func drop_to_roof(caption: String, from: Vector3, minimum: float) -> void:
	var player: HeroActor = session.player
	player.reset_actor(from)
	player.intent = CombatIntent.new()
	await step(150)
	check(player.alive and player.is_on_floor() and player.position.y >= minimum, caption + " supports an actual landing capsule")
	print("ROOF ",caption," landed=",player.position)

func run() -> void:
	arena = load("res://scenes/city/meridian_gardens.tscn").instantiate() as Node3D
	root.add_child(arena)
	current_scene = arena
	session = arena.match_controller
	session.freeze_ai = true
	var controller: PlayerController = session.player.controller
	controller.active = false
	session.player.controller = null
	var started: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec()-started < 30000: await step(1)
	check(session.navigation_ready,"arcade and street navigation finish baking")
	session.set_physics_process(false)
	session.player.collision_mask = 1 # Geometry traversal; team gates have separate integration checks.
	for point: Vector3 in [Vector3(-18,0,-18),Vector3(0,0,-8),Vector3(18,0,-18),Vector3(-18,0,0),Vector3(18,0,0),Vector3(-18,0,18),Vector3(0,0,8),Vector3(18,0,18)]:
		var floor_hit: Dictionary = cast(point+Vector3(0,-4.5,0),point+Vector3(0,-5.5,0))
		check(not floor_hit.is_empty() and absf(floor_hit.position.y+5)<.08,"continuous concourse floor at "+str(Vector2(point.x,point.z)))
		var ceiling_hit: Dictionary = cast(point+Vector3(0,-3,0),point+Vector3(0,-.3,0))
		check(not ceiling_hit.is_empty() and ceiling_hit.position.y >= -1.6,"physical ceiling below the park at "+str(Vector2(point.x,point.z)))
	for shop: Vector3 in session.definition.shopping_arcade_shops:
		var side: float = signf(shop.x)
		await walk_route("Through shop "+str(Vector2(shop.x,shop.z)),Vector3(side*7,-5,shop.z),Vector3(side*18,-5,shop.z))
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = .12
		query.shape = sphere
		query.collision_mask = 1
		query.transform = Transform3D(Basis.IDENTITY,controller.camera.global_position)
		check(arena.get_world_3d().direct_space_state.intersect_shape(query).is_empty(),"shop shoulder-camera clears walls and ceiling")
	await walk_route("Central gallery around foundation and kiosks",Vector3(0,-5,18),Vector3(0,-5,-18))
	for side_x: float in [-1.0,1.0]:
		for side_z: float in [-1.0,1.0]:
			await walk_route("Arcade corner street exit "+str(Vector2(side_x,side_z)),Vector3(side_x*18,-5,side_z*18),Vector3(side_x*18,0,side_z*40))
	for side: float in [-1.0,1.0]:
		await walk_route("Arcade station connection "+str(side),Vector3(0,-5,side*35),Vector3(0,0,side*60))
	check(not cast(Vector3(0,-3.6,10),Vector3(0,-3.6,-10)).is_empty(),"the central structural drum breaks underground diagonal fire")
	check(not cast(Vector3(5.1,-3.6,12),Vector3(5.1,-3.6,2)).is_empty(),"kiosk backboards provide opaque standing-height cover")
	check(not cast(Vector3(-5,-4.1,12),Vector3(-5,-4.1,6)).is_empty(),"low counters provide solid crouching-height cover")
	check(cast(Vector3(7,-3.6,0),Vector3(18,-3.6,0)).is_empty(),"front and rear shop doors preserve an open cross-route")
	check(not session.hill.contains(Vector3(6,-5,0)),"arcade occupants cannot capture the hill through its floor")
	check(cast(Vector3(5, 3, 4), Vector3(5, 16, 4)).is_empty(), "point has open sky for aerial fights")
	for side: float in [-1.0, 1.0]:
		check(cast(Vector3(side*23,8.3,side*8),Vector3(side*7,1.4,side*7)).is_empty(), "promenade can pressure the point through the removed canopy")
		await walk_route("Direct hill stair ascent " + str(side),Vector3(0,-5,side*9),Vector3(0,0,side*26))
		await walk_route("Direct hill stair descent " + str(side),Vector3(0,0,side*26),Vector3(0,-5,side*9))
		await walk_route("Mall cross-route below hill stair " + str(side),Vector3(0,-5,side*18),Vector3(8,-5,side*18))
		await walk_route("Station passage below hill stair " + str(side),Vector3(0,-5,side*18),Vector3(0,-5,side*35))
	await drop_to_roof("Closed apartment gable",Vector3(34,23,48),18.8)
	await drop_to_roof("Garden pavilion vault",Vector3(-34,10,0),6.6)
	for side: float in [-1.0,1.0]:
		await walk_route("Flush inner stair landing "+str(side),Vector3(side*17.7,0,-side*17),Vector3(side*23,6.5,side*2.5))
		await walk_route("Inner stair return to street "+str(side),Vector3(side*23,6.5,side*2.5),Vector3(side*17.7,0,-side*17))
	var atlas_event := InputEventAction.new()
	atlas_event.action = "city_map"
	atlas_event.pressed = true
	session.player.position = Vector3(6,-5,0)
	session.hud.overview_open = false
	session.hud._unhandled_input(atlas_event)
	check(session.hud.overview_open and session.hud.underground_view,"opening the atlas below ground selects the arcade layer")
	var layer_event := InputEventAction.new()
	layer_event.action = "city_map_layer"
	layer_event.pressed = true
	session.hud._unhandled_input(layer_event)
	check(not session.hud.underground_view,"B switches the atlas back to surface routes")
	print("RESULT: ",checks," checks, ",failures.size()," failures")
	var file := FileAccess.open("res://artifacts/city-arcade.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"physical_routes":routes},"\t"))
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
