class_name SlayerBurstEffect
extends Node3D
## Shared finite lifetime for the authored muzzle and impact scenes. No physics or RNG.
@export var duration: float = .42
@export var flash_duration: float = .075
var age: float = 0.0

func _ready() -> void:
	for child: Node in get_children():
		if child is MeshInstance3D: child.material_override = child.material_override.duplicate()
	deactivate()

func activate() -> void:
	age = 0.0
	visible = true
	set_process(true)
	get_node("Flash").visible = true
	get_node("Flash").scale = Vector3.ONE
	add_to_group("transient")
	add_to_group("slayer_bursts")
	for child: Node in get_children():
		if child is GPUParticles3D: child.restart()

func deactivate() -> void:
	visible = false
	set_process(false)
	remove_from_group("transient")
	remove_from_group("slayer_bursts")
	for child: Node in get_children():
		if child is GPUParticles3D: child.emitting = false

func tint(colour: Color) -> void:
	for child: Node in get_children():
		if child is MeshInstance3D:
			var material: StandardMaterial3D = child.material_override
			material.albedo_color = colour
			material.emission = colour
			child.material_override = material

func _process(delta: float) -> void:
	age += delta
	var flash := get_node("Flash") as MeshInstance3D
	flash.visible = age < flash_duration
	flash.scale = Vector3.ONE * lerpf(1.0, .35, clampf(age / flash_duration, 0, 1))
	if has_node("Shockwave"):
		var ring := get_node("Shockwave") as MeshInstance3D
		ring.scale = Vector3.ONE * lerpf(.2, 7.0, clampf(age / duration,0,1))
		(ring.material_override as StandardMaterial3D).albedo_color.a = .35 * clampf(1.0-age/duration,0,1)
	if age >= duration: get_node("/root/SlayerEffectPool").recycle(self)
