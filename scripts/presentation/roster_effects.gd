class_name RosterEffects
extends RefCounted

static func zone(parent: Node, at: Vector3, radius: float, color: Color) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = at+Vector3.UP*.06
	var ring := TorusMesh.new()
	ring.inner_radius = maxf(.1,radius-.09)
	ring.outer_radius = radius
	ring.rings = 48
	ring.ring_segments = 8
	var mat: StandardMaterial3D = Geometry.material(color,.8)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Geometry.mesh(root,ring,Vector3.ZERO,mat)
	for i: int in 12:
		var theta: float = i*TAU/12
		var pillar: Node3D = Geometry.box(root,Vector3(.045,.6,.045),Vector3(cos(theta)*radius,.3,sin(theta)*radius),color,false)
		pillar.rotation.y = -theta
	return root

static func wall_preview(parent: Node, tuning: DynamoTuning) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var box := BoxMesh.new()
	box.size = Vector3(tuning.wall_width,tuning.wall_height,tuning.wall_depth)
	var mat: StandardMaterial3D = Geometry.material(Color(.2,1,.7,.25),.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Geometry.mesh(root,box,Vector3.ZERO,mat)
	return root
