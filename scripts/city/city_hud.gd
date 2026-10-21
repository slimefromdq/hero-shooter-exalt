class_name CityHUD
extends CanvasLayer

var match_controller: Node
var canvas: Control
var menu: Control
var font: SystemFont
var bold: SystemFont
var overview_open: bool = false
var underground_view: bool = false
var hit_timer: float = 0.0
var hit_head: bool = false
var hit_text: String = ""
var ink := Color("101c2a")
var paper := Color("eeeedf")
var muted := Color("acbcc7")
var mint := Color("38dfff")
var coral := Color("ff4f65")
var brass := Color("d7b884")
var health_green := Color("8ef7a7")
var panel_style: StyleBoxFlat
var light_style: StyleBoxFlat
var display_settings: Node
var display_button: Button
var portraits: Dictionary = {}
var numbers: DamageNumbers

func show_hit(amount: float, head: bool, executed: bool = false) -> void:
	hit_timer = .8
	hit_head = head
	hit_text = "EXECUTED" if executed else str(roundi(amount))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	bold = SystemFont.new()
	bold.font_names = font.font_names
	bold.font_weight = 700
	panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(.045,.085,.13,.89)
	panel_style.set_corner_radius_all(3)
	panel_style.border_color = Color(.46,.61,.68,.3)
	panel_style.set_border_width_all(1)
	light_style = StyleBoxFlat.new()
	light_style.bg_color = paper
	light_style.set_corner_radius_all(3)
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	canvas.draw.connect(draw_hud)
	numbers = DamageNumbers.new()
	numbers.viewer = match_controller.player
	numbers.font = bold
	canvas.add_child(numbers)
	display_settings = get_node("/root/DisplaySettings")
	for hero: String in HeroRoster.IDS:
		portraits[hero] = load("res://assets/portraits/" + hero + (".svg" if hero == "samson" else ".png")) as Texture2D
	build_menu()

func refresh_display_button() -> void:
	if is_instance_valid(display_button): display_button.text = display_settings.button_text()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("city_map") and not event.is_echo():
		overview_open = not overview_open
		if overview_open: underground_view = match_controller.player.position.y < -2
		get_viewport().set_input_as_handled()
	elif overview_open and event.is_action_pressed("city_map_layer") and not event.is_echo():
		underground_view = not underground_view
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	hit_timer = maxf(0, hit_timer - delta)
	if is_instance_valid(match_controller):
		menu.visible = match_controller.menu_open
	canvas.queue_redraw()

func box(at: Vector2, size: Vector2, color: Color) -> void:
	canvas.draw_rect(Rect2(at,size),color)

func panel(at: Vector2, size: Vector2, light: bool = false) -> void:
	canvas.draw_style_box(light_style if light else panel_style,Rect2(at,size))

