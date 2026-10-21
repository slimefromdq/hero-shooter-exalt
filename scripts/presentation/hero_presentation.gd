class_name HeroPresentation
extends Node3D

var selections: AbilitySelectionMarkers
var actor: HeroActor
var movement: MovementPresentation
var overhealth_visual: OverhealthVisual
var marshal_combat: MarshalCombatPresentation
var model: Node3D
var body: Node3D
var umbrella: Node3D
var canopy: MeshInstance3D
var shield: MeshInstance3D
var rifle: Node3D
var nameplate: Label3D
var health_bar: ActorHealthBar
var debug_label: Label3D
var fire_flash: float = 0.0
var weapon_kick: float = 0.0
var pose_clock: float = 0.0
var melee_star: Node3D
var walk_phase: float = 0.0
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var animator: AnimationPlayer
var sound: ProceduralSound
var weapon_sound: ProceduralSound
var impact_sound: ProceduralSound
var block_sound: ProceduralSound
var block_flash: float = 0.0
var block_effect: BlockImpact
var stagger_marks: Node3D
var was_grounded: bool = false
var boot_release: float = 0.0
var cc_previous: String = ""
var control_sound: ProceduralSound
var slayer_axe: Node3D
var muzzle_flash: MeshInstance3D
var omen_sigil: Label3D
var status_label: Label3D
var status_ring: MeshInstance3D
var held_knife: Node3D
var huddle_colony: Node3D
var huddle_bugs: Array[Node3D] = []
var care_tool: Node3D
var held_trap: Node3D
var team_ring: MeshInstance3D
var roster_parts: Dictionary = {}
var slayer_shot: SlayerShotPresentation
var slayer_model: SlayerCharacterDriver
var marshal_model: MarshalCharacterDriver
var slayer_abilities: SlayerAbilityPresentation

