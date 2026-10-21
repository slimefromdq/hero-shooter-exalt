class_name DamageNumbers
extends Control
## Coalesce pellets on each target in a physics tick; keep separate hits readable.
var viewer: HeroActor
var font: Font
var entries: Array[Dictionary] = []
var incoming: Array[Dictionary] = []
var hurt_sound: AudioStreamPlayer
var hit_sound: AudioStreamPlayer
var pending_hit: int = -1

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewer.resolver.impact_confirmed.connect(on_impact)
	viewer.resolver.confirmed_heal.connect(on_heal)
	viewer.resolver.event_logged.connect(on_event)
	viewer.resolver.feedback_cleared.connect(clear_for)
	hurt_sound = AudioStreamPlayer.new()
	hurt_sound.bus = "Feedback"
	hurt_sound.volume_db = -9
	add_child(hurt_sound)
	hit_sound = AudioStreamPlayer.new()
	hit_sound.bus = "Feedback"
	hit_sound.volume_db = -13
	add_child(hit_sound)

func clear_for(actor: HeroActor) -> void:
	if actor != viewer: return
	entries.clear()
	incoming.clear()
	if hurt_sound != null: hurt_sound.stop()
	if hit_sound != null: hit_sound.stop()
	pending_hit = -1

func on_impact(source: HeroActor, target: HeroActor, amount: float, head: bool, executed: bool, origin: Vector3, shield_damage: float, _cast_id: int, _tag: String) -> void:
	if amount <= 0: return
	on_hit(source,target,amount,head,executed)
	if source == viewer and not entries.is_empty():
		pending_hit = maxi(pending_hit,3 if executed or not target.alive else 2 if head else 1 if shield_damage > 0 else 0)
		var entry: Dictionary = entries.back()
		for candidate: Dictionary in entries:
			if candidate.target == target.get_instance_id() and candidate.tick == Engine.get_physics_frames(): entry = candidate
		entry.shield = float(entry.get("shield",0))+shield_damage
		entry.executed = bool(entry.get("executed",false)) or executed or not target.alive
	if target != viewer or amount <= 0: return
	incoming.append({"origin":origin,"age":0.0,"amount":amount})
	if incoming.size() > 8: incoming.pop_front()
	if not hurt_sound.playing:
		hurt_sound.stream = ProceduralSound.slayer_wave("hurt_shield" if shield_damage > 0 else "hurt_body")
		if DisplayServer.get_name() != "headless": hurt_sound.play()

func on_event(entry: Dictionary) -> void:
	if (entry.event == "reset" and entry.actor == viewer.actor_id) or entry.event == "round_end":
		entries.clear()
		incoming.clear()
		if hurt_sound != null: hurt_sound.stop()

func on_hit(source: HeroActor, target: HeroActor, amount: float, head: bool, _executed: bool) -> void:
	if source != viewer or amount <= 0: return
	var tick: int = Engine.get_physics_frames()
	for entry: Dictionary in entries:
		if not entry.get("healing",false) and entry.tick == tick and entry.target == target.get_instance_id():
			entry.amount += amount
			entry.head = entry.head or head
			return
	entries.append({"tick":tick,"target":target.get_instance_id(),"at":target.global_position + Vector3.UP * 1.9,"amount":amount,"head":head,"age":0.0})
	if entries.size() > 24: entries.pop_front()

func on_heal(source: HeroActor, target: HeroActor, amount: float) -> void:
	if source != viewer or amount <= 0: return
	for entry: Dictionary in entries:
		if entry.get("healing",false) and entry.target == target.get_instance_id() and entry.age < .25:
			entry.amount += amount
			entry.at = target.global_position + Vector3.UP * 2
			return
	entries.append({"tick":Engine.get_physics_frames(),"target":target.get_instance_id(),"at":target.global_position + Vector3.UP * 2,"amount":amount,"head":false,"age":0.0,"healing":true})
	if entries.size() > 24: entries.pop_front()

