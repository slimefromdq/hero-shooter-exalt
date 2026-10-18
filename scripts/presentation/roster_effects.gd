class_name RosterEffects
extends RefCounted

static func drone(parent: Node) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	Geometry.box(root,Vector3(.38,.18,.3),Vector3.ZERO,Color("d79b38"),false)
	var eye := SphereMesh.new()
	eye.radius = .075
	eye.height = .15
	Geometry.mesh(root,eye,Vector3(0,0,-.18),Geometry.material(Color("fff0b1"),1.5))
	for side: float in [-1.0,1.0]:
		Geometry.box(root,Vector3(.4,.045,.055),Vector3(side*.3,.04,0),Color("394957"),false)
		var ring := TorusMesh.new()
		ring.inner_radius = .12
		ring.outer_radius = .15
		Geometry.mesh(root,ring,Vector3(side*.38,.07,0),Geometry.material(Color("ffd774"),.7))
	return root

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
