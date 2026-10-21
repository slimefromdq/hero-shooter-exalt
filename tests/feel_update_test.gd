extends SceneTree
var world: Node3D
var a: HeroActor
var b: HeroActor
var c: HeroActor
var resolver: CombatResolver
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",caption)
func step(count: int = 1) -> void:
	for i: int in count:
		await physics_frame
		await process_frame
func reset(hero: String = "nimbus") -> void:
	a.select_hero(hero)
	a.reset_actor(Vector3(0,.01,0))
	b.reset_actor(Vector3(0,.01,-2))
	c.reset_actor(Vector3(15,.01,0))
	b.intent.aim = Vector3.BACK
	c.intent.aim = Vector3.BACK
	resolver.clear_round()
	await step(3)
func arm_parry() -> void:
	b.intent.guard = true
	await step(5)
	b.intent.guard = false
	await step()
func ability_id() -> int:
	return resolver.classify(resolver.new_cast(a),CombatResolver.ImpactKind.ABILITY)

func run() -> void:
	TrainingInputs.install()
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(100,1,100),Vector3(0,-.5,0),Color.GRAY)
	a = HeroActor.new()
	b = HeroActor.new()
	c = HeroActor.new()
	b.team = 1
	c.team = 1
	world.add_child(a)
	world.add_child(b)
	world.add_child(c)
	await reset()
	await movement()
	await weapons()
	await parries()
	await close_actions()
	world.queue_free()
	await step(3)
	print("FEEL UPDATE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func movement() -> void:
	a.motor.mode = "air"
	var initial := Vector3(0,0,-10)
	check(a.motor.steer_horizontal(Vector3.ZERO,Vector3.RIGHT,6,false,false,.1).x > 1.9,"starting air movement still responds immediately below running speed")
	check(a.motor.steer_horizontal(initial,Vector3.ZERO,6,false,false,.1) == initial,"neutral airborne momentum preserved")
	var speeds: Array[float] = []
	for hz: int in [30,60,120]:
		var v := initial
		for i: int in hz:
			var wish: Vector3 = v.normalized().rotated(Vector3.UP,-1.42)
			v = a.motor.steer_horizontal(v,wish,6,false,false,1.0/hz)
		speeds.append(v.length())
	check(speeds[1] > 10.3,"turning opens projection headroom and builds speed")
	check(absf(speeds[0]-speeds[2]) < .02,"air speed gain is consistent across 30/60/120 Hz")
	for speed: float in speeds:
		check(speed <= 10.751,"one second of air strafing cannot gain more than 0.75 m/s")
	for start_speed: float in [6,11.9,12,20]:
		var velocity: Vector3 = Vector3.FORWARD*start_speed
		for i: int in 1200:
			var wish: Vector3 = velocity.normalized().rotated(Vector3.UP,-1.42)
			velocity = a.motor.steer_horizontal(velocity,wish,6,false,false,1.0/60)
		check(velocity.length() <= maxf(12,start_speed)+.002,"sustained turning cannot farm speed beyond ceiling from %.1f m/s" % start_speed)
		if start_speed >= 12:
			check(absf(velocity.length()-start_speed) < .002,"air steering preserves earned launch speed without increasing it")
	var aligned: Vector3 = a.motor.steer_horizontal(initial,Vector3.FORWARD,6,false,false,.1)
	check(aligned == initial,"wish already above projection cap cannot accelerate")
	var cap: Vector3 = a.motor.steer_horizontal(Vector3(25.99,0,0),Vector3.FORWARD,6,false,false,1)
	check(cap.length() <= 26.001,"air strafing respects 26 m/s cap")
	var distances: Array[float] = []
	for source: String in ["momentum","ground_dash"]:
		await reset()
		a.velocity = Vector3.RIGHT*10
		a.intent.slide = true
		a.motor.slide_source = source
		a.motor.transition("slide")
		await step(30)
		distances.append(a.position.x)
		check(a.motor.crouched,"slide capsule remains crouched")
		a.intent.slide = false
		await step(3)
		check(not a.motor.crouched and a.motor.mode != "slide","release clears slide posture and motor mode")
	check(distances[0] > distances[1]+.1,"momentum slide retains more speed than dash slide")
	await reset()
	a.motor.set_crouched(true)
	a.motor.mode = "crouch"
	var ceiling: StaticBody3D = Geometry.box(world,Vector3(3,.2,3),Vector3(0,1.5,0),Color.GRAY)
	await step(3)
	check(a.motor.crouched,"low ceiling safely prevents standing")
	ceiling.queue_free()
	await step(4)
	check(not a.motor.crouched and a.motor.mode == "ground","clearance returning retries standing without another input")
	for hero: String in ["nimbus","slayer","marshal"]:
		await reset(hero)
		a.movement_confirmed.emit("jump",a.position,Vector3.UP,Vector3.UP,1)
		await step()
		check(a.presentation.model.scale.y >= .94 and a.presentation.model.scale.y <= 1.06,hero+" squash/stretch stays within six percent")
		if hero != "nimbus":
			var driver: Node = a.presentation.slayer_model if hero == "slayer" else a.presentation.marshal_model
			check(driver != null and driver.active,hero+" rig driver remains connected")

func weapons() -> void:
	for hero: String in HeroRoster.IDS:
		await reset(hero)
		a.kit.ammo = 0
		await step()
		check(a.kit.reloading == (hero != "relay"),hero+" zero-ammo automatic reload policy")
	await reset()
	a.state = "stagger"
	a.state_time = .15
	a.kit.ammo = 0
	await step()
	check(not a.kit.reloading,"automatic reload waits for action permission")
	await step(12)
	check(a.kit.reloading,"automatic reload retries after recovery")
	await reset()
	a.kit.ammo = 1
	a.kit.fire(false)
	await step()
	check(a.kit.reloading,"last shot starts reload without another trigger press")
	var store: Node = root.get_node("GameSettings")
	check(store.DEFAULTS.aim_fov == 42 and store.clamp_value("aim_fov",42) == 42,"ADS defaults and settings accept 42 degrees")
	var settings: Node = load("res://scripts/presentation/game_settings.gd").new()
	var config := ConfigFile.new()
	config.set_value("meta","version",1)
	config.set_value("settings","aim_fov",60.0)
	settings.load_settings(config)
	check(settings.values.aim_fov == 42,"version one default ADS migrates to 42 degrees")
	config.set_value("settings","aim_fov",55.0)
	settings.load_settings(config)
	check(settings.values.aim_fov == 55,"customized saved ADS remains unchanged")
	settings.free()
	await reset()
	var controller := PlayerController.new()
	controller.actor = a
	a.add_child(controller)
	a.set_physics_process(false)
	a.intent.aim_held = true
	await step(20)
	check(absf(controller.camera.fov-42) < .1,"ADS camera actually reaches the new zoom")
	var ray: CombatIntent = controller.gather_intent(1.0/60)
	check(ray.aim.is_equal_approx(-controller.camera.global_basis.z) and ray.aim_origin.is_equal_approx(controller.camera.global_position),"aim intent follows the zoomed camera ray")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var mouse := InputEventMouseMotion.new()
		mouse.relative = Vector2(100,0)
		var old_yaw: float = controller.yaw
		controller._unhandled_input(mouse)
		var ads_turn: float = absf(controller.yaw-old_yaw)
		check(absf(ads_turn-controller.sensitivity*100*tan(deg_to_rad(42)*.5)/tan(deg_to_rad(82)*.5)*controller.ads_multiplier) < .001,"mouse ADS sensitivity follows tangent FOV ratio")
		a.intent.aim_held = false
		Input.action_press("move_right")
		var turn_speeds: Array[float] = []
		for sign_value: float in [-1,1]:
			controller.yaw = 0
			var velocity := Vector3.FORWARD*10
			for i: int in 120:
				controller.yaw += sign_value*.004
				controller._process(1.0/60)
				var strafe_input: CombatIntent = controller.gather_intent(1.0/60)
				a.motor.mode = "air"
				velocity = a.motor.steer_horizontal(velocity,strafe_input.move,6,false,false,1.0/60)
			turn_speeds.append(velocity.length())
		Input.action_release("move_right")
		check(turn_speeds[0] > turn_speeds[1]+.1,"holding D and steering right sustains more speed than steering against it")
	controller.combat_camera_effects = 0
	controller.recoil = .04
	controller.combat_impulse = Vector3(.03,0,.02)
	controller._process(1.0/60)
	check(controller.camera.rotation.is_zero_approx(),"zero combat camera intensity suppresses visual impulses")
	check(is_equal_approx(controller.rig.rotation.x,controller.pitch),"zero combat camera intensity also suppresses existing gun recoil")
	controller.queue_free()
	a.set_physics_process(true)
	await step()
	var hud := DamageNumbers.new()
	hud.viewer = b
	hud.font = ThemeDB.fallback_font
	world.add_child(hud)
	resolver.damage(a,b,5,"rifle",resolver.new_cast(a),false,false,Vector3(4,1,0))
	check(hud.incoming.size() == 1 and hud.incoming[0].origin == Vector3(4,1,0),"incoming direction uses actual impact origin")
	resolver.damage(a,b,5,"bleed",resolver.new_cast(a))
	check(hud.incoming.back().origin == Vector3.INF,"ongoing damage has no invented direction")
	resolver.damage(a,b,5,"lodestone",resolver.classify(resolver.new_cast(a),CombatResolver.ImpactKind.AREA))
	check(hud.incoming.back().origin == Vector3.INF,"persistent area damage uses undirected hurt feedback")
	hud.viewer = a
	hud.incoming.clear()
	b.shields = 25
	resolver.damage(a,b,10,"shotgun",resolver.new_cast(a))
	resolver.damage(a,b,10,"shotgun",resolver.new_cast(a),true)
	check(hud.entries.size() == 1 and hud.entries[0].amount == 20 and hud.entries[0].head and hud.entries[0].shield == 20,"pellets coalesce with head and shield distinctions")
	hud.queue_free()

func parries() -> void:
	await reset()
	await arm_parry()
	check(b.close.parry_left > .1 and b.close.guard_cd > .4,"shield release opens parry and short cooldown")
	var id: int = ability_id()
	check(resolver.damage(a,b,35,"projectile",id) == "parried" and b.health == 250,"front ability damage is negated")
	check(resolver.admit_impact(a,b,id,a.body_point(1)) == CombatResolver.Admission.PARRIED,"same impact rejects attached status/capture/displacement")
	check(b.close.parry_left == 0 and b.close.notice == "PARRY","successful parry consumes window and confirms")
	check(resolver.damage(a,b,5,"projectile",ability_id()) == "hit","parry absorbs one impact only")
	check(resolver.damage(a,c,5,"projectile",id) == "hit","parry never protects another target")
	await reset()
	await arm_parry()
	id = ability_id()
	resolver.ultimate_casts[id] = true
	check(resolver.damage(a,b,5,"projectile",id) == "parried","ordinary ability remains parryable during an ongoing support ultimate")
	for kind: CombatResolver.ImpactKind in [CombatResolver.ImpactKind.WEAPON,CombatResolver.ImpactKind.MELEE,CombatResolver.ImpactKind.THROW,CombatResolver.ImpactKind.PERIODIC,CombatResolver.ImpactKind.AREA,CombatResolver.ImpactKind.ULTIMATE]:
		await reset()
		await arm_parry()
		id = resolver.classify(resolver.new_cast(a),kind)
		check(resolver.damage(a,b,5,"projectile",id) == "hit","excluded impact kind %d bypasses parry" % kind)
	await reset()
	await arm_parry()
	check(resolver.damage(a,b,5,"projectile",ability_id(),false,false,b.position+Vector3.FORWARD) == "hit","rear impact cannot be parried")
	await reset()
	await arm_parry()
	await step(9)
	check(resolver.damage(a,b,5,"projectile",ability_id()) == "hit","expired release window cannot parry")
	await reset()
	b.intent.guard = true
	await step()
	b.intent.guard = false
	await step()
	check(b.close.parry_left == 0,"sub-minimum shield tap grants no parry")
	await reset()
	await arm_parry()
	b.intent.melee = true
	await step()
	check(b.close.parry_left == 0,"new action closes release window")
	await reset()
	b.intent.guard = true
	await step(10)
	b.intent.throw_action = true
	await step()
	check(b.close.parry_left == 0,"canceling shield into throw cannot grant parry")
	await reset("huddle")
	await arm_parry()
	(a.kit as HuddleKit).pulse()
	check(b.health == 250 and b.motor.external_velocity.is_zero_approx(),"parried Wingbeat negates damage and push together")
	await reset("slayer")
	await arm_parry()
	var trap := HunterSnare.new()
	trap.source = a
	world.add_child(trap)
	trap.global_position = a.position
	trap.trigger(b)
	check(b.health == 250 and not b.statuses.effects.has("root"),"parried snare negates damage and root together")
	trap.queue_free()
	await reset("stitch")
	await arm_parry()
	a.aim_direction = (b.body_point(1.1)-a.body_point(1.4)).normalized()
	a.intent.aim = a.aim_direction
	(a.kit as StitchKit).attach_thread()
	check(not is_instance_valid((a.kit as StitchKit).thread),"parry negates damage-free Red Thread attachment")
	check(a.kit.bomb_cd > 0,"parried ability still spends its ordinary cooldown")
	await reset("relay")
	await arm_parry()
	a.aim_direction = (b.body_point(1.1)-a.body_point(1.4)).normalized()
	a.intent.aim = a.aim_direction
	var accepted: bool = (a.kit as RelayKit).cast_omen()
	check(accepted and not (a.kit as RelayKit).valid_omen() and b.close.notice == "PARRY","parry negates damage-free Omen mark")
	await reset()
	b.intent.guard = true
	await step(182)
	check(b.state != "guard" and b.close.guard_cd > 0,"full shield lasts three seconds")

func close_actions() -> void:
	await reset()
	a.intent.stationary_melee = true
	a.intent.melee = true
	await step()
	a.intent.melee = false
	await step(16)
	check(b.health == 175 and b.motor.external_velocity.length() > 0,"confirmed melee applies damage and push")
	check(b.state == "ready" and not b.statuses.stunned(),"ordinary melee does not stun")
	await reset()
	a.intent.stationary_melee = true
	a.intent.melee = true
	await step()
	a.intent.melee = false
	await step(10)
	b.close.start_throw()
	await step(6)
	check(a.close.notice == "COUNTER HIT" and b.state == "throw_whiff","confirmed melee interrupts throw startup with counter feedback")
	await reset()
	b.reset_actor(Vector3(0,.01,-3.65))
	await step(3)
	check(a.close.select_throw_target() == null,"preview rejects out-of-range target")
	a.close.start_throw()
	await step(20)
	check(a.state == "throw_pair" and b.state == "captured","approach plus acquisition at connection catches newly in-range target")
	await step(68)
	check(b.state == "throw_release" and b.state_time > 0,"completed throw has brief victim recovery")
	check(b.close.grace > 1.4,"throw immunity begins at release")
	await step(24)
	check(b.state == "ready" and b.close.grace > 0,"control returns while throw immunity remains")
	await reset()
	a.close.start_throw()
	b.close.start_throw()
	await step(19)
	check(a.state == "counterthrow" and b.state == "counterthrow","simultaneous throws clash")
	check(a.motor.external_velocity.length() > 0 and b.motor.external_velocity.length() > 0,"clash separation uses external impulse")
	await reset()
	a.close.start_throw()
	await step(20)
	a.close.cancel()
	check(b.close.grace > 1.4 and not a.get_collision_exceptions().has(b),"interrupted throw preserves immunity and cleans collision exception")
	a.close.parry_left = .12
	a.reset_actor()
	check(a.close.parry_left == 0 and a.close.grace == 0,"respawn clears temporary parry and throw state")
	await reset("slayer")
	var trainer := ParryPracticeController.new()
	trainer.actor = a
	trainer.target = b
	a.add_child(trainer)
	a.controller = trainer
	b.invulnerable = true
	await step(100)
	var launched: bool = false
	for event: Dictionary in resolver.events:
		if event.event == "cast" and event.ability == "silver_knife": launched = true
	check(launched,"parry practice controller launches the real Slayer knife through combat intent")
	a.controller = null
	trainer.queue_free()
