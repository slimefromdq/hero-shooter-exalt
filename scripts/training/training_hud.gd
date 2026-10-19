class_name TrainingHUD
extends CanvasLayer

var training: TrainingManager
var canvas: Control
var menu: Control
var font: SystemFont
var bold: SystemFont
var hit_timer: float = 0.0
var hit_head: bool = false
var hit_text: String = ""
var ink: Color = Color("213a44")
var paper: Color = Color("f0efdf")
var mint: Color = Color("a0eed7")
var coral: Color = Color("f4947e")
var check_controls: Dictionary = {}
var scenario_control: OptionButton
var display_settings: Node
var display_button: Button
var numbers: DamageNumbers

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	bold = SystemFont.new()
	bold.font_names = font.font_names
	bold.font_weight = 700
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.draw.connect(draw_hud)
	numbers = DamageNumbers.new()
	numbers.viewer = training.player
	numbers.font = bold
	canvas.add_child(numbers)
	display_settings = get_node("/root/DisplaySettings")
	build_menu()

func refresh_display_button() -> void:
	display_button.text = display_settings.button_text()

func _process(delta: float) -> void:
	hit_timer = maxf(0.0, hit_timer - delta)
	canvas.queue_redraw()

func rect(at: Vector2, size: Vector2, color: Color, radius: int = 0) -> void:
	if radius <= 0:
		canvas.draw_rect(Rect2(at, size), color)
	else:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		canvas.draw_style_box(style, Rect2(at, size))

