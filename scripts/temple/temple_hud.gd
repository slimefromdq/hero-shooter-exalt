class_name TempleHUD
extends CityHUD

func draw_topbar(p: HeroActor) -> void:
	var m := match_controller as TempleMatch
	var rules: TempleObjective = m.objective
	for side: int in 2:
		var team: int = p.team if side == 0 else 1-p.team
		var start: float = 28 if side == 0 else 1116
		var accent: Color = mint if team == 0 else coral
		text(("ROOT" if team == 0 else "CLOUD")+(" / YOUR TEAM" if side == 0 else " / ENEMY"),Vector2(start,22),10,accent,true)
		var slot: int = 0
		for actor: HeroActor in m.actors:
			if actor.team != team: continue
			draw_team_slot(actor,Vector2(start+slot*77,30),side == 0,accent,actor == p)
			slot += 1
	panel(Vector2(510,24),Vector2(580,145))
	var clock: int = ceili(rules.preparation_remaining if rules.preparation_remaining > 0 else rules.time_remaining)
	centered("OVERTIME" if rules.overtime else "%02d:%02d" % [clock/60,clock%60],Vector2(800,52),25,coral if rules.overtime else paper,true)
	centered("SAKURA VEIL / FIVE CONTROL POINTS",Vector2(800,73),11,brass,true)
	for index: int in 5:
		var at := Vector2(538+index*108,83)
		var color: Color = muted if rules.owners[index] < 0 else (mint if rules.owners[index] == 0 else coral)
		box(at,Vector2(92,42),Color(color,.25))
		centered(String.chr(65+index),at+Vector2(46,20),18,color,true)
		centered("CONTEST" if rules.contested[index] else ("ATTACK" if rules.eligible(index,p.team) else ("OWNED" if rules.owners[index] == p.team else "LOCKED")),at+Vector2(46,36),9,color)
		box(at+Vector2(0,45),Vector2(92*rules.progress[index],4),coral if rules.capturing[index] == 1 else mint)
	var state: String = "CAPTURE ADJACENT POINTS / TAKE ALL FIVE"
	if not m.navigation_ready: state = "PREPARING MOUNTAIN ROUTES"
	elif m.exploration: state = "EXPLORE / CLOCK AND BOTS PAUSED"
	elif rules.finished: state = "STALEMATE" if rules.winner < 0 else "TEMPLE SECURED"
	elif rules.preparation_remaining > 0: state = "PREPARATION / MID OPENS SOON"
	centered(state,Vector2(800,156),11,brass)
	text("M ATLAS / B ELEVATIONS / TAB PAUSE",Vector2(1280,193),11,muted)
	if not overview_open and not m.menu_open and p.alive and not rules.finished:
		var index: int = m.goal_index(p.team)
		var target: Vector3 = m.temple_definition().POINTS[index]+Vector3.UP*2
		var camera: Camera3D = p.controller.camera if p.controller is PlayerController else null
		if camera != null and camera.is_inside_tree() and absf((camera.global_transform.affine_inverse()*target).z) > .01:
			var layout: Dictionary = MuseumObjectiveMarker.screen_layout(camera,target,canvas.size)
			var position: Vector2 = layout.position
			canvas.draw_circle(position,12,Color(brass,.8))
			centered(String.chr(65+index),position+Vector2(0,5),15,ink,true)
			centered(("APPROACH " if layout.edge else "POINT ")+String.chr(65+index)+" / %d m" % int(p.global_position.distance_to(target)),position-Vector2(0,23),12,brass,true)

func atlas_point(at: Vector3) -> Vector2:
	return Vector2(800,528)+Vector2(at.x,at.z)*1.65

