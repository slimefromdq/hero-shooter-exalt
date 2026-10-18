extends SceneTree
var world: Node3D
var a: HeroActor
var b: HeroActor
var c: HeroActor
var resolver: CombatResolver
var checks: int = 0
var failures: Array[String] = []
var trajectories: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if ok: print("PASS  ",caption)
	else:
		failures.append(caption)
		push_error(caption)
func step(frames: int = 1) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame
func spawn(hero: String, team: int, at: Vector3) -> HeroActor:
	var actor: HeroActor = preload("res://scenes/actors/hero_actor.tscn").instantiate()
	actor.tuning = HeroRoster.tuning_for(hero)
	actor.team = team
	actor.position = at
	world.add_child(actor)
	return actor
func reset() -> void:
	CombatEffect.clear_transients(self)
	a.reset_actor(Vector3(0,.01,0))
	b.reset_actor(Vector3(20,.01,-5))
	c.reset_actor(Vector3(-20,.01,-5))
	a.aim_direction = Vector3.FORWARD
	a.intent.aim = Vector3.FORWARD
	a.set_physics_process(true)
	b.set_physics_process(false)
	c.set_physics_process(false)
	await step(2)
func projectile(kind: String, at: Vector3, forward: Vector3) -> SlayerProjectile:
	var p := SlayerProjectile.new()
	p.source = a
	p.kind = kind
	p.direction = forward.normalized()
	world.add_child(p)
	p.global_position = at
	p.set_physics_process(false)
	return p
