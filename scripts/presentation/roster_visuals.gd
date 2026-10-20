class_name RosterVisuals
extends RefCounted

static func orb(parent: Node3D, at: Vector3, scale: Vector3, color: String, glow: float = 0) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radius = .5
	shape.height = 1
	shape.radial_segments = 16
	shape.rings = 8
	var mesh: MeshInstance3D = Geometry.mesh(parent,shape,at,Geometry.material(Color(color),glow))
	mesh.scale = scale
	return mesh

static func remodel(p: HeroPresentation) -> void:
	if p.actor.kit is StitchKit:
		StitchPresentation.build(p)
		return
	for mesh: MeshInstance3D in p.body.find_children("*","MeshInstance3D",true,false): mesh.visible = false
	var id: String = p.actor.tuning.hero_id
	var heavy: bool = id == "dynamo"
	var thief: bool = id == "wisp"
	var cloth: String = "465567" if heavy else "513d76" if thief else "c38c39"
	var skin: String = "9f715d" if heavy else "cfae9b" if thief else "cfa786"
	orb(p.body,Vector3(0,1.05,0),Vector3(1.0,1.05,.72) if heavy else Vector3(.59,.78,.4),cloth)
	orb(p.body,Vector3(0,1.76,0),Vector3(.47,.5,.43),skin)
	orb(p.body,Vector3(0,1.95,.035),Vector3(.52,.29,.46),"c2bdaf" if heavy else "28233f" if thief else "433f3d")
	for side: float in [-1.0,1.0]:
		orb(p.body,Vector3(side*.1,1.79,-.204),Vector3(.065,.045,.035),"edc3ff" if thief else "28353c",.6 if thief else 0)
		var arm: Node3D = p.left_arm if side < 0 else p.right_arm
		Geometry.cylinder(arm,.15 if heavy else .1,.33,Vector3(0,-.15,0),Color(cloth))
		Geometry.cylinder(arm.get_node("Joint"),.12 if heavy else .08,.26,Vector3(0,-.13,0),Color("b49762") if heavy else Color(skin))
		var leg: Node3D = p.left_leg if side < 0 else p.right_leg
		Geometry.cylinder(leg,.15 if heavy else .095,.32,Vector3(0,-.16,0),Color("354450") if heavy else Color(cloth))
		Geometry.box(leg.get_node("Joint"),Vector3(.3,.3,.43) if heavy else Vector3(.18,.23,.3),Vector3(0,-.22,-.07),Color("343143") if thief else Color("26363e"),false)
		orb(p.body,Vector3(side*(.45 if heavy else .32),1.44,0),Vector3(.48,.37,.5) if heavy else Vector3(.23,.22,.29),"b5a176" if heavy else cloth)
	p.rifle.position = Vector3(.36,1.28,-.35)
	Geometry.box(p.rifle,Vector3(.23,.2,.5),Vector3(0,0,-.12),Color("394451"),false)
	if heavy:
		Geometry.box(p.body,Vector3(.66,.27,.16),Vector3(0,1.22,-.36),Color("a38c62"),false)
		for side: float in [-1.0,1.0]:
			Geometry.box(p.body,Vector3(.21,.48,.18),Vector3(side*.28,.95,-.32),Color("657686"),false)
			orb(p.body,Vector3(side*.26,1.76,.03),Vector3(.18,.27,.2),"b9b8ad")
		var rotor := Node3D.new()
		p.rifle.add_child(rotor)
		p.roster_parts["rotor"] = rotor
		rotor.position = Vector3(0,0,-.42)
		for i: int in 6:
			var angle: float = i*TAU/6
			Geometry.cylinder(rotor,.035,.85,Vector3(cos(angle)*.11,sin(angle)*.11,-.25),Color("aeb5bd")).rotation.x = PI/2
		for z: float in [-.2,-.65]:
			var ring := TorusMesh.new()
			ring.inner_radius = .13
			ring.outer_radius = .18
			Geometry.mesh(rotor,ring,Vector3(0,0,z),Geometry.material(Color("c2a36d"))).rotation.x = PI/2
		Geometry.box(p.rifle,Vector3(.35,.35,.28),Vector3(0,-.12,.12),Color("6d786f"),false)
	elif thief:
		# Ivory domino mask, tailored lapels and silk tails.
		Geometry.box(p.body,Vector3(.4,.11,.055),Vector3(0,1.79,-.226),Color("f6e6ff"),false)
		for side: float in [-1.0,1.0]:
			Geometry.box(p.body,Vector3(.065,.04,.065),Vector3(side*.1,1.79,-.258),Color("30213e"),false)
			var lapel: Node3D = Geometry.box(p.body,Vector3(.09,.36,.04),Vector3(side*.12,1.26,-.21),Color("c69ae8"),false)
			lapel.rotation.z = side*.3
			Geometry.box(p.body,Vector3(.09,.14,.025),Vector3(side*.28,1.08,-.22),Color("eee1fa"),false).rotation.z = side*.25
		var skirt := CylinderMesh.new()
		skirt.top_radius = .22
		skirt.bottom_radius = .39
		skirt.height = .55
		Geometry.mesh(p.body,skirt,Vector3(0,.75,0),Geometry.material(Color("46335f")))
		for side: float in [-1.0,1.0]:
			orb(p.body,Vector3(side*.24,1.83,.05),Vector3(.27,.5,.4),"28233f")
			var ribbon: Node3D = Geometry.box(p.body,Vector3(.12,.7,.045),Vector3(side*.3,.75,.19),Color("ad8cd4"),false)
			ribbon.rotation.z = side*.2
		p.rifle.scale = Vector3.ONE*.7
		Geometry.box(p.rifle,Vector3(.075,.08,.48),Vector3(0,.05,-.42),Color("d9b7ef"),false)
		Geometry.box(p.rifle,Vector3(.09,.23,.1),Vector3(0,-.12,.02),Color("9f79c0"),false)
		var second := Node3D.new()
		p.body.add_child(second)
		p.roster_parts["second"] = second
		Geometry.box(second,Vector3(.16,.14,.42),Vector3.ZERO,Color("d9b7ef"),false)
		Geometry.box(second,Vector3(.075,.18,.09),Vector3(0,-.1,.12),Color("9f79c0"),false)
		var meshes: Array[MeshInstance3D] = []
		for mesh: MeshInstance3D in p.body.find_children("*","MeshInstance3D",true,false):
			if not mesh.visible: continue
			var mat := mesh.material_override as StandardMaterial3D
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = 1.0
			meshes.append(mesh)
		p.roster_parts["thief_meshes"] = meshes
	else:
		Geometry.box(p.body,Vector3(.13,.45,.08),Vector3(-.15,1.16,-.21),Color("ffe1a4"),false)
		Geometry.box(p.body,Vector3(.4,.47,.24),Vector3(0,1.18,.29),Color("465c61"),false)
		Geometry.box(p.body,Vector3(.39,.1,.07),Vector3(0,1.79,-.23),Color("b7dddf"),false)
		Geometry.box(p.body,Vector3(.13,.25,.12),Vector3(.25,1.88,0),Color("e4b957"),false)
		Geometry.box(p.rifle,Vector3(.065,.07,.48),Vector3(0,.015,-.44),Color("f1c968"),false)
		Geometry.box(p.rifle,Vector3(.11,.23,.16),Vector3(0,-.17,.05),Color("b9a275"),false)

