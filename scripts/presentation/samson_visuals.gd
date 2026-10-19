class_name SamsonVisuals
extends RefCounted

static func roach(parent: Node3D, at: Vector3, scale: float, tint: Color) -> Node3D:
	var bug := Node3D.new()
	parent.add_child(bug)
	bug.position = at
	bug.scale = Vector3.ONE*scale
	var shell := SphereMesh.new()
	shell.radius = .45
	shell.height = 1.1
	var body: MeshInstance3D = Geometry.mesh(bug,shell,Vector3.ZERO,Geometry.material(tint,.35))
	body.scale = Vector3(.65,.3,1.3)
	for side: float in [-1,1]:
		for i: int in 3:
			var leg: Node3D = Geometry.box(bug,Vector3(.55,.045,.045),Vector3(side*.35,-.05,(i-1)*.3),tint,false)
			leg.rotation.y = side*(i-1)*.5
		var antenna: Node3D = Geometry.box(bug,Vector3(.035,.035,.7),Vector3(side*.2,.05,-.75),tint,false)
		antenna.rotation.y = side*.3
	return bug

static func remodel(p: HeroPresentation) -> void:
	for mesh: MeshInstance3D in p.body.find_children("*","MeshInstance3D",true,false): mesh.visible = false
	# Retain the articulated common limbs so locomotion, melee and throws keep
	# their authored animation hooks beneath the new shell and suit.
	for limb: Node3D in [p.left_arm,p.right_arm,p.left_leg,p.right_leg]:
		for mesh: MeshInstance3D in limb.find_children("*","MeshInstance3D",true,false):
			mesh.visible = true
			mesh.material_override = Geometry.material(Color("805b38"))
	p.umbrella.visible = false
	RosterVisuals.orb(p.body,Vector3(0,1.1,0),Vector3(.7,.85,.45),"293e38")
	RosterVisuals.orb(p.body,Vector3(0,1.1,.22),Vector3(.65,.9,.3),"805b38")
	RosterVisuals.orb(p.body,Vector3(0,1.76,-.02),Vector3(.48,.48,.36),"a97849")
	for side: float in [-1,1]:
		RosterVisuals.orb(p.body,Vector3(side*.15,1.8,-.17),Vector3(.16,.15,.08),"151d15")
		var antenna: Node3D = Geometry.box(p.body,Vector3(.025,.45,.025),Vector3(side*.17,2.07,-.02),Color("b99264"),false)
		antenna.rotation.z = -side*.25
		Geometry.box(p.body,Vector3(.22,.06,.06),Vector3(side*.15,1.81,-.23),Color("dbbe7e"),false)
		for i: int in 2:
			var arm: Node3D = Geometry.box(p.body,Vector3(.11,.45,.11),Vector3(side*.42,1.2-i*.2,.1),Color("956a42"),false)
			arm.rotation.z = side*.6
	Geometry.box(p.body,Vector3(.12,.45,.035),Vector3(0,1.2,-.24),Color("e2d5ac"),false)
	Geometry.box(p.body,Vector3(.045,.3,.045),Vector3(0,1.25,-.27),Color("d8a14a"),false)
	p.rifle.visible = true
	p.rifle.scale = Vector3.ONE*.7
	Geometry.box(p.rifle,Vector3(.22,.16,.5),Vector3(0,0,-.25),Color("25473c"),false)
	Geometry.cylinder(p.rifle,.08,.3,Vector3(0,.13,-.15),Color("65e6c1"))
	Geometry.box(p.body,Vector3(.3,.38,.07),Vector3(-.45,1.15,-.2),Color("e4d49b"),false)

static func animate(p: HeroPresentation) -> void:
	p.umbrella.visible = false
	p.body.rotation.x = -.18 if p.actor.state == "samson_intervene" else 0.0
	if p.actor.state == "samson_cross":
		p.right_arm.rotation.x = -1.1
		p.left_arm.rotation.x = -.6
	elif p.actor.state == "samson_court_start":
		p.right_arm.rotation.z = -.9
		p.left_arm.rotation.z = .9
	if p.actor.statuses.stunned() or p.actor.statuses.silenced():
		p.debug_label.visible = true
		p.debug_label.text = "STUNNED" if p.actor.statuses.stunned() else "SILENCED"
