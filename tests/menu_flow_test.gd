extends SceneTree
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",caption)

func settle(count: int = 4) -> void:
	for index: int in count: await process_frame

func wait_scene(path: String) -> void:
	for index: int in 200:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == path: return
	check(false,"scene transition completed: "+path)

func run() -> void:
	var startup: Node = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(startup)
	current_scene = startup
	await settle()
	check(get_nodes_in_group("actors").is_empty(),"startup does not load a running match")
	var menu: GameMenu = startup.get_child(0).get_child(0)
	menu.mode = "training"
	menu.show_heroes()
	menu.choose("doctor")
	await wait_scene("res://scenes/training/combat_sandbox.tscn")
	var training: TrainingManager = current_scene.training
	check(training.player.kit is DoctorKit and training.bots.size() == 16,"startup selection launches chosen hero into full training")
	training.toggle_menu()
	var paused_menu: GameMenu = training.hud.menu.get_child(1)
	paused_menu.show_settings()
	var original: float = root.get_node("GameSettings").values.sensitivity
	var spin: SpinBox = paused_menu.content.get_child(4).get_child(1)
	spin.value = .0035
	check(is_equal_approx(root.get_node("GameSettings").values.sensitivity,.0035),"settings UI edits its intended setting")
	root.get_node("GameSettings").set_setting("sensitivity",original)
	paused_menu.show_heroes()
	paused_menu.choose("slayer")
	await settle()
	check(not paused and training.player.kit is SlayerKit and training.bots.size() == 16,"training hero selection resets range and resumes")
	training.enter_city()
	await wait_scene("res://scenes/city/meridian_gardens.tscn")
	var city: CityMatch = current_scene.match_controller
	city.freeze_ai = true
	city.player.controller.active = false
	var started: int = Time.get_ticks_msec()
	while not city.navigation_ready and Time.get_ticks_msec()-started < 20000: await process_frame
	check(city.navigation_ready,"city navigation initializes from menu transition")
	var serial: int = city.round_serial
	city.hill.scores = [12.0,34.0]
	var bot_heroes: Array = city.bots.map(func(bot: HeroActor) -> String: return bot.tuning.hero_id)
	city.toggle_menu()
	city.select_hero("doctor")
	check(city.player.kit is DoctorKit and not city.menu_open,"spawn hero switch applies and resumes")
	check(city.round_serial == serial and city.hill.scores == PackedFloat64Array([12.0,34.0]),"spawn switch preserves match progress")
	check(city.player.kit.ultimate_charge == 0,"spawn switch resets only player ultimate")
	check(city.bots.map(func(bot: HeroActor) -> String: return bot.tuning.hero_id) == bot_heroes,"hero change preserves existing bots")
	city.player.reset_actor(Vector3(0,.01,0))
	city.player.kit.ultimate_charge = 78
	city.select_hero("nimbus")
	check(city.pending_hero == "nimbus" and city.player.kit is DoctorKit,"field selection queues without replacing live hero")
	city.player.die()
	city.respawn_actor(city.player)
	check(city.pending_hero == "" and city.player.kit is NimbusKit and city.player.kit.ultimate_charge == 0,"queued hero applies at respawn with zero charge")
	check(city.round_serial == serial,"queued hero change never restarts match")
	var common := GameMenu.new()
	city.hud.add_child(common)
	common.session = city
	common.go_main()
	await wait_scene("res://scenes/menu/main_menu.tscn")
	check(get_nodes_in_group("actors").is_empty() and not paused,"return to main menu clears actors and pause state")
	# Direct launch flags apply only on entry, never when returning to the menu.
	HeroRoster.direct_entry_pending = true
	change_scene_to_file("res://scenes/training/combat_sandbox.tscn")
	await wait_scene("res://scenes/training/combat_sandbox.tscn")
	check(not HeroRoster.direct_entry_pending,"explicit training entry consumes direct-launch flag")
	change_scene_to_file("res://scenes/menu/main_menu.tscn")
	await wait_scene("res://scenes/menu/main_menu.tscn")
	await settle(8)
	check(current_scene.scene_file_path == "res://scenes/menu/main_menu.tscn","direct-launch flag cannot bounce return-to-menu back into a match")
	HeroRoster.selected = "slayer"
	HeroRoster.direct_entry_pending = true
	change_scene_to_file("res://scenes/menu/main_menu.tscn")
	await wait_scene("res://scenes/city/meridian_gardens.tscn")
	city = current_scene.match_controller
	check(city.player.kit is SlayerKit and not HeroRoster.direct_entry_pending,"startup direct entry routes once to the selected city hero")
	var return_menu := GameMenu.new()
	return_menu.session = city
	city.hud.add_child(return_menu)
	return_menu.go_main()
	await wait_scene("res://scenes/menu/main_menu.tscn")
	await settle(8)
	check(current_scene.scene_file_path == "res://scenes/menu/main_menu.tscn","direct city entry also permits returning to main menu")
	current_scene.queue_free()
	await settle()
	print("MENU FLOW: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