func text(caption: String, at: Vector2, size: int = 16, color: Color = Color.WHITE, heavy: bool = false) -> void:
	canvas.draw_string(bold if heavy else font,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func centered(caption: String, at: Vector2, size: int = 16, color: Color = Color.WHITE, heavy: bool = false) -> void:
	var typeface: Font = bold if heavy else font
	var width: float = typeface.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	text(caption,at - Vector2(width * .5,0),size,color,heavy)

func draw_hud() -> void:
	if not is_instance_valid(match_controller) or not is_instance_valid(match_controller.player):
		return
	canvas.draw_set_transform_matrix(HUDLayout.fit(canvas.size, Vector2(1600,900)))
	var m: Node = match_controller
	var p: HeroActor = m.player
	draw_topbar(p)
	if m.debug_view:
		text("%d FPS  /  F3 ROUTES & RESOURCES" % Engine.get_frames_per_second(),Vector2(28,177),11,mint)
	if p.spawn_protected and p.alive:
		centered(("SPAWN IMMUNITY / +200 HP PER SECOND / FIRE THROUGH OPEN DOORS" if m is MuseumMatch else "SPAWN / +200 HP PER SECOND / WEAPONS LOCKED") if m.spawn_contains(p.global_position,p.team) else "PROTECTED ARRIVAL / WEAPONS LOCKED",Vector2(800,190),13,mint,true)
	elif m.notice_time > 0:
		centered(m.notice,Vector2(800,190),14,brass,true)
	if p.alive and not m.menu_open and not overview_open:
		draw_crosshair(p)
	draw_player_rail(p)
	draw_combat_feed(p)
	if not p.alive:
		panel(Vector2(555,355),Vector2(490,155))
		centered("AGENT DOWN",Vector2(800,400),35,paper,true)
		centered("RETURNING IN %.1f" % m.respawn_remaining(p),Vector2(800,437),21,mint,true)
		centered("EARNED ULTIMATE CHARGE RETAINED",Vector2(800,473),11,muted)
	if m.winner >= 0:
		panel(Vector2(555,320),Vector2(490,158))
		centered("STALEMATE" if m.winner == 2 else ("VICTORY" if m.winner == p.team else "DEFEAT"),Vector2(800,378),42,mint if m.winner == p.team else coral,true)
		centered("FIVE CONTROL POINTS / SAKURA VEIL" if m.is_in_group("temple_match") else ("CAPTURE + ESCORT  /  MERIDIAN MUSEUM" if m.is_in_group("museum_match") else "FIRST TO 100  /  MERIDIAN GARDENS"),Vector2(800,414),12,brass)
		centered("F5  PLAY AGAIN     ·     TAB  MATCH CONSOLE",Vector2(800,450),12,paper)
	ControlFeedback.draw(canvas,p,bold,Vector2(32,280))
	if overview_open:
		draw_overview()
	elif m.debug_view:
		draw_debug(p)

func draw_combat_feed(p: HeroActor) -> void:
	var feedback: MatchFeedback = match_controller.feedback
	if feedback == null: return
	panel(Vector2(28,201),Vector2(500,48))
	text("[+] CYAN: ROOT     [!] RED: CLOUD" if match_controller.is_in_group("temple_match") else "[+] CYAN: LANTERN / YOUR TEAM     [!] RED: CROWN / ENEMY",Vector2(32,217),11,paper,true)
	text("%d KILLS   %d ASSISTS   /   %d STREAK" % [feedback.kills,feedback.assists,int(feedback.streaks.get(p.get_instance_id(),0))],Vector2(32,239),11,mint,true)
	for index: int in feedback.feed.size():
		var entry: Dictionary = feedback.feed[feedback.feed.size() - 1 - index]
		var y: float = 175 + index * 68
		panel(Vector2(1112,y),Vector2(460,61))
		box(Vector2(1112,y),Vector2(3,61),brass if entry.personal else muted)
		text(str(entry.killer),Vector2(1124,y+19),12,mint if entry.killer_team == 0 else (coral if entry.killer_team == 1 else muted),true)
		text("  >  " + str(entry.victim),Vector2(1345,y+19),12,mint if entry.victim_team == 0 else coral,true)
		text(str(entry.ability),Vector2(1124,y+36),10,muted)
		if entry.assistants != "":
			text("ASSIST: " + str(entry.assistants),Vector2(1124,y+51),9,brass)
	if feedback.banner_time > 0.0:
		var lines: PackedStringArray = feedback.banner.split("\n")
		panel(Vector2(530,527),Vector2(540,38 + (lines.size()-1)*27))
		for index: int in lines.size():
			centered(lines[index],Vector2(800,552+index*27),21 if index == 0 else 15,brass,true)

# Six stable actor slots per side; deaths never reorder the roster.
func draw_topbar(p: HeroActor) -> void:
	var m: Node = match_controller
	var hill: CityHill = m.hill
	for side: int in 2:
		var team: int = p.team if side == 0 else 1 - p.team
		var accent: Color = mint if team == 0 else coral
		var start: float = 28.0 if side == 0 else 1116.0
		text(("LANTERN" if team == 0 else "CROWN") + (" / YOUR TEAM" if side == 0 else " / ENEMY TEAM"),Vector2(start,22),10,accent,true)
		var slot: int = 0
		for actor: HeroActor in m.actors:
			if not is_instance_valid(actor) or actor.team != team:
				continue
			draw_team_slot(actor,Vector2(start + slot * 77,30),side == 0,accent,actor == p)
			slot += 1
			if slot == 6: break
	panel(Vector2(510,24),Vector2(580,108))
	centered("%02d:%02d" % [int(m.elapsed) / 60,int(m.elapsed) % 60],Vector2(800,55),27,paper,true)
	centered("MERIDIAN GARDENS / KING OF THE HILL",Vector2(800,73),9,muted,true)
	var status: String = "CELESTIAL CONSERVATORY"
	var state_color: Color = brass
	if m.winner >= 0:
		status = "LANTERN VICTORY" if m.winner == 0 else "CROWN VICTORY"
		state_color = mint if m.winner == 0 else coral
	elif m.exploration:
		status = "EXPLORATION / AI PAUSED"
	elif not hill.unlocked:
		status = "UNLOCKS IN %02d" % ceili(hill.unlock_remaining)
	elif hill.contested:
		status = "CONTESTED"
		state_color = coral
	elif hill.capturing_team >= 0:
		status = "CAPTURING" if hill.capturing_team == p.team else "ENEMY CAPTURING"
		state_color = mint if hill.capturing_team == 0 else coral
	elif hill.owner_team >= 0:
		status = "LANTERN CONTROL" if hill.owner_team == 0 else "CROWN CONTROL"
		state_color = mint if hill.owner_team == 0 else coral
	for side: int in 2:
		var team: int = p.team if side == 0 else 1 - p.team
		var accent: Color = mint if team == 0 else coral
		var x: float = 528.0 if side == 0 else 910.0
		centered("%d%%" % floori(hill.scores[team]),Vector2(x + 81,58),25,accent,true)
		box(Vector2(x,81),Vector2(162,7),Color("394550"))
		var fill: float = 162 * clampf(hill.scores[team] / m.definition.score_to_win,0,1)
		box(Vector2(x if side == 0 else x + 162 - fill,81),Vector2(fill,7),accent)
		if hill.owner_team == team:
			centered("CONTROLLING",Vector2(x + 81,104),9,accent,true)
	centered("A / " + status,Vector2(800,105),10,state_color,true)
	box(Vector2(707,116),Vector2(186,4),Color("394550"))
	box(Vector2(707,116),Vector2(186 * clampf(hill.capture_progress,0,1),4),state_color)
	text("M  MAP   /   TAB  PAUSE",Vector2(1393,161),10,muted)

func draw_team_slot(actor: HeroActor, at: Vector2, friendly: bool, accent: Color, local: bool) -> void:
	panel(at,Vector2(71,143 if friendly else 112))
	var portrait: Texture2D = portraits.get(actor.tuning.hero_id)
	if portrait != null:
		var source_size: Vector2 = portrait.get_size()
		var source_width: float = source_size.y * 69.0 / 79.0
		canvas.draw_texture_rect_region(portrait,Rect2(at + Vector2(1,1),Vector2(69,79)),Rect2(Vector2((source_size.x - source_width) * .5,0),Vector2(source_width,source_size.y)))
	box(at,Vector2(71,3),paper if local else accent)
	box(at + Vector2(1,65),Vector2(69,16),Color(.025,.04,.06,.9))
	centered(HeroRoster.display_name(actor.tuning.hero_id).to_upper(),at + Vector2(35,77),10,paper,true)
	if not actor.alive:
		box(at + Vector2(0,3),Vector2(71,78),Color(0.025,0.04,0.06,.78))
		centered("%d" % ceili(match_controller.respawn_remaining(actor)),at + Vector2(35,40),25,coral,true)
		centered("RESPAWN",at + Vector2(35,60),9,paper,true)
	var hp: float = clampf(actor.health / maxf(1,actor.effective_max_health()),0,1) if actor.alive else 0.0
	box(at + Vector2(4,85),Vector2(63,7),Color("394550"))
	box(at + Vector2(4,85),Vector2(63 * hp,7),health_green if friendly and hp >= .3 else coral)
	var temporary: float = actor.overhealth.value() if actor.alive else 0
	if temporary > 0:
		box(at+Vector2(4,94),Vector2(63*clampf(temporary/maxf(1,actor.effective_max_health()),0,1),3),ActorOverhealth.COLOR)
	centered("%d HP" % ceili(actor.health if actor.alive else 0)+(" +%d" % ceili(temporary) if temporary > 0 else ""),at+Vector2(35,108),10 if temporary > 0 else 14,ActorOverhealth.COLOR if temporary > 0 else paper,true)
	if friendly:
		var charge: float = clampf(actor.kit.ultimate_charge,0,100)
		box(at + Vector2(4,115),Vector2(63,4),Color("394550"))
		box(at + Vector2(4,115),Vector2(63 * charge / 100,4),brass)
		centered("ULT READY" if charge >= 100 else "ULT %d%%" % floori(charge),at + Vector2(35,136),12 if charge >= 100 else 14,brass,true)
	if local:
		box(at + Vector2(3,5),Vector2(27,14),ink)
		text("YOU",at + Vector2(6,16),10,paper,true)

func draw_crosshair(p: HeroActor) -> void:
	var center := Vector2(800,450)
	var color: Color = paper if p.permits("primary") else brass
	for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		var bloom: float = p.presentation.fire_flash * 40 + p.velocity.length() * .35 if p.kit is SlayerKit else 0.0
		canvas.draw_line(center + direction * (7+bloom),center + direction * (13+bloom),Color(0,0,0,.6),4)
		canvas.draw_line(center + direction * (7+bloom),center + direction * (13+bloom),color,1.5)
	canvas.draw_circle(center,1.3,color)
	if p.alive and not match_controller.menu_open: CombatHUD.ammo(canvas,p,bold,center)
	if p.alive and not match_controller.menu_open: MovementHUD.draw(canvas,p,bold,center)
	draw_reticle_resources(p,center)
	if hit_timer > 0:
		CombatHUD.hit(canvas,bold,hit_text,center,hit_head,hit_timer)
	if p.state == "ultimate":
		canvas.draw_arc(center,180,-PI/2,-PI/2 + TAU * minf(1,p.kit.ultimate_age / p.tuning.ultimate_preparation),72,mint,2,true)
		centered("FINAL NOTICE / PREPARING" if p.kit.ultimate_age < p.tuning.ultimate_preparation else "FINAL NOTICE / ACQUIRED",Vector2(800,650),13,mint,true)

# Dash sits below the ammunition, leaving room for its reload prompt.
func draw_reticle_resources(p: HeroActor, center: Vector2) -> void:
	var at: Vector2 = center + Vector2(68,53)
	var ready: bool = p.motor.dash_charges > 0
	var accent: Color = mint if ready else muted
	canvas.draw_circle(at,15,Color(.025,.05,.075,.9))
	canvas.draw_arc(at,14,-PI/2,-PI/2 + TAU,40,Color("394550"),2,true)
	var progress: float = 1 - clampf(p.motor.dash_cd / maxf(.01,p.tuning.dash_cooldown),0,1)
	if progress > 0:
		canvas.draw_arc(at,14,-PI/2,-PI/2 + TAU * progress,40,accent,2,true)
	draw_ability_glyph("dash",at,accent,.55)
	canvas.draw_string(font,at+Vector2(-4,29),str(p.motor.dash_charges),HORIZONTAL_ALIGNMENT_LEFT,-1,13,accent)
	if p.state == "guard":
		# The open right edge keeps the ammo counter clear; only the arc carries guard state.
		var start: float = PI * .15
		var sweep: float = PI * 1.7
		var fraction: float = clampf(p.close.guard_meter / 100,0,1)
		canvas.draw_arc(center,22,start,start + sweep,64,Color(.025,.05,.075,.85),4,true)
		canvas.draw_arc(center,22,start,start + sweep,64,Color("394550"),2,true)
		if fraction > 0:
			canvas.draw_arc(center,22,start,start + sweep * fraction,64,mint if fraction > .25 else coral,2,true)

func draw_player_rail(p: HeroActor) -> void:
	var origin := Vector2(600,764)
	panel(origin - Vector2(8,30),Vector2(420,57))
	text(HeroRoster.display_name(p.tuning.hero_id).to_upper(),origin + Vector2(2,-12),12,paper,true)
	text("%d / %d HP" % [ceili(p.health if p.alive else 0),p.effective_max_health()],origin + Vector2(263,-12),15,paper,true)
	box(origin,Vector2(404,16),Color("25452d"))
	var hp: float = clampf(p.health / p.tuning.max_health,0,1) if p.alive else 0.0
	box(origin,Vector2(404 * hp,16),health_green if hp > .25 else coral)
	var ceiling: float = p.effective_max_health() / p.tuning.max_health
	if ceiling < 1:
		box(origin + Vector2(404 * ceiling,0),Vector2(404 * (1 - ceiling),16),Color("a166cc"))
	if p.shields > 0:
		box(origin + Vector2(0,19),Vector2(404 * clampf(p.shields / p.tuning.max_health,0,1),4),CombatHUD.SHIELD_COLOR)
		text("+%d SHIELD" % ceili(p.shields),origin + Vector2(132,-12),11,CombatHUD.SHIELD_COLOR,true)
	var temporary: float = p.overhealth.value()
	if temporary > 0:
		box(origin+Vector2(0,25),Vector2(404*clampf(temporary/p.tuning.max_health,0,1),5),ActorOverhealth.COLOR)
		text("+%d OVERHEALTH" % ceili(temporary),origin+Vector2(4,43),12,ActorOverhealth.COLOR,true)
	if p.kit is CareKit:
		var labels: Array[String] = CareHUD.labels(p)
		var times: Array[float] = CareHUD.cooldowns(p)
		for i: int in 3: ability(600+i*104,TrainingInputs.key_label(["hover","deflect","bomb"][i]),labels[i],times[i],CareHUD.durations(p)[i],["boot","shield","bomb"][i])
	elif p.kit is SlayerKit:
		var hunter := p.kit as SlayerKit
		var t := p.tuning as SlayerTuning
		ability(600,TrainingInputs.key_label("hover"),"SILVER KNIVES",0 if hunter.knives > 0 else hunter.knife_timer,t.knife_recharge,"knife","%d/%d" % [hunter.knives,t.knife_charges])
		ability(704,TrainingInputs.key_label("deflect"),"BOOT RUSH",hunter.deflect_cd,t.boot_cooldown,"boot")
		ability(808,TrainingInputs.key_label("bomb"),"TOSS SNARE",0 if hunter.snares > 0 else hunter.snare_timer,t.trap_recharge,"trap","%d/%d" % [hunter.snares,t.trap_limit])
	else:
		ability(600,TrainingInputs.key_label("hover"),"UMBRELLA VAULT",p.motor.hover_cd,p.tuning.hover_cooldown,"umbrella")
		ability(704,TrainingInputs.key_label("deflect"),"DEFLECT",p.kit.deflect_cd,p.tuning.deflect_cooldown,"shield")
		ability(808,TrainingInputs.key_label("bomb"),"POCKET BOMB",p.kit.bomb_cd,p.tuning.bomb_cooldown,"bomb")
	var charge: float = clampf(p.kit.ultimate_charge,0,100)
	ability(912,TrainingInputs.key_label("ultimate"),CareHUD.ultimate_label(p),100-charge,100,"axe" if p.kit is SlayerKit else "scope","READY" if charge >= 100 else "%d%%" % floori(charge),true)
	var status_text: String = CareHUD.detail(p) + "  " + CareHUD.status(p)
	for kind: String in p.statuses.effects:
		if kind in ["root","slow"]: continue
		status_text += "%s %.1fs   " % [kind.replace("max_health","MAX HP WOUND").to_upper(),p.statuses.effects[kind].remaining]
	if status_text != "": centered(status_text,Vector2(800,704),15,coral,true)
	if p.kit is SlayerKit:
		var hunter := p.kit as SlayerKit
		if hunter.action_hint_time > 0:
			centered(hunter.action_hint,Vector2(800,620),18,brass,true)
		elif hunter.boot_slow_time > 0:
			centered("BOOT RECOVERY / SPEED %d%%" % roundi(hunter.movement_scale() * 100),Vector2(800,690),14,paper,true)

func ability(x: float, key: String, caption: String, cd: float, total: float, glyph: String, detail: String = "", ultimate: bool = false) -> void:
	var at := Vector2(x,804)
	var accent: Color = brass if ultimate else (mint if cd <= 0 else muted)
	panel(at,Vector2(92,67))
	text(key,at + Vector2(7,15),12,paper,true)
	draw_ability_glyph(glyph,at + Vector2(48,25),accent)
	centered(detail if detail != "" else ("READY" if cd <= 0 else "%.1f s" % cd),at + Vector2(46,56),14,accent,true)
	box(at + Vector2(6,62),Vector2(80,3),Color("394550"))
	box(at + Vector2(6,62),Vector2(80 * (1 - clampf(cd / maxf(.01,total),0,1)),3),accent)
	centered(caption,at + Vector2(46,81),9,paper,true)

# Small, consistent line icons remain sharp at every HUD scale.
func draw_ability_glyph(kind: String, at: Vector2, color: Color, scale: float = 1.0) -> void:
	var strokes: Array[PackedVector2Array] = []
	match kind:
		"dash":
			strokes = [PackedVector2Array([-Vector2(14,8),Vector2(-5,0),Vector2(-14,-8)]),PackedVector2Array([Vector2(-3,8),Vector2(6,0),Vector2(-3,-8)]),PackedVector2Array([Vector2(8,8),Vector2(17,0),Vector2(8,-8)])]
		"knife":
			strokes = [PackedVector2Array([Vector2(-10,13),Vector2(12,-14),Vector2(7,3),Vector2(-10,13)]),PackedVector2Array([Vector2(-13,6),Vector2(-3,14)]),PackedVector2Array([Vector2(-8,11),Vector2(-14,18)])]
		"boot":
			strokes = [PackedVector2Array([Vector2(-9,-14),Vector2(3,-14),Vector2(3,2),Vector2(14,7),Vector2(14,13),Vector2(-11,13),Vector2(-9,-14)]),PackedVector2Array([Vector2(-17,-3),Vector2(-12,-3)]),PackedVector2Array([Vector2(-19,4),Vector2(-14,4)])]
		"trap":
			strokes = [PackedVector2Array([Vector2(-17,3),Vector2(-10,14),Vector2(10,14),Vector2(17,3)]),PackedVector2Array([Vector2(-14,-7),Vector2(-8,2),Vector2(-4,-7),Vector2(0,2),Vector2(5,-7),Vector2(9,2),Vector2(14,-7)])]
		"umbrella":
			strokes = [PackedVector2Array([Vector2(-17,-1),Vector2(-12,-10),Vector2(0,-15),Vector2(12,-10),Vector2(17,-1),Vector2(-17,-1)]),PackedVector2Array([Vector2(0,-15),Vector2(0,13),Vector2(5,17),Vector2(10,13)])]
		"shield":
			strokes = [PackedVector2Array([Vector2(0,-16),Vector2(15,-10),Vector2(12,7),Vector2(0,17),Vector2(-12,7),Vector2(-15,-10),Vector2(0,-16)]),PackedVector2Array([Vector2(-6,0),Vector2(-1,5),Vector2(8,-5)])]
		"bomb":
			canvas.draw_arc(at + Vector2(0,4) * scale,12 * scale,0,TAU,24,color,2,true)
			strokes = [PackedVector2Array([Vector2(0,-8),Vector2(4,-15),Vector2(11,-15)]),PackedVector2Array([Vector2(14,-19),Vector2(16,-15),Vector2(20,-13)])]
		"axe":
			strokes = [PackedVector2Array([Vector2(-11,17),Vector2(9,-15)]),PackedVector2Array([Vector2(-3,-9),Vector2(-12,-5),Vector2(-8,6),Vector2(3,3),Vector2(11,9),Vector2(18,-1),Vector2(10,-5)])]
		"scope":
			canvas.draw_arc(at,12 * scale,0,TAU,24,color,2,true)
			strokes = [PackedVector2Array([Vector2(-18,0),Vector2(-6,0)]),PackedVector2Array([Vector2(6,0),Vector2(18,0)]),PackedVector2Array([Vector2(0,-18),Vector2(0,-6)]),PackedVector2Array([Vector2(0,6),Vector2(0,18)])]
	for stroke: PackedVector2Array in strokes:
		var points := PackedVector2Array()
		for point: Vector2 in stroke:
			points.append(at + point * scale)
		canvas.draw_polyline(points,Color(.025,.04,.06,.9),4,true)
		canvas.draw_polyline(points,color,2,true)

func map_point(point: Vector3, bounds: Rect2) -> Vector2:
	return bounds.position + Vector2((point.x + 72.0) / 144.0,(point.z + 66.0) / 132.0) * bounds.size

func map_rect(at: Vector3, size: Vector2, bounds: Rect2, color: Color, fill: bool = true) -> void:
	canvas.draw_rect(Rect2(map_point(at - Vector3(size.x * .5,0,size.y * .5),bounds),size / Vector2(144,132) * bounds.size),color,fill,-1.0 if fill else 1.5)

func route_line(points: Array[Vector3], bounds: Rect2, color: Color, width: float = 2.0) -> void:
	if points.size() < 2:
		return
	var line := PackedVector2Array()
	for point: Vector3 in points:
		line.append(map_point(point,bounds))
	canvas.draw_polyline(line,color,width,true)

func draw_overview() -> void:
	if underground_view:
		draw_underground_overview()
		return
	box(Vector2.ZERO,Vector2(1600,900),Color(.025,.05,.08,.96))
	text("MERIDIAN GARDENS",Vector2(65,65),31,paper,true)
	text("DISTRICT ATLAS  /  TACTICAL ROUTES & SHARED RESOURCES",Vector2(67,91),12,brass)
	text("M  CLOSE",Vector2(1445,65),14,mint,true)
	text("B  ARCADE",Vector2(1290,65),14,brass,true)
	var bounds := Rect2(69,125,752,689)
	box(bounds.position,bounds.size,Color("14222e"))
	# The overview uses the actual district metre scale and labels all three traversal layers.
	for x: int in range(-60,73,12):
		canvas.draw_line(map_point(Vector3(x,0,-66),bounds),map_point(Vector3(x,0,66),bounds),Color(.35,.48,.56,.12),1)
	for z: int in range(-60,67,12):
		canvas.draw_line(map_point(Vector3(-72,0,z),bounds),map_point(Vector3(72,0,z),bounds),Color(.35,.48,.56,.12),1)
	map_rect(Vector3.ZERO,Vector2(44,42),bounds,Color("334c4a"))
	map_rect(Vector3.ZERO,Vector2(30,28),bounds,Color("475b5c"))
	map_rect(Vector3.ZERO,Vector2(20,18),bounds,Color("b7b69b"),false)
	for side: float in [-1.0, 1.0]:
		map_rect(Vector3(0,0,side*17),Vector2(5.6,14),bounds,Color("547f91"))
	canvas.draw_circle(map_point(Vector3.ZERO,bounds),10,brass)
	for side: int in [-1,1]:
		map_rect(Vector3(0,0,side * 60),Vector2(29,11),bounds,Color("294a5a") if side == -1 else Color("624439"))
		for wing: int in [-1,1]:
			map_rect(Vector3(wing * 34,0,side * 31),Vector2(11,17),bounds,Color("293a46"))
			map_rect(Vector3(wing * 53,0,side * 19),Vector2(15,24),bounds,Color("293a46"))
			map_rect(Vector3(wing * 24,0,side * 48),Vector2(16,12),bounds,Color("293a46"))
			route_line([Vector3(wing*8,0,side*60),Vector3(wing*8,0,side*40),Vector3(wing*8,0,side*28),Vector3(wing*8,0,side*10)],bounds,Color(.8,.78,.66,.8),6)
			route_line([Vector3(wing*34,0,side*40),Vector3(wing*34,0,0),Vector3(wing*15,0,0)],bounds,Color(.42,.64,.49,.8),5)
			route_line([Vector3(wing*37.5,0,side*24),Vector3(wing*37.5,3.25,side*36.25),Vector3(wing*42,3.25,side*36.25),Vector3(wing*42,6.5,side*20),Vector3(wing*23,6.5,side*20),Vector3(wing*23,6.5,side*21)],bounds,Color(.73,.56,.86,.85),3)
			route_line([Vector3(wing*18,0,side*38),Vector3(wing*18,-5,side*18),Vector3(0,-5,side*18)],bounds,Color(.27,.76,.84,.8),2)
			route_line([Vector3(wing*23,6.5,-21),Vector3(wing*23,6.5,21)],bounds,Color(.73,.56,.86,.85),3)
		route_line([Vector3(-18,-5,side*18),Vector3(18,-5,side*18)],bounds,Color(.27,.76,.84,.8),2)
	for side: int in [-1,1]:
		route_line([Vector3(side*18,-5,-18),Vector3(side*18,-5,18)],bounds,Color(.27,.76,.84,.8),2)
	if match_controller.debug_view:
		for team: int in 2:
			for role: String in ["frontline","flank_left","flank_right","high_ground"]:
				var points: Array[Vector3] = match_controller.definition.route_points(team,role)
				route_line(points,bounds,Color(.4,.85,1,.5) if team == 0 else Color(1,.5,.4,.5),1)
	for pickup: Node3D in match_controller.pickups:
		var at: Vector2 = map_point(pickup.global_position,bounds)
		var large: bool = absf(pickup.global_position.x) > 30
		var color: Color = health_green if pickup.available else Color("486356")
		canvas.draw_circle(at,9 if large else 6,Color("172d24"))
		canvas.draw_line(at - Vector2(5 if large else 3,0),at + Vector2(5 if large else 3,0),color,3)
		canvas.draw_line(at - Vector2(0,5 if large else 3),at + Vector2(0,5 if large else 3),color,3)
		if match_controller.debug_view:
			text(("400" if large else "75") if pickup.available else "%ds" % ceili(pickup.cooldown_remaining),at + Vector2(10,-5),9,color)
	for actor: HeroActor in match_controller.actors:
		if not actor.alive or (actor.team != match_controller.player.team and not match_controller.debug_view):
			continue
		var at: Vector2 = map_point(actor.global_position,bounds)
		canvas.draw_circle(at,5 if actor == match_controller.player else 3,mint if actor.team == 0 else coral)
		if actor == match_controller.player:
			canvas.draw_arc(at,8,0,TAU,20,paper,1,true)
	map_label("CROWN STATION",Vector3(0,0,-61),bounds,coral)
	map_label("LANTERN COURT",Vector3(0,0,62),bounds,mint)
	map_label("GARDEN WALK",Vector3(-43,0,0),bounds,brass)
	map_label("LANTERN MARKET",Vector3(43,0,0),bounds,brass)
	map_label("A",Vector3(0,0,0),bounds,paper)
	text("N",bounds.position + Vector2(12,25),16,brass,true)
	text("144 m",bounds.position + Vector2(bounds.size.x - 48,bounds.size.y + 22),11,muted)
	text("132 m",bounds.position + Vector2(-2,bounds.size.y + 22),11,muted)
	draw_map_legend()

func arcade_point(point: Vector3) -> Vector2:
	return Vector2(440, 480) + Vector2(point.x, point.z) * 14.0

func arcade_rect(point: Vector3, size: Vector2, color: Color) -> void:
	box(arcade_point(point) - size * 7, size * 14, color)

func draw_underground_overview() -> void:
	box(Vector2.ZERO, Vector2(1600,900), Color("0b151e"))
	text("LOWER MERIDIAN EXCHANGE",Vector2(65,65),29,paper,true)
	text("UNDERGROUND ATLAS  /  −5 m  /  BELOW THE CONSERVATORY",Vector2(67,91),12,brass)
	text("B  SURFACE",Vector2(1270,65),14,brass,true)
	text("M  CLOSE",Vector2(1445,65),14,mint,true)
	arcade_rect(Vector3.ZERO, Vector2(46,46), Color("14222e"))
	arcade_rect(Vector3.ZERO, Vector2(42,42), Color("52616a"))
	for side: float in [-1.0, 1.0]:
		for x: float in [-18.0, 0.0, 18.0]:
			arcade_rect(Vector3(x,0,side*21), Vector2(4,3), Color("547f91"))
			centered("STAIRS",arcade_point(Vector3(x,0,side*22.4)),9,mint,true)
	for side: float in [-1.0, 1.0]:
		arcade_rect(Vector3(0,0,side*15.5), Vector2(5.6,11), Color("547f91"))
		centered("HILL STAIRS",arcade_point(Vector3(0,0,side*14)),10,mint,true)
	for shop: Vector3 in match_controller.definition.shopping_arcade_shops:
		arcade_rect(shop, Vector2(6,7), Color("b7aca0"))
		for edge: float in [-1.0, 1.0]:
			arcade_rect(shop + Vector3(0,0,edge*3.5), Vector2(6,.3), Color("283945"))
		arcade_rect(shop + Vector3(0,0,2.3), Vector2(3.2,1), Color("88705c"))
		centered("SHOP",arcade_point(shop) + Vector2(0,4),10,ink,true)
	for side: float in [-1.0, 1.0]:
		arcade_rect(Vector3(side*5.1,0,side*7),Vector2(2.8,2.1),Color("c38d79"))
		arcade_rect(Vector3(-side*5,0,side*9),Vector2(2.4,1.4),Color("d1c8ae"))
		arcade_rect(Vector3(side*4.7,0,side*17.2),Vector2(2,.4),Color("283945"))
	canvas.draw_circle(arcade_point(Vector3.ZERO),3.4*14,Color("253b49"))
	centered("CORE",arcade_point(Vector3.ZERO) + Vector2(0,4),12,brass,true)
	for pickup: CityHealthPack in match_controller.pickups:
		if pickup.position.y > -2: continue
		var at: Vector2 = arcade_point(pickup.position)
		canvas.draw_line(at-Vector2(7,0),at+Vector2(7,0),health_green,4)
		canvas.draw_line(at-Vector2(0,7),at+Vector2(0,7),health_green,4)
		text("75",at+Vector2(12,4),11,health_green)
	for actor: HeroActor in match_controller.actors:
		if not actor.alive or actor.position.y > -2 or absf(actor.position.z)>21 or absf(actor.position.x)>21: continue
		if actor.team != match_controller.player.team and not match_controller.debug_view: continue
		canvas.draw_circle(arcade_point(actor.position),5,mint if actor.team == 0 else coral)
	text("N",Vector2(125,154),16,brass,true)
	text("42 × 42 m",Vector2(650,820),12,muted)
	text("SIX SHOPS. MULTIPLE WAYS THROUGH.",Vector2(850,180),22,paper,true)
	var notes: Array[String] = ["Central drum and kiosks break long sightlines.", "Shop doors connect the gallery to both perimeter aisles.", "Four corner stairs return to the garden streets.", "Two short hill stairs + two station tunnels.", "Two shared 75 HP caches remain in the entry recesses.", "The hill above cannot be captured from this floor."]
	for index: int in notes.size():
		text(notes[index],Vector2(850,240+index*46),15,muted)
	text("WEST",Vector2(850,575),13,brass,true)
	text("Moon & Quill · Starling Tailors · Astra Patisserie",Vector2(850,609),14,paper)
	text("EAST",Vector2(850,661),13,brass,true)
	text("Botanica Gifts · Thauma Workshop · Meridian Maps",Vector2(850,695),14,paper)
	text("B  SWITCH SURFACE / UNDERGROUND",Vector2(850,805),12,mint,true)

func map_label(caption: String, point: Vector3, bounds: Rect2, color: Color) -> void:
	centered(caption,map_point(point,bounds) + Vector2(0,4),10,color,true)

func draw_map_legend() -> void:
	var x: float = 878
	text("ONE PARK. THREE LEVELS.",Vector2(x,159),23,paper,true)
	text("A   CELESTIAL CONSERVATORY",Vector2(x,203),15,brass,true)
	text("20 × 18 m hill  ·  ground level only",Vector2(x,230),14,muted)
	text("Four entrances. Central cover divides diagonal fire.",Vector2(x,254),13,muted)
	text("CROWN & LANTERN",Vector2(x,299),14,paper,true)
	text("Two street exits and a subway connection per spawn.",Vector2(x,326),13,muted)
	text("Protected rooms prevent incoming and outgoing damage.",Vector2(x,350),13,muted)
	var lines: Array = [
		[Color("c8c6a8"),"STREETS / 0 m","Main approaches, shop passages and the hill"],
		[Color("72a27d"),"GARDENS / 2 m","Terraces and contested flank resources"],
		[Color("bc8fdc"),"VIADUCT / 6.5 m","Covered walkways; stairs from both neighbourhoods"],
		[Color("45c2d6"),"SUBWAY / −5 m","Four corner connections; no direct hill hatch"]
	]
	for index: int in lines.size():
		var y: float = 402 + index * 64
		canvas.draw_line(Vector2(x,y - 5),Vector2(x + 31,y - 5),lines[index][0],3)
		text(lines[index][1],Vector2(x + 46,y),13,paper,true)
		text(lines[index][2],Vector2(x + 46,y + 23),12,muted)
	text("+   SHARED HEALTH",Vector2(x,690),15,health_green,true)
	text("6 SMALL   75 HP / 10 s",Vector2(x,719),14,paper)
	text("2 LARGE   400 HP / 15 s",Vector2(x,746),14,paper)
	text("Healing stops at maximum health. Full HP leaves packs available.",Vector2(x,776),12,muted)
	text("F3  TOGGLE LIVE ENEMIES & BOT ROUTE OVERLAY",Vector2(x,819),11,brass)

func draw_debug(p: HeroActor) -> void:
	panel(Vector2(28,173),Vector2(310,201))
	text("FIELD TELEMETRY",Vector2(43,200),12,brass,true)
	var moving: int = 0
	var stalled: int = 0
	for bot: HeroActor in match_controller.bots:
		if bot.velocity.length() > .5: moving += 1
		if bot.controller.stuck_time > 1: stalled += 1
	var lines: Array[String] = [
		"POSITION   %.1f / %.1f / %.1f" % [p.global_position.x,p.global_position.y,p.global_position.z],
		"MOTION   %s / %.2f m/s" % [p.motor.mode,p.velocity.length()],
		"STATE   %s" % p.state.to_upper(),
		"BOT MOTION   %d moving / %d delayed" % [moving,stalled],
		"OCCUPANCY   %d LANTERN / %d CROWN" % [match_controller.hill.occupancy[0],match_controller.hill.occupancy[1]],
		"M  ATLAS / ROUTES / HEALTH RESOURCES"
	]
	for index: int in lines.size():
		text(lines[index],Vector2(43,227 + index * 23),11,muted)

func build_menu() -> void:
	var common := GameMenu.new()
	common.session = match_controller
	menu = common
	add_child(menu)
	menu.visible = false
	menu.visibility_changed.connect(func() -> void:
		if menu.visible: common.show_home())

func menu_label(parent: Node, caption: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)

func menu_button(parent: Node, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 43
	button.add_theme_font_override("font",bold)
	button.add_theme_font_size_override("font_size",13)
	button.add_theme_color_override("font_color",paper)
	button.add_theme_color_override("font_hover_color",mint)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("21313e")
	style.border_color = Color("465660")
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	button.add_theme_stylebox_override("normal",style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color("304856")
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",hover)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button
