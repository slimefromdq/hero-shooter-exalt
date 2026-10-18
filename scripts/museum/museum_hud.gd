class_name MuseumHUD
extends CityHUD

func draw_topbar(p: HeroActor) -> void:
	var m := match_controller as MuseumMatch
	var capturing: bool = m.capture_progress < 1.0
	for side: int in 2:
		var team: int = p.team if side == 0 else 1-p.team
		var start: float = 28 if side == 0 else 1116
		var accent: Color = mint if team == 0 else coral
		text(("ATTACK" if team == 0 else "DEFEND")+(" / YOUR TEAM" if side == 0 else " / ENEMY"),Vector2(start,22),10,accent,true)
		var slot: int = 0
		for actor: HeroActor in m.actors:
			if actor.team != team: continue
			draw_team_slot(actor,Vector2(start+slot*77,30),side == 0,accent,actor == p)
			slot += 1
	panel(Vector2(510,24),Vector2(580,118))
	var clock: int = ceili(m.objective.preparation_remaining if m.phase == "preparation" else m.time_remaining)
	centered("OVERTIME" if m.overtime else "%02d:%02d" % [clock/60,clock%60],Vector2(800,53),26,coral if m.overtime else paper,true)
	centered("MERIDIAN MUSEUM / CAPTURE + ESCORT",Vector2(800,73),11,brass,true)
	var status: String = "CAPTURE THE ASTROLABE" if m.phase == "capture" else "ESCORT / CHECKPOINT %d OF 3" % mini(3,m.checkpoint_index+1)
	if not m.navigation_ready: status = "PREPARING NAVIGATION"
	elif m.exploration: status = "EXPLORE / CLOCK AND BOTS PAUSED"
	elif m.phase == "preparation": status = "DEFENDERS DEPLOY / ATTACK GATES CLOSED"
	elif m.winner >= 0: status = "ATTACK VICTORY" if m.winner == 0 else "DEFENSE VICTORY"
	elif m.objective.contested: status = "CONTESTED / "+status
	centered(status,Vector2(800,95),12,coral if m.objective.contested else mint,true)
	for index: int in 3:
		var x: float = 540+index*174
		box(Vector2(x,108),Vector2(164,7),Color("394550"))
		var progress: float = clampf(m.capture_progress*3-index,0,1) if capturing else clampf((m.payload_distance-(0.0 if index == 0 else m.museum_definition().checkpoint_distances()[index-1]))/(m.museum_definition().checkpoint_distances()[index]-(0.0 if index == 0 else m.museum_definition().checkpoint_distances()[index-1])),0,1)
		box(Vector2(x,108),Vector2(progress*164,7),mint)
		centered(("CAPTURE %d" if capturing else "CP%d") % (index+1),Vector2(x+82,132),10,brass)
	text("M  ATLAS / B  LEVELS / TAB  PAUSE",Vector2(1310,193),11,muted)

