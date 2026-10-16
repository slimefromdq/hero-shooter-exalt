class_name HeroPresentation
extends Node3D

var actor: HeroActor
var model: Node3D
var umbrella: Node3D
var canopy: MeshInstance3D
var shield: MeshInstance3D
var rifle: Node3D
var nameplate: Label3D
var debug_label: Label3D
var fire_flash: float = 0.0
var walk_phase: float = 0.0
var left_leg: MeshInstance3D
var right_leg: MeshInstance3D
var sound: ProceduralSound
var was_grounded: bool = false

func _ready() -> void:
	model = Node3D.new()
	add_child(model)
	var suit: Color = Color("253d4b") if actor.team == 0 else Color("aa534a")
	var trim: Color = Color("80e1d0") if actor.team == 0 else Color("ffd4b4")
	var torso := CapsuleMesh.new()
	torso.radius = 0.3
	torso.height = 0.84
	Geometry.mesh(model, torso, Vector3(0, 1.12, 0), Geometry.material(suit))
	Geometry.box(model, Vector3(0.13, 0.42, 0.05), Vector3(0, 1.26, -0.27), Color("f2ebd9"), false)
	Geometry.box(model, Vector3(0.065, 0.32, 0.055), Vector3(0, 1.22, -0.3), trim, false)
	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	Geometry.mesh(model, head, Vector3(0, 1.73, 0), Geometry.material(Color("d8b698")))
	Geometry.box(model, Vector3(0.42, 0.1, 0.28), Vector3(0, 1.76, -0.13), Color("1a3038"), false)
	Geometry.cylinder(model, 0.24, 0.12, Vector3(0, 1.94, 0), suit)
	Geometry.cylinder(model, 0.3, 0.04, Vector3(0, 1.89, 0), suit)
	var limb := CapsuleMesh.new()
	limb.radius = 0.115
	limb.height = 0.7
	left_leg = Geometry.mesh(model, limb, Vector3(-0.15, 0.43, 0), Geometry.material(suit))
	right_leg = Geometry.mesh(model, limb, Vector3(0.15, 0.43, 0), Geometry.material(suit))
	Geometry.box(model, Vector3(0.2, 0.14, 0.35), Vector3(-0.15, 0.1, -0.07), Color("142e38"), false)
	Geometry.box(model, Vector3(0.2, 0.14, 0.35), Vector3(0.15, 0.1, -0.07), Color("142e38"), false)
	var arm := CapsuleMesh.new()
	arm.radius = 0.105
	arm.height = 0.6
	var arm_visual := Geometry.mesh(model, arm, Vector3(0.34, 1.28, -0.17), Geometry.material(suit))
	arm_visual.rotation_degrees.x = -70
	arm_visual = Geometry.mesh(model, arm, Vector3(-0.3, 1.2, -0.12), Geometry.material(suit))
	arm_visual.rotation_degrees.z = -25
	rifle = Node3D.new()
	model.add_child(rifle)
	rifle.position = Vector3(0.34, 1.38, -0.25)
	var barrel: MeshInstance3D = Geometry.cylinder(rifle, 0.035, 1.15, Vector3(0, 0, -0.32), Color("e9d9aa"))
	barrel.rotation_degrees.x = 90
	var folded := CylinderMesh.new()
	folded.top_radius = 0.025
	folded.bottom_radius = 0.13
	folded.height = 0.85
	var cloth: MeshInstance3D = Geometry.mesh(rifle, folded, Vector3(0, 0, -0.35), Geometry.material(suit))
	cloth.rotation_degrees.x = -90
	Geometry.box(rifle, Vector3(0.1, 0.2, 0.2), Vector3(0, -0.1, 0.22), Color("c4a56f"), false)
	umbrella = Node3D.new()
	model.add_child(umbrella)
	umbrella.position = Vector3(0, 2.3, 0)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.06
	cap.bottom_radius = 1.15
	cap.height = 0.38
	cap.radial_segments = 8
	canopy = Geometry.mesh(umbrella, cap, Vector3.ZERO, Geometry.material(Color("356879")))
	Geometry.cylinder(umbrella, 0.025, 1.0, Vector3(0, -0.6, 0), Color("ddc99d"))
	var disc := CylinderMesh.new()
	disc.top_radius = 0.95
	disc.bottom_radius = 0.95
	disc.height = 0.045
	disc.radial_segments = 8
	var mat: StandardMaterial3D = Geometry.material(trim, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.55
	shield = Geometry.mesh(model, disc, Vector3(0, 1.3, -0.65), mat)
	shield.rotation_degrees.x = 90
	nameplate = Geometry.text3d(self, actor.actor_id.to_upper(), Vector3(0, 2.65, 0), 28, Color("fff0da"))
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.no_depth_test = false
	debug_label = Geometry.text3d(self, "", Vector3(0, 3.1, 0), 23, trim)
	debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sound = ProceduralSound.new()
	add_child(sound)

func _process(delta: float) -> void:
	fire_flash = maxf(0.0, fire_flash - delta)
	walk_phase += Vector2(actor.velocity.x, actor.velocity.z).length() * delta * 1.8
	left_leg.rotation.x = sin(walk_phase) * 0.4 if actor.is_on_floor() else -0.25
	right_leg.rotation.x = -left_leg.rotation.x
	model.rotation.z = lerp_angle(model.rotation.z, -0.85 if not actor.alive else 0.0, delta * 8.0)
	model.position.y = lerpf(model.position.y, -0.5 if actor.motor.mode == "slide" else 0.0, delta * 12.0)
	model.rotation.x = lerp_angle(model.rotation.x, -0.28 if actor.motor.mode == "slide" else 0.0, delta * 10.0)
	umbrella.visible = actor.motor.mode in ["hover", "hover_ascent"]
	shield.visible = actor.state in ["guard", "deflect"]
	shield.scale = Vector3.ONE * (1.0 if actor.state == "deflect" else 0.7)
	rifle.rotation = Vector3.ZERO
	if actor.state == "melee_windup":
		rifle.rotation.y = 1.3
	elif actor.state in ["melee_active", "melee_recovery"]:
		rifle.rotation.y = -1.5
	elif actor.state == "reload":
		rifle.rotation.x = -0.7
	elif actor.state in ["throw_startup", "throw_pair", "captured"]:
		rifle.rotation.z = -0.8
		model.rotation.x = sin(actor.state_time * 9.0) * 0.25
		if actor.state == "captured" and is_instance_valid(actor.close.pair):
			var progress: float = 1.0 - actor.close.pair.state_time / actor.tuning.throw_duration
			model.position.y = sin(clampf(progress, 0.0, 1.0) * PI) * 0.65
			model.rotation.z = sin(clampf(progress, 0.0, 1.0) * PI) * -0.85
	if actor.team != 0:
		var marker: String = ""
		if actor.state == "melee_windup": marker = "  /  STRIKE"
		elif actor.state == "throw_startup": marker = "  /  GRAB!  [F]"
		elif actor.state == "guard": marker = "  /  GUARD"
		nameplate.text = "%s    %d HP%s" % [actor.actor_id.to_upper(), ceili(actor.health), marker]
		nameplate.modulate = Color("ffd096") if marker != "" else Color("fff1db")
	else:
		nameplate.visible = false
	var debug: bool = bool(get_tree().get_first_node_in_group("training").get("debug_view")) if get_tree().get_first_node_in_group("training") != null else false
	debug_label.visible = debug
	debug_label.text = "%s • %s\n%.1f m/s" % [actor.state, actor.motor.mode, actor.velocity.length()]
	if actor.is_on_floor() and not was_grounded and actor.velocity.length() > 1.0:
		sound.play_tone(70.0, 0.07, 0.1)
	was_grounded = actor.is_on_floor()
