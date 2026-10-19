class_name BotDebugOverlay
extends Control
var session: Node
var selection: int = 0
var refresh: float = 0.0
var lines: Array[String] = []
var selected: HeroActor

static func install(parent: Node) -> void:
	if parent.has_node("BotDiagnostics"): return
	var layer := CanvasLayer.new()
	layer.name = "BotDiagnostics"
	layer.layer = 8
	parent.add_child(layer)
	var overlay := BotDebugOverlay.new()
	overlay.session = parent
	layer.add_child(overlay)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode == KEY_BRACKETRIGHT: selection += 1
	elif event.keycode == KEY_BRACKETLEFT: selection = maxi(0,selection-1)

func _process(delta: float) -> void:
	visible = is_instance_valid(session) and bool(session.get("debug_view")) and not bool(session.get("menu_open"))
	if not visible: return
	refresh -= delta
	if refresh > 0: return
	refresh = .15
	var bots: Array[HeroActor] = []
	for a: HeroActor in get_tree().get_nodes_in_group("actors"):
		if a.controller != null and a.controller.get("brain") != null: bots.append(a)
	if bots.is_empty(): return
	selected = bots[selection%bots.size()]
	var brain: BotBrain = selected.controller.brain
	var metrics: Dictionary = brain.diagnostics.summary()
	lines = ["BOT DIAGNOSTICS  /  [ ] SELECT",selected.actor_id+" / "+brain.skill.title,
		"PROFILE %s / %s" % [brain.hero_profile.hero,brain.class_profile.role],
		"STATE %s  / TEAM %s" % [brain.tactical_state,brain.team_intention],
		"TARGET %s / %s" % [str(brain.target_id),"visible" if brain.visible_target() else "memory"],
		"RANGE %.0f - %.0f m" % [brain.hero_profile.minimum_range,brain.hero_profile.maximum_range],
		"ABILITY "+brain.combat.intention,"POSITION "+str(brain.movement.selected_position),
		"THREATS %d / FOLLOW-UP %d" % [brain.nearby_enemies,brain.follow_up],
		"NAV stalled %.1fs / failures %d" % [selected.controller.stuck_time,selected.controller.stuck_events],
		"QUERIES sight %d / positioning %d" % [brain.perception.ray_count,brain.movement.query_count],
		"DAMAGE %.0f / DEATHS %d / IDLE %.1fs" % [metrics.damage,metrics.deaths,metrics.idle_seconds],
		"OBJECTIVE %.1fs / BOMB SHOTS %d / EARLY %d" % [metrics.objective_seconds,metrics.bomb_shot_attempts,metrics.early_detonations]]
	append_scores("UTILITY",brain.scores)
	append_scores("ABILITY",brain.combat.ability_scores)
	for ability: String in metrics.ability_casts:
		var rate: Dictionary = metrics.ability_casts[ability]
		lines.append("HITS %s  %d / %d casts" % [ability,rate.hits,rate.casts])
	for entry: Dictionary in brain.diagnostics.history.slice(-3): lines.append("%.1f  %s" % [entry.time,entry.state])
	queue_redraw()

func _draw() -> void:
	if not visible or lines.is_empty(): return
	var font: Font = ThemeDB.fallback_font
	var width: float = minf(590,get_viewport_rect().size.x*.47)
	var origin := Vector2(get_viewport_rect().size.x-width-16,190)
	draw_style_box(panel_style(),Rect2(origin,Vector2(width,lines.size()*23+20)))
	for index: int in lines.size():
		draw_string(font,origin+Vector2(12,24+index*23),lines[index],HORIZONTAL_ALIGNMENT_LEFT,width-24,13,Color("d7f4e9"))
	if not is_instance_valid(selected) or selected.controller == null: return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null: return
	var point: Vector3 = selected.controller.brain.movement.selected_position
	if not camera.is_position_behind(point) and not camera.is_position_behind(selected.body_point(2)):
		draw_line(camera.unproject_position(selected.body_point(2)),camera.unproject_position(point),Color("8be0c4"),2)
		draw_circle(camera.unproject_position(point),5,Color("8be0c4"))

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.03,.08,.12,.92)
	return style

func append_scores(title: String, values: Dictionary) -> void:
	var row: String = title+" "
	var count: int = 0
	for key: String in values:
		row += "%s %.2f  " % [key,float(values[key])]
		count += 1
		if count%3 == 0:
			lines.append(row)
			row = title+" "
	if count%3 != 0: lines.append(row)
