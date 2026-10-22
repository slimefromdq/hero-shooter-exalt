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
		"OBJECTIVE %.1fs / BOMB SHOTS %d / EARLY %d" % [metrics.objective_seconds,metrics.bomb_shot_attempts,metrics.early_detonations],
		"PERSONA %s  confidence %+.2f  tilt %.2f" % [str(brain.personality.get("archetype","-")),brain.confidence,brain.tilt],
		"SENSES cone %.0f / side %.0f deg  heard %d  side-glimpses %d" % [brain.skill.cone_degrees,brain.skill.peripheral_degrees,brain.perception.sounds_heard,brain.perception.peripheral_detections],
		"QUERY %s  candidates %d" % [str(brain.movement.last_query.get("mode","-")),brain.movement.last_candidates.size()],
		"MOVES %s" % str(brain.movement.locomotion.counters).replace("\"","")]
	if is_instance_valid(brain.director):
		var d: TeamDirector = brain.director
		lines.append("TEAM ORDER %s  odds %.2f  focus %s  flankers %d" % [d.order,d.odds,str(d.focus_id),d.flankers.size()])
		for entry: Dictionary in d.comms_log.slice(-2): lines.append("SAYS %s: %s" % [entry.speaker,entry.text])
	var controller: Object = selected.controller
	if controller.get("link") != null:
		var link: Dictionary = controller.link
		lines.append("LINK %s  uses %d  fails %d  hops %d" % [str(link.get("type","none")),int(controller.link_uses),int(controller.link_failures),int(controller.hops)])
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
	var brain: BotBrain = selected.controller.brain
	var point: Vector3 = brain.movement.selected_position
	if not camera.is_position_behind(point) and not camera.is_position_behind(selected.body_point(2)):
		draw_line(camera.unproject_position(selected.body_point(2)),camera.unproject_position(point),Color("8be0c4"),2)
		draw_circle(camera.unproject_position(point),5,Color("8be0c4"))
	# View cone (focused and peripheral edges).
	var eye: Vector3 = selected.body_point(1.45)
	var facing: Vector3 = (selected.aim_direction*Vector3(1,0,1)).normalized()
	if not facing.is_zero_approx():
		for spec: Array in [[brain.skill.cone_degrees,Color(1,.85,.35,.8)],[brain.skill.peripheral_degrees,Color(1,.85,.35,.3)]]:
			for side: float in [-1.0,1.0]:
				var edge: Vector3 = eye+facing.rotated(Vector3.UP,deg_to_rad(float(spec[0]))*side)*8.0
				if not camera.is_position_behind(eye) and not camera.is_position_behind(edge):
					draw_line(camera.unproject_position(eye),camera.unproject_position(edge),spec[1],1.5)
	# Tactical query candidates coloured by score (red low, green high).
	var low: float = INF
	var high: float = -INF
	for entry: Array in brain.movement.last_candidates:
		low = minf(low,float(entry[1]))
		high = maxf(high,float(entry[1]))
	for entry: Array in brain.movement.last_candidates:
		var at: Vector3 = entry[0]
		if camera.is_position_behind(at): continue
		var t: float = (float(entry[1])-low)/maxf(.001,high-low)
		draw_circle(camera.unproject_position(at+Vector3.UP*.1),3.5,Color(1-t,t,.25,.85))
	# Remembered (not visible) enemies: predicted position with an uncertainty ring.
	for id: int in brain.perception.observations:
		if id in brain.perception.visible_ids: continue
		var entry: Dictionary = brain.perception.observations[id]
		var guess: Vector3 = BotPerception.predicted(entry,brain.now)
		if camera.is_position_behind(guess): continue
		var centre: Vector2 = camera.unproject_position(guess+Vector3.UP)
		var rim: Vector2 = camera.unproject_position(guess+Vector3.UP+Vector3.RIGHT*BotPerception.uncertainty(entry,brain.now))
		draw_arc(centre,maxf(4,centre.distance_to(rim)),0,TAU,24,Color(.95,.45,.45,.7),1.5)
	# Team gather point and an active traversal link.
	if is_instance_valid(brain.director) and brain.director.gather_point != Vector3.INF and not camera.is_position_behind(brain.director.gather_point):
		draw_circle(camera.unproject_position(brain.director.gather_point+Vector3.UP*.2),7,Color(.45,.7,1,.8))
	var controller: Object = selected.controller
	if controller.get("link") != null and not Dictionary(controller.link).is_empty():
		var exit: Vector3 = controller.link.exit
		if not camera.is_position_behind(exit) and not camera.is_position_behind(selected.global_position):
			draw_line(camera.unproject_position(selected.global_position),camera.unproject_position(exit),Color(.8,.5,1,.9),3)

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
