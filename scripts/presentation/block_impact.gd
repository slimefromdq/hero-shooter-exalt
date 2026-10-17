class_name BlockImpact
extends Node3D

const DURATION: float = 0.32
var age: float = 0.0
var rings: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var flash: MeshInstance3D

static func spawn(parent: Node3D, at: Vector3, normal: Vector3) -> BlockImpact:
	var effect := BlockImpact.new()
	parent.add_child(effect)
	effect.global_position = at
	effect.look_at(at + normal, Vector3.UP)
	return effect

func _ready() -> void:
	add_to_group("transient")
	for index: int in 2:
		var ring := TorusMesh.new()
		ring.inner_radius = .38 if index == 0 else .49
		ring.outer_radius = ring.inner_radius + .035
		ring.rings = 24
		ring.ring_segments = 8
		var mesh: MeshInstance3D = Geometry.mesh(self, ring, Vector3.ZERO, glow(Color("8bfff1") if index == 0 else Color("ffe3a0")))
		mesh.rotation.x = PI / 2
		rings.append(mesh)
	for index: int in 12:
		var streak := BoxMesh.new()
		streak.size = Vector3(.035, .18 if index % 2 == 0 else .11, .025)
		var mesh: MeshInstance3D = Geometry.mesh(self, streak, Vector3.ZERO, glow(Color("fff0bd")))
		mesh.rotation.z = -TAU * index / 12.0
		sparks.append(mesh)
	var core := SphereMesh.new()
	core.radius = .17
	core.height = .34
	flash = Geometry.mesh(self, core, Vector3.ZERO, glow(Color("fff8df")))

func glow(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = Geometry.material(color, 2.0)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func _process(delta: float) -> void:
	age += delta
	var progress: float = clampf(age / DURATION, 0.0, 1.0)
	for index: int in rings.size():
		rings[index].scale = Vector3.ONE * lerpf(.9, 2.6 + index * .35, sqrt(progress))
		(rings[index].material_override as StandardMaterial3D).albedo_color.a = 1.0 - progress
	for index: int in sparks.size():
		var angle: float = TAU * index / sparks.size()
		sparks[index].position = Vector3(sin(angle), cos(angle), -.12 * progress) * (.45 + sqrt(progress) * (1.0 if index % 2 == 0 else .75))
		sparks[index].scale = Vector3.ONE * (1.0 - progress * .85)
		(sparks[index].material_override as StandardMaterial3D).albedo_color.a = 1.0 - progress
	flash.scale = Vector3.ONE * maxf(.001, 1.0 - progress * 4.0)
	if age >= DURATION:
		queue_free()
