class_name CityHUD
extends CanvasLayer

var match_controller: Node
var canvas: Control
var menu: Control
var font: SystemFont
var bold: SystemFont
var overview_open: bool = false
var hit_timer: float = 0.0
var hit_head: bool = false
var hit_text: String = ""
var ink := Color("101c2a")
var paper := Color("eeeedf")
var muted := Color("acbcc7")
var mint := Color("8ed7e5")
var coral := Color("f29177")
var brass := Color("d7b884")
var health_green := Color("8ef7a7")
var panel_style: StyleBoxFlat
var light_style: StyleBoxFlat

func show_hit(amount: float, head: bool, executed: bool = false) -> void:
	hit_timer = .22
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
	build_menu()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("city_map") and not event.is_echo():
		overview_open = not overview_open
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
	canvas.draw_set_transform(Vector2.ZERO,0,canvas.size / Vector2(1600,900))
	var m: Node = match_controller
	var p: HeroActor = m.player
	var hill: Node = m.hill
	# The city title stays compact so the landmark and approach remain visible.
	panel(Vector2(28,25),Vector2(278,64))
	canvas.draw_line(Vector2(43,40),Vector2(43,73),brass,2,true)
	text("MERIDIAN GARDENS",Vector2(57,51),20,paper,true)
	text("EXALT  /  KING OF THE HILL",Vector2(58,72),10,brass)
	panel(Vector2(579,25),Vector2(442,93))
	box(Vector2(579,25),Vector2(5,93),mint)
	box(Vector2(1016,25),Vector2(5,93),coral)
	centered("LANTERN",Vector2(640,49),10,mint,true)
	centered("CROWN",Vector2(960,49),10,coral,true)
	centered("%02d%%" % floori(hill.scores[0]),Vector2(640,84),28,paper,true)
	centered("%02d%%" % floori(hill.scores[1]),Vector2(960,84),28,paper,true)
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
		state_color = mint if hill.capturing_team == p.team else coral
	elif hill.owner_team >= 0:
		status = "LANTERN CONTROL" if hill.owner_team == 0 else "CROWN CONTROL"
		state_color = mint if hill.owner_team == 0 else coral
	centered("A",Vector2(800,55),27,state_color,true)
	centered(status,Vector2(800,79),10,state_color,true)
	box(Vector2(709,92),Vector2(182,4),Color("394550"))
	box(Vector2(709,92),Vector2(182 * hill.capture_progress,4),state_color)
	for team: int in 2:
		for index: int in 6:
			var at := Vector2(603 + index * 12,103) if team == 0 else Vector2(933 + index * 12,103)
			canvas.draw_circle(at,2.5,(mint if team == 0 else coral) if index < m.team_count(team) else Color("45515b"))
	panel(Vector2(1360,25),Vector2(212,37))
	text("M  MAP     TAB  PAUSE",Vector2(1375,49),12,paper,true)
	if m.debug_view:
		panel(Vector2(1360,71),Vector2(212,63))
		text("%d FPS  ·  %02d:%02d" % [Engine.get_frames_per_second(),int(m.elapsed) / 60,int(m.elapsed) % 60],Vector2(1374,96),13,mint)
		text("F3  ROUTES / RESOURCES",Vector2(1374,118),10,muted)
	if p.spawn_protected and p.alive:
		centered("PROTECTED ARRIVAL  /  WEAPONS LOCKED",Vector2(800,154),13,mint,true)
	elif m.notice_time > 0:
		centered(m.notice,Vector2(800,154),14,brass,true)
	if p.alive and not m.menu_open and not overview_open:
		draw_crosshair(p)
	draw_player_rail(p)
	if not p.alive:
		panel(Vector2(555,355),Vector2(490,155))
		centered("AGENT DOWN",Vector2(800,400),35,paper,true)
		centered("RETURNING IN %.1f" % m.respawn_remaining(p),Vector2(800,437),21,mint,true)
		centered("EARNED ULTIMATE CHARGE RETAINED",Vector2(800,473),11,muted)
	if m.winner >= 0:
		panel(Vector2(555,320),Vector2(490,158))
		centered("VICTORY" if m.winner == p.team else "DEFEAT",Vector2(800,378),42,mint if m.winner == p.team else coral,true)
		centered("FIRST TO 100  /  MERIDIAN GARDENS",Vector2(800,414),12,brass)
		centered("F5  PLAY AGAIN     ·     TAB  MATCH CONSOLE",Vector2(800,450),12,paper)
	if p.last_hit_age < .25:
		canvas.draw_rect(Rect2(4,4,1592,892),Color(1,.28,.16,(.25 - p.last_hit_age) * 2),false,5)
	if overview_open:
		draw_overview()
	elif m.debug_view:
		draw_debug(p)

