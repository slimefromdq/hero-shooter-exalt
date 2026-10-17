class_name CityHealthPack
extends Node3D

signal collected(actor: HeroActor, amount: float)

@export var heal_amount: float = 75.0
@export var respawn_seconds: float = 10.0
var available: bool = true
var cooldown_remaining: float = 0.0
var label: Label3D
var symbol: Node3D
var glow: OmniLight3D
var animation_time: float = 0.0

func _ready() -> void:
	add_to_group("city_health_packs")
	var base_material := StandardMaterial3D.new()
	base_material.albedo_color = Color("18352e")
	base_material.metallic = 0.6
	base_material.roughness = 0.3
	var base := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.72 if heal_amount >= 400 else 0.52
	disc.bottom_radius = disc.top_radius + 0.06
	disc.height = 0.12
	disc.radial_segments = 24
	base.mesh = disc
	base.material_override = base_material
	base.position.y = 0.07
	add_child(base)
	symbol = Node3D.new()
	add_child(symbol)
	var medical := StandardMaterial3D.new()
	medical.albedo_color = Color("8bff9d")
	medical.emission_enabled = true
	medical.emission = Color("48f47a")
	medical.emission_energy_multiplier = 2.0
	var cross_scale: float = 0.8 if heal_amount >= 400 else 0.58
	for size: Vector3 in [Vector3(cross_scale, 0.19, 0.18), Vector3(0.19, cross_scale, 0.18)]:
		var cross_mesh := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = size
		cross_mesh.mesh = shape
		cross_mesh.material_override = medical
		symbol.add_child(cross_mesh)
	label = Label3D.new()
	label.position.y = 1.7
	label.font_size = 36
	label.pixel_size = 0.006
	label.modulate = Color("c3ffcb")
	label.outline_modulate = Color("102a20")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	add_child(label)
	glow = OmniLight3D.new()
	glow.light_color = Color("67ffa0")
	glow.light_energy = 0.45
	glow.omni_range = 2.5
	glow.shadow_enabled = false
	glow.position.y = 0.8
	add_child(glow)
	_sync_visual()

func _process(delta: float) -> void:
	animation_time += delta
	if is_instance_valid(symbol):
		symbol.position.y = 0.9 + sin(animation_time * 2.1) * 0.09
		symbol.rotation.y += delta * 0.75
	if cooldown_remaining > 0.0:
		cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
		if cooldown_remaining <= 0.0:
			available = true
		_sync_visual()

func try_collect(actor: HeroActor) -> bool:
	if not available or not is_instance_valid(actor) or not actor.alive or actor.health >= actor.effective_max_health():
		return false
	var restored: float = minf(heal_amount, maxf(0.0, actor.effective_max_health() - actor.health))
	if restored <= 0.0:
		return false
	actor.health += restored
	available = false
	cooldown_remaining = respawn_seconds
	_sync_visual()
	collected.emit(actor, restored)
	return true

func is_available() -> bool:
	return available

func try_pickup(actor: HeroActor) -> bool:
	return try_collect(actor)

func reset() -> void:
	available = true
	cooldown_remaining = 0.0
	_sync_visual()

func _sync_visual() -> void:
	if not is_instance_valid(label):
		return
	symbol.visible = available
	glow.visible = available
	label.text = "+%d HP" % int(heal_amount) if available else "%ds" % ceili(cooldown_remaining)
	label.modulate = Color("c3ffcb") if available else Color("6c8378")
