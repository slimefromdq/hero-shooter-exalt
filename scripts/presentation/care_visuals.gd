class_name CareVisuals
extends RefCounted

static func remodel(p: HeroPresentation) -> void:
	var marshal: bool = p.actor.tuning.hero_id == "marshal"
	var cloth := Color("233e61") if marshal else Color("eee8d7")
	var trim := Color("d6b36d") if marshal else Color("48786f")
	var skin := Color("d3ac8e")
	for child: Node in p.body.get_children():
		if child not in [p.left_leg,p.right_leg,p.left_arm,p.right_arm,p.rifle,p.shield,p.umbrella]:
			p.body.remove_child(child)
			child.queue_free()
	for limb: Node3D in [p.left_leg,p.right_leg,p.left_arm,p.right_arm]:
		for mesh: MeshInstance3D in limb.find_children("*","MeshInstance3D",true,false): mesh.material_override = Geometry.material(cloth)
		if limb in [p.left_arm,p.right_arm]:
			Geometry.box(limb.get_node("Joint"),Vector3(.19,.17,.2),Vector3(0,-.23,0),Color("f6f1df"),false)
	Geometry.box(p.body,Vector3(.72 if marshal else .51,.64,.4),Vector3(0,1.2,0),cloth,false)
	Geometry.box(p.body,Vector3(.12,.44,.05),Vector3(0,1.3,-.23),Color("fff7e0"),false)
	for side: float in [-1.0,1.0]:
		var lapel: Node3D = Geometry.box(p.body,Vector3(.12,.42,.07),Vector3(side*.16,1.3,-.25),trim,false)
		lapel.rotation.z = side * -.2
		Geometry.box(p.body,Vector3(.32 if marshal else .25,.5,.34),Vector3(side*.16,.7,.04),cloth,false)
		if marshal:
			Geometry.box(p.body,Vector3(.3,.09,.46),Vector3(side*.4,1.52,0),trim,false)
			Geometry.box(p.body,Vector3(.07,.28,.07),Vector3(side*.48,1.4,-.1),trim,false)
		else:
			Geometry.box(p.body,Vector3(.17,.15,.035),Vector3(side*.15,.98,-.22),Color("c8d3c7"),false)
	for i: int in 4:
		Geometry.box(p.body,Vector3(.04,.04,.04),Vector3(.08,1.08+i*.09,-.26),trim,false)
	var head := SphereMesh.new()
	head.radius = .235 if marshal else .21
	head.height = .47 if marshal else .44
	Geometry.mesh(p.body,head,Vector3(0,1.77,0),Geometry.material(skin))
	# Facial features face forward (-Z), keeping the moustache readable in portraits.
	for side: float in [-1.0,1.0]:
		Geometry.box(p.body,Vector3(.045,.025,.025),Vector3(side*.08,1.8,-.208),Color("263d44"),false)
		Geometry.box(p.body,Vector3(.08,.025,.035),Vector3(side*.09,1.85,-.2),Color("544637"),false)
	Geometry.box(p.body,Vector3(.07,.08,.08),Vector3(0,1.74,-.22),skin,false)
	Geometry.box(p.body,Vector3(.075,.018,.025),Vector3(0,1.63,-.2),Color("80574b"),false)
	if marshal:
		Geometry.cylinder(p.body,.25,.12,Vector3(0,1.99,0),cloth)
		Geometry.box(p.body,Vector3(.46,.04,.26),Vector3(0,1.94,-.13),trim,false)
		for side: float in [-1.0,1.0]:
			for i: int in 10:
				var curl := SphereMesh.new()
				curl.radius = .043 - i*.002
				curl.height = curl.radius*2
				Geometry.mesh(p.body,curl,Vector3(side*(.02+i*.024),1.69 + pow(i/9.0,3)*.11,-.25),Geometry.material(Color("795b3d")))
		Geometry.box(p.body,Vector3(.12,.2,.035),Vector3(-.23,1.35,-.25),trim,false)
		Geometry.box(p.body,Vector3(.12,.05,.04),Vector3(-.23,1.45,-.28),Color("bf5753"),false)
	else:
		var hair := SphereMesh.new()
		hair.radius = .215
		hair.height = .28
		Geometry.mesh(p.body,hair,Vector3(0,1.96,.025),Geometry.material(Color("4d3534")))
		var bun := SphereMesh.new()
		bun.radius = .13
		bun.height = .26
		Geometry.mesh(p.body,bun,Vector3(0,1.93,.23),Geometry.material(Color("4d3534")))
		Geometry.box(p.body,Vector3(.29,.12,.3),Vector3(0,1.53,0),Color("faf4e2"),false)
		Geometry.box(p.body,Vector3(.13,.08,.055),Vector3(0,1.5,-.22),trim,false)
		# Medical emblem and a brass stethoscope loop.
		Geometry.box(p.body,Vector3(.035,.13,.03),Vector3(-.17,1.3,-.28),trim,false)
		Geometry.box(p.body,Vector3(.11,.035,.03),Vector3(-.17,1.3,-.28),trim,false)
	for child: Node in p.rifle.get_children():
		p.rifle.remove_child(child)
		child.queue_free()
	if marshal:
		Geometry.box(p.rifle,Vector3(.26,.28,.65),Vector3(0,0,-.15),Color("27323c"),false)
		for x: float in [-.07,.07]:
			Geometry.box(p.rifle,Vector3(.075,.09,.4),Vector3(x,.04,-.6),trim,false)
		Geometry.cylinder(p.rifle,.15,.26,Vector3(0,-.05,.16),trim)
	else:
		Geometry.box(p.rifle,Vector3(.09,.13,.37),Vector3(0,0,-.15),Color("cbbd8b"),false)
		Geometry.box(p.rifle,Vector3(.08,.18,.09),Vector3(0,-.12,0),Color("48786f"),false)
		Geometry.box(p.rifle,Vector3(.045,.045,.16),Vector3(0,.08,-.13),Color("b1efde"),false)
	p.care_tool = Node3D.new()
	p.body.add_child(p.care_tool)
	if marshal:
		Geometry.cylinder(p.care_tool,.04,.65,Vector3.ZERO,trim)
		Geometry.box(p.care_tool,Vector3(.28,.28,.28),Vector3(0,.4,0),Color("dccca3"),false)
		Geometry.box(p.body,Vector3(.22,.32,.15),Vector3(-.4,1.1,-.18),trim,false)
	else:
		Geometry.box(p.care_tool,Vector3(.13,.25,.18),Vector3.ZERO,Color("cbbd8b"),false)
		var light := SphereMesh.new()
		light.radius = .07
		light.height = .14
		Geometry.mesh(p.care_tool,light,Vector3(0,.17,0),Geometry.material(Color("95efcb"),1.0))
	p.animator.add_animation_library("care",animations())

