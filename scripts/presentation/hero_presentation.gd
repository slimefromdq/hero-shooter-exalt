class_name HeroPresentation
extends Node3D

var actor: HeroActor
var model: Node3D
var body: Node3D
var umbrella: Node3D
var canopy: MeshInstance3D
var shield: MeshInstance3D
var rifle: Node3D
var nameplate: Label3D
var debug_label: Label3D
var fire_flash: float = 0.0
var walk_phase: float = 0.0
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var animator: AnimationPlayer
var sound: ProceduralSound
var impact_sound: ProceduralSound
var block_sound: ProceduralSound
var block_flash: float = 0.0
var block_effect: BlockImpact
var stagger_marks: Node3D
var was_grounded: bool = false
var slayer_axe: Node3D
var muzzle_flash: MeshInstance3D
var status_label: Label3D
var status_ring: MeshInstance3D
var held_knife: Node3D
var care_tool: Node3D
var held_trap: Node3D

func _ready() -> void:
	model = Node3D.new()
	model.name = "Model"
	model.position.y = 1.0
	add_child(model)
	body = Node3D.new()
	body.name = "Geometry"
	body.position.y = -1.0
	model.add_child(body)
	var suit: Color = Color("253d4b") if actor.team == 0 else Color("aa534a")
	var trim: Color = Color("80e1d0") if actor.team == 0 else Color("ffd4b4")
	var torso := CapsuleMesh.new()
	torso.radius = 0.3
	torso.height = 0.84
	Geometry.mesh(body, torso, Vector3(0, 1.12, 0), Geometry.material(suit))
	Geometry.box(body, Vector3(0.13, 0.42, 0.05), Vector3(0, 1.26, -0.27), Color("f2ebd9"), false)
	Geometry.box(body, Vector3(0.065, 0.32, 0.055), Vector3(0, 1.22, -0.3), trim, false)
	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.44
	Geometry.mesh(body, head, Vector3(0, 1.73, 0), Geometry.material(Color("d8b698")))
	Geometry.box(body, Vector3(0.42, 0.1, 0.28), Vector3(0, 1.76, -0.13), Color("1a3038"), false)
	Geometry.cylinder(body, 0.24, 0.12, Vector3(0, 1.94, 0), suit)
	Geometry.cylinder(body, 0.3, 0.04, Vector3(0, 1.89, 0), suit)
	left_leg = make_limb("LeftLeg", Vector3(-.15,.8,0), .34, .34, .105, suit)
	right_leg = make_limb("RightLeg", Vector3(.15,.8,0), .34, .34, .105, suit)
	for leg: Node3D in [left_leg, right_leg]:
		Geometry.box(leg.get_node("Joint"), Vector3(.2,.14,.35), Vector3(0,-.3,-.07), Color("142e38"), false)
	left_arm = make_limb("LeftArm", Vector3(-.34,1.43,0), .28, .27, .09, suit)
	right_arm = make_limb("RightArm", Vector3(.34,1.43,0), .28, .27, .09, suit)
	for arm: Node3D in [left_arm,right_arm]:
		var hand := SphereMesh.new()
		hand.radius = .095
		hand.height = .19
		Geometry.mesh(arm.get_node("Joint"), hand, Vector3(0,-.27,0), Geometry.material(Color("d8b698")))
	rifle = Node3D.new()
	rifle.name = "Rifle"
	body.add_child(rifle)
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
	body.add_child(umbrella)
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
	shield = Geometry.mesh(body, disc, Vector3(0, 1.3, -0.65), mat)
	shield.rotation_degrees.x = 90
	nameplate = Geometry.text3d(self, actor.actor_id.to_upper(), Vector3(0, 2.65, 0), 28, Color("fff0da"))
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.no_depth_test = false
	debug_label = Geometry.text3d(self, "", Vector3(0, 3.1, 0), 23, trim)
	debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	stagger_marks = Node3D.new()
	stagger_marks.position.y = 2.25
	add_child(stagger_marks)
	for index: int in 3:
		var star := Node3D.new()
		star.position = Vector3(cos(TAU * index / 3.0) * .42,0,sin(TAU * index / 3.0) * .42)
		stagger_marks.add_child(star)
		for angle: float in [0.0, PI / 2]:
			var shape := BoxMesh.new()
			shape.size = Vector3(.05,.22,.05)
			var star_mat: StandardMaterial3D = Geometry.material(Color("ffce65"),1.0)
			star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			Geometry.mesh(star,shape,Vector3.ZERO,star_mat).rotation.z = angle
	stagger_marks.visible = false
	sound = ProceduralSound.new()
	sound.spatial_owner = actor
	add_child(sound)
	impact_sound = ProceduralSound.new()
	impact_sound.spatial_owner = actor
	add_child(impact_sound)
	block_sound = ProceduralSound.new()
	block_sound.spatial_owner = actor
	add_child(block_sound)
	actor.resolver.confirmed_block.connect(on_block)
	animator = AnimationPlayer.new()
	animator.name = "CloseCombatAnimation"
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(animator)
	animator.add_animation_library("", CloseCombatAnimations.library())
	if actor.tuning is SlayerTuning:
		SlayerVisuals.remodel(self)
		animator.add_animation_library("slayer",SlayerAnimations.library())
	if actor.kit is CareKit: CareVisuals.remodel(self)
	status_label = Geometry.text3d(self,"",Vector3(0,2.3,0),23,Color("e3b8ff"))
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.no_depth_test = false
	status_label.pixel_size = .0045
	var ring := TorusMesh.new()
	ring.inner_radius = .47
	ring.outer_radius = .52
	status_ring = Geometry.mesh(self,ring,Vector3(0,.15,0),Geometry.material(Color("c79aef"),.8))
	status_ring.visible = false