func _process(delta: float) -> void:
	if pending_hit >= 0:
		hit_sound.stream = ProceduralSound.slayer_wave(["hit_body","hit_shield","hit_head","hit_finish"][pending_hit])
		if DisplayServer.get_name() != "headless": hit_sound.play()
		pending_hit = -1
	for index: int in range(incoming.size()-1,-1,-1):
		incoming[index].age += delta
		if incoming[index].age >= .8: incoming.remove_at(index)
	for index: int in range(entries.size() - 1,-1,-1):
		entries[index].age += delta
		if entries[index].age >= 1.0: entries.remove_at(index)
	queue_redraw()

func _draw() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or font == null: return
	var scale_factor: float = minf(size.x / 1440.0,size.y / 900.0)
	var center: Vector2 = size*.5
	for hit: Dictionary in incoming:
		var alpha: float = clampf((.8-hit.age)*2,0,1)
		if hit.origin == Vector3.INF:
			draw_arc(center,115*scale_factor,0,TAU,40,Color(1,.35,.2,alpha*.4),3)
			continue
		var direction: Vector3 = camera.global_basis.inverse()*(hit.origin-viewer.body_point(1))
		var angle: float = atan2(direction.x,-direction.z)-PI*.5
		draw_arc(center,125*scale_factor,angle-.20,angle+.20,12,Color(1,.24,.14,alpha),6*scale_factor,true)
		draw_line(center+Vector2.from_angle(angle)*112*scale_factor,center+Vector2.from_angle(angle)*102*scale_factor,Color(1,.7,.35,alpha),3,true)
	if viewer.alive:
		var caption: String = viewer.close.notice if viewer.close.notice_left > 0 else ""
		if caption != "": draw_string_outline(font,center+Vector2(-65,80),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,24,5,Color.BLACK)
		if caption != "": draw_string(font,center+Vector2(-65,80),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("fff1a3"))
		var target: HeroActor = viewer.close.select_throw_target() if viewer.permits("throw") and viewer.close.grace <= 0 else null
		if target != null:
			var text: String = "[%s] THROW  %.1fm" % [TrainingInputs.key_label("throw"),viewer.global_position.distance_to(target.global_position)]
			draw_string_outline(font,center+Vector2(-100,120),text,HORIZONTAL_ALIGNMENT_LEFT,-1,20,4,Color.BLACK)
			draw_string(font,center+Vector2(-100,120),text,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("ffe49a"))
			var forward: Vector3 = (viewer.aim_direction*Vector3(1,0,1)).normalized()
			for i: int in 13:
				var point: Vector3 = viewer.global_position+forward.rotated(Vector3.UP,lerpf(-.86,.86,i/12.0))*viewer.tuning.throw_range+Vector3.UP*.04
				if not camera.is_position_behind(point): draw_circle(camera.unproject_position(point),2.5,Color("ffe49a"))
		elif viewer.close.grace > 0:
			draw_string(font,center+Vector2(40,65),"THROW IMMUNE %.1fs" % viewer.close.grace,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a8ddff"))
	for entry: Dictionary in entries:
		if camera.is_position_behind(entry.at): continue
		var at: Vector2 = camera.unproject_position(entry.at) + Vector2(40,-40 - entry.age * 60) * scale_factor
		var alpha: float = clampf((1.0 - entry.age) * 4,0,1)
		var color := Color(1.0,.88,.38,alpha) if entry.head else Color(.95,1,.95,alpha)
		if entry.get("healing",false): color = Color(.5,1,.75,alpha)
		elif float(entry.get("shield",0)) > 0: color = Color(.5,.85,1,alpha)
		var pixels: int = maxi(18,roundi((38 if entry.head else 32) * scale_factor * (1.0 + .15 * maxf(0,1-entry.age * 8))))
		var caption: String = ("+" if entry.get("healing",false) else "") + str(roundi(entry.amount))
		if not entry.get("healing",false):
			caption = ("◆ " if entry.head else "• ")+caption
			if float(entry.get("shield",0)) > 0: caption += " ◇"
			if entry.get("executed",false): caption += " KO"
		draw_string_outline(font,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,maxi(3,roundi(scale_factor * 4)),Color(.02,.035,.05,alpha))
		draw_string(font,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)

func _exit_tree() -> void:
	for voice: AudioStreamPlayer in [hurt_sound,hit_sound]:
		if not is_instance_valid(voice): continue
		voice.stop()
		voice.stream = null
