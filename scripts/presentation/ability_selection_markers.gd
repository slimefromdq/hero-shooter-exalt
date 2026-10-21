class_name AbilitySelectionMarkers
extends Node3D
## Local-player feedback only. Kits own acquisition, resources and cast permissions.
## Pool by visible target count, never retain actor references between frames.
var actor: HeroActor
var markers: Array[Label3D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func display_available() -> bool:
	if get_tree().paused or not actor.alive or not actor.controller is PlayerController: return false
	var player := actor.controller as PlayerController
	if not player.active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	if not is_instance_valid(player.camera) or not player.camera.is_current(): return false
	var session: Node = get_tree().get_first_node_in_group("game_session")
	return session == null or not session.menu_open

func _process(_delta: float) -> void:
	for marker: Label3D in markers: marker.hide()
	if not display_available(): return
	var grouped: Dictionary = {}
	var previews: Array[Dictionary] = actor.kit.selection_previews()
	var throw_target: HeroActor = actor.close.select_throw_target() if actor.permits("throw") and actor.close.grace <= 0 else null
	if throw_target != null: previews.append({"target":throw_target,"action":"throw"})
	for preview: Dictionary in previews:
		var target: HeroActor = preview.target
		if not is_instance_valid(target) or not target.alive: continue
		if not grouped.has(target): grouped[target] = PackedStringArray()
		var keys: PackedStringArray = grouped[target]
		keys.append(TrainingInputs.key_label(preview.action))
		grouped[target] = keys
	var index: int = 0
	var camera: Camera3D = (actor.controller as PlayerController).camera
	for target: HeroActor in grouped:
		var at: Vector3 = target.body_point(3.35)
		if camera.is_position_behind(at): continue
		if index >= markers.size():
			var marker := Label3D.new()
			marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.font_size = 64
			marker.outline_size = 14
			# Keep the available key readable at the full acquisition range.
			marker.fixed_size = true
			marker.pixel_size = .00065
			marker.outline_modulate = Color("12212e")
			add_child(marker)
			markers.append(marker)
		var marker: Label3D = markers[index]
		marker.text = "[ %s ]\n▽" % " / ".join(grouped[target])
		marker.modulate = Color("77ffd4") if target.team == actor.team else Color("ffad70")
		marker.global_position = at
		marker.show()
		index += 1