func draw_crosshair(p: HeroActor) -> void:
	var center := Vector2(800,450)
	var color: Color = paper if p.permits("primary") else brass
	for direction: Vector2 in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		canvas.draw_line(center + direction * 7,center + direction * 13,Color(0,0,0,.6),4)
		canvas.draw_line(center + direction * 7,center + direction * 13,color,1.5)
	canvas.draw_circle(center,1.3,color)
	if hit_timer > 0:
		for direction: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			canvas.draw_line(center + direction * 17,center + direction * 24,coral if hit_head else mint,2.5,true)
		text(hit_text,center + Vector2(30,-20),16,coral if hit_head else paper,true)
	if p.state == "ultimate":
		canvas.draw_arc(center,180,-PI/2,-PI/2 + TAU * minf(1,p.kit.ultimate_age / p.tuning.ultimate_preparation),72,mint,2,true)
		centered("FINAL NOTICE / PREPARING" if p.kit.ultimate_age < p.tuning.ultimate_preparation else "FINAL NOTICE / ACQUIRED",Vector2(800,650),13,mint,true)

func draw_player_rail(p: HeroActor) -> void:
	panel(Vector2(28,760),Vector2(310,108))
	text("NIMBUS",Vector2(46,789),22,paper,true)
	text("LANTERN DIVISION",Vector2(167,787),10,mint)
	text("%03d" % ceili(p.health),Vector2(46,829),30,paper,true)
	text("/ %d HP" % int(p.tuning.max_health),Vector2(113,827),12,muted)
	box(Vector2(46,846),Vector2(274,5),Color("3a4853"))
	box(Vector2(46,846),Vector2(274 * clampf(p.health / p.tuning.max_health,0,1),5),mint if p.health > p.tuning.max_health * .25 else coral)
	panel(Vector2(350,760),Vector2(150,108))
	text("UMBRELLA RIFLE",Vector2(364,784),10,muted,true)
	text("%02d" % p.kit.ammo,Vector2(364,826),34,paper,true)
	text("/ %02d" % p.tuning.magazine,Vector2(423,822),15,muted)
	text("R  RELOAD" if p.state != "reload" else "RELOADING %.1f" % p.state_time,Vector2(364,849),10,brass)
	ability(512,"3","VECTOR DASH",p.motor.dash_cd,p.tuning.dash_cooldown)
	ability(644,"Q","UMBRELLA VAULT",p.motor.hover_cd,p.tuning.hover_cooldown)
	ability(776,"E","DEFLECT",p.kit.deflect_cd,p.tuning.deflect_cooldown)
	ability(908,"1","POCKET BOMB",p.kit.bomb_cd,p.tuning.bomb_cooldown)
	panel(Vector2(1040,760),Vector2(186,108))
	text("2  FINAL NOTICE",Vector2(1054,784),11,brass,true)
	text("READY" if p.kit.ultimate_charge >= 100 else "%02d%%" % int(p.kit.ultimate_charge),Vector2(1054,824),28,mint if p.kit.ultimate_charge >= 100 else paper,true)
	box(Vector2(1054,846),Vector2(158,4),Color("3a4853"))
	box(Vector2(1054,846),Vector2(158 * p.kit.ultimate_charge / 100.0,4),brass)
	panel(Vector2(1238,760),Vector2(334,108))
	text("6  SHIELD",Vector2(1252,786),12,paper,true)
	box(Vector2(1366,778),Vector2(190,4),Color("3a4853"))
	box(Vector2(1366,778),Vector2(190 * p.close.guard_meter / 100.0,4),mint)
	text("5  MELEE ENGAGE",Vector2(1252,817),11,muted)
	text("4  THROW / COUNTER",Vector2(1404,817),10,muted)
	text("SHIFT  CROUCH / SLIDE",Vector2(1252,849),11,brass)
	text("WASD  MOVE    SPACE  JUMP / WALL KICK    HOLD SPACE + MOVE  AUTO MANTLE",Vector2(30,889),10,muted)
	text("F5  RESTART     M  MAP     F3  DEBUG",Vector2(1327,889),10,muted)

