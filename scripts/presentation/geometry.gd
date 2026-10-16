class_name Geometry
extends RefCounted

static func material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.82
	if emission > 0.0:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = emission
	return result

static func mesh(parent: Node3D, shape: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = shape
	result.material_override = mat
	result.position = at
	parent.add_child(result)
	return result

static func box(parent: Node3D, size: Vector3, at: Vector3, color: Color, solid: bool = true) -> Node3D:
	var root := StaticBody3D.new() if solid else Node3D.new()
	parent.add_child(root)
	root.position = at
	var shape := BoxMesh.new()
	shape.size = size
	mesh(root, shape, Vector3.ZERO, material(color))
	if solid:
		var collision := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		root.add_child(collision)
	return root

static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	return mesh(parent, shape, at, material(color))

static func text3d(parent: Node3D, caption: String, at: Vector3, size: int = 64, color: Color = Color.WHITE) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.font_size = size
	label.pixel_size = 0.008
	label.position = at
	label.modulate = color
	label.outline_size = 0
	parent.add_child(label)
	return label