func draw_overview() -> void:
	var m := match_controller as MuseumMatch
	var d: MuseumMapDefinition = m.museum_definition()
	panel(Vector2(120,210),Vector2(1360,500))
	text("MERIDIAN MUSEUM / "+("ELEVATED ROUTES" if underground_view else "GROUND + GARDEN"),Vector2(150,245),23,brass,true)
	text("M close / B switch levels   |   stairs: gold   shortcuts: cyan   medical: green   active spawn: team color",Vector2(150,272),12,paper)
	var bounds := Rect2(165,320,1250,290)
	for index: int in 4:
		var left: float = [-26.0,16,64,108][index]
		var right: float = [16.0,64,108,160][index]
		var a: Vector2 = map_point(Vector3(left,0,-26),bounds)
		var b: Vector2 = map_point(Vector3(right,0,26),bounds)
		box(a,b-a,Color(.16+index*.02,.23,.27))
		text(["A / ASTROLABE","CP1 / GIANTS","CP2 / TERRACE","CP3 / VAULT"][index],Vector2(a.x,310),13,brass,true)
	# Draw authored collision footprints, so the atlas describes actual walls,
	# exhibit cover and platforms rather than an abstract lane diagram.
	for child: Node in m.arena.builder.architecture.collision_body.get_children():
		var collision := child as CollisionShape3D
		if collision.shape is BoxShape3D:
			var size: Vector3 = collision.shape.size
			if size.y < .1 or size.x > 100 or size.z > 70: continue
			var ground: float = 1.5 if collision.position.x >= 108 else 0.0
			var top: float = collision.position.y+size.y/2
			if top <= ground+.2: continue
			var corners := PackedVector2Array()
			for corner: Vector3 in [Vector3(-size.x/2,0,-size.z/2),Vector3(size.x/2,0,-size.z/2),Vector3(size.x/2,0,size.z/2),Vector3(-size.x/2,0,size.z/2)]:
				corners.append(map_point(collision.transform*corner,bounds))
			canvas.draw_colored_polygon(corners,Color("8898a0") if size.y > 3 else Color("4f6c73"))
		elif collision.shape is CylinderShape3D:
			canvas.draw_circle(map_point(collision.position,bounds),collision.shape.radius*bounds.size.x/266,Color("70848b"))
	var capture_a: Vector2 = map_point(Vector3(-9,0,-7),bounds)
	var capture_b: Vector2 = map_point(Vector3(9,0,7),bounds)
	canvas.draw_rect(Rect2(capture_a,capture_b-capture_a),mint,false,2)
	for index: int in range(1,d.payload_path.size()):
		canvas.draw_line(map_point(d.payload_path[index-1],bounds),map_point(d.payload_path[index],bounds),brass,3,true)
	for index: int in 3:
		var at: Vector2 = map_point(d.path_position(d.checkpoint_distances()[index]),bounds)
		canvas.draw_circle(at,6,mint)
		text("CP%d" % (index+1),at+Vector2(0,20),11,paper,true)
	for stair: Dictionary in m.arena.builder.stairs:
		canvas.draw_line(map_point(stair.a,bounds),map_point(stair.b,bounds),Color("ffcb74"),3,true)
	for shortcut: Dictionary in m.arena.builder.shortcuts:
		canvas.draw_line(map_point(shortcut.a,bounds),map_point(shortcut.b,bounds),mint,2,true)
	if underground_view:
		for index: int in d.high_positions.size():
			var at: Vector2 = map_point(d.high_positions[index],bounds)
			canvas.draw_circle(at,7,brass)
			text("+%.1f m" % d.high_positions[index].y,at+Vector2(8,-5),12,paper)
	else:
		for point: Vector3 in d.small_pack_positions: canvas.draw_circle(map_point(point,bounds),4,health_green)
		for point: Vector3 in d.large_pack_positions: canvas.draw_circle(map_point(point,bounds),7,health_green)
	for team: int in 2:
		var rooms: Array[Vector3] = d.attacker_rooms if team == 0 else d.defender_rooms
		for index: int in rooms.size():
			var at: Vector2 = map_point(rooms[index],bounds)
			var active: bool = index == (d.attacker_stage if team == 0 else d.defender_stage)
			box(at-Vector2(10,7),Vector2(20,14),(mint if team == 0 else coral) if active else muted.darkened(.65))
			text(("A" if team == 0 else "D")+str(index),at+Vector2(-7,-11),11,paper)
	var objective_at: Vector3 = Vector3.ZERO if m.capture_progress < 1.0 else m.payload.global_position
	canvas.draw_circle(map_point(objective_at,bounds),10,mint,false,2)
	for actor: HeroActor in m.actors:
		if actor.alive: canvas.draw_circle(map_point(actor.global_position,bounds),4,paper if actor == m.player else (mint if actor.team == 0 else coral))
	text("A: 0 / +3.6 m    GIANTS: 0 / +4 m    TERRACE: garden -1.5 / roof +4.5 m    VAULT: +1.5 / gantry +5 m",Vector2(165,650),14,paper)
	text("All primary perches have two ordinary approaches. Missed skill jumps land on lower playable routes.",Vector2(165,679),13,muted)

func map_point(point: Vector3, bounds: Rect2) -> Vector2:
	return bounds.position+Vector2((point.x+66)/266,(point.z+40)/80)*bounds.size

func draw_player_rail(p: HeroActor) -> void:
	super.draw_player_rail(p)
	if p.kit is DynamoKit and p.kit.previewing and not p.kit.wall_valid:
		centered("INVALID WALL / KEEP THE PAYLOAD TRACK AND SPAWN EXITS CLEAR",Vector2(800,655),14,coral,true)
