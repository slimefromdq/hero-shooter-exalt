class_name MarshalImpact
extends Node3D

const DURATION: float = .85
const RADIUS: float = 8.0
var age: float = 0.0
var rings: Array[MeshInstance3D] = []
var debris: Array[MeshInstance3D] = []

static func spawn(parent: Node3D, at: Vector3) -> MarshalImpact:
	var effect := MarshalImpact.new()
	parent.add_child(effect)
	effect.global_position = at + Vector3.UP * .07
	return effect

func _ready() -> void:
	add_to_group("transient")
	for index: int in 3:
		var ring := TorusMesh.new()
		ring.inner_radius = .94
		ring.outer_radius = 1.0
		ring.rings = 64
		ring.ring_segments = 8
		var mat := Geometry.material(Color("ffdb91") if index == 0 else Color("c9a474"),1.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mesh: MeshInstance3D = Geometry.mesh(self,ring,Vector3.UP * index * .025,mat)
		mesh.scale = Vector3.ONE * .1
		rings.append(mesh)
	for index: int in 20:
		var stone := BoxMesh.new()
		stone.size = Vector3(.12,.16,.18) * (1.0 + (index % 3) * .3)
		var mat := Geometry.material(Color("c4aa85"))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		debris.append(Geometry.mesh(self,stone,Vector3.ZERO,mat))

func _process(delta: float) -> void:
	age += delta
	var progress: float = clampf(age / DURATION,0,1)
	for index: int in rings.size():
		var travel: float = clampf((age - index * .07) / (DURATION - index * .07),0,1)
		var size: float = lerpf(.3,RADIUS - index * .8,sqrt(travel))
		rings[index].scale = Vector3(size,1 + index * 2,size)
		(rings[index].material_override as StandardMaterial3D).albedo_color.a = (1 - travel) * (.9 - index * .2)
	for index: int in debris.size():
		var angle: float = TAU * index / debris.size()
		var distance: float = .4 + progress * (3 + index % 4)
		debris[index].position = Vector3(sin(angle) * distance,maxf(0,sin(progress * PI) * (1 + index % 3 * .4)),cos(angle) * distance)
		debris[index].rotation = Vector3(progress * 8,angle,progress * 5)
		(debris[index].material_override as StandardMaterial3D).albedo_color.a = 1 - progress
	if age >= DURATION: queue_free()