func ability(x: float, key: String, caption: String, cd: float, total: float) -> void:
	panel(Vector2(x,760),Vector2(120,108))
	text(key,Vector2(x + 13,790),20,paper,true)
	text(caption,Vector2(x + 13,815),9,muted)
	text("READY" if cd <= 0 else "%.1f s" % cd,Vector2(x + 13,837),11,mint if cd <= 0 else brass,true)
	box(Vector2(x + 13,847),Vector2(94,3),Color("3a4853"))
	box(Vector2(x + 13,847),Vector2(94 * (1 - clampf(cd / total,0,1)),3),mint)

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
	box(Vector2.ZERO,Vector2(1600,900),Color(.025,.05,.08,.96))
	text("MERIDIAN GARDENS",Vector2(65,65),31,paper,true)
	text("DISTRICT ATLAS  /  TACTICAL ROUTES & SHARED RESOURCES",Vector2(67,91),12,brass)
	text("M  CLOSE",Vector2(1445,65),14,mint,true)
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
	canvas.draw_circle(map_point(Vector3.ZERO,bounds),10,brass)
	for side: int in [-1,1]:
		map_rect(Vector3(0,0,side * 60),Vector2(29,11),bounds,Color("294a5a") if side == -1 else Color("624439"))
		for wing: int in [-1,1]:
			map_rect(Vector3(wing * 34,0,side * 31),Vector2(11,17),bounds,Color("293a46"))
			map_rect(Vector3(wing * 53,0,side * 19),Vector2(15,24),bounds,Color("293a46"))
			map_rect(Vector3(wing * 24,0,side * 48),Vector2(16,12),bounds,Color("293a46"))
			route_line([Vector3(wing*8,0,side*60),Vector3(wing*8,0,side*40),Vector3(wing*8,0,side*28),Vector3(wing*8,0,side*10)],bounds,Color(.8,.78,.66,.8),6)
			route_line([Vector3(wing*34,0,side*40),Vector3(wing*34,0,0),Vector3(wing*15,0,0)],bounds,Color(.42,.64,.49,.8),5)
			route_line([Vector3(wing*42,0,side*46),Vector3(wing*42,6.5,side*20),Vector3(wing*23,6.5,side*20),Vector3(wing*23,6.5,side*21)],bounds,Color(.73,.56,.86,.85),3)
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
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.visible = false
	add_child(menu)
	var veil := ColorRect.new()
	veil.color = Color(.025,.05,.08,.91)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(600,0)
	var style := panel_style.duplicate() as StyleBoxFlat
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	frame.add_theme_stylebox_override("panel",style)
	center.add_child(frame)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation",13)
	frame.add_child(root)
	menu_label(root,"MERIDIAN GARDENS",28,paper)
	menu_label(root,"MATCH CONSOLE  /  SESSION PAUSED",12,brass)
	menu_label(root,"6 v 6  ·  Nimbus  ·  First to 100%",15,muted)
	menu_button(root,"RETURN TO THE CITY  /  TAB",func() -> void: match_controller.toggle_menu())
	menu_button(root,"DISTRICT ATLAS  /  ROUTES & HEALTH",func() -> void: overview_open = true; match_controller.toggle_menu())
	menu_button(root,"RESTART MATCH  /  F5",func() -> void: match_controller.restart_match())
	menu_button(root,"TOGGLE EXPLORATION  /  FREEZE CITY BOTS",func() -> void: match_controller.toggle_exploration())
	menu_button(root,"RETURN TO NIMBUS TRAINING",func() -> void: match_controller.return_to_training())
	menu_label(root,"20 s unlock  ·  5 s capture  ·  8 s respawn",13,muted)
	menu_label(root,"Enemy presence pauses scoring. Empty owned hills keep scoring.",12,muted)
	menu_label(root,"F3  field telemetry & route overlay    M  district atlas",12,brass)

func menu_label(parent: Node, caption: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)

func menu_button(parent: Node, caption: String, callback: Callable) -> void:
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
