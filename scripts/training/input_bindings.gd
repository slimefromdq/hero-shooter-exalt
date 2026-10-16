class_name TrainingInputs
extends RefCounted

static func install() -> void:
	var keys: Dictionary = {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A,
		"move_right": KEY_D, "jump": KEY_SPACE, "dash": KEY_SHIFT,
		"slide": KEY_CTRL, "reload": KEY_R, "melee": KEY_V,
		"guard": KEY_C, "throw": KEY_F, "hover": KEY_E,
		"deflect": KEY_Q, "bomb": KEY_G, "ultimate": KEY_X,
		"training_menu": KEY_TAB, "pause": KEY_ESCAPE,
		"reset_scenario": KEY_F5, "refill": KEY_F6, "debug_view": KEY_F3
	}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.device = -1
			event.physical_keycode = keys[action]
			InputMap.action_add_event(action, event)
	for action: String in ["primary", "aim"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventMouseButton.new()
			event.device = -1
			event.button_index = MOUSE_BUTTON_LEFT if action == "primary" else MOUSE_BUTTON_RIGHT
			InputMap.action_add_event(action, event)
