extends SceneTree
## Run with a real display to verify native mode changes, paused input and scene transitions.
var failures: Array[String] = []
var checks: int = 0
var display: Node

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ", caption)
	if not ok: failures.append(caption)

func settle() -> void:
	await create_timer(.3, true).timeout

func press(key: Key, alt: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.alt_pressed = alt
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func capture(stem: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/fullscreen/" + stem + ".png")

func saved_fullscreen() -> bool:
	var settings := ConfigFile.new()
	settings.load(display.config_path)
	return bool(settings.get_value("display", "fullscreen", false))

func run() -> void:
	display = root.get_node("DisplaySettings")
	var original_path: String = display.config_path
	display.config_path = "user://fullscreen-test.cfg"
	check(InputMap.action_get_events("toggle_fullscreen").size() == 2, "global fullscreen shortcuts are installed independently of the active scene")
	if DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/fullscreen"))
		display.set_fullscreen(false, false)
		root.size = Vector2i(1280,800)
		await settle()
		var original_size: Vector2i = root.size
		var original_position: Vector2i = root.position
		var arena: Node = load("res://scenes/city/meridian_gardens.tscn").instantiate()
		root.add_child(arena)
		current_scene = arena
		var city: CityMatch = arena.match_controller
		city.freeze_ai = true
		while not city.navigation_ready: await process_frame
		city.toggle_menu()
		await press(KEY_F11)
		check(display.is_fullscreen() and paused and city.menu_open, "F11 enters desktop fullscreen while the city pause menu remains open")
		check(root.size == DisplayServer.screen_get_size(root.current_screen), "fullscreen occupies the current monitor at native resolution")
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "fullscreen switching preserves the menu cursor")
		check(saved_fullscreen(), "fullscreen preference is saved for the next launch")
		display.set_fullscreen(false, false)
		display.apply_launch_preferences(PackedStringArray())
		await settle()
		check(display.is_fullscreen(), "startup restores a saved fullscreen preference")
		await capture("city-fullscreen-menu")
		await press(KEY_ENTER, true)
		check(not display.is_fullscreen() and paused, "Alt+Enter leaves fullscreen without resuming the paused match")
		check(root.size == original_size and root.position.distance_to(original_position) <= 2, "returning to windowed restores its previous size and position")
		check(not saved_fullscreen(), "windowed preference is saved")
		display.apply_launch_preferences(PackedStringArray())
		check(not display.is_fullscreen(), "startup respects a saved windowed preference")
		var echo := InputEventKey.new()
		echo.physical_keycode = KEY_F11
		echo.pressed = true
		echo.echo = true
		Input.parse_input_event(echo)
		await settle()
		check(not display.is_fullscreen(), "key repeat cannot repeatedly toggle display mode")
		var city_menu: GameMenu = city.hud.menu
		city_menu.show_settings()
		var toggle: Button = city_menu.find_child("DisplayMode",true,false)
		toggle.pressed.emit()
		await settle()
		check(display.is_fullscreen() and (city_menu.find_child("DisplayMode",true,false) as Button).text.begins_with("WINDOWED"), "city menu display button changes mode and refreshes its label")
		city.toggle_menu()
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "resuming fullscreen play restores captured mouse aiming")
		await capture("city-fullscreen-play")
		city.return_to_training()
		await settle()
		var training: TrainingManager = get_first_node_in_group("training")
		check(training != null and display.is_fullscreen(), "fullscreen survives transition from city to training")
		training.toggle_menu()
		await press(KEY_F11)
		check(not display.is_fullscreen() and paused and training.menu_open, "fullscreen shortcut also works in the paused training console")
		var training_menu: GameMenu = training.hud.menu.get_child(1)
		training_menu.show_settings()
		var training_toggle: Button = training_menu.find_child("DisplayMode",true,false)
		check(training_toggle != null and training_toggle.text.begins_with("FULLSCREEN"), "training console exposes the current display toggle")
		training_toggle.pressed.emit()
		await settle()
		check(display.is_fullscreen() and paused and (training_menu.find_child("DisplayMode",true,false) as Button).text.begins_with("WINDOWED"), "training menu display button toggles mode without closing the console")
		await press(KEY_ENTER, true)
		training.toggle_menu()
		root.size = Vector2i(1600,675)
		await capture("training-ultrawide")
		check(root.get_visible_rect().size.x / root.get_visible_rect().size.y > 2.3, "ultrawide viewport expands without pillarboxing the game")
		root.size = Vector2i(1080,810)
		training.toggle_menu()
		await capture("training-4x3-menu")
		check(training.hud.menu.get_rect().size.is_equal_approx(root.get_visible_rect().size), "training menu fills the resized 4:3 viewport")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(display.config_path))
		display.apply_launch_preferences(PackedStringArray())
		await settle()
		check(display.is_fullscreen(), "a fresh launch defaults to desktop fullscreen when no preference exists")
		display.set_fullscreen(false, false)
		paused = false
		current_scene.queue_free()
		await process_frame
		await settle()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(display.config_path))
	display.config_path = original_path
	print("FULLSCREEN RESULT: ", checks, " checks, ", failures.size(), " failures")
	var file := FileAccess.open("res://artifacts/fullscreen-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"display":DisplayServer.get_name()},"\t"))
	quit(0 if failures.is_empty() else 1)
