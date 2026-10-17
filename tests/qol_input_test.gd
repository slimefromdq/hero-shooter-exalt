extends SceneTree
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",caption)

func wheel(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = pressed
	Input.parse_input_event(event)

func run() -> void:
	var arena: Node = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var training: TrainingManager = arena.training
	training.freeze_ai = true
	var player: HeroActor = training.player
	var controller: PlayerController = player.controller
	player.controller = null
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for fps: int in [30,60,144]:
		Engine.max_fps = fps
		controller.clear_action_queue()
		wheel(true)
		wheel(false)
		await process_frame
		await process_frame
		check(controller.gather_intent(1.0/fps).dash,"real wheel pulse survives release / %d fps" % fps)
		check(not controller.gather_intent(1.0/fps).dash,"wheel pulse consumed once / %d fps" % fps)
	training.toggle_menu()
	wheel(true)
	wheel(false)
	await process_frame
	training.toggle_menu()
	check(not controller.gather_intent(1.0/60).dash,"paused wheel scrolling never becomes a resumed dash")
	var range_node: PracticeRange = training.practice_range
	var target_button: Dictionary = range_node.buttons.filter(func(item: Dictionary) -> bool: return item.caption == "TOGGLE FIRING")[0]
	player.reset_actor(target_button.at+Vector3(0,-.85,1.5))
	player.aim_direction = (target_button.at-(player.global_position+Vector3.UP*1.5)).normalized()
	range_node._process(0)
	check(range_node.prompt.contains("TOGGLE FIRING"),"nearby visible panel offers F prompt")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	key.pressed = true
	range_node._unhandled_input(key)
	check(range_node.firing,"F activates the selected physical panel")
	var cover: Node3D = Geometry.box(arena,Vector3(2,3,.2),player.global_position+Vector3(0,1.5,-.7),Color.GRAY)
	await physics_frame
	await process_frame
	range_node._process(0)
	check(range_node.prompt == "","solid cover suppresses interaction prompt")
	cover.queue_free()
	player.reset_actor(Vector3(0,.01,11))
	range_node._process(0)
	check(range_node.prompt == "","distant panels never offer interaction")
	player.controller = controller
	player.motor.transition("hover")
	player.set_physics_process(false)
	controller.pitch = .5
	for index: int in 10: await process_frame
	var canopy: StandardMaterial3D = player.presentation.canopy.material_override
	check(is_equal_approx(canopy.albedo_color.a,.2),"local umbrella fades while inside aim-view region")
	var enemy: HeroActor = training.bots[0]
	enemy.motor.transition("hover")
	for index: int in 3: await process_frame
	check(is_equal_approx((enemy.presentation.canopy.material_override as StandardMaterial3D).albedo_color.a,1),"other Nimbus canopies remain opaque")
	seed(7401)
	var expected_random: int = randi()
	seed(7401)
	player.presentation.sound.play_tone(333,.03,.1)
	check(randi() == expected_random,"presentation audio cannot consume gameplay random state")
	Engine.max_fps = 0
	print("QOL INPUT: %d checks, %d failures" % [checks,failures])
	arena.queue_free()
	await process_frame
	await create_timer(.25).timeout
	quit(1 if failures else 0)