func kit() -> SlayerKit: return a.kit as SlayerKit
func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(100,1,100),Vector3(0,-.5,0),Color.GRAY)
	a = spawn("slayer",0,Vector3(0,.01,0))
	b = spawn("nimbus",1,Vector3(20,.01,-5))
	c = spawn("nimbus",1,Vector3(-20,.01,-5))
	await step(4)
	await steering()
	await knives()
	await axes()
	await lifecycle()
	Engine.physics_ticks_per_second = 60
	world.queue_free()
	await step(3)
	var pool: Node = root.get_node("SlayerEffectPool")
	check(pool.free_ability.size() == 32,"scene exit recycles every ability burst")
	print("RESULT: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/slayer-task2-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"trajectories":trajectories},"\t"))
	if DisplayServer.get_name() != "headless":
		var end: int = Time.get_ticks_msec()+150
		while Time.get_ticks_msec() < end: await process_frame
	quit(0 if failures.is_empty() else 1)
func steering() -> void:
	var endpoints: Array[Vector3] = []
	for rate: int in [30,60,144]:
		await reset()
		kit().boot_launch_direction = Vector3.FORWARD
		kit().boot_steer_angle = 0
		a.intent.move = Vector3.RIGHT
		for index: int in rate: kit().steer_boot(1.0/rate)
		check(is_equal_approx(rad_to_deg(kit().boot_steer_angle),-15),"right steering caps at fifteen degrees at %d Hz" % rate)
		a.intent.move = Vector3.LEFT
		kit().steer_boot(.1)
		check(is_equal_approx(rad_to_deg(kit().boot_steer_angle),-11),"turn rate is forty degrees per second at %d Hz" % rate)
		for index: int in rate: kit().steer_boot(1.0/rate)
		check(is_equal_approx(rad_to_deg(kit().boot_steer_angle),15),"left steering caps at fifteen degrees at %d Hz" % rate)
		kit().boot_launch_direction = Vector3(0,.4,-1).normalized()
		kit().steer_boot(.1)
		check(is_equal_approx(kit().boot_direction.y,kit().boot_launch_direction.y),"air steering preserves launch elevation at %d Hz" % rate)
		Engine.physics_ticks_per_second = rate
		await reset()
		a.intent.move = Vector3.RIGHT
		kit().start_boot()
		var travelled: float = 0.0
		var previous: Vector3 = a.global_position
		for index: int in ceili(rate*.6):
			await step()
			if a.state == "ready": break
			travelled += Vector2(a.position.x-previous.x,a.position.z-previous.z).length()
			previous = a.global_position
		check(a.position.x > .8 and a.position.z < -11.3 and a.position.length() < 12.3,"curved boot preserves twelve metre commitment at %d Hz" % rate)
		check(kit().deflect_cd > 8.2 and is_equal_approx(kit().data().boot_speed,32),"boot speed/cooldown remain unchanged at %d Hz" % rate)
		trajectories["boot_%d" % rate] = str(a.position)
		endpoints.append(a.position)
	check(endpoints[0].distance_to(endpoints[1]) < .12 and endpoints[2].distance_to(endpoints[1]) < .12,"grounded turn endpoints agree within twelve centimetres across physics rates")
	Engine.physics_ticks_per_second = 60
	await reset()
	a.position.y = 6
	a.aim_direction = Vector3(0,.4,-1).normalized()
	a.intent.aim = a.aim_direction
	a.intent.move = Vector3.RIGHT
	kit().start_boot()
	var elevation: float = kit().boot_direction.y
	await step(12)
	check(a.position.x > .1 and a.position.y > 6 and is_equal_approx(kit().boot_direction.y,elevation),"actual airborne boot curves horizontally without changing its vertical trajectory")
	await reset()
	b.position = Vector3(1.25,.01,-6)
	a.intent.move = Vector3.RIGHT
	await step(2)
	kit().start_boot()
	await step(16)
	check(b.health == 195 and a.boot_pair != null,"swept target detection connects during a right turn for exactly 55 damage")
	await step(35)
	check(a.boot_pair == null and b.motor.external_velocity.length() > 0,"attachment ends and existing launch knockback is retained")
	await reset()
	var wall: Node3D = Geometry.box(world,Vector3(10,4,.04),Vector3(0,2,-3),Color.GRAY)
	await step(2)
	a.intent.move = Vector3.RIGHT
	kit().start_boot()
	await step(32)
	check(a.position.z > -2.7 and a.state == "ready" and kit().boot_slow_time > 0,"steering cannot tunnel through a thin wall and enters miss recovery")
	wall.queue_free()
	await reset()
	kit().start_boot()
	a.close.stagger()
	await step(3)
	check(a.state == "stagger" and kit().boot_remaining == 0,"stagger interrupts boot movement")
func knives() -> void:
	for rate: int in [30,60,144]:
		await reset()
		a.set_physics_process(false)
		var p: SlayerProjectile = projectile("knife",Vector3(0,5,0),Vector3.FORWARD)
		check(p.velocity == Vector3(0,0,-110),"knife initializes exact 110 m/s velocity at %d Hz" % rate)
		var time: float = 0.0
		while time < .18-.000001:
			var dt: float = minf(1.0/rate,.18-time)
			p._physics_process(dt)
			time += dt
		check(absf(p.position.y-(5.0-6.0*.18*.18)) < .0001 and absf(p.position.z+19.8) < .001,"knife follows analytical ballistic drop at %d Hz" % rate)
		check((-p.global_basis.z).is_equal_approx(p.velocity.normalized()),"knife point follows instantaneous velocity at %d Hz" % rate)
		trajectories["knife_%d" % rate] = str(p.position)
		p._physics_process(.2)
		check(p.is_queued_for_deletion() and p.travelled <= 25.001,"knife expires on actual travelled range at %d Hz" % rate)
		await reset()
		a.set_physics_process(false)
		var wall: Node3D = Geometry.box(world,Vector3(4,10,.025),Vector3(0,5,-4),Color.GRAY)
		await step(2)
		p = projectile("knife",Vector3(0,5,0),Vector3.FORWARD)
		p._physics_process(1.0/rate)
		p._physics_process(1.0/rate)
		p._physics_process(1.0/rate)
		p._physics_process(1.0/rate)
		p._physics_process(1.0/rate)
		p._physics_process(1.0/rate)
		check(p.is_queued_for_deletion() and p.position.z > -4.15,"curved sweeps stop at a 25 mm wall at %d Hz" % rate)
		wall.queue_free()
		await reset()
		a.set_physics_process(false)
		b.position = Vector3(0,.01,-20)
		await step(2)
		p = projectile("knife",Vector3(0,1.2,0),Vector3.FORWARD)
		for index: int in ceili(rate*.23): p._physics_process(1.0/rate)
		check(b.health == 220 and b.statuses.effects.has("bleed"),"curved knife sphere hits a medium-range enemy at %d Hz" % rate)
	await reset()
	a.set_physics_process(false)
	b.position = Vector3(0,.01,-10)
	await step(2)
	var p: SlayerProjectile = projectile("knife",Vector3(0,1.1,0),Vector3.FORWARD)
	p._physics_process(.12)
	check(b.health == 220 and b.statuses.effects.has("bleed"),"ballistic knife retains 30 damage and the existing bleed")
	await reset()
	a.set_physics_process(false)
	b.position = Vector3(0,.01,-4)
	b.state = "deflect"
	b.aim_direction = Vector3.BACK
	await step(2)
	p = projectile("knife",Vector3(0,1.1,0),Vector3.FORWARD)
	p._physics_process(.06)
	check(b.health == 250 and p.is_queued_for_deletion() and a.presentation.slayer_abilities.last_impact_category == "deflect","knife preserves frontal deflect consumption and distinct shield feedback")
	check(SlayerWeaponMeshes.build_knife() == SlayerWeaponMeshes.build_knife() and SlayerWeaponMeshes.build_knife().get_surface_count() == 3,"held and thrown knives share a cached three-surface mesh")
func axes() -> void:
	await reset()
	a.set_physics_process(false)
	for forward: Vector3 in [Vector3.FORWARD,Vector3.RIGHT,Vector3.BACK,Vector3.LEFT,Vector3(0,.5,-1).normalized()]:
		var p: SlayerProjectile = projectile("axe",Vector3(0,8,0),forward)
		check(p.spin_frame.global_basis.x.is_equal_approx(forward),"axe blade-plane X aligns to travel " + str(forward))
		check(absf(p.spin_frame.global_basis.z.dot(forward)) < .0001,"axe spin normal is perpendicular to travel " + str(forward))
		var before: float = p.visual.rotation.z
		p._physics_process(.025)
		check(is_equal_approx(p.visual.rotation.z,before-.5),"axe tumbles about blade-local Z at editable twenty rad/s")
		check(p.visual.scale.is_equal_approx(Vector3.ONE*1.215) and is_equal_approx((p.get_child(0).shape as SphereShape3D).radius,.55),"35 percent larger axe keeps the .55 metre physical radius")
		p.queue_free()
	await reset()
	a.set_physics_process(false)
	b.position = Vector3(0,.01,-4)
	c.position = Vector3(0,.01,-7)
	await step(2)
	var p: SlayerProjectile = projectile("axe",Vector3(0,1.1,0),Vector3.FORWARD)
	p._physics_process(.5)
	check(b.health == 125 and c.health == 125 and p.hit_targets.size() == 2,"enlarged axe retains 110 damage, max-health wound and two-target piercing")
	check(b.effective_max_health() == 125 and c.effective_max_health() == 125,"axe debuff magnitude is unchanged")
func lifecycle() -> void:
	await reset()
	a.presentation.slayer_abilities.begin_boot()
	a.presentation.sound.play_slayer("boot_wind")
	a.presentation.slayer_abilities.wind_voice = true
	kit().cancel()
	check(a.presentation.slayer_abilities.effects.is_empty() and not a.presentation.slayer_abilities.wind_voice,"interruption clears ability bursts and wind voice")
	var p: SlayerProjectile = projectile("axe",Vector3(0,4,0),Vector3.FORWARD)
	a.die()
	await step(2)
	check(not is_instance_valid(p) and a.presentation.sound.slayer_voices.is_empty(),"death clears projectiles, trails and overlapping audio")
	await reset()
	p = projectile("knife",Vector3(0,4,0),Vector3.FORWARD)
	a.select_hero("nimbus")
	await step(2)
	check(not is_instance_valid(p) and get_nodes_in_group("slayer_bursts").is_empty(),"hero switch clears ability/projectile transients")