func label_at(text: String, at: Vector2, size: int = 18, color: Color = Color.WHITE, heavy: bool = false) -> void:
	canvas.draw_string(bold if heavy else font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func draw_hud() -> void:
	if not is_instance_valid(training.player):
		return
	canvas.draw_set_transform_matrix(HUDLayout.fit(canvas.size, Vector2(1440,900)))
	var p: HeroActor = training.player
	# Masthead, division insignia and live-session marker.
	rect(Vector2(30, 28), Vector2(48, 48), ink, 3)
	canvas.draw_arc(Vector2(54, 52), 14.0, PI, TAU, 20, mint, 2.0, true)
	canvas.draw_line(Vector2(54, 38), Vector2(54, 65), mint, 2.0, true)
	canvas.draw_arc(Vector2(50, 65), 4.0, 0, PI, 12, mint, 2.0, true)
	label_at("FIELD DIVISION", Vector2(92, 49), 21, ink, true)
	label_at("COMBAT RESEARCH  /  " + p.tuning.hero_id.to_upper(), Vector2(92, 71), 11, ink)
	rect(Vector2(574, 28), Vector2(292, 37), Color(0.10, 0.20, 0.24, 0.92), 3)
	canvas.draw_circle(Vector2(593, 46), 3.5, mint)
	label_at("LIVE TRAINING", Vector2(607, 51), 13, paper, true)
	label_at("%02d:%02d" % [int(training.elapsed) / 60, int(training.elapsed) % 60], Vector2(797, 51), 14, mint)
	rect(Vector2(1215, 28), Vector2(195, 37), paper, 3)
	label_at("TAB   TRAINING CONSOLE", Vector2(1230, 51), 12, ink, true)
	label_at("EXERCISE  %02d" % (training.scenario + 1), Vector2(32, 125), 12, ink, true)
	label_at(TrainingManager.SCENARIOS[training.scenario].to_upper(), Vector2(32, 154), 25, ink, true)
	label_at("%02d TARGETS    /    %02d ELIMINATIONS" % [training.bots.size(), training.eliminations], Vector2(32, 178), 12, ink)
	label_at("%d HITS    ·    %d DAMAGE" % [training.hits, int(training.damage_total)], Vector2(32, 199), 12, ink)
	if training.scenario == 6:
		label_at("ENTER THE RING  /  HOLD %s TO BLOCK" % TrainingInputs.key_label("guard"),Vector2(32,238),13,ink,true)
		label_at("STRIKE RANGE %.1f m   ·   INTERVAL %.1f s" % [minf(training.guard_test_range,p.tuning.melee_range),training.guard_test_interval],Vector2(32,260),12,ink)
	if training.notice_time > 0.0:
		var notice_width: float = font.get_string_size(training.notice, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 36
		rect(Vector2(720 - notice_width / 2, 96), Vector2(notice_width, 35), Color(0.10, 0.20, 0.24, 0.88), 3)
		label_at(training.notice, Vector2(738 - notice_width / 2, 119), 14, mint)
	var cheats: Array[String] = []
	if training.infinite: cheats.append("INFINITE RESOURCES")
	if training.god_mode: cheats.append("INVULNERABLE")
	if training.freeze_ai: cheats.append("AI FROZEN")
	if training.target_invulnerable: cheats.append("TARGET IMMUNE")
	if training.target_shields > 0: cheats.append("TARGET SHIELDS")
	if training.target_health_override: cheats.append("TARGET HP PRESET")
	if not cheats.is_empty():
		rect(Vector2(1040, 82), Vector2(370, 28), coral, 3)
		label_at("DEBUG  /  " + " · ".join(cheats), Vector2(1050, 101), 10, ink, true)
	# Crosshair and scoped stance have the same true camera-center aim point.
	var center := Vector2(720, 450)
	if p.alive and not training.menu_open:
		var cross_color: Color = paper if p.permits("primary") else coral
		for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var bloom: float = (p.presentation.fire_flash * 40.0 + p.velocity.length() * .35) if p.kit is SlayerKit else 0.0
			canvas.draw_line(center + direction * (7 + bloom), center + direction * (14 + bloom), Color(0, 0, 0, 0.35), 4)
			canvas.draw_line(center + direction * (7 + bloom), center + direction * (14 + bloom), cross_color, 2)
		canvas.draw_circle(center, 1.3, cross_color)
		CombatHUD.ammo(canvas,p,bold,center)
		MovementHUD.draw(canvas,p,bold,center)
		if p.state == "ultimate":
			canvas.draw_arc(center, 250, 0, TAU, 100, Color(0.65, 0.95, 0.85, 0.7), 1, true)
			canvas.draw_arc(center, 220, -PI / 2, -PI / 2 + TAU * minf(1, p.kit.ultimate_age / p.tuning.ultimate_preparation), 100, mint, 3, true)
			label_at("FINAL NOTICE  /  " + ("ACQUIRED" if p.kit.ultimate_age >= p.tuning.ultimate_preparation else "PREPARING"), Vector2(592, 690), 14, mint, true)
		if hit_timer > 0.0:
			for d: Vector2 in [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1), Vector2(1,1)]:
				canvas.draw_line(center + d * 17, center + d * 25, coral if hit_head else mint, 3, true)
			CombatHUD.hit(canvas,bold,hit_text,center,hit_head,hit_timer)
	# Health / magazine / ability rail.
	CombatHUD.vitals(canvas,p,font,bold,Vector2(32,816))
	rect(Vector2(450, 738), Vector2(88, 126), paper, 4)
	label_at(CareHUD.weapon_label(p), Vector2(460, 763), 11, ink, true)
	label_at("%02d" % p.kit.ammo, Vector2(460, 811), 30 if p.tuning.magazine >= 100 else 37, ink, true)
	label_at("/ %02d" % p.tuning.magazine, Vector2(460,830) if p.tuning.magazine >= 100 else Vector2(503,808), 11 if p.tuning.magazine >= 100 else 13, ink)
	label_at("R  LOAD" if not p.kit.reloading else "LOAD %.1f" % p.kit.reload_remaining, Vector2(460, 844), 10, ink)
	ability_card(550, TrainingInputs.key_label("dash"), "DASH %d/%d" % [p.motor.dash_charges,p.tuning.dash_capacity], "READY", p.motor.dash_cd, p.tuning.dash_cooldown, p.motor.dash_charges > 0)
	if p.kit is CareKit:
		var labels: Array[String] = CareHUD.labels(p)
		var times: Array[float] = CareHUD.cooldowns(p)
		for i: int in 3: ability_card(663+i*113,TrainingInputs.key_label(["hover","deflect","bomb"][i]),labels[i],"",times[i],CareHUD.durations(p)[i])
		rect(Vector2(470,674),Vector2(720,31),Color(.06,.13,.17,.85),4)
		label_at(CareHUD.detail(p) + "  " + CareHUD.status(p),Vector2(480,695),14,paper,true)
	elif p.kit is SlayerKit:
		var hunter := p.kit as SlayerKit
		var t := p.tuning as SlayerTuning
		ability_card(663,TrainingInputs.key_label("hover"),"SILVER KNIVES","%d / %d" % [hunter.knives,t.knife_charges],0 if hunter.knives > 0 else hunter.knife_timer,t.knife_recharge)
		ability_card(776,TrainingInputs.key_label("deflect"),"BOOT","RUSH",hunter.deflect_cd,t.boot_cooldown)
		ability_card(889,TrainingInputs.key_label("bomb"),"TOSS SNARE","%d / %d" % [hunter.snares,t.trap_limit],0 if hunter.snares > 0 else hunter.snare_timer,t.trap_recharge)
	else:
		ability_card(663, TrainingInputs.key_label("hover"), "UMBRELLA", "HOVER", p.motor.hover_cd, p.tuning.hover_cooldown)
		ability_card(776, TrainingInputs.key_label("deflect"), "RETURN", "DEFLECT", p.kit.deflect_cd, p.tuning.deflect_cooldown)
		ability_card(889, TrainingInputs.key_label("bomb"), "POCKET", "BOMB", p.kit.bomb_cd, p.tuning.bomb_cooldown)
	rect(Vector2(1014, 738), Vector2(190, 126), mint if p.kit.ultimate_charge >= 100.0 else Color("bdd5c5"), 4)
	label_at("%s    %s" % [TrainingInputs.key_label("ultimate"),CareHUD.ultimate_label(p)], Vector2(1030, 763), 11, ink, true)
	label_at("READY" if p.kit.ultimate_charge >= 100.0 else "%02d%%" % int(p.kit.ultimate_charge), Vector2(1030, 810), 29, ink, true)
	label_at(CareHUD.ultimate_detail(p), Vector2(1030, 844), 11, ink)
	rect(Vector2(1216, 738), Vector2(194, 126), Color(0.10, 0.20, 0.24, 0.88), 4)
	label_at("%s   GUARD" % TrainingInputs.key_label("guard"), Vector2(1231, 763), 12, paper, true)
	rect(Vector2(1231, 776), Vector2(164, 4), Color("4c6269"))
	rect(Vector2(1231, 776), Vector2(164 * p.close.guard_meter / 100.0, 4), mint)
	label_at("%s   MELEE ENGAGE" % TrainingInputs.key_label("melee"), Vector2(1231, 809), 11, paper)
	label_at("%s   THROW / COUNTER" % TrainingInputs.key_label("throw"), Vector2(1231, 842), 11, paper)
	label_at("W A S D  MOVE    SPACE  JUMP / WALL KICK    HOLD SPACE + MOVE  MANTLE    %s  CROUCH / SLIDE    %s" % [TrainingInputs.key_label("slide"),CareHUD.secondary_label(p)], Vector2(32, 889), 11, ink, true)
	label_at("F5  RESET    F6  REFILL    F3  TELEMETRY", Vector2(1098, 889), 10, ink)
	if p.state != "ready" or p.motor.mode not in ["ground", "air"]:
		label_at(p.state.to_upper().replace("_", " ") + "  /  " + p.motor.mode.to_upper(), Vector2(600, 721), 13, paper, true)
	if training.route_running or training.scenario == 5:
		label_at("ROUTE  %.2f s    BEST  %.2f s" % [training.route_time, training.route_best], Vector2(32, 240), 18, ink, true)
		label_at("Falls %d / Overshoots %d / Landing %.2f m" % [training.route_falls, training.route_overshoots, training.route_accuracy], Vector2(32, 265), 12, ink)
		label_at("HOLD SPACE + MOVE into a ledge: MANTLE   /   PRESS SPACE in air by a wall: WALL KICK   /   %s: UMBRELLA VAULT" % TrainingInputs.key_label("hover"),Vector2(32,288),11,ink)
	if training.debug_view:
		draw_debug(p)
	draw_statuses(p)
	ControlFeedback.draw(canvas,p,bold,Vector2(32,320))
	if is_instance_valid(training.practice_range) and training.practice_range.prompt != "": label_at(training.practice_range.prompt,Vector2(490,610),19,mint,true)
	if training.feedback != null:
		rect(Vector2(25,263),Vector2(260,31),Color(.02,.05,.07,.86))
		label_at("%d KILLS / %d STREAK" % [training.feedback.kills,training.feedback.streaks.get(p.get_instance_id(),0)],Vector2(32,285),15,paper,true)
		if training.feedback.banner_time > 0:
			label_at(training.feedback.banner.replace("\n"," / "),Vector2(400,210),18,paper,true)
	if p.last_hit_age < 0.3:
		canvas.draw_rect(Rect2(3, 3, 1434, 894), Color(0.95, 0.3, 0.22, (0.3 - p.last_hit_age) * 2), false, 6)
	if not p.alive:
		rect(Vector2(0, 0), Vector2(1440, 900), Color(0.08, 0.16, 0.2, 0.55))
		label_at("AGENT DOWN", Vector2(552, 405), 46, paper, true)
		label_at("F5  RESTART EXERCISE     /     TAB  TRAINING CONSOLE", Vector2(514, 451), 15, mint)

func ability_card(x: float, key: String, top: String, bottom: String, cd: float, total: float, available: bool = false) -> void:
	rect(Vector2(x, 738), Vector2(101, 126), paper if cd <= 0.0 or available else Color("ccd3c8"), 4)
	label_at(key, Vector2(x + 12, 761), 12, ink, true)
	label_at(top, Vector2(x + 12, 803), 10, ink)
	label_at(bottom if cd <= 0.0 else "%.1f s" % cd, Vector2(x + 12, 827), 15, ink, true)
	rect(Vector2(x + 12, 844), Vector2(77, 4), Color("adbcb5"))
	rect(Vector2(x + 12, 844), Vector2(77 * (1 - clampf(cd / maxf(.01,total), 0, 1)), 4), Color("428d80"))

func draw_statuses(p: HeroActor) -> void:
	var status: String = ""
	for kind: String in p.statuses.effects:
		if kind in ["root","slow"]: continue
		status += "%s %.1fs   " % [kind.replace("max_health","MAX HP WOUND").to_upper(),p.statuses.effects[kind].remaining]
	if status != "": label_at(status,Vector2(475,675),16,coral,true)
	if p.kit is SlayerKit:
		var hunter := p.kit as SlayerKit
		label_at("Q KNIVES   ·   E BOOT RUSH   ·   1 TOSS SNARE   ·   4 GRAB / SLAM",Vector2(430,706),12,paper,true)
		if hunter.action_hint_time > 0:
			label_at(hunter.action_hint,Vector2(470,620),18,coral,true)
		elif hunter.boot_slow_time > 0:
			label_at("BOOT RECOVERY  /  SPEED %d%%" % roundi(hunter.movement_scale() * 100),Vector2(475,675),14,paper,true)
		if training.debug_view:
			label_at("SHOT %.1f HP / %d PELLETS   ·   KNIFE %.1fs   SNARE %.1fs" % [hunter.last_shot_damage,hunter.last_shot_pellets,hunter.knife_timer,hunter.snare_timer],Vector2(430,650),12,paper)

func rebuild_menu() -> void:
	if display_settings.display_mode_changed.is_connected(refresh_display_button):
		display_settings.display_mode_changed.disconnect(refresh_display_button)
	remove_child(menu)
	menu.queue_free()
	check_controls.clear()
	build_menu()
	menu.visible = training.menu_open

func draw_debug(p: HeroActor) -> void:
	rect(Vector2(30, 300), Vector2(335, 227), Color(0.09, 0.19, 0.23, 0.91), 4)
	label_at("TELEMETRY / ORDINARY RULES" if not training.infinite else "TELEMETRY / OVERRIDE ACTIVE", Vector2(44, 326), 12, mint, true)
	var lines: Array[String] = [
		"STATE  %s / %.2f s" % [p.state, p.state_time],
		"MOTION  %s / %.2f s" % [p.motor.mode, p.motor.timer],
		"VELOCITY  %.2f m/s" % p.velocity.length(),
		"HP %.1f   SHIELD %.1f   GUARD %.1f" % [p.health, p.shields, p.close.guard_meter],
		"THROW GRACE %.2f  /  COUNTER %.2f s" % [p.close.grace, p.tuning.counter_window],
		"RIFLE %.0f / %.0f   BOMB %.0f   ULT %.0f" % [p.tuning.rifle_damage, p.tuning.rifle_damage * p.tuning.head_multiplier, p.tuning.bomb_damage, p.tuning.ultimate_damage],
		"TETHER —    CHARGES 1    LOG %d" % p.resolver.events.size()
	]
	for index: int in lines.size():
		label_at(lines[index], Vector2(44, 353 + index * 23), 12, paper)
	var camera: Camera3D = (p.controller as PlayerController).camera
	for bot: HeroActor in training.bots:
		if not bot.alive or camera.is_position_behind(bot.global_position): continue
		var inverse: Transform2D = HUDLayout.fit(canvas.size, Vector2(1440,900)).affine_inverse()
		var head: Vector2 = inverse * camera.unproject_position(bot.global_position + Vector3.UP * 1.9)
		var feet: Vector2 = inverse * camera.unproject_position(bot.global_position)
		var height: float = feet.y - head.y
		canvas.draw_rect(Rect2(head.x - height * 0.22, head.y, height * 0.44, height), coral, false, 1)
		canvas.draw_line(Vector2(head.x - height * 0.22, head.y + height * 0.21), Vector2(head.x + height * 0.22, head.y + height * 0.21), mint, 1)

func build_advanced_menu() -> void:
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	menu.visible = false
	var veil := ColorRect.new()
	veil.color = Color(0.06, 0.14, 0.18, 0.88)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(veil)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 100
	panel.offset_top = 80
	panel.offset_right = -100
	panel.offset_bottom = -80
	var style := StyleBoxFlat.new()
	style.bg_color = paper
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	menu.add_child(panel)
	var scroll := ScrollContainer.new()
	panel.add_child(scroll)
	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)
	scroll.add_child(root)
	menu_label(root, "TRAINING CONSOLE", 30)
	menu_label(root, "Session paused · defaults are experiments · TAB / ESC returns to the field", 14)
	display_button = button(root, display_settings.button_text(), display_settings.toggle_fullscreen)
	display_settings.display_mode_changed.connect(refresh_display_button)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 42)
	root.add_child(columns)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 9)
	columns.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 9)
	columns.add_child(right)
	menu_label(left, "01  /  EXERCISE & TARGETS", 18)
	button(left,"Play Slayer  /  monster hunter",training.select_hero.bind("slayer"))
	button(left,"Play Nimbus  /  field agent",training.select_hero.bind("nimbus"))
	button(left,"Play Marshal / shield tank",training.select_hero.bind("marshal"))
	button(left,"Play Doctor / main support",training.select_hero.bind("doctor"))
	button(left,"Play Huddle / mobile off-tank",training.select_hero.bind("huddle"))
	button(left,"Play Relay / drone support",training.select_hero.bind("relay"))
	button(left,"Play Dynamo / storm tank",training.select_hero.bind("dynamo"))
	button(left,"Play Wisp / ghost DPS",training.select_hero.bind("wisp"))
	button(left,"Relay circuit / drone and battery",training.start_roster_drill.bind("relay"))
	button(left,"Dynamo siege / walls and storm",training.start_roster_drill.bind("dynamo"))
	button(left,"Wisp ballet / marks and air combos",training.start_roster_drill.bind("wisp"))
	button(left,"Huddle rescue / flight, screen, wave",training.start_huddle_drill)
	button(left,"Doctor rounds / heal, cleanse, escape",training.start_care_drill.bind("doctor"))
	button(left,"Marshal drill / shield and barrage",training.start_care_drill.bind("marshal"))
	button(left,"Start Slayer hunt  /  full kit practice",training.start_slayer_hunt)
	button(left,"Cleanse player statuses",func() -> void: training.player.statuses.cleanse())
	var scenarios := OptionButton.new()
	scenario_control = scenarios
	for option: String in TrainingManager.SCENARIOS: scenarios.add_item(option)
	left.add_child(scenarios)
	scenarios.item_selected.connect(func(index: int) -> void: training.scenario = index; training.reset_scenario())
	button(left,"Start guard drill  /  hold %s" % TrainingInputs.key_label("guard"),training.start_guard_drill)
	button(left,"Play Meridian Gardens  /  6v6 King of the Hill",training.enter_city)
	menu_label(left,"Tactical AI difficulty",14)
	var difficulty := OptionButton.new()
	difficulty.name = "TacticalDifficulty"
	for title: String in BotSkillProfile.NAMES: difficulty.add_item(title)
	difficulty.select(int(get_node("/root/GameSettings").values.get("bot_difficulty",1)))
	difficulty.item_selected.connect(func(index: int) -> void: get_node("/root/GameSettings").set_setting("bot_difficulty",index))
	left.add_child(difficulty)
	var profile := OptionButton.new()
	for option: String in TrainingManager.PROFILES: profile.add_item(option)
	profile.select(2)
	left.add_child(profile)
	button(left, "Spawn target (maximum 8)", func() -> void: training.spawn_bot(profile.selected))
	button(left, "Despawn all targets", training.despawn_bots)
	button(left, "Reset exercise  [F5]", training.reset_scenario)
	button(left, "Refill all resources  [F6]", training.refill_all)
	button(left, "Refill cooldowns only", func() -> void: training.player.motor.refill_dashes(); training.player.motor.hover_cd = 0; training.player.kit.deflect_cd = 0; training.player.kit.bomb_cd = 0; training.player.close.guard_cd = 0)
	button(left, "Refill ultimate only", func() -> void: training.player.kit.ultimate_charge = 100)
	check(left, "Freeze bot intent", false, func(on: bool) -> void: training.freeze_ai = on)
	check(left, "Infinite resources  [CHEAT]", false, func(on: bool) -> void: training.infinite = on)
	check(left, "Player invulnerability  [CHEAT]", false, func(on: bool) -> void: training.god_mode = on)
	check(left, "Hitboxes & actor state  [F3]", false, func(on: bool) -> void: training.debug_view = on)
	spin(left, "Bot reaction delay (s)", 0.22, 0.05, 1.5, 0.01, func(value: float) -> void: training.reaction = value; training.apply_bot_settings())
	spin(left, "Bot aggression", 1.0, 0.25, 2.0, 0.05, func(value: float) -> void: training.aggression = value; training.apply_bot_settings())
	spin(left, "Bot error probability", 0.15, 0.0, 1.0, 0.05, func(value: float) -> void: training.error_chance = value; training.apply_bot_settings())
	menu_label(left,"STATIONARY GUARD DRILL",16)
	spin(left,"Strike trigger range (m)",2.4,.8,2.6,.1,func(value: float) -> void: training.guard_test_range = value; training.apply_bot_settings())
	spin(left,"Strike interval (s)",1.6,1.0,4.0,.1,func(value: float) -> void: training.guard_test_interval = value; training.apply_bot_settings())
	menu_label(right, "02  /  RULE LABORATORY", 18)
	spin(right, "Player maximum HP (reset applies)", training.player_max_health, 50, 1000, 25, func(value: float) -> void: training.player_max_health = value)
	spin(right, "Target maximum HP (reset applies)", 250, 50, 1000, 50, func(value: float) -> void: training.bot_max_health = value)
	var health_row := HBoxContainer.new()
	right.add_child(health_row)
	for percent: int in [19, 20, 21, 100]:
		button(health_row, "%d%% HP" % percent, training.set_targets_health.bind(percent / 100.0))
	spin(right, "Target shield HP", 0, 0, 200, 10, func(value: float) -> void: training.target_shields = value; training.apply_bot_settings())
	check(right, "Target invulnerability", false, func(on: bool) -> void: training.target_invulnerable = on; training.apply_bot_settings())
	var fields: Array = [
		["Melee damage", "melee_damage", 75.0, 10.0, 150.0, 5.0],
		["Melee reach (m)", "melee_range", 2.6, 1.0, 4.0, 0.1],
		["Melee lunge travel (m)", "melee_lunge_distance", 6.0, 0.0, 10.0, 0.1],
		["Throw reach (m)", "throw_range", 3.2, 1.0, 4.0, 0.1],
		["Throw damage", "throw_damage", 95.0, 10.0, 200.0, 5.0],
		["Counter window (s)", "counter_window", 0.24, 0.05, 0.4, 0.01],
		["Throw outside damage multiplier", "throw_outside_multiplier", 0.1, 0.05, 1.0, 0.05],
		["Guard bullet reduction (0 = none)", "bullet_guard_reduction", 0.0, 0.0, 0.8, 0.05],
		["Dash speed (m/s)", "dash_speed", 20.0, 12.0, 26.0, 1.0],
		["Slide friction", "slide_friction", 4.0, 1.0, 8.0, 0.2],
		["Hover ascent (m/s)", "hover_ascent", 8.5, 4.0, 14.0, 0.5]
	]
	for field: Array in fields:
		spin(right, field[0], float(training.player.tuning.get(field[1])), field[3], field[4], field[5], change_tuning.bind(field[1]))
	button(right, "Start timed traversal route", training.start_route)
	button(right, "Movement preset · responsive", func() -> void: training.set_tuning("acceleration", 42); training.set_tuning("braking", 34); training.set_tuning("air_steering", 8.25))
	button(right, "Movement preset · weighty (default)", func() -> void: training.set_tuning("acceleration", 30); training.set_tuning("braking", 24); training.set_tuning("air_steering", 5.625))
	var camera_controls := VBoxContainer.new()
	right.add_child(camera_controls)
	var camera_controller: PlayerController = training.player.controller as PlayerController
	check(camera_controls,"Movement camera effects",float(get_node("/root/GameSettings").values.get("movement_camera_effects",1)) >= .5,func(on: bool) -> void: get_node("/root/GameSettings").set_setting("movement_camera_effects",1.0 if on else 0.0))
	spin(camera_controls, "Camera distance (m)", camera_controller.camera_distance, 2.0, 8.0, 0.1, func(value: float) -> void: camera_controller.camera_distance = value)
	spin(camera_controls, "Camera shoulder offset (m)", camera_controller.shoulder_offset, -1.2, 1.2, 0.05, func(value: float) -> void: camera_controller.shoulder_offset = value)
	spin(camera_controls, "Camera height (m)", camera_controller.camera_height, 1.0, 2.4, 0.05, func(value: float) -> void: camera_controller.camera_height = value)
	spin(camera_controls, "Mouse sensitivity", camera_controller.sensitivity, 0.0005, 0.008, 0.0005, func(value: float) -> void: camera_controller.sensitivity = value)
	var advanced := VBoxContainer.new()
	advanced.visible = false
	button(right, "Show / hide all remaining tuning values", func() -> void: advanced.visible = not advanced.visible)
	right.add_child(advanced)
	var exposed: Array[String] = ["max_health", "magazine"]
	for field: Array in fields: exposed.append(field[1])
	for property: Dictionary in training.player.tuning.get_property_list():
		var field: String = property.name
		if field in exposed or not (property.usage & PROPERTY_USAGE_EDITOR) or property.type not in [TYPE_FLOAT, TYPE_INT]:
			continue
		var initial: float = training.player.tuning.get(field)
		var maximum: float = maxf(initial * 4.0, 2.0)
		var increment: float = 1.0 if property.type == TYPE_INT else (0.01 if initial < 3 else (0.1 if initial < 30 else 1.0))
		if field == "execute_threshold": maximum = 1.0
		spin(advanced, field.replace("_", " ").capitalize(), initial, 1.0 if property.type == TYPE_INT else 0.01, maximum, increment, change_tuning.bind(field))
	button(right, "Export recent combat events (JSON)", training.export_events)
	button(root, "RETURN TO FIELD   /   TAB", training.toggle_menu)