static func animate(p: HeroPresentation, delta: float) -> void:
	if p.actor.kit is StitchKit:
		StitchPresentation.animate(p,delta)
		return
	var actor: HeroActor = p.actor
	p.umbrella.visible = false
	if actor.kit is DynamoKit:
		var k := actor.kit as DynamoKit
		(p.roster_parts["rotor"] as Node3D).rotation.z += delta*k.spin*40
		p.left_arm.rotation.x = 1.0
		p.right_arm.rotation.x = 1.15
		p.rifle.position = Vector3(.34,1.2,-.35)
		if k.charge_left > 0: p.rifle.rotation.z = sin(Time.get_ticks_msec()*.02)*.025
	elif actor.kit is WispKit:
		var phased: bool = actor.state == "wisp_phase"
		for mesh: MeshInstance3D in p.roster_parts["thief_meshes"]:
			(mesh.material_override as StandardMaterial3D).albedo_color.a = .22 if phased else 1.0
		var second: Node3D = p.roster_parts["second"]
		second.position = Vector3(-.34,1.34,-.46)
		second.rotation = p.rifle.rotation
		p.left_arm.rotation.x = 1.25
		if actor.state == "wisp_heist_start" or (actor.kit as WispKit).leap_active:
			p.model.rotation.z = sin(Time.get_ticks_msec()*.004)*.15
			p.left_leg.rotation.x = -.35
			p.right_leg.rotation.x = .5
		else: p.model.rotation.z = 0