func draw_overview() -> void:
	var m := match_controller as TempleMatch
	panel(Vector2(120,205),Vector2(1360,620))
	text("SAKURA VEIL / "+("UPPER GALLERIES + ROOFS" if underground_view else "LOWER GALLERIES + MAIN"),Vector2(150,242),22,brass,true)
	text("M close / B elevation layer / gold: main / pink: upper / cyan: lower / green: health",Vector2(150,267),12,paper)
	for index: int in 5:
		var at: Vector3 = m.temple_definition().POINTS[index]
		box(atlas_point(at)-Vector2(36,32)*1.65,Vector2(72,64)*1.65,Color("344b55"))
	for entry: Dictionary in m.arena.builder.routes:
		var kind: String = entry.kind
		if kind.begins_with("upper") and not underground_view: continue
		if kind.begins_with("lower") and underground_view: continue
		var color: Color = brass if kind == "main" else (Color("e5a9cb") if kind.begins_with("upper") else mint if kind.begins_with("lower") else muted)
		var line := PackedVector2Array()
		for at: Vector3 in entry.points: line.append(atlas_point(at))
		# Independent broad segments avoid miter spikes at hairpins and ramps.
		for segment: int in range(1,line.size()):
			if line[segment].distance_squared_to(line[segment-1]) < .01: continue
			canvas.draw_line(line[segment-1],line[segment],Color(color,.35),entry.width*1.65,true)
		canvas.draw_polyline(line,color,2,true)
	for index: int in 5:
		var at: Vector2 = atlas_point(m.temple_definition().POINTS[index])
		var owner: int = m.objective.owners[index]
		var color: Color = muted if owner < 0 else (mint if owner == 0 else coral)
		canvas.draw_rect(Rect2(at-Vector2(20,18)*1.65,Vector2(40,36)*1.65),color,false,2)
		centered(String.chr(65+index)+" / %+d m" % int(m.temple_definition().POINTS[index].y),at+Vector2(0,5),14,paper,true)
	for pickup: CityHealthPack in m.pickups:
		if (pickup.position.y > 12) != underground_view: continue
		canvas.draw_circle(atlas_point(pickup.position),4,health_green if pickup.available else muted)
	for team: int in 2:
		var center: Vector3 = m.temple_definition().room_center(team,m.stages[team])
		box(atlas_point(center)-Vector2(10,6),Vector2(20,12),mint if team == 0 else coral)
	for actor: HeroActor in m.actors:
		if actor.alive and (actor.team == m.player.team or m.debug_view): canvas.draw_circle(atlas_point(actor.position),5 if actor == m.player else 3,mint if actor.team == 0 else coral)
	for gallery: Dictionary in m.temple_definition().galleries():
		if not underground_view: continue
		var at: Vector2 = atlas_point(gallery.center)
		canvas.draw_rect(Rect2(at-Vector2(14,6)*1.65,Vector2(28,12)*1.65),Color("e5a9cb"),false,2)
	for entry: Dictionary in m.arena.builder.audit:
		if entry.element != "stairs": continue
		canvas.draw_line(atlas_point(entry.from),atlas_point(entry.to),paper,3)
	for pad: Dictionary in m.temple_definition().jump_pads():
		var start: Vector2 = atlas_point(pad.position)
		var end: Vector2 = atlas_point(pad.destination)
		canvas.draw_circle(start,5,Color("68e5dc"))
		canvas.draw_line(start,end,Color("68e5dc"),2)
		var direction: Vector2 = (end-start).normalized()
		canvas.draw_line(end,end-direction.rotated(.5)*9,Color("68e5dc"),2)
		canvas.draw_line(end,end-direction.rotated(-.5)*9,Color("68e5dc"),2)
	text("TEMPLE CONNECTIONS",Vector2(165,320),17,brass,true)
	text("White: stairs and ramps",Vector2(165,348),12,paper)
	text("Cyan arrows: directional wind lifts",Vector2(165,370),12,paper)
	text("Pink: upper fighting galleries",Vector2(165,392),12,paper)
	text("Every gallery also has stairs",Vector2(165,414),12,paper)
	text("WIND LIFTS",Vector2(1130,650),17,brass,true)
	text("Step on a marked pad to launch",Vector2(1130,678),12,paper)
	text("Steer or use abilities in flight",Vector2(1130,700),12,paper)
	text("Gold squares mark landing areas",Vector2(1130,722),12,paper)

func draw_debug(_p: HeroActor) -> void:
	var m := match_controller as TempleMatch
	text("TEMPLE / NAV BAKE %d ms / %d AUDITED ELEMENTS" % [m.arena.builder.bake_milliseconds,m.arena.builder.audit.size()],Vector2(30,275),12,mint)
