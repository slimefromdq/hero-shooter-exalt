class_name TrainingInputs
extends RefCounted

static func keyboard_bindings() -> Dictionary:
	return {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A,
		"move_right": KEY_D, "jump": KEY_SPACE, "interact": KEY_F,
		"slide": KEY_SHIFT, "reload": KEY_R, "melee": KEY_5,
		"guard": KEY_6, "throw": KEY_4, "hover": KEY_Q,
		"deflect": KEY_E, "bomb": KEY_1, "ultimate": KEY_2,
		"training_menu": KEY_TAB, "pause": KEY_ESCAPE,
		"reset_scenario": KEY_F5, "refill": KEY_F6, "debug_view": KEY_F3,
		"city_map": KEY_M, "city_map_layer": KEY_B
	}

static func install() -> void:
	var keys: Dictionary = keyboard_bindings()
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.device = -1
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)

	for action: String in ["primary", "aim", "dash"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventMouseButton.new()
			event.device = -1
			event.button_index = MOUSE_BUTTON_WHEEL_UP if action == "dash" else (MOUSE_BUTTON_LEFT if action == "primary" else MOUSE_BUTTON_RIGHT)
			InputMap.action_add_event(action, event)

static func key_label(action: String) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventMouseButton:
			return {MOUSE_BUTTON_WHEEL_UP:"WHEEL UP",MOUSE_BUTTON_LEFT:"LMB",MOUSE_BUTTON_RIGHT:"RMB"}.get(event.button_index,"MOUSE %d" % event.button_index)
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode).to_upper()
	return "—"
