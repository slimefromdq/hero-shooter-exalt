class_name DamageNumbers
extends Control
## Coalesce pellets on each target in a physics tick; keep separate hits readable.
var viewer: HeroActor
var font: Font
var entries: Array[Dictionary] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewer.resolver.confirmed_hit.connect(on_hit)
	viewer.resolver.event_logged.connect(on_event)

func on_event(entry: Dictionary) -> void:
	if entry.event == "reset" and entry.actor == viewer.actor_id: entries.clear()

func on_hit(source: HeroActor, target: HeroActor, amount: float, head: bool, _executed: bool) -> void:
	if source != viewer or amount <= 0: return
	var tick: int = Engine.get_physics_frames()
	for entry: Dictionary in entries:
		if entry.tick == tick and entry.target == target.get_instance_id():
			entry.amount += amount
			entry.head = entry.head or head
			return
	entries.append({"tick":tick,"target":target.get_instance_id(),"at":target.global_position + Vector3.UP * 1.9,"amount":amount,"head":head,"age":0.0})
	if entries.size() > 24: entries.pop_front()

func _process(delta: float) -> void:
	for index: int in range(entries.size() - 1,-1,-1):
		entries[index].age += delta
		if entries[index].age >= 1.0: entries.remove_at(index)
	queue_redraw()

func _draw() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or font == null: return
	var scale_factor: float = minf(size.x / 1440.0,size.y / 900.0)
	for entry: Dictionary in entries:
		if camera.is_position_behind(entry.at): continue
		var at: Vector2 = camera.unproject_position(entry.at) + Vector2(40,-40 - entry.age * 60) * scale_factor
		var alpha: float = clampf((1.0 - entry.age) * 4,0,1)
		var color := Color(1.0,.88,.38,alpha) if entry.head else Color(.95,1,.95,alpha)
		var pixels: int = maxi(18,roundi((38 if entry.head else 32) * scale_factor * (1.0 + .15 * maxf(0,1-entry.age * 8))))
		var caption: String = str(roundi(entry.amount))
		draw_string_outline(font,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,maxi(3,roundi(scale_factor * 4)),Color(.02,.035,.05,alpha))
		draw_string(font,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,color)
