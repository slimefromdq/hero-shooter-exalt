extends SceneTree
var checks: int = 0
var failures: Array[String] = []
var arena: Node
var training: TrainingManager

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func step(count: int = 2) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func event(action: String, down: bool) -> void:
	var value: InputEvent = InputMap.action_get_events(action)[0].duplicate()
	value.pressed = down
	Input.parse_input_event(value)
	Input.flush_buffered_events()

func press(action: String, count: int = 2) -> void:
	event(action,true)
	await step(count)
	event(action,false)
	await step(2)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/stitch-"+label+".png")
	print("CAPTURE ",label)

func run() -> void:
	HeroRoster.selected = "stitch"
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	training = arena.training
	training.freeze_ai = true
	training.scenario = 1
	training.reset_scenario()
	training.despawn_bots()
	var actor: HeroActor = training.player
	var controller := actor.controller as PlayerController
	controller.yaw = .06
	controller.pitch = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var target: HeroActor = training.spawn_bot(0,Vector3(0,.1,3))
	await step(10)
	var k := actor.kit as StitchKit
	check(k != null and actor.health == 225,"native scene selects Stitch at 225 HP")
	await press("primary",42)
	check(target.health < 250 and target.statuses.stitch_count(actor) >= 2,"native held LMB throws marking needles")
	check(not k.shears_mode,"native ranged weapon stays in needle mode")
	await press("bomb")
	check(is_instance_valid(k.thread) and k.thread.valid(),"native 1 attaches Red Thread")
	await capture("thread")
	await press("hover")
	check(k.mobility_cd > 12,"native Q launches hook with thirteen-second cooldown")
	await step(40)
	check(actor.state == "ready" and actor.global_position.z > 10,"native Spoolstep rejects actor anchor and retains control")
	actor.reset_actor(Vector3(0,.1,11))
	await step(4)
	await press("deflect")
	check(k.concealed and k.deflect_cd == 0,"native E starts concealment without starting cooldown")
	await step(20)
	await capture("play-dead")
	await press("dash")
	check(k.concealed and actor.motor.mode not in ["dash","dash_windup"],"wheel dash cannot bypass concealment restrictions")
	await press("slide",8)
	check(k.concealed and actor.motor.mode != "slide","Shift retains crouched concealment without sliding")
	await press("deflect")
	check(not k.concealed and k.deflect_cd > 11.8,"native E cancellation starts twelve-second cooldown")
	actor.reset_actor(Vector3(0,.1,11))
	await step(3)
	await press("deflect")
	await step(25)
	await press("primary")
	check(not k.concealed and k.deflect_cd > 11.8,"native LMB reveals and starts cooldown before attacking")
	actor.reset_actor(Vector3(0,.1,11))
	target.reset_actor(Vector3(0,.1,3))
	for i: int in 3: target.statuses.add_stitch(actor,3,4)
	await step(3)
	await press("ultimate")
	check(actor.state == "stitch_windup" and k.ultimate_charge < 1,"native 2 starts visible committed windup")
	await capture("curtain-windup")
	await step(70)
	check(actor.state == "ready" and target.health < 100,"native Curtain Call damages once and returns control")
	await capture("curtain-finish")
	training.start_stitch_drill()
	await step(5)
	check(training.bots.size() == 3 and training.bots[2].kit is StitchKit,"dedicated drill spawns stationary, moving and tactical Stitch targets")
	check(training.bots[2].controller is TrainingTacticalController,"Stitch drill uses fair tactical bot perception")
	training.toggle_menu()
	arena.queue_free()
	await step(4)
	print("STITCH INPUT: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/stitch-input-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
