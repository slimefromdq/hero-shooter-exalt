class_name GameMenu
extends Control
## Reusable startup, pause, settings and hero selection flow.
var session: Node
var advanced: Control
@onready var settings_store: Node = get_node("/root/GameSettings")
var content: VBoxContainer
var heading: Label
var page: String = ""
var mode: String = "city"
const HEROES := {
	"nimbus":["FIELD AGENT","Precise umbrella rifle, aerial Hover and explosive setups.","Q Hover · E Deflect · 1 Pocket Bomb · 2 Final Notice"],
	"slayer":["MONSTER HUNTER","Shotgun pressure, bleeding knives and directional boot captures.","Q Silver Knives · E Boot Rush · 1 Snare · 2 Heads Will Roll"],
	"marshal":["MAIN TANK","Lead the advance behind an arcane barrier.","Q Forward March · E Rallying Command · 1 Orbital Barrage · 2 Verdict"],
	"samson":["PEEL SUPPORT","Rescue allies, cross-examine threats, and establish Witness Protection.","Q Intervene · E Cross-Examination · 1 Cease and Desist · 2 Roach Court"],
	"doctor":["MAIN SUPPORT","Hold RMB to heal allies; use LMB for precise sidearm fire.","Q House Call · E Ward Round · 1 Prescription · 2 Exemplary Condition"],
	"huddle":["MOBILE OFF-TANK","A colony with seed fire, two flight bursts and ally protection.","Q Scatterbound · E Screen · 1 Personal Space · 2 Nobody Gets Squished"],
	"relay":["DRONE SUPPORT","RMB assigns the healing drone. Recall to recharge; attack while it heals.","Q Kickstart · E Shock Delivery · 1 Recall / Self · 2 Full Circuit"],
	"dynamo":["STORM TANK","Prespin a ramping minigun, build physical walls and gather enemies.","Q Stormcharge · E Wall · 1 Lodestone · 2 Storm Dominion"],
	"stitch":["DOLL ASSASSIN","Needles sew marks; close shears consume them. Thread prey and approach unseen.","Q Spoolstep · E Play Dead · 1 Red Thread · 2 Curtain Call"],
	"wisp":["GHOST DPS","Pistols mark souls; dashes load shotgun shells. Land the core to detonate.","Q Ghoststep · E Phase · 1 Spectral Lift · 2 Death Ballet"]}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(.025,.045,.075,.96)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,30)
	add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	scroll.add_child(content)
	get_node("/root/DisplaySettings").display_mode_changed.connect(refresh_display)
	show_home()

func refresh_display() -> void:
	var control: Button = find_child("DisplayMode",true,false)
	if is_instance_valid(control): control.text = get_node("/root/DisplaySettings").button_text()

func clear(title: String, subtitle: String) -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	heading = label(title,32,Color("e9d5a6"))
	label(subtitle,15,Color("b4d2d5"))
	content.add_child(HSeparator.new())

func label(caption: String, size: int = 16, color: Color = Color("edf0e1"), parent: Node = null) -> Label:
	var result := Label.new()
	result.text = caption
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size",size)
	result.add_theme_color_override("font_color",color)
	(parent if parent != null else content).add_child(result)
	return result

func button(caption: String, action: Callable, parent: Node = null) -> Button:
	var result := Button.new()
	result.text = caption
	result.custom_minimum_size.y = 43
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17313f")
	style.border_color = Color("718d8e")
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	result.add_theme_stylebox_override("normal",style)
	result.pressed.connect(action)
	(parent if parent != null else content).add_child(result)
	return result

