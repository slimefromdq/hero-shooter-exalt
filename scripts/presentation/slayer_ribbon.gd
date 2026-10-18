class_name SlayerRibbon
extends MeshInstance3D
## Bounded world-space history. One persistent mesh, no per-frame effect nodes.
var points: Array[Vector3] = []
var ages: Array[float] = []
var lifetime: float = .18
var width: float = .035
var mesh_data := ImmediateMesh.new()
var material: StandardMaterial3D

func _ready() -> void:
	mesh = mesh_data
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = Geometry.material(Color("bdeaff"),1.5)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

func sample(at: Vector3) -> void:
	if not points.is_empty() and points.back().distance_to(at) < .015: return
	points.append(at)
	ages.append(0.0)
	while points.size() > 32:
		points.pop_front()
		ages.pop_front()

func clear() -> void:
	points.clear()
	ages.clear()
	mesh_data.clear_surfaces()

func _process(delta: float) -> void:
	for index: int in range(ages.size()-1,-1,-1):
		ages[index] += delta
		if ages[index] >= lifetime:
			ages.remove_at(index)
			points.remove_at(index)
	mesh_data.clear_surfaces()
	if points.size() < 2: return
	mesh_data.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP,material)
	for index: int in points.size():
		var tangent: Vector3 = points[mini(index+1,points.size()-1)] - points[maxi(index-1,0)]
		var across: Vector3 = tangent.cross(Vector3.UP).normalized()
		if across.is_zero_approx(): across = Vector3.RIGHT
		var size: float = width * clampf(1.0 - ages[index]/lifetime,0,1)
		mesh_data.surface_add_vertex(points[index] - across * size)
		mesh_data.surface_add_vertex(points[index] + across * size)
	mesh_data.surface_end()