static func animations() -> AnimationLibrary:
	var library := AnimationLibrary.new()
	var slam := Animation.new()
	slam.length = 1.0
	CloseCombatAnimations.track(slam,"Model/Geometry/RightArm:rotation",[0,.6,.85,1],[Vector3(1.1,0,0),Vector3(2.9,0,.1),Vector3(2.8,0,.1),Vector3(.5,0,.1)])
	CloseCombatAnimations.track(slam,"Model:rotation",[0,.6,.85,1],[Vector3.ZERO,Vector3(-.25,0,0),Vector3(-.2,0,0),Vector3(.5,0,0)])
	library.add_animation("verdict",slam)
	var care := Animation.new()
	care.length = 1.0
	CloseCombatAnimations.track(care,"Model/Geometry/LeftArm:rotation",[0,.3,1],[Vector3(.1,0,-.15),Vector3(1.3,0,-.3),Vector3(1.6,0,-.15)])
	CloseCombatAnimations.track(care,"Model:rotation",[0,.5,1],[Vector3.ZERO,Vector3(0,-.15,0),Vector3.ZERO])
	library.add_animation("prescribe",care)
	return library

static func animate(p: HeroPresentation) -> void:
	var a: HeroActor = p.actor
	p.umbrella.visible = false
	if a.kit is MarshalKit:
		p.care_tool.visible = a.state.begins_with("melee_") or a.state in ["marshal_verdict","marshal_recovery"]
		p.care_tool.position = Vector3(.4,1.4,-.3)
		p.care_tool.rotation = p.right_arm.rotation
		p.rifle.visible = not p.care_tool.visible and a.state != "marshal_shield"
		if a.state == "marshal_shield": p.left_arm.rotation.x = 1.45
	else:
		p.care_tool.visible = (a.kit as DoctorKit).beam_healing or a.state == "doctor_ultimate"
		p.care_tool.position = Vector3(-.35,1.35,-.45)
		p.rifle.visible = not p.care_tool.visible
		if p.care_tool.visible: p.left_arm.rotation.x = 1.4
