class_name CombatEffect
extends Node3D

var lifetime: float = 0.2
var initial_lifetime: float = 0.2
var expanding: bool = false
var radius: float = 1.0
var visual: MeshInstance3D

static func line(parent: Node3D, from: Vector3, to: Vector3, color: Color, width: float = 0.025) -> void:
	if from.distance_to(to) < 0.01:
		return
	var effect := CombatEffect.new()
	parent.add_child(effect)
	effect.global_position = (from + to) * 0.5
	var shape := BoxMesh.new()
	shape.size = Vector3(width, width, from.distance_to(to))
	effect.visual = Geometry.mesh(effect, shape, Vector3.ZERO, Geometry.material(color, 1.5))
	effect.look_at(to)

static func pulse(parent: Node3D, at: Vector3, color: Color, size: float) -> void:
	var effect := CombatEffect.new()
	effect.expanding = true
	effect.radius = size
	effect.lifetime = 0.35
	effect.initial_lifetime = 0.35
	parent.add_child(effect)
	effect.global_position = at
	var shape := SphereMesh.new()
	shape.radius = 1.0
	shape.height = 2.0
	var mat: StandardMaterial3D = Geometry.material(color, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.22
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	effect.visual = Geometry.mesh(effect, shape, Vector3.ZERO, mat)
	effect.scale = Vector3.ONE * 0.1

func _ready() -> void:
	add_to_group("transient")

func _process(delta: float) -> void:
	lifetime -= delta
	if expanding:
		scale = Vector3.ONE * maxf(0.05, radius * (1.0 - lifetime / initial_lifetime))
	if lifetime <= 0.0:
		queue_free()
