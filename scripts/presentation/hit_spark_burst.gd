class_name HitSparkBurst
extends Node3D
var tint: Color = Color("ff4057")
var age: float = 0
var sparks: Array[MeshInstance3D] = []
var directions: Array[Vector3] = []
func _ready() -> void:
	add_to_group("transient")
	var mat := Geometry.material(tint,1.5)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for index: int in 7:
		var shape := SphereMesh.new()
		shape.radius = .035
		shape.height = .07
		sparks.append(Geometry.mesh(self,shape,Vector3.ZERO,mat))
		directions.append(Vector3(cos(index*2.4),sin(index*2.4),sin(index*1.7)).normalized())
func _process(delta: float) -> void:
	age += delta
	if age >= .22:
		queue_free()
		return
	for index: int in sparks.size():
		sparks[index].position = directions[index]*age*2.2
		sparks[index].scale = Vector3.ONE*(1-age/.22)
