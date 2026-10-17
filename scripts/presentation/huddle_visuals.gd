class_name HuddleVisuals
extends RefCounted
## Reusable original toy-like bugs. No textures or imported character assets.
static var materials: Dictionary = {}
static var shared_sphere: SphereMesh

static func material(color: String) -> StandardMaterial3D:
	if not materials.has(color):
		var mat: StandardMaterial3D = Geometry.material(Color(color))
		if color == "f5d34e":
			mat.emission_enabled = true
			mat.emission = Color(color)
			mat.emission_energy_multiplier = .16
		if color == "302418": mat.roughness = .16
		if color in ["fff3bd","e6ecbe"]:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = .65
			mat.roughness = .25
		materials[color] = mat
	return materials[color]

static func orb(parent: Node3D, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	if shared_sphere == null:
		shared_sphere = SphereMesh.new()
		shared_sphere.radius = .5
		shared_sphere.height = 1.0
		shared_sphere.radial_segments = 12
		shared_sphere.rings = 6
	var result: MeshInstance3D = Geometry.mesh(parent,shared_sphere,at,material(color))
	result.scale = size
	return result

static func bug(parent: Node3D, radius: float = .2) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.scale = Vector3.ONE*radius
	orb(root,Vector3.ZERO,Vector3(2,1.7,1.6),"f5d34e")
	for i: int in 5:
		var angle: float = i*PI/4
		orb(root,Vector3(cos(angle)*.81,sin(angle)*.7,0),Vector3(.42,.42,.8),"f5d34e")
	for side: float in [-1.0,1.0]:
		orb(root,Vector3(side*.42,.16,-.7),Vector3(.64,.72,.3),"302418")
		orb(root,Vector3(side*.42-.09,.3,-.86),Vector3(.19,.21,.08),"fff9de")
		orb(root,Vector3(side*.62,-.1,-.7),Vector3(.24,.13,.08),"efa574")
		orb(root,Vector3(side*.65,-.75,-.18),Vector3(.45,.35,.45),"ffe58b")
		var stalk: MeshInstance3D = orb(root,Vector3(side*.5,1.05,0),Vector3(.1,.7,.1),"c49b39")
		stalk.rotation.z = -side*.35
		orb(root,Vector3(side*.64,1.4,0),Vector3(.36,.36,.36),"ffe68a")
		var wing: Node3D = Node3D.new()
		wing.name = "WingL" if side < 0 else "WingR"
		wing.position = Vector3(side*.8,.1,.38)
		root.add_child(wing)
		orb(wing,Vector3(side*.3,.25,0),Vector3(.85,1.25,.12),"fff3bd").rotation.z = -side*.5
		orb(wing,Vector3(side*.24,-.25,0),Vector3(.65,.7,.1),"e6ecbe").rotation.z = side*.5
	orb(root,Vector3(0,-.22,-.8),Vector3(.28,.12,.08),"775330")
	return root

static func remodel(p: HeroPresentation) -> void:
	# Preserve the shared limb nodes as animation anchors, but replace their meshes.
	for mesh: MeshInstance3D in p.body.find_children("*","MeshInstance3D",true,false): mesh.visible = false
	p.huddle_colony = Node3D.new()
	p.body.add_child(p.huddle_colony)
	for i: int in 24:
		var b: Node3D = bug(p.huddle_colony,.20 if i < 23 else .25)
		var tier: int = i/6
		var angle: float = (i%6)*TAU/6+tier*.35
		b.position = Vector3(cos(angle)*(.23 if tier < 3 else .12),.23+tier*.41,sin(angle)*.19)
		if i == 23: b.position = Vector3(0,1.65,-.07)
		b.set_meta("home",b.position)
		p.huddle_bugs.append(b)
	# Team-colored leaf sash, keeping both colonies distinct.
	var trim := Color("77dbc8") if p.actor.team == 0 else Color("ef8b92")
	Geometry.box(p.huddle_colony,Vector3(.42,.08,.05),Vector3(0,1.2,-.36),trim,false)

static func animate(p: HeroPresentation) -> void:
	var a: HeroActor = p.actor
	var k := a.kit as HuddleKit
	p.rifle.visible = false
	p.umbrella.visible = false
	var time: float = Time.get_ticks_msec()*.001
	var wave: bool = a.state == "huddle_wave"
	var scatter: bool = a.state == "huddle_scatter"
	var heal: bool = a.state == "huddle_regroup"
	for i: int in p.huddle_bugs.size():
		var b: Node3D = p.huddle_bugs[i]
		var home: Vector3 = b.get_meta("home")
		if wave:
			b.position = Vector3(((i%8)/7.0-.5)*k.data().wave_width,.35+(i/8)*.5+sin(time*13+i)*.1,sin(i*2.4)*.42)
			# The larger lookout keeps the damageable center readable during the surge.
			if i == p.huddle_bugs.size()-1: b.position = Vector3(0,1.1,-.12)
		elif scatter:
			b.position = home+Vector3(sin(i*2.4+time*7)*.23,cos(time*11+i)*.16,sin(i*1.7)*.35)
		elif heal:
			b.position = Vector3(home.x*.75,home.y*.72,home.z*.75)
		else:
			b.position = home+Vector3(0,sin(time*4+i*.8)*.035,0)
		b.rotation.z = sin(time*(12 if wave else 4)+i)*(.18 if scatter or wave else .045)
		b.rotation.y = sin(time*.7+i)*.15
		for name: String in ["WingL","WingR"]:
			var wing: Node3D = b.get_node(name)
			wing.rotation.y = sin(time*(40 if scatter or wave else 22)+i)*.55
	if a.state == "huddle_wave_start": p.huddle_colony.scale = Vector3(1.2,.8,1.2)
	elif a.state == "huddle_pulse": p.huddle_colony.scale = Vector3.ONE*1.15
	else: p.huddle_colony.scale = Vector3.ONE
	# A colony crouches by compressing its stack, keeping the lowest bugs above
	# the floor while the shared camera, muzzle and collision move down.
	p.huddle_colony.position.y = a.motor.posture_lowering()
	if a.motor.crouched: p.huddle_colony.scale *= Vector3(1.1,.6,1.1)