func make_limb(caption: String, at: Vector3, upper: float, lower: float, radius: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = caption
	pivot.position = at
	body.add_child(pivot)
	var top := CapsuleMesh.new()
	top.radius = radius
	top.height = upper + radius
	Geometry.mesh(pivot, top, Vector3(0,-upper / 2,0), Geometry.material(color))
	var joint := Node3D.new()
	joint.name = "Joint"
	joint.position.y = -upper
	pivot.add_child(joint)
	var bottom := CapsuleMesh.new()
	bottom.radius = radius * .9
	bottom.height = lower + radius
	Geometry.mesh(joint, bottom, Vector3(0,-lower / 2,0), Geometry.material(color))
	return pivot

func _process(delta: float) -> void:
	fire_flash = maxf(0.0, fire_flash - delta)
	block_flash = maxf(0.0, block_flash - delta)
	walk_phase += Vector2(actor.velocity.x, actor.velocity.z).length() * delta * 1.8
	left_leg.rotation = Vector3(sin(walk_phase) * .4 if actor.is_on_floor() else -.25,0,0)
	right_leg.rotation = Vector3(-left_leg.rotation.x,0,0)
	left_arm.rotation = Vector3(.1,0,-.15)
	right_arm.rotation = Vector3(1.1,0,0)
	for limb: Node3D in [left_arm,right_arm,left_leg,right_leg]:
		(limb.get_node("Joint") as Node3D).rotation = Vector3.ZERO
	model.position = Vector3(0,.5 if actor.motor.mode == "slide" else 1.0,0)
	model.rotation = Vector3(-.28 if actor.motor.mode == "slide" else 0,0,-.85 if not actor.alive else 0)
	umbrella.visible = actor.motor.mode in ["hover", "hover_ascent"]
	shield.visible = actor.state in ["guard", "deflect"] or block_flash > 0
	var block_strength: float = block_flash / BlockImpact.DURATION
	shield.scale = Vector3.ONE * ((1.0 if actor.state == "deflect" else 0.7) + block_strength * .2)
	var shield_mat := shield.material_override as StandardMaterial3D
	var trim: Color = Color("80e1d0") if actor.team == 0 else Color("ffd4b4")
	shield_mat.albedo_color = trim.lerp(Color("fff5cd"), block_strength)
	shield_mat.albedo_color.a = (.55 if actor.state == "deflect" else .28) + block_strength * .24
	stagger_marks.visible = actor.alive and actor.state == "stagger"
	stagger_marks.rotation.y = (1.0 - actor.state_time / maxf(.01,actor.tuning.stagger_duration)) * TAU
	rifle.rotation = Vector3.ZERO
	rifle.position = Vector3(.34,1.38,-.25)
	if actor.state == "reload":
		rifle.rotation.x = -0.7
	var animation: String = ""
	var progress: float = 0.0
	if actor.state == "marshal_verdict":
		animation = "care/verdict"
		progress = (actor.kit as MarshalKit).verdict_progress()
	elif actor.state == "doctor_ultimate":
		animation = "care/prescribe"
		progress = 1.0 - actor.state_time / (actor.tuning as DoctorTuning).exemplary_windup
	elif actor.state in ["slayer_knife", "slayer_trap"]:
		animation = "slayer/knife" if actor.state == "slayer_knife" else "slayer/toss"
		var hunter := actor.kit as SlayerKit
		var data := actor.tuning as SlayerTuning
		progress = hunter.action_age / (data.knife_recovery if actor.state == "slayer_knife" else data.trap_recovery)
	elif actor.state.begins_with("melee_"):
		animation = "melee"
		progress = actor.close.melee_progress()
	elif actor.state == "stagger":
		animation = "stagger"
		progress = 1.0 - actor.state_time / maxf(.01, actor.tuning.stagger_duration)
	elif actor.state == "mantle":
		animation = "mantle"
		progress = actor.motor.traversal.progress
	elif actor.state == "guard" and block_flash > 0:
		animation = "block"
		progress = 1.0 - block_strength
	elif actor.state == "throw_startup":
		animation = "slayer/grab" if actor.tuning is SlayerTuning else "grab"
		progress = 1.0 - actor.state_time / actor.tuning.throw_startup
	elif actor.state in ["throw_pair","captured"]:
		animation = "thrower" if actor.state == "throw_pair" else "victim"
		if actor.state == "throw_pair" and actor.tuning is SlayerTuning: animation = "slayer/thrower"
		progress = actor.close.pair_progress
		var owner: HeroActor = actor if actor.close.pair_owner else actor.close.pair
		if is_instance_valid(owner) and owner.close.sequence != null:
			var impact: float = owner.close.sequence.impact
			if progress >= impact:
				progress = lerpf(.72,1.0,(progress - impact) / (1.0 - impact))
			elif progress > .46:
				progress = lerpf(.46,.72,(progress - .46) / (impact - .46))
	elif actor.state == "ready" and actor.motor.mode == "air" and actor.motor.traversal.wall_pose > 0:
		animation = "wall_jump"
		progress = 1.0 - actor.motor.traversal.wall_pose / .28
	if animation != "":
		if animator.current_animation != animation:
			animator.play(animation)
		animator.seek(clampf(progress,0,.9999), true)
	else:
		animator.stop(true)
	if actor.state in ["throw_startup","throw_pair","captured","mantle"]:
		rifle.position = Vector3(.22,1.12,.32)
		rifle.rotation = Vector3(-.4,0,-.6)
	var session: Node = get_tree().get_first_node_in_group("game_session")
	var city_play: bool = get_tree().get_first_node_in_group("city_match") != null
	model.visible = actor.alive if city_play else true
	nameplate.visibility_range_end = 40.0 if city_play else 0.0
	if actor.team != 0 or (city_play and session.player != actor):
		var marker: String = ""
		if actor.state == "melee_windup": marker = "  /  STRIKE"
		elif actor.state == "throw_startup": marker = "  /  GRAB!  [%s]" % TrainingInputs.key_label("throw")
		elif actor.state == "guard": marker = "  /  GUARD"
		elif actor.state == "stagger": marker = "  /  STAGGERED"
		nameplate.text = "%s    %d HP%s" % [actor.actor_id.to_upper(), ceili(actor.health), marker]
		if city_play:
			nameplate.text = "%s%s   %d%s" % ["L" if actor.team == 0 else "C", actor.actor_id.get_slice("_", 1), ceili(actor.health), marker]
			nameplate.font_size = 24
			nameplate.pixel_size = .0045
			nameplate.outline_size = 4
			nameplate.outline_modulate = Color("152333")
		nameplate.modulate = Color("8ee7ed") if actor.team == 0 else (Color("ffd096") if marker != "" else Color("ffb5a3"))
		nameplate.visible = actor.alive
	else:
		nameplate.visible = false
	var debug: bool = bool(session.get("debug_view")) if session != null else false
	debug_label.visible = debug
	debug_label.text = "%s • %s\n%.1f m/s" % [actor.state, actor.motor.mode, actor.velocity.length()]
	if actor.is_on_floor() and not was_grounded and actor.velocity.length() > 1.0:
		sound.play_tone(70.0, 0.07, 0.1)
	was_grounded = actor.is_on_floor()
	if actor.tuning is SlayerTuning: SlayerVisuals.animate(self)
	if actor.kit is CareKit: CareVisuals.animate(self)
	var status_text: String = CareHUD.status(actor)
	for effect: String in actor.statuses.effects:
		status_text += "%s %.1f  " % [effect.replace("max_health","MAX HP WOUND").to_upper(),actor.statuses.effects[effect].remaining]
	var viewer: HeroActor = session.player if session != null else null
	if is_instance_valid(viewer) and viewer.tuning is SlayerTuning and actor.statuses.marked_for(viewer):
		var slayer_data := viewer.tuning as SlayerTuning
		if viewer.global_position.distance_to(actor.global_position) <= slayer_data.mark_range and actor.resolver.visible(viewer.global_position + Vector3.UP * 1.5,actor,[viewer.get_rid()]):
			status_text += "WOUNDED ◆" if actor.health / actor.effective_max_health() <= slayer_data.wounded_threshold else "HUNTED ◇"
	status_label.text = status_text
	status_label.visible = actor.alive and status_text != "" and actor != viewer
	status_ring.visible = actor.alive and (actor.statuses.effects.has("max_health") or actor.statuses.effects.has("root") or actor.benefits.has_kind("exemplary") or actor.benefits.has_kind("prescription"))
	var ring_color := Color("ffda80") if actor.benefits.has_kind("exemplary") else (Color("b7f3ff") if actor.benefits.has_kind("prescription") else Color("c79aef"))
	(status_ring.material_override as StandardMaterial3D).albedo_color = ring_color
	status_ring.rotation.y += delta

func on_block(attacker: HeroActor, defender: HeroActor) -> void:
	if defender != actor:
		return
	block_flash = BlockImpact.DURATION
	block_sound.play_guard_clang()
	if is_instance_valid(block_effect):
		block_effect.queue_free()
	var toward: Vector3 = (attacker.global_position - actor.global_position).normalized()
	toward.y = 0
	toward = toward.normalized()
	if toward.is_zero_approx():
		toward = -actor.global_basis.z
	block_effect = BlockImpact.spawn(actor.get_parent(), actor.global_position + Vector3.UP * 1.3 + toward * .72, toward)

func clear_feedback() -> void:
	block_flash = 0.0
	if is_instance_valid(stagger_marks):
		stagger_marks.visible = false
	if is_instance_valid(impact_sound):
		impact_sound.stop()
	if is_instance_valid(block_sound):
		block_sound.stop()
	if is_instance_valid(block_effect):
		block_effect.queue_free()
		block_effect = null

func _exit_tree() -> void:
	clear_feedback()

func slam_impact(at: Vector3) -> void:
	CombatEffect.pulse(actor.get_parent(), at + Vector3.UP * .1, Color("f8d3a0"), .9)
	sound.play_tone(65, .18, .5)
