extends SceneTree
## Run natively: actual InputMap keyboard/mouse events reach the live controller.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func frames(count: int = 2) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func event(action: String, down: bool) -> void:
	var value: InputEvent = InputMap.action_get_events(action)[0].duplicate()
	value.pressed = down
	Input.parse_input_event(value)
	Input.flush_buffered_events()

func press(action: String) -> void:
	event(action,true)
	await frames(2)
	event(action,false)
	await frames(2)

func run() -> void:
	HeroRoster.selected = "nimbus"
	MuseumMatch.start_exploring = true
	var arena: Node3D = load("res://scenes/museum/meridian_museum.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var session: MuseumMatch = arena.match_controller
	var actor: HeroActor = session.player
	var controller: PlayerController = actor.controller
	var start: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec()-start < 30000: await frames(1)
	check(session.navigation_ready and session.exploration,"native Explore entry initializes the museum")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	actor.reset_actor(session.definition.spawn_center(0)+Vector3(-4,.08,3))
	controller.yaw = PI
	await frames(3)
	event("move_forward",true)
	await frames(40)
	event("move_forward",false)
	check(actor.global_position.z > session.definition.spawn_center(0).z+5.7,"native WASD walks through an opened Explore spawn exit")
	actor.reset_actor(Vector3(6,.08,4))
	controller.yaw = -PI/2
	await frames(3)
	event("dash",true)
	event("dash",false)
	await frames(12)
	check(actor.motor.mode == "dash" and actor.global_position.x > 6.2,"native wheel-up pulse starts a museum dash")
	await frames(50)
	check(actor.motor.mode not in ["dash","dash_windup"],"released wheel pulse does not repeatedly dash")
	actor.reset_actor(Vector3(6,.08,4))
	await frames(3)
	event("slide",true)
	await frames(5)
	check(actor.motor.crouched and actor.motor.mode == "crouch","native Shift crouches at low speed in the museum")
	event("slide",false)
	await frames(5)
	if actor.motor.crouched:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = actor.motor.standing_capsule
		query.transform = Transform3D(Basis.IDENTITY,actor.global_position+Vector3.UP*.95)
		query.collision_mask = actor.collision_mask
		query.exclude = [actor.get_rid()]
		print("STAND DIAGNOSTIC at=",actor.global_position," slide=",Input.is_action_pressed("slide")," hits=",actor.get_world_3d().direct_space_state.intersect_shape(query,4))
	check(not actor.motor.crouched,"native Shift release restores standing clearance")
	actor.reset_actor(Vector3(-9,.01,-9.85))
	controller.yaw = 0
	await frames(2)
	event("move_forward",true)
	event("jump",true)
	await frames(3)
	check(actor.motor.traversal.active,"native held Space and W start a museum mantle")
	await frames(24)
	event("jump",false)
	event("move_forward",false)
	check(actor.global_position.y > 1.1,"native mantle reaches the court planter")
	actor.reset_actor(Vector3(-16.7,1,13))
	actor.velocity = Vector3(0,0,-3)
	await frames(2)
	event("jump",true)
	await frames(1)
	event("jump",false)
	check(actor.velocity.y > 7 and actor.velocity.x < -1,"native Space kicks off the cloister wall")
	await press("city_map")
	check(session.hud.overview_open,"native M opens the museum atlas")
	var layer: bool = session.hud.underground_view
	await press("city_map_layer")
	check(session.hud.underground_view != layer,"native B switches atlas floor emphasis")
	await press("city_map")
	check(not session.hud.overview_open,"native M closes the museum atlas")
	await press("training_menu")
	check(session.menu_open and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"native Tab pauses museum and releases the pointer")
	event("dash",true)
	event("dash",false)
	await frames(2)
	await press("training_menu")
	check(not session.menu_open and not paused,"native Tab resumes museum")
	check(not controller.dash_queued,"wheel scrolling while paused cannot queue a gameplay dash")
	await press("reset_scenario")
	check(session.phase == "preparation" and not session.exploration and session.spawn_contains(actor.global_position,actor.team),"native F5 resets the round and returns player to spawn")
	var file := FileAccess.open("res://artifacts/museum/input.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	print("MUSEUM INPUT ",checks," checks; ",failures.size()," failures")
	arena.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
