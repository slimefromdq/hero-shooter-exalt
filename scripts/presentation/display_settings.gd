extends Node
## Shared by city and training, including menus while the scene tree is paused.
signal display_mode_changed

var config_path: String = "user://display.cfg"
var windowed_size := Vector2i(1280, 800)
var windowed_position := Vector2i.ZERO
var windowed_mode: Window.Mode = Window.MODE_WINDOWED
var has_windowed_position: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not InputMap.has_action("toggle_fullscreen"):
		InputMap.add_action("toggle_fullscreen")
		var function_key := InputEventKey.new()
		function_key.physical_keycode = KEY_F11
		InputMap.action_add_event("toggle_fullscreen", function_key)
		var shortcut := InputEventKey.new()
		shortcut.physical_keycode = KEY_ENTER
		shortcut.alt_pressed = true
		InputMap.action_add_event("toggle_fullscreen", shortcut)
	if DisplayServer.get_name() == "headless": return
	apply_launch_preferences(OS.get_cmdline_args())

func apply_launch_preferences(args: PackedStringArray) -> void:
	if DisplayServer.get_name() == "headless": return
	# Explicit engine/test window settings take precedence over the saved preference.
	if args.has("--windowed") or args.has("-w") or args.has("--resolution") or args.has("--script") or args.has("-s"):
		return
	var settings := ConfigFile.new()
	settings.load(config_path)
	var wants_fullscreen: bool = bool(settings.get_value("display", "fullscreen", true))
	if args.has("--fullscreen") or args.has("-f"): wants_fullscreen = true
	set_fullscreen(wants_fullscreen, false)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen") and not event.is_echo():
		toggle_fullscreen()
		get_viewport().set_input_as_handled()

func is_fullscreen() -> bool:
	return get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]

func toggle_fullscreen() -> void:
	set_fullscreen(not is_fullscreen())

func set_fullscreen(enabled: bool, save_preference: bool = true) -> void:
	if DisplayServer.get_name() == "headless": return
	var window: Window = get_window()
	if enabled and not is_fullscreen():
		windowed_mode = window.mode
		windowed_size = window.size
		windowed_position = window.position
		has_windowed_position = true
		# Borderless desktop fullscreen permits normal Alt+Tab and native resolution.
		window.mode = Window.MODE_FULLSCREEN
	elif not enabled and is_fullscreen():
		window.mode = windowed_mode
		if windowed_mode == Window.MODE_WINDOWED:
			var usable: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
			window.size = windowed_size.min(usable.size)
			var desired: Vector2i = windowed_position if has_windowed_position else usable.position + (usable.size - window.size) / 2
			window.position = desired.clamp(usable.position, usable.end - window.size)
	if save_preference:
		var settings := ConfigFile.new()
		settings.set_value("display", "fullscreen", enabled)
		var result: Error = settings.save(config_path)
		if result != OK: push_warning("Could not save display preference: " + error_string(result))
	display_mode_changed.emit()

func button_text() -> String:
	return ("WINDOWED" if is_fullscreen() else "FULLSCREEN") + "  /  F11 · ALT+ENTER"
