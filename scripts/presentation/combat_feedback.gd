class_name CombatFeedback
extends Control
var viewer: HeroActor
var markers: Dictionary = {}
var incoming: Array[Dictionary] = []
var skull_left: float = 0
var low_alpha: float = 0
static func marker_size(amount: float) -> float:
	return clampf(13.0+sqrt(maxf(0,amount))*1.15,16,36)
static func low_health_strength(health: float, maximum: float) -> float:
	return clampf((.25-health/maxf(1,maximum))/.25,0,1)
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewer.resolver.impact_confirmed.connect(on_impact)
	viewer.resolver.elimination.connect(on_elimination)
	viewer.resolver.feedback_cleared.connect(clear_for)
	viewer.died.connect(clear)
func clear_for(actor: HeroActor) -> void:
	if actor == viewer: clear()
func clear() -> void:
	markers.clear()
	incoming.clear()
	skull_left = 0
	low_alpha = 0
func on_elimination(killer: HeroActor, _victim: HeroActor, _assistants: Array[HeroActor], _ability: String) -> void:
	if killer == viewer: skull_left = .6
func on_impact(source: HeroActor, target: HeroActor, amount: float, head: bool, _executed: bool, origin: Vector3, _shields: float, cast: int, tag: String) -> void:
	if amount <= 0:
		# Immortality at 1 HP still communicates admitted incoming attacks.
		if target == viewer and viewer.training_prevent_death:
			incoming.append({"origin":origin,"age":0.0})
			if incoming.size() > 12: incoming.pop_front()
		return
	if source == viewer:
		var key: String = "%d:%s" % [Engine.get_physics_frames(),tag] if tag in ["shotgun","cannon"] else str(cast)
		if markers.has(key):
			markers[key].amount += amount
			markers[key].head = markers[key].head or head
		else: markers[key] = {"amount":amount,"head":head,"age":0.0}
	if target == viewer:
		incoming.append({"origin":origin,"age":0.0})
		if incoming.size() > 12: incoming.pop_front()
func _process(delta: float) -> void:
	skull_left = maxf(0,skull_left-delta)
	for key: String in markers.keys():
		markers[key].age += delta
		if markers[key].age > .35: markers.erase(key)
	for index: int in range(incoming.size()-1,-1,-1):
		incoming[index].age += delta
		if incoming[index].age >= 1: incoming.remove_at(index)
	var desired: float = low_health_strength(viewer.health,viewer.effective_max_health())*.44 if viewer.alive else 0.0
	low_alpha = move_toward(low_alpha,desired,delta*1.5)
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(viewer) or not viewer.alive: return
	var center: Vector2 = size*.5
	var factor: float = minf(size.x/1440,size.y/900)
	var camera := get_viewport().get_camera_3d()
	# Layered transparent edges keep the centre of the view unobstructed.
	for index: int in 24:
		var inset: float = index*4*factor
		var alpha: float = low_alpha*(1-index/24.0)*.4
		if not incoming.is_empty(): alpha += (1-float(incoming.back().age))*.008*(1-index/24.0)
		draw_rect(Rect2(Vector2.ONE*inset,size-Vector2.ONE*inset*2),Color(1,.015,.045,alpha),false,8*factor)
	if camera != null:
		for hit: Dictionary in incoming:
			var alpha: float = minf(1,(1-hit.age)*2)
			if hit.origin == Vector3.INF:
				draw_arc(center,112*factor,0,TAU,64,Color(1,.16,.2,alpha*.6),4*factor,true)
				continue
			var direction: Vector3 = camera.global_basis.inverse()*(hit.origin-viewer.body_point(1))
			var angle: float = atan2(direction.x,-direction.z)-PI*.5
			draw_arc(center,132*factor,angle-.28,angle+.28,16,Color(0,0,0,alpha*.85),11*factor,true)
			draw_arc(center,132*factor,angle-.28,angle+.28,16,Color(1,.08,.13,alpha),6*factor,true)
			var radial := Vector2.from_angle(angle)
			var side := Vector2(-radial.y,radial.x)
			draw_colored_polygon(PackedVector2Array([center+radial*112*factor,center+(radial*126+side*7)*factor,center+(radial*126-side*7)*factor]),Color(1,.32,.3,alpha))
	if skull_left > 0:
		var color := Color(1,.04,.12,minf(1,skull_left*6))
		var at: Vector2 = center+Vector2(0,-35)*factor
		draw_circle(at,11*factor,color)
		draw_rect(Rect2(at+Vector2(-7,5)*factor,Vector2(14,12)*factor),color)
		for side: float in [-1.0,1.0]:
			draw_circle(at+Vector2(side*4,-1)*factor,3*factor,Color("180c16"))
		draw_line(at+Vector2(-3,9)*factor,at+Vector2(-3,15)*factor,Color("180c16"),2*factor)
		draw_line(at+Vector2(3,9)*factor,at+Vector2(3,15)*factor,Color("180c16"),2*factor)
	elif not markers.is_empty():
		var hit: Dictionary = markers.values().back()
		var radius: float = marker_size(hit.amount)*factor
		var alpha: float = minf(1,(.35-hit.age)*8)
		var color := Color(1,.045,.12,alpha) if hit.head else Color(1,1,1,alpha)
		for diagonal: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			var direction: Vector2 = diagonal.normalized()
			var a: Vector2 = center+direction*radius
			var b: Vector2 = center+direction*(radius+9*factor)
			if hit.head: draw_line(a,b,Color(1,0,.03,alpha*.25),10*factor,true)
			draw_line(a,b,Color(0,0,0,alpha*.8),5*factor,true)
			draw_line(a,b,color,2.5*factor,true)