func _ready() -> void:
	selections = AbilitySelectionMarkers.new()
	selections.actor = actor
	add_child(selections)
	movement = MovementPresentation.new()
	movement.actor = actor
	add_child(movement)
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
	umbrella.position = Vector3(-.45, 2.75, .4)
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
	health_bar = ActorHealthBar.new()
	health_bar.actor = actor
	add_child(health_bar)
	nameplate = Geometry.text3d(self, actor.actor_id.to_upper(), Vector3(0, 3.15, 0), 28, Color("fff0da"))
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
	weapon_sound = ProceduralSound.new()
	weapon_sound.spatial_owner = actor
	add_child(weapon_sound)
	impact_sound = ProceduralSound.new()
	impact_sound.spatial_owner = actor
	add_child(impact_sound)
	block_sound = ProceduralSound.new()
	block_sound.spatial_owner = actor
	add_child(block_sound)
	control_sound = ProceduralSound.new()
	control_sound.spatial_owner = actor
	add_child(control_sound)
	actor.resolver.confirmed_block.connect(on_block)
	animator = AnimationPlayer.new()
	animator.name = "CloseCombatAnimation"
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(animator)
	animator.add_animation_library("", CloseCombatAnimations.library())
	if actor.tuning is SlayerTuning:
		SlayerVisuals.remodel(self)
		slayer_model = SlayerCharacterDriver.attach(self)
		slayer_shot = SlayerShotPresentation.new()
		slayer_shot.presentation = self
		add_child(slayer_shot)
		slayer_abilities = SlayerAbilityPresentation.new()
		slayer_abilities.presentation = self
		add_child(slayer_abilities)
		animator.add_animation_library("slayer",SlayerAnimations.library())
	if actor.kit is SamsonKit: SamsonVisuals.remodel(self)
	elif actor.kit is ExpansionKit: RosterVisuals.remodel(self)
	elif actor.kit is HuddleKit: HuddleVisuals.remodel(self)
	elif actor.kit is CareKit: CareVisuals.remodel(self)
	if actor.kit is MarshalKit: marshal_model = MarshalCharacterDriver.attach(self)
	overhealth_visual = OverhealthVisual.new()
	overhealth_visual.actor = actor
	add_child(overhealth_visual)
	if actor.kit is MarshalKit:
		marshal_combat = MarshalCombatPresentation.new()
		marshal_combat.presentation = self
		add_child(marshal_combat)
	# Applied after hero remodeling so both silhouettes carry the same team language.
	var team_colour := Color("38dfff") if actor.team == 0 else Color("ff4f65")
	var team_material: StandardMaterial3D = Geometry.material(team_colour, .65)
	team_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var team_parent: Node3D = roster_parts["doll"] if actor.kit is StitchKit else body
	for side: float in [-1.0, 1.0]:
		var badge := BoxMesh.new()
		badge.size = Vector3(.065,.10,.055) if is_instance_valid(slayer_model) or actor.kit is StitchKit else Vector3(.14, .18, .37)
		if is_instance_valid(marshal_model):
			badge.size = Vector3(.05,.045,.24)
		Geometry.mesh(team_parent, badge, Vector3(side*.48,1.57,0) if is_instance_valid(marshal_model) else Vector3(side * (.225 if is_instance_valid(slayer_model) else .31),1.44,0),team_material)
	for z: float in [-.23, .23]:
		var band := BoxMesh.new()
		band.size = Vector3(.5, .09, .04)
		if actor.kit is StitchKit: band.size = Vector3(.16,.025,.012)
		if is_instance_valid(slayer_model): band.size = Vector3(.29,.025,.012)
		if is_instance_valid(marshal_model): band.size = Vector3(.27,.024,.012)
		Geometry.mesh(team_parent,band,Vector3(0,1.33,z*.61) if is_instance_valid(slayer_model) else Vector3(0,1.25,z),team_material)
	var team_shape := TorusMesh.new()
	team_shape.inner_radius = .43
	team_shape.outer_radius = .49
	team_ring = Geometry.mesh(self, team_shape, Vector3(0, .07, 0), team_material)
	team_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	omen_sigil = Geometry.text3d(self,"◇ OMEN ◇",Vector3(0,2.6,0),32,Color("8dfff0"))
	omen_sigil.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	omen_sigil.no_depth_test = true
	omen_sigil.visible = false
	status_label = Geometry.text3d(self,"",Vector3(0,2.3,0),23,Color("e3b8ff"))
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.no_depth_test = false
	status_label.pixel_size = .0045
	var ring := TorusMesh.new()
	ring.inner_radius = .47
	ring.outer_radius = .52
	status_ring = Geometry.mesh(self,ring,Vector3(0,.15,0),Geometry.material(Color("c79aef"),.8))
	status_ring.visible = false
	if is_instance_valid(marshal_model):
		health_bar.position.y = 2.95
		nameplate.position.y = 3.45
		stagger_marks.position.y = 2.9
		status_label.position.y = 2.85
	melee_star = Node3D.new()
	add_child(melee_star)
	var star_material: StandardMaterial3D = Geometry.material(Color("ffe99a"),2)
	star_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index: int in 4:
		var ray_mesh := BoxMesh.new()
		ray_mesh.size = Vector3(.055,.46 if index%2 == 0 else .3,.035)
		Geometry.mesh(melee_star,ray_mesh,Vector3.ZERO,star_material).rotation.z = index*PI/4
	melee_star.hide()

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
	pose_clock += delta
	melee_star.visible = actor.alive and actor.state in ["melee_windup","melee_active"]
	if melee_star.visible:
		melee_star.global_position = rifle.to_global(Vector3(0,.12,-.45))
		melee_star.rotation.z = pose_clock*4
		melee_star.scale = Vector3.ONE*(1+.12*sin(pose_clock*26))
	fire_flash = maxf(0.0, fire_flash - delta)
	block_flash = maxf(0.0, block_flash - delta)
	walk_phase += Vector2(actor.velocity.x, actor.velocity.z).length() * delta * 1.8
	left_leg.rotation = Vector3(sin(walk_phase) * .4 if actor.is_on_floor() else -.25,0,0)
	right_leg.rotation = Vector3(-left_leg.rotation.x,0,0)
	right_leg.scale = Vector3.ONE
	left_leg.position.y = .8
	right_leg.position.y = .8
	left_arm.rotation = Vector3(.1,0,-.15)
	right_arm.rotation = Vector3(1.1,0,0)
	for limb: Node3D in [left_arm,right_arm,left_leg,right_leg]:
		(limb.get_node("Joint") as Node3D).rotation = Vector3.ZERO
	model.scale = Vector3.ONE
	model.position = Vector3(0,1.0 - actor.motor.posture_lowering(),0)
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
	rifle.position = Vector3(.10,1.30,0) if is_instance_valid(slayer_model) and slayer_model.active else Vector3(.34,1.38,-.25)
	if is_instance_valid(marshal_model) and marshal_model.active: rifle.position = Vector3(.13,1.34,.08)
	if actor.kit.reloading and actor.state == "ready":
		rifle.rotation.x = -0.7
	var animation: String = ""
	var progress: float = 0.0
	if actor.state == "boot_attached":
		animation = "slayer/boot_attach"
		progress = 1.0 - actor.boot_pair.remaining / (actor.tuning as SlayerTuning).boot_hold
	elif boot_release > 0:
		animation = "slayer/boot_release"
		progress = 1.0 - boot_release / .18
	elif actor.state == "marshal_march":
		animation = "care/march"
		var marshal_kit := actor.kit as MarshalKit
		progress = minf(.85,marshal_kit.march_age/.15*.2) if marshal_kit.march_left > 2 else lerpf(.85,1,1-marshal_kit.march_left/2)
	elif actor.state == "marshal_verdict":
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
		if animation == "melee": model.rotation.x -= asin(clampf(actor.close.melee_direction.y,-1,1)) * .65
	else:
		animator.stop(true)
	if actor.state in ["throw_startup","throw_pair","captured","mantle"]:
		rifle.position = Vector3(.22,1.12,.32)
		rifle.rotation = Vector3(-.4,0,-.6)
	var session: Node = get_tree().get_first_node_in_group("game_session")
	var city_play: bool = get_tree().get_first_node_in_group("city_match") != null
	model.visible = actor.alive if city_play else true
	nameplate.visibility_range_end = 65.0 if city_play else 0.0
	team_ring.visible = actor.alive and (not city_play or session.player != actor)
	health_bar.refresh()
	if session == null or session.player != actor:
		var marker: String = ""
		if actor.state == "melee_windup": marker = "  /  STRIKE"
		elif actor.state == "throw_startup": marker = "  /  GRAB!  [%s]" % TrainingInputs.key_label("throw")
		elif actor.state == "guard": marker = "  /  GUARD"
		elif actor.state == "stagger": marker = "  /  STAGGERED"
		nameplate.text = actor.actor_id.to_upper() + marker
		if city_play:
			var ally: bool = actor.team == session.player.team
			nameplate.text = "%s / %s\n%s%s" % ["[+] ALLY" if ally else "[!] ENEMY", "LANTERN" if actor.team == 0 else "CROWN", actor.actor_id.to_upper(), marker]
			nameplate.font_size = 28
			nameplate.pixel_size = .0045
			nameplate.outline_size = 4
			nameplate.outline_modulate = Color("152333")
		nameplate.modulate = Color("38dfff") if actor.team == 0 else Color("ff4f65")
		if actor.get_meta("built_in",false):
			nameplate.text = str(actor.get_meta("station","TARGET")).to_upper()
			nameplate.font_size = 20
		nameplate.visible = actor.alive
	else:
		nameplate.visible = false
	var debug: bool = bool(session.get("debug_view")) if session != null else false
	debug_label.visible = debug
	debug_label.text = "%s • %s\n%.1f m/s" % [actor.state, actor.motor.mode, actor.velocity.length()]
	if actor.statuses.stunned() or actor.statuses.silenced():
		debug_label.visible = true
		debug_label.text = "STUNNED" if actor.statuses.stunned() else "SILENCED"
	if actor.is_on_floor() and not was_grounded and actor.velocity.length() > 1.0:
		sound.play_tone(70.0, 0.07, 0.1)
	was_grounded = actor.is_on_floor()
	if actor.tuning is SlayerTuning: SlayerVisuals.animate(self)
	if actor.kit is SamsonKit: SamsonVisuals.animate(self)
	elif actor.kit is ExpansionKit: RosterVisuals.animate(self,delta)
	elif actor.kit is HuddleKit: HuddleVisuals.animate(self)
	elif actor.kit is CareKit: CareVisuals.animate(self)
	if actor.motor.mode == "slide":
		left_leg.position.y = 1.0
		right_leg.position.y = 1.0
		left_leg.rotation.x = 1.4
		right_leg.rotation.x = 1.4
	if actor.motor.crouched and actor.motor.mode != "slide" and actor.state not in ["captured","throw_pair","boot_attached","boot_captured","mantle"] and not actor.state.begins_with("slayer_boot"):
		# Fold both legs under the lowered torso; retain aiming and kit arm poses.
		var stride: float = sin(walk_phase) * .16 if actor.motor.grounded() else 0.0
		left_leg.position.y = .95
		right_leg.position.y = .95
		left_leg.rotation.x = 1.25 + stride
		right_leg.rotation.x = 1.25 - stride
		(left_leg.get_node("Joint") as Node3D).rotation.x = -2.5 - stride
		(right_leg.get_node("Joint") as Node3D).rotation.x = -2.5 + stride
	var status_text: String = ControlFeedback.caption(actor)
	if status_text != "": status_text += "\n"
	status_text += CareHUD.status(actor,false)
	if actor.close.grace > 0: status_text += "THROW IMMUNE %.1fs  " % actor.close.grace
	if actor.controller is ParryPracticeController and (actor.controller as ParryPracticeController).action_timer < .5:
		status_text += "KNIFE INCOMING"
	for effect: String in actor.statuses.effects:
		if effect in ["root","slow","stun","silence"]: continue
		status_text += "%s %.1f  " % [effect.replace("max_health","MAX HP WOUND").to_upper(),actor.statuses.effects[effect].remaining]
	var viewer: HeroActor = session.player if session != null else null
	if is_instance_valid(viewer) and viewer.kit is StitchKit and actor.statuses.stitch_count(viewer) > 0:
		status_text += "STITCHES %d / %.1fs" % [actor.statuses.stitch_count(viewer),actor.statuses.stitches[viewer.get_instance_id()].remaining]
	if is_instance_valid(viewer) and viewer.kit is WispKit and actor.statuses.soul_count(viewer) > 0:
		status_text += "CARDS " + str(actor.statuses.soul_count(viewer))
	if is_instance_valid(viewer) and viewer.tuning is SlayerTuning and actor.statuses.marked_for(viewer):
		var slayer_data := viewer.tuning as SlayerTuning
		if viewer.global_position.distance_to(actor.global_position) <= slayer_data.mark_range and actor.resolver.visible(viewer.global_position + Vector3.UP * 1.5,actor,[viewer.get_rid()]):
			status_text += "WOUNDED ◆" if actor.health / actor.effective_max_health() <= slayer_data.wounded_threshold else "HUNTED ◇"
	omen_sigil.visible = false
	for source: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if source.kit is RelayKit and (source.kit as RelayKit).reveals(actor,viewer):
			omen_sigil.visible = true
			omen_sigil.text = "◇ OMEN %.1fs ◇" % (source.kit as RelayKit).omen_left
			break
	status_label.text = status_text
	status_label.visible = actor.alive and status_text != "" and actor != viewer
	status_ring.visible = actor.alive and (not ControlFeedback.snapshot(actor).is_empty() or actor.statuses.effects.has("max_health") or actor.statuses.effects.has("root") or actor.benefits.has_kind("exemplary") or actor.benefits.has_kind("prescription"))
	var ring_color := Color("ffda80") if actor.benefits.has_kind("exemplary") else (Color("b7f3ff") if actor.benefits.has_kind("prescription") else Color("c79aef"))
	(status_ring.material_override as StandardMaterial3D).albedo_color = ring_color
	status_ring.rotation.y += delta
	var effects: Array[Dictionary] = ControlFeedback.snapshot(actor)
	var signature := PackedStringArray()
	for effect: Dictionary in effects: signature.append(effect.kind)
	var current: String = ",".join(signature)
	if current != cc_previous:
		for effect: Dictionary in effects:
			if str(effect.kind) in cc_previous.split(","): continue
			control_sound.play_tone(effect.tone,.11,.13)
			CombatEffect.pulse(actor.get_parent(),actor.global_position+Vector3.UP*.2,effect.color,.7 if effect.kind == "root" else 1.1)
			break
	cc_previous = current
	if actor.concealed() and is_instance_valid(viewer) and viewer.team != actor.team:
		team_ring.visible = false
		nameplate.visible = false
		health_bar.visible = false
		status_ring.visible = false
		status_label.visible = false
	if not effects.is_empty():
		var kind: String = effects[0].kind
		match kind:
			"root":
				status_ring.scale = Vector3.ONE
				status_ring.rotation.y = 0
			"slow": status_ring.scale = Vector3.ONE*(1.1+.15*sin(float(Time.get_ticks_msec())*.008))
			"push":
				status_ring.scale = Vector3(1.6,1,.45)
				status_ring.rotation.y = atan2(actor.motor.external_velocity.x,actor.motor.external_velocity.z)
			"counterthrow","throw_release":
				status_ring.scale = Vector3(.6,1,1.5)
				status_ring.rotation.y += delta*10
			"boot": status_ring.scale = Vector3.ONE*.8
			"throw": status_ring.scale = Vector3.ONE*1.4
			_: status_ring.scale = Vector3.ONE
		(status_ring.material_override as StandardMaterial3D).albedo_color = effects[0].color
	boot_release = maxf(0,boot_release-delta)
	if actor.boot_pair != null or boot_release > 0:
		if actor.state == "boot_attached" or boot_release > 0:
			right_leg.rotation.x = 1.6 if boot_release <= 0 else 1.9
			if actor.boot_pair != null:
				var contact: Vector3 = right_leg.to_local(actor.boot_pair.victim.global_position+Vector3.UP*.85)
				var facing: Vector3 = actor.global_basis.inverse()*(actor.boot_pair.victim.global_position-actor.global_position)
				right_leg.rotation.y = atan2(-facing.x,-facing.z)
				right_leg.scale.y = clampf(contact.length()/.68,1,2.4)
			(right_leg.get_node("Joint") as Node3D).rotation.x = -.15
			model.rotation.x = -.15
		else:
			model.rotation.x = -.3
			left_arm.rotation.z = -.65
			right_arm.rotation.z = .65
	if actor.tuning.hero_id == "nimbus" and actor.controller is PlayerController:
		var camera: Camera3D = (actor.controller as PlayerController).camera
		var to_canopy: Vector3 = canopy.global_position-camera.global_position
		var screen_center: Vector2 = camera.get_viewport().get_visible_rect().size * .5
		var obstructing: bool = to_canopy.dot(-camera.global_basis.z) > 0 and camera.unproject_position(canopy.global_position).distance_to(screen_center) < screen_center.y
		var material := canopy.material_override as StandardMaterial3D
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if obstructing else BaseMaterial3D.TRANSPARENCY_DISABLED
		material.albedo_color.a = .2 if obstructing else 1.0

	if movement.jump_left > 0 and actor.state == "ready":
		left_leg.rotation.x = -.45
		right_leg.rotation.x = .1
	if actor.motor.mode == "dash_windup":
		model.rotation.x += .12
		model.scale = Vector3(1.03,.94,1.03)
	MotionPose.apply(self,delta)
	if is_instance_valid(slayer_model): slayer_model.update(delta)
	if is_instance_valid(marshal_model): marshal_model.update(delta)

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
	if is_instance_valid(actor) and is_instance_valid(actor.resolver):
		actor.resolver.feedback_cleared.emit(actor)
		if actor.controller is PlayerController:
			var controller := actor.controller as PlayerController
			controller.combat_impulse = Vector3.ZERO
			controller.recoil = 0
			if is_instance_valid(controller.camera): controller.camera.rotation = Vector3.ZERO
	if is_instance_valid(melee_star): melee_star.hide()
	if is_instance_valid(movement): movement.clear()
	if is_instance_valid(marshal_combat): marshal_combat.clear()
	if is_instance_valid(overhealth_visual): overhealth_visual.clear()
	fire_flash = 0.0
	weapon_kick = 0
	pose_clock = 0
	if is_instance_valid(slayer_model): slayer_model.reset_feedback()
	if is_instance_valid(marshal_model): marshal_model.reset_feedback()
	if is_instance_valid(slayer_shot): slayer_shot.clear()
	if is_instance_valid(slayer_abilities): slayer_abilities.clear()
	if is_instance_valid(sound): sound.stop_slayer_voices()
	if is_instance_valid(weapon_sound): weapon_sound.stop()
	boot_release = 0
	cc_previous = ""
	if is_instance_valid(control_sound): control_sound.stop()
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
	combat_feedback("slam",at)

