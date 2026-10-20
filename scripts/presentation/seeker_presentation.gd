class_name SeekerPresentation
extends RefCounted
## Original procedural placeholders: no physics or independent combat actors.
static func bird(parent: Node, index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "GuidingSpirit" if index == 0 else "MurmurationBird%d" % index
	parent.add_child(root)
	var tint: String = "ffdc89" if index == 0 else "83e8e1" if index == 1 else "b7a6ff"
	RosterVisuals.orb(root,Vector3.ZERO,Vector3(.23,.24,.45),tint,1.0)
	RosterVisuals.orb(root,Vector3(0,.12,-.23),Vector3(.2,.2,.21),tint,1.2)
	Geometry.box(root,Vector3(.07,.06,.15),Vector3(0,.1,-.37),Color("fff3d0"),false)
	for side: int in [-1,1]:
		var wing := Node3D.new()
		wing.name = "Wing%d" % side
		root.add_child(wing)
		for feather: int in 4:
			var mesh := Geometry.box(wing,Vector3(.4-feather*.04,.025,.12),Vector3(side*(.2+feather*.06),0,.02+feather*.06),Color(tint),false)
			mesh.rotation.y = side*(.2+feather*.15)
			if index > 0:
				var mat := (mesh.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = .65
	for feather: int in (3 if index == 0 else 2):
		var crest := Geometry.box(root,Vector3(.035,.18 if index == 0 else .1,.05),Vector3((feather-1)*.055,.25,-.2),Color(tint),false)
		crest.rotation.x = -.35
	for side: int in [-1,1]: Geometry.box(root,Vector3(.07,.03,.32 if index == 0 else .48),Vector3(side*.05,-.03,.32),Color(tint),false).rotation.y = side*.2
	var shape := CylinderMesh.new()
	shape.top_radius = .5
	shape.bottom_radius = .5
	shape.height = 1
	var beam := Geometry.mesh(root,shape,Vector3.ZERO,Geometry.material(Color(tint),.8))
	beam.name = "Healing"
	beam.visible = false
	return root

static func build(p: HeroPresentation) -> void:
	for mesh: MeshInstance3D in p.body.find_children("*","MeshInstance3D",true,false): mesh.visible = false
	RosterVisuals.orb(p.body,Vector3(0,1.12,0),Vector3(.62,.8,.42),"285a61")
	RosterVisuals.orb(p.body,Vector3(0,1.78,0),Vector3(.45,.49,.43),"b98c74")
	RosterVisuals.orb(p.body,Vector3(0,1.95,.04),Vector3(.49,.28,.44),"e4dfca")
	for side: int in [-1,1]:
		RosterVisuals.orb(p.body,Vector3(side*.1,1.8,-.208),Vector3(.06,.04,.035),"92fff0",1)
		var arm: Node3D = p.left_arm if side < 0 else p.right_arm
		Geometry.cylinder(arm,.095,.34,Vector3(0,-.16,0),Color("285a61"))
		Geometry.cylinder(arm.get_node("Joint"),.075,.28,Vector3(0,-.14,0),Color("b98c74"))
		var leg: Node3D = p.left_leg if side < 0 else p.right_leg
		Geometry.cylinder(leg,.095,.36,Vector3(0,-.17,0),Color("364a57"))
		Geometry.box(leg.get_node("Joint"),Vector3(.19,.28,.31),Vector3(0,-.21,-.06),Color("293e47"),false)
		for i: int in 4:
			Geometry.box(p.body,Vector3(.11,.29,.04),Vector3(side*(.21+i*.045),1.48-i*.035,.02),Color("f0dca3"),false).rotation.z = side*.65
	# Long split cloak and feather tails distinguish the silhouette from Relay's equipment.
	for side: int in [-1,1]:
		var cloak := Geometry.box(p.body,Vector3(.27,.95,.08),Vector3(side*.16,.95,.25),Color("183d49"),false)
		cloak.rotation.x = -.16
		Geometry.box(p.body,Vector3(.07,.65,.035),Vector3(side*.24,.68,.32),Color("9bdcd0"),false).rotation.z = side*.16
	p.rifle.position = Vector3(-.35,1.35,-.45)
	var bow := Node3D.new()
	p.rifle.add_child(bow)
	p.roster_parts["seeker_bow"] = bow
	for side: int in [-1,1]:
		for segment: int in 4:
			var limb := Geometry.box(bow,Vector3(.065,.21,.065),Vector3(0,side*(.1+segment*.17),-.14*sin(segment/3.0*PI)),Color("e9c781"),false)
			limb.rotation.x = side*(segment-1.5)*.25
	var string := Geometry.box(bow,Vector3(.012,1.25,.012),Vector3(0,0,.08),Color("c8fff4"),false)
	p.roster_parts["seeker_string"] = string
	var arrow := Geometry.box(bow,Vector3(.025,.025,.75),Vector3(0,0,-.3),Color("b0fff0"),false)
	p.roster_parts["seeker_arrow"] = arrow

static func animate(p: HeroPresentation) -> void:
	var k := p.actor.kit as RelayKit
	var charge: float = k.volley_age/k.data().volley_charge if k.volley_charging else 0.0
	p.rifle.position = Vector3(-.35,1.35,-.5)
	p.rifle.rotation.x = asin(clampf(p.actor.aim_direction.y,-1,1))
	p.left_arm.rotation.x = 1.15
	p.right_arm.rotation.x = 1.1-charge*.4
	p.right_arm.rotation.z = -.3-charge*.35
	if p.roster_parts.has("seeker_string"):
		p.roster_parts.seeker_string.position.z = .08+charge*.2
		p.roster_parts.seeker_arrow.position.z = -.3+charge*.2
		p.roster_parts.seeker_bow.scale = Vector3.ONE*(1+charge*.08+p.fire_flash*.3)