func show_home() -> void:
	page = "home"
	clear("EXALT" if session == null else "SESSION PAUSED", "Eight heroes. Celestial streets and living history." if session == null else "Choose your next move.")
	if session == null:
		button("PLAY MATCH  /  6 v 6 KING OF THE HILL",func() -> void: mode = "city"; show_heroes())
		button("MUSEUM  /  CAPTURE + PAYLOAD",show_museum)
		button("TRAINING  /  PRACTICE RANGE",func() -> void: mode = "training"; show_heroes())
	else:
		button("RESUME",session.toggle_menu)
		button("CHANGE HERO",show_heroes)
		if session is MuseumMatch: button("MUSEUM LIGHTING",show_museum_lighting)
		button("RESTART MATCH" if session is CityMatch else "RESTART EXERCISE",session.restart_match if session is CityMatch else session.reset_scenario)
		button("ENTER TRAINING" if session is CityMatch else "PLAY CITY MATCH",func() -> void: mode = "training" if session is CityMatch else "city"; launch())
		if session is CityMatch:
			button("EXPLORATION / TOGGLE BOTS",session.toggle_exploration)
		elif advanced != null:
			button("ADVANCED TRAINING TOOLS",func() -> void: visible = false; advanced.visible = true)
	button("SETTINGS & CONTROLS",show_settings)
	if session != null: button("MAIN MENU",go_main)
	button("QUIT",func() -> void: get_tree().quit())
	content.get_child(3).grab_focus()

func show_heroes() -> void:
	page = "heroes"
	clear("SELECT YOUR HERO", "Pick a hero to enter the field." if session == null else ("In the safe room: switch now. Elsewhere: queue for respawn. Ultimate charge resets." if session is CityMatch else "Switching resets the active exercise."))
	var grid := GridContainer.new()
	grid.columns = 2 if get_viewport_rect().size.x >= 1000 else 1
	grid.add_theme_constant_override("h_separation",16)
	grid.add_theme_constant_override("v_separation",12)
	content.add_child(grid)
	for id: String in HeroRoster.IDS:
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		card.add_child(row)
		var portrait := TextureRect.new()
		portrait.texture = load("res://assets/portraits/"+id+(".svg" if id == "samson" else ".png"))
		portrait.custom_minimum_size = Vector2(85,110)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(portrait)
		var detail := VBoxContainer.new()
		detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(detail)
		label(id.to_upper()+" / "+HEROES[id][0],18,Color("eed8a2"),detail)
		label(HEROES[id][1],14,Color("d6e6df"),detail)
		label(HEROES[id][2].replace("Q ",TrainingInputs.key_label("hover")+" ").replace("E ",TrainingInputs.key_label("deflect")+" ").replace("1 ",TrainingInputs.key_label("bomb")+" ").replace("2 ",TrainingInputs.key_label("ultimate")+" "),12,Color("9ed6d3"),detail)
		button("SELECT "+id.to_upper(),choose.bind(id),detail)
	button("BACK",show_home)

func choose(id: String) -> void:
	HeroRoster.selected = id
	if session == null: launch()
	else:
		session.select_hero(id)
		if session.menu_open: session.toggle_menu()
		if is_inside_tree(): show_home()

func show_settings() -> void:
	page = "settings"
	clear("SETTINGS & CONTROLS","Changes save automatically and apply in every mode.")
	var display: Node = get_node("/root/DisplaySettings")
	var display_control: Button = button(display.button_text(),func() -> void: display.toggle_fullscreen())
	display_control.name = "DisplayMode"
	var settings: Array = [["Mouse sensitivity","sensitivity",.0005,.008,.0005],["Camera distance (m)","camera_distance",2,6,.1],["Normal FOV","normal_fov",70,105,1],["Aim FOV","aim_fov",45,75,1],["Master volume","master",0,1,.05],["Combat volume","combat",0,1,.05],["Feedback volume","feedback",0,1,.05]]
	for setting: Array in settings:
		var row := HBoxContainer.new()
		content.add_child(row)
		var name_label: Label = label(setting[0],15,Color("edf0e1"),row)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var spin := SpinBox.new()
		spin.min_value = setting[2]
		spin.max_value = setting[3]
		spin.step = setting[4]
		spin.value = settings_store.values[setting[1]]
		spin.custom_minimum_size.x = 160
		row.add_child(spin)
		spin.value_changed.connect(func(value: float) -> void: settings_store.set_setting(setting[1],value))
	var movement_camera := CheckButton.new()
	movement_camera.text = "Movement camera effects"
	movement_camera.button_pressed = float(settings_store.values.get("movement_camera_effects",1)) >= .5
	content.add_child(movement_camera)
	movement_camera.toggled.connect(func(on: bool) -> void: settings_store.set_setting("movement_camera_effects",1.0 if on else 0.0))
	add_bot_difficulty_selector(content)
	label("WASD move · Space jump / wall kick · Hold Space + move to mantle",14)
	var bindings := PackedStringArray()
	for action: String in ["dash","slide","reload","melee","throw","guard","hover","deflect","bomb","ultimate","interact"]:
		bindings.append("%s: %s" % ["Crouch / slide" if action == "slide" else action.capitalize(),TrainingInputs.key_label(action)])
	label("  /  ".join(bindings),13)
	label("Air-dash slide: press Shift in the last 0.12 s before impact. Slide shots cost no ammo while loaded.",13)
	label("Hold Shift at low speed to crouch; WASD crouch-walks at half speed. Enough momentum takes priority as a slide.",13)
	button("RESTORE DEFAULTS",func() -> void: settings_store.restore_defaults(); show_settings())
	if session != null:
		button("EXPORT BOT DIAGNOSTICS",func() -> void:
			var result: Error = BotDebug.export_tree(get_tree())
			if result == OK: session.show_notice("BOT METRICS SAVED / user://bot_metrics.json")
			else: session.show_notice("BOT METRICS / "+error_string(result)))
	button("BACK",show_home)