func shot_feedback() -> void:
	weapon_kick = 1.0
	if not actor.kit is SlayerKit:
		weapon_sound.stream = ProceduralSound.weapon_report(actor.tuning.hero_id)
		weapon_sound.volume_db = -9+weapon_sound.distance_gain()
		if DisplayServer.get_name() != "headless": weapon_sound.play()
	if actor.controller is PlayerController and not actor.kit is SlayerKit:
		(actor.controller as PlayerController).combat_impulse.x -= .009 if actor.kit is WispKit else .018

func combat_feedback(kind: String, at: Vector3 = Vector3.INF) -> void:
	var point: Vector3 = actor.body_point(1.2) if at == Vector3.INF else at
	if kind == "shield_break": point = actor.body_point(1.3)+actor.aim_direction*.6
	movement.spawn(kind,point,actor.aim_direction,actor.aim_direction if kind == "shield_break" else Vector3.UP)
	var hz: float = 90 if kind in ["melee_hit","slam"] else 780 if kind == "parry" else 440
	if kind == "wall_clang": impact_sound.play_guard_clang()
	else: impact_sound.play_tone(hz,.12,.22)
	if actor.controller is PlayerController:
		var impulse := Vector3(-.025,0,.012)
		if kind == "melee_swing": impulse = Vector3(.015,0,-.018)
		elif kind == "throw_lift": impulse = Vector3(.025,0,.012)
		elif kind == "throw_caught": impulse = Vector3(-.035,0,-.018)
		elif kind == "throw_landing": impulse = Vector3(.05,0,-.02)
		elif kind == "slam": impulse = Vector3(-.045,0,.018)
		(actor.controller as PlayerController).combat_impulse += impulse

func surface_impact(hit: Dictionary) -> void:
	if hit.is_empty(): return
	var collider: Object = hit.get("collider")
	if collider is HeroActor: return
	var metallic: bool = collider is CombatBarrier
	if collider is Node:
		metallic = metallic or str(collider.get_meta("surface_material","")) == "metal" or "metal" in str(collider.name).to_lower() or "steel" in str(collider.name).to_lower()
	movement.spawn("metal_hit" if metallic else "surface_hit",hit.position,actor.aim_direction,hit.get("normal",Vector3.UP))
	impact_sound.play_tone(920 if metallic else 140,.07,.1)
