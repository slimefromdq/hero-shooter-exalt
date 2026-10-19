extends SceneTree
var stage: Node3D
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func step(count: int = 1) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func capture(stem: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/ai-"+stem+".png")
	print("CAPTURE ",stem)

func run() -> void:
	HeroRoster.selected = "nimbus"
	stage = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	var training: TrainingManager = stage.training
	training.player.controller.active = false
	training.scenario = 15
	training.reset_scenario()
	training.debug_view = true
	var bot: HeroActor = training.bots[0]
	var driver: TrainingTacticalController = bot.controller
	training.player.reset_actor(Vector3(0,.01,-13))
	training.player.tuning.max_health = 2000
	training.player.health = 2000
	bot.reset_actor(Vector3(0,.01,0))
	bot.kit.ultimate_charge = 0
	bot.motor.hover_cd = 99
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.position = Vector3(14,8,12)
	camera.look_at(Vector3(7,1,-6))
	camera.fov = 60
	var tracked: bool = false
	var detonated: bool = false
	for frame: int in 220:
		await step()
		if not tracked and is_instance_valid(driver.brain.combat.bomb):
			tracked = true
			await capture("bomb-track")
		if driver.brain.diagnostics.early_detonations > 0:
			detonated = true
			training.debug_view = false
			await capture("bomb-explosion")
			training.debug_view = true
			break
	check(tracked,"rendered tactical Nimbus tracks its own airborne bomb")
	check(detonated,"rendered tactical Nimbus shoots bomb through real rifle resolution")
	check(training.player.health < 2000,"rendered bomb combo damages its opponent")
	await step(10)
	await capture("training-debug")
	training.toggle_menu()
	var common: GameMenu = training.hud.menu.get_child(1)
	common.show_settings()
	await capture("difficulty-settings")
	check(common.find_child("BotDifficulty",true,false) != null,"rendered settings expose four bot difficulties")
	paused = false
	stage.queue_free()
	await step(3)
	stage = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	var session: CityMatch = stage.match_controller
	session.player.controller.active = false
	session.debug_view = true
	while not session.navigation_ready: await step()
	await step(180)
	await capture("city-debug")
	check(session.bots.size() == 11,"rendered match retains full bot roster")
	var overlay: BotDebugOverlay = session.get_node("BotDiagnostics").get_child(0)
	var before: int = overlay.selection
	var select_event := InputEventKey.new()
	select_event.keycode = KEY_BRACKETRIGHT
	select_event.physical_keycode = KEY_BRACKETRIGHT
	select_event.pressed = true
	Input.parse_input_event(select_event)
	await step(2)
	check(overlay.selection == before+1,"native renderer dispatches bracket selection to bot diagnostics")
	select_event.pressed = false
	Input.parse_input_event(select_event)
	var toggle := InputEventKey.new()
	toggle.keycode = KEY_F3
	toggle.physical_keycode = KEY_F3
	toggle.pressed = true
	Input.parse_input_event(toggle)
	await step(2)
	check(not session.debug_view and not overlay.visible,"F3 disables tactical overlay through normal input dispatch")
	toggle.pressed = false
	Input.parse_input_event(toggle)
	toggle = toggle.duplicate() as InputEventKey
	toggle.pressed = true
	Input.parse_input_event(toggle)
	await step(2)
	check(session.debug_view and overlay.visible,"F3 restores tactical overlay through normal input dispatch")
	stage.queue_free()
	await step(4)
	print("BOT RENDER: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
