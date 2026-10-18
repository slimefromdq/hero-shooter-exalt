class_name CombatEffect
extends Node3D

var lifetime: float = 0.2
var initial_lifetime: float = 0.2
var expanding: bool = false
var radius: float = 1.0
var visual: MeshInstance3D
var fading: bool = false

static func cone_warning(parent: Node3D, origin: Vector3, forward: Vector3, reach: float, seconds: float) -> CombatEffect:
	var effect := CombatEffect.new()
	effect.lifetime = seconds
	effect.initial_lifetime = seconds
	parent.add_child(effect)
	var mat := Geometry.material(Color("ffba64"),1.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,mat)
	lines.surface_add_vertex(Vector3.ZERO)
	for i: int in 33:
		lines.surface_add_vertex(forward.rotated(Vector3.UP,lerpf(-PI/4,PI/4,i/32.0)) * reach)
	lines.surface_add_vertex(Vector3.ZERO)
	lines.surface_end()
	effect.visual = Geometry.mesh(effect,lines,Vector3.ZERO,mat)
	effect.position = origin + Vector3.UP * .06
	return effect

static func streak(parent: Node3D, from: Vector3, to: Vector3, width: float, seconds: float) -> void:
	if from.distance_to(to) < .001: return
	var effect := CombatEffect.new()
	effect.fading = true
	effect.lifetime = seconds
	effect.initial_lifetime = seconds
	parent.add_child(effect)
	effect.add_to_group("knife_trails")
	effect.global_position = (from + to) * .5
	var shape := BoxMesh.new()
	shape.size = Vector3(width,width,from.distance_to(to))
	var mat: StandardMaterial3D = Geometry.material(Color("c2f6ff"),1.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	effect.visual = Geometry.mesh(effect,shape,Vector3.ZERO,mat)
	effect.look_at(to,Vector3.RIGHT if absf((to-from).normalized().dot(Vector3.UP)) > .99 else Vector3.UP)

static func line(parent: Node3D, from: Vector3, to: Vector3, color: Color, width: float = 0.025) -> void:
	if from.distance_to(to) < 0.01:
		return
	var effect := CombatEffect.new()
	parent.add_child(effect)
	effect.global_position = (from + to) * 0.5
	var shape := BoxMesh.new()
	shape.size = Vector3(width, width, from.distance_to(to))
	effect.visual = Geometry.mesh(effect, shape, Vector3.ZERO, Geometry.material(color, 1.5))
	effect.look_at(to,Vector3.RIGHT if absf((to-from).normalized().dot(Vector3.UP)) > .99 else Vector3.UP)

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
	if fading:
		(visual.material_override as StandardMaterial3D).albedo_color.a = clampf(lifetime / initial_lifetime,0,1)
	if lifetime <= 0.0:
		queue_free()