func change_tuning(value: float, field: String) -> void:
	training.set_tuning(field, value)

func menu_label(parent: Node, caption: String, size: int) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", ink)
	parent.add_child(label)

func button(parent: Node, caption: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = caption
	result.custom_minimum_size.y = 34
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_font_override("font", font)
	result.add_theme_font_size_override("font_size", 14)
	parent.add_child(result)
	result.pressed.connect(callback)
	return result

func check(parent: Node, caption: String, checked: bool, callback: Callable) -> void:
	var result := CheckButton.new()
	result.text = caption
	result.button_pressed = checked
	result.add_theme_color_override("font_color", ink)
	result.add_theme_color_override("font_hover_color", ink)
	result.add_theme_color_override("font_pressed_color", ink)
	result.add_theme_font_override("font", font)
	result.add_theme_font_size_override("font_size", 14)
	parent.add_child(result)
	result.toggled.connect(callback)
	check_controls[caption] = result

func sync_menu() -> void:
	scenario_control.select(training.scenario)
	var fields: Dictionary = {"Freeze bot intent": training.freeze_ai,
		"Infinite resources  [CHEAT]": training.infinite,
		"Player invulnerability  [CHEAT]": training.god_mode,
		"Hitboxes & actor state  [F3]": training.debug_view,
		"Target invulnerability": training.target_invulnerable}
	for caption: String in fields:
		(check_controls[caption] as CheckButton).set_pressed_no_signal(fields[caption])

func spin(parent: Node, caption: String, value: float, minimum: float, maximum: float, step: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", ink)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)
	var spinner := SpinBox.new()
	spinner.min_value = minimum
	spinner.max_value = maximum
	spinner.step = step
	spinner.value = value
	spinner.custom_minimum_size.x = 100
	row.add_child(spinner)
	spinner.value_changed.connect(callback)

func build_menu() -> void:
	build_advanced_menu()
	var advanced_panel: Control = menu
	remove_child(advanced_panel)
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	menu.add_child(advanced_panel)
	advanced_panel.visible = false
	var common := GameMenu.new()
	common.session = training
	common.advanced = advanced_panel
	menu.add_child(common)
	menu.visible = false
	menu.visibility_changed.connect(func() -> void:
		if menu.visible:
			advanced_panel.visible = false
			common.visible = true
			common.show_home())
