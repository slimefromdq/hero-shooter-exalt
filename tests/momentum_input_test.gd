extends SceneTree
## Native-only input and rendered handoff smoke; run with --windowed.
var actor: HeroActor
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func step(count: int = 1) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",label)

func key(code: Key, held: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = held
	Input.parse_input_event(event)

func wheel() -> void:
	for held: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_UP
		event.pressed = held
		Input.parse_input_event(event)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/momentum-native/"+name+".png")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("momentum_input_test requires a native display")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://artifacts/momentum-native")
	HeroRoster.selected = "nimbus"
	var arena: Node3D = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.training.freeze_ai = true
	actor = arena.training.player
	for other: HeroActor in get_nodes_in_group("actors"):
		if other != actor: other.set_physics_process(false)
	await step(5)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	actor.reset_actor(Vector3(0,.01,10))
	await step(4)
	key(KEY_W,true)
	key(KEY_SHIFT,true)
	await step(2)
	wheel()
	await step(36)
	check(actor.motor.mode == "slide" and actor.motor.slide_source == "ground_dash","physical held Shift and wheel pulse flow into ground dash slide")
	check(actor.motor.dash_charges == 1 and actor.velocity.z < -8,"one wheel pulse spends one charge and carries speed")
	check(actor.presentation.movement.failure_left == 0,"ground dash slide has no obsolete airborne-start warning")
	await shot("ground-dash-slide")
	key(KEY_W,false)
	key(KEY_SHIFT,false)
	actor.reset_actor(Vector3(0,6,10))
	var controller: PlayerController = actor.controller as PlayerController
	controller.pitch = deg_to_rad(75)
	controller.yaw = 0
	await step(3)
	wheel()
	await step(12)
	check(actor.motor.mode == "dash" and is_equal_approx(actor.motor.dash_direction.y,.5),"physical wheel dash caps steep camera aim at thirty degrees")
	var rise_speed: float = actor.velocity.y
	await step(6)
	check(actor.velocity.y < rise_speed,"upward dash loses vertical speed under gravity")
	await shot("upward-dash-arc")
	await step(20)
	check(actor.velocity.y < 0 and actor.velocity.z < -8,"dash exits into falling motion while preserving horizontal travel")
	controller.pitch = -.12
	arena.queue_free()
	await step(2)
	print("MOMENTUM INPUT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
