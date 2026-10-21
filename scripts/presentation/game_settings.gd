extends Node
signal changed
const PATH := "user://game_settings.cfg"
const DEFAULTS := {"sensitivity":.0025,"camera_distance":3.0,"normal_fov":82.0,"aim_fov":42.0,"ads_multiplier":1.0,"combat_camera_effects":1.0,"movement_camera_effects":1.0,"master":1.0,"combat":1.0,"feedback":1.0,"bot_difficulty":1.0}
var values: Dictionary = DEFAULTS.duplicate()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for name: String in ["Combat","Feedback"]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,name)
	var config := ConfigFile.new()
	if config.load(PATH) == OK: load_settings(config)
	apply_audio()

func load_settings(config: ConfigFile) -> void:
	if int(config.get_value("meta","version",0)) not in [1,2]: return
	for key: String in DEFAULTS:
		var saved: Variant = config.get_value("settings",key,DEFAULTS[key])
		if saved is float or saved is int: values[key] = clamp_value(key,float(saved))
	if int(config.get_value("meta","version",0)) == 1 and is_equal_approx(float(values.aim_fov),60): values.aim_fov = 42.0

func clamp_value(key: String, value: float) -> float:
	match key:
		"bot_difficulty": return float(clampi(roundi(value),0,3))
		"sensitivity": return clampf(value,.0005,.008)
		"camera_distance": return clampf(value,2,6)
		"normal_fov": return clampf(value,70,105)
		"aim_fov": return clampf(value,30,75)
		"ads_multiplier": return clampf(value,.25,2)
	return clampf(value,0,1)

func set_setting(key: String, value: float) -> void:
	if not DEFAULTS.has(key): return
	values[key] = clamp_value(key,value)
	apply_audio()
	var config := ConfigFile.new()
	config.set_value("meta","version",2)
	for field: String in values: config.set_value("settings",field,values[field])
	var result: Error = config.save(PATH)
	if result != OK: push_warning("Settings save failed: "+error_string(result))
	changed.emit()

func apply_audio() -> void:
	for key: String in ["master","combat","feedback"]:
		var index: int = AudioServer.get_bus_index(key.capitalize())
		if index < 0: continue
		AudioServer.set_bus_mute(index,float(values[key]) <= 0)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(.0001,float(values[key]))))

func restore_defaults() -> void:
	for key: String in DEFAULTS: set_setting(key,DEFAULTS[key])
	get_node("/root/DisplaySettings").set_fullscreen(true)

func apply_controller(controller: Node) -> void:
	for key: String in ["sensitivity","camera_distance","normal_fov","aim_fov","ads_multiplier","movement_camera_effects","combat_camera_effects"]: controller.set(key,values[key])
