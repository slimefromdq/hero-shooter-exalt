class_name SlayerVisuals
extends RefCounted
## Original articulated prototype, guided by the supplied layered-hair streetwear references.
static func knife(parent: Node3D) -> void:
	Geometry.box(parent,Vector3(.06,.035,.28),Vector3(0,0,-.16),Color("d4dce5"),false)
	Geometry.box(parent,Vector3(.11,.05,.035),Vector3.ZERO,Color("a6a4ba"),false)
	Geometry.box(parent,Vector3(.04,.05,.14),Vector3(0,0,.08),Color("312735"),false)

static func axe(parent: Node3D) -> void:
	Geometry.cylinder(parent,.035,1.8,Vector3(0,.15,0),Color("3c3040"))
	Geometry.cylinder(parent,.052,.55,Vector3(0,-.43,0),Color("8d354c"))
	for side: float in [-1.0,1.0]:
		var blade := PrismMesh.new()
		blade.size = Vector3(.63,.68,.14)
		var mesh: MeshInstance3D = Geometry.mesh(parent,blade,Vector3(side * .31,.8,0),Geometry.material(Color("c9cad9"),.18))
		mesh.rotation.z = side * PI / 2
		Geometry.box(parent,Vector3(.04,.52,.16),Vector3(side * .61,.8,0),Color("b98bce"),false)
	Geometry.box(parent,Vector3(.13,.38,.19),Vector3(0,.82,0),Color("674568"),false)

static func trap(parent: Node3D) -> void:
	Geometry.cylinder(parent,.24,.06,Vector3.ZERO,Color("4c4253"))
	Geometry.cylinder(parent,.1,.08,Vector3(0,.04,0),Color("e183ab"))
	for side: float in [-1.0,1.0]:
		Geometry.box(parent,Vector3(.12,.06,.5),Vector3(side * .24,.05,0),Color("b4bdcf"),false)
		for index: int in 4:
			var tooth := PrismMesh.new()
			tooth.size = Vector3(.07,.13,.08)
			Geometry.mesh(parent,tooth,Vector3(side * .23,.13,-.18 + index * .12),Geometry.material(Color("e2d8eb")))

static func remodel(p: HeroPresentation) -> void:
	for child: Node in p.body.get_children():
		if child not in [p.left_leg,p.right_leg,p.left_arm,p.right_arm,p.rifle,p.shield,p.umbrella]:
			p.body.remove_child(child)
			child.queue_free()
	for limb: Node3D in [p.left_leg,p.right_leg,p.left_arm,p.right_arm]:
		for mesh: Node in limb.find_children("*","MeshInstance3D",true,false):
			(mesh as MeshInstance3D).material_override = Geometry.material(Color("211f2b") if limb in [p.left_leg,p.right_leg] else Color("342333"))
	var skin := Color("d4a38d")
	var torso := CapsuleMesh.new()
	torso.radius = .255
	torso.height = .62
	Geometry.mesh(p.body,torso,Vector3(0,1.12,0),Geometry.material(Color("241d2b")))
	# Cropped jacket, asymmetric lapels, silver zipper and belt with visible equipment.
	Geometry.box(p.body,Vector3(.56,.38,.32),Vector3(0,1.35,.02),Color("3b2c39"),false)
	for side: float in [-1.0,1.0]:
		var lapel: Node3D = Geometry.box(p.body,Vector3(.12,.34,.06),Vector3(side * .17,1.36,-.19),Color("746170"),false)
		lapel.rotation.z = side * -.28
		Geometry.box(p.body,Vector3(.18,.18,.12),Vector3(side * .22,.86,-.05),Color("433744"),false)
	Geometry.box(p.body,Vector3(.035,.31,.055),Vector3(.06,1.31,-.21),Color("c1bacb"),false)
	Geometry.box(p.body,Vector3(.51,.1,.36),Vector3(0,.9,0),Color("151725"),false)
	Geometry.box(p.body,Vector3(.13,.09,.05),Vector3(0,.91,-.2),Color("c1b9cc"),false)
	for index: int in 3:
		var dagger := Node3D.new()
		p.body.add_child(dagger)
		dagger.position = Vector3(-.25 + index * .09,1.01,.2)
		dagger.rotation.x = PI / 2
		dagger.scale = Vector3.ONE * .65
		knife(dagger)
	var snare := Node3D.new()
	p.body.add_child(snare)
	snare.position = Vector3(.29,.92,.16)
	snare.rotation.z = PI / 2
	snare.scale = Vector3.ONE * .6
	trap(snare)
	for leg: Node3D in [p.left_leg,p.right_leg]:
		Geometry.box(leg.get_node("Joint"),Vector3(.23,.3,.38),Vector3(0,-.25,-.06),Color("151624"),false)
		Geometry.box(leg.get_node("Joint"),Vector3(.24,.06,.18),Vector3(0,-.36,-.2),Color("a2a4b7"),false)
		Geometry.box(leg,Vector3(.16,.13,.08),Vector3(.08,-.17,.07),Color("4d4554"),false)
	for arm: Node3D in [p.left_arm,p.right_arm]:
		Geometry.box(arm.get_node("Joint"),Vector3(.16,.1,.16),Vector3(0,-.22,0),Color("aaa3b9"),false)
	var head := SphereMesh.new()
	head.radius = .205
	head.height = .43
	Geometry.mesh(p.body,head,Vector3(0,1.73,0),Geometry.material(skin))
	Geometry.cylinder(p.body,.11,.16,Vector3(0,1.53,0),Color("27212e"))
	# Shaggy dark hair, raised crown and long angled side locks.
	var hair := SphereMesh.new()
	hair.radius = .224
	hair.height = .24
	Geometry.mesh(p.body,hair,Vector3(0,1.88,.025),Geometry.material(Color("171c28")))
	for index: int in 11:
		var angle: float = TAU * index / 11.0
		var lock := PrismMesh.new()
		lock.size = Vector3(.16,.39 if index % 3 == 0 else .28,.12)
		var strand: MeshInstance3D = Geometry.mesh(p.body,lock,Vector3(cos(angle) * .17,1.76,sin(angle) * .16 + .04),Geometry.material(Color("202333") if index % 2 else Color("302c40")))
		strand.rotation = Vector3(.12,.0,PI + cos(angle) * .32 + .2)
	for index: int in 5:
		var angle: float = TAU * index / 5.0
		var tuft := PrismMesh.new()
		tuft.size = Vector3(.14,.27,.12)
		var spike: MeshInstance3D = Geometry.mesh(p.body,tuft,Vector3(cos(angle) * .13,1.98,sin(angle) * .1 + .02),Geometry.material(Color("252637")))
		spike.rotation = Vector3(sin(angle) * .65,angle,cos(angle) * .7)
	for side: float in [-1.0,1.0]:
		Geometry.box(p.body,Vector3(.085,.027,.035),Vector3(side * .09,1.75,-.193),Color("e3bd77"),false)
		Geometry.cylinder(p.body,.028,.13,Vector3(side * .22,1.65,0),Color("cdc7dc"))
	Geometry.box(p.body,Vector3(.06,.025,.035),Vector3(0,1.63,-.194),Color("8c3e58"),false)
	Geometry.box(p.body,Vector3(.045,.13,.03),Vector3(-.1,1.14,-.28),Color("d2c6df"),false)
	Geometry.box(p.body,Vector3(.11,.025,.035),Vector3(-.1,1.16,-.28),Color("d2c6df"),false)
	for child: Node in p.rifle.get_children():
		p.rifle.remove_child(child)
		child.queue_free()
	Geometry.box(p.rifle,Vector3(.15,.16,.4),Vector3(0,0,-.1),Color("443247"),false)
	var barrel: MeshInstance3D = Geometry.cylinder(p.rifle,.052,.65,Vector3(0,.03,-.54),Color("b0a6b6"))
	barrel.rotation.x = PI / 2
	var magazine: MeshInstance3D = Geometry.cylinder(p.rifle,.037,.55,Vector3(0,-.06,-.5),Color("3d3346"))
	magazine.rotation.x = PI / 2
	Geometry.box(p.rifle,Vector3(.16,.1,.24),Vector3(0,-.08,-.48),Color("923e58"),false)
	Geometry.box(p.rifle,Vector3(.13,.18,.35),Vector3(0,-.06,.22),Color("2a2635"),false)
	p.slayer_axe = Node3D.new()
	p.body.add_child(p.slayer_axe)
	axe(p.slayer_axe)
	p.slayer_axe.position = Vector3(-.1,1.04,.3)
	p.slayer_axe.rotation.z = -.6
	p.slayer_axe.scale = Vector3.ONE * .7
	p.muzzle_flash = Geometry.mesh(p.rifle,SphereMesh.new(),Vector3(0,.03,-.9),Geometry.material(Color("ffd394"),3.0))
	p.muzzle_flash.scale = Vector3(.18,.18,.3)
	p.muzzle_flash.visible = false