func show_museum() -> void:
	page = "museum"
	clear("MERIDIAN MUSEUM","Capture the Astrolabe in three thirds, then escort the artifact through three checkpoints.")
	for choice: String in ["ATTACK","DEFEND","EXPLORE"]:
		button(choice,func() -> void:
			MuseumMatch.selected_side = 1 if choice == "DEFEND" else 0
			MuseumMatch.start_exploring = choice == "EXPLORE"
			mode = "museum"
			show_heroes())
	add_museum_lighting_selector()
	button("BACK",show_home)

func launch() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var scene: String = "res://scenes/training/combat_sandbox.tscn" if mode == "training" else ("res://scenes/museum/meridian_museum.tscn" if mode == "museum" else "res://scenes/city/meridian_gardens.tscn")
	get_tree().change_scene_to_file.call_deferred(scene)

func go_main() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file.call_deferred("res://scenes/menu/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if session == null and page != "home" and event.is_action_pressed("pause"):
		show_home()
		get_viewport().set_input_as_handled()

func add_museum_lighting_selector() -> OptionButton:
	var row := HBoxContainer.new()
	content.add_child(row)
	var title: Label = label("MUSEUM LIGHTING",15,Color("eed8a2"),row)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selector := OptionButton.new()
	selector.name = "MuseumLightingPreset"
	selector.custom_minimum_size = Vector2(260,43)
	var current: String = session.arena.builder.lighting.current_preset if session is MuseumMatch else MuseumLighting.load_preference()
	for caption: String in MuseumLighting.TITLES: selector.add_item(caption)
	selector.select(MuseumLighting.IDS.find(current))
	row.add_child(selector)
	selector.item_selected.connect(func(index: int) -> void:
		var id: String = MuseumLighting.IDS[index]
		MuseumLighting.choose(id)
		if session is MuseumMatch: session.arena.builder.lighting.apply_preset(id))
	return selector

func show_museum_lighting() -> void:
	page = "museum_lighting"
	clear("MUSEUM LIGHTING","Choose a time of day. Changes apply immediately and save for your next visit.")
	add_museum_lighting_selector()
	label("COOL DAWN / blue morning light and pale mist",15)
	label("ROSY AFTERNOON / brilliant rose sunlight and pink clouds",15)
	label("STARRY NIGHT / moonlight, stars, and warm glowing galleries",15)
	button("BACK",show_home)

func add_bot_difficulty_selector(parent: Node) -> OptionButton:
	label("BOT DIFFICULTY",14,Color("edf0e1"),parent)
	var selector := OptionButton.new()
	selector.name = "BotDifficulty"
	for title: String in BotSkillProfile.NAMES: selector.add_item(title)
	selector.select(int(settings_store.values.get("bot_difficulty",1)))
	selector.item_selected.connect(func(index: int) -> void: settings_store.set_setting("bot_difficulty",index))
	parent.add_child(selector)
	return selector