static func animate(p: HeroPresentation) -> void:
	var a: HeroActor = p.actor
	var t := a.tuning as SlayerTuning
	p.muzzle_flash.visible = p.fire_flash > .08
	p.rifle.position.z += p.fire_flash * .7
	p.rifle.rotation.x += p.fire_flash * 1.5
	if a.state == "ready":
		p.rifle.rotation.x += asin(clampf(a.aim_direction.y,-1,1))
		p.left_arm.rotation = Vector3(1.0,-.5,.4)
	p.slayer_axe.visible = not a.state.begins_with("slayer_axe") or a.state == "slayer_axe_windup"
	p.slayer_axe.position = Vector3(-.1,1.04,.3)
	p.slayer_axe.rotation = Vector3(0,0,-.6)
	if a.state == "reload":
		p.left_arm.rotation.x = .8 + sin(a.state_time / t.shell_time * TAU) * .35
	elif a.state == "slayer_knife":
		p.left_arm.rotation = Vector3(2.1,-.2,-.5)
		p.model.rotation.z = -.12
	elif a.state == "slayer_trap":
		p.left_arm.rotation.x = 1.7
		p.model.rotation.x = .2
	elif a.state.begins_with("slayer_boot"):
		p.rifle.position = Vector3(.3,1.3,.15)
		p.rifle.rotation.x = -.6
		p.model.rotation.x = -.24 if a.state == "slayer_boot_active" else .18
		p.right_leg.rotation.x = 1.45 if a.state == "slayer_boot_active" else .7
		(p.right_leg.get_node("Joint") as Node3D).rotation.x = .12 if a.state == "slayer_boot_active" else -1.2
		p.left_leg.rotation.x = -.55
		p.left_arm.rotation = Vector3(.8,0,-.8)
	elif a.state.begins_with("slayer_axe"):
		var progress: float = clampf(1.0 - a.state_time / t.axe_windup,0,1)
		p.rifle.position = Vector3(.22,1.12,.32)
		p.rifle.rotation = Vector3(-.4,0,-.6)
		p.right_arm.rotation.x = 2.4 if a.state == "slayer_axe_windup" else 1.8
		p.left_arm.rotation = Vector3(1.9,0,-.4)
		p.slayer_axe.position = Vector3(.1,1.85,-.1)
		p.slayer_axe.rotation = Vector3(-.7 - progress * .5,0,.15)
		p.model.rotation.z = -.15
