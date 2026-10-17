extends SceneTree

var world: Node3D
var resolver: CombatResolver
var doctor: HeroActor
var friend: HeroActor
var enemy: HeroActor
var marshal: HeroActor
var hunter: HeroActor
var second: HeroActor
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if value else "FAIL  ",caption)
	if not value: failures.append(caption)

func near(value: float, expected: float, caption: String, tolerance: float = .05) -> void:
	check(absf(value - expected) <= tolerance,caption + " [%.3f / %.3f]" % [value,expected])

func step(count: int = 2) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func spawn(id: String, team: int, at: Vector3) -> HeroActor:
	var a := HeroActor.new()
	a.actor_id = id
	a.team = team
	a.tuning = HeroRoster.tuning_for(id)
	a.position = at
	world.add_child(a)
	a.set_physics_process(false)
	return a

func aim(a: HeroActor, b: HeroActor) -> void:
	a.intent = CombatIntent.new()
	a.intent.aim_origin = a.global_position + Vector3.UP * 1.2
	a.aim_direction = (b.global_position + Vector3.UP * 1.2 - a.intent.aim_origin).normalized()
	a.intent.aim = a.aim_direction

func reset() -> void:
	doctor.reset_actor(Vector3(0,.01,0))
	friend.reset_actor(Vector3(0,.01,-8))
	enemy.reset_actor(Vector3(12,.01,-8))
	marshal.reset_actor(Vector3(-15,.01,0))
	hunter.reset_actor(Vector3(15,.01,-8))
	second.reset_actor(Vector3(3,.01,0))
	for a: HeroActor in [doctor,friend,enemy,marshal,hunter,second]: a.set_physics_process(false)
	resolver.clear_round()
	aim(doctor,friend)
	await step()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(150,1,150),Vector3(0,-.5,0),Color.GRAY)
	doctor = spawn("doctor",0,Vector3.ZERO)
	friend = spawn("nimbus",0,Vector3(0,0,-8))
	enemy = spawn("nimbus",1,Vector3(12,0,-8))
	marshal = spawn("marshal",0,Vector3(-15,0,0))
	hunter = spawn("slayer",1,Vector3(15,0,-8))
	second = spawn("doctor",0,Vector3(3,0,0))
	await step(4)
	await healing_tests()
	await buff_tests()
	await shield_tests()
	await weapon_barrier_tests()
	await mobility_tests()
	await offensive_tests()
	await edge_tests()
	await marshal_revision_tests()
	await marshal_forward_tests()
	await lifecycle_tests()
	world.queue_free()
	await step()
	await scene_tests()
	print("RESULT: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/care-heroes-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)

func healing_tests() -> void:
	await reset()
	var k := doctor.kit as DoctorKit
	check(doctor.health == 250 and marshal.health == 550,"new heroes load their own health resources")
	check(not doctor.permits("hover") and not marshal.permits("hover"),"new heroes cannot accidentally use Nimbus Hover")
	friend.health = 100
	k.ultimate_charge = 0
	doctor.intent.secondary_held = true
	k.tick(.5,doctor.intent)
	near(friend.health,132.5,"right hold supplies 65 HP/s")
	near(k.ultimate_charge,2.35,"healing charge counts actual healing plus passive")
	check(k.patient == friend and k.beam_healing,"beam exposes connected patient")
	friend.benefits.tick(.5)
	near(friend.health,132.5,"aftercare does not add healing to active beam")
	friend.health = 249
	k.tick(.5,doctor.intent)
	near(friend.health,250,"beam clamps at maximum health")
	friend.health = 100
	doctor.intent.secondary_held = false
	k.tick(0,doctor.intent)
	friend.benefits.tick(1)
	near(friend.health,115,"disconnected patient retains aftercare")
	friend.benefits.tick(1.5)
	near(friend.health,130,"aftercare expires without excess final-frame healing")
	friend.health = 100
	friend.benefits.grant("ward",doctor,3,15)
	friend.benefits.grant("ward",second,3,15)
	friend.benefits.tick(1)
	near(friend.health,115,"two doctors cannot stack identical ongoing healing")
	friend.benefits.grant("aftercare",second,2,15)
	friend.benefits.tick(1)
	near(friend.health,145,"distinct ongoing healing abilities combine")
	near(resolver.heal(doctor,enemy,100,"test"),0,"healing rejects enemies")
	friend.alive = false
	near(resolver.heal(doctor,friend,100,"test"),0,"healing rejects dead allies")
	await reset()
	friend.health = 100
	doctor.intent.secondary_held = true
	doctor.intent.primary_held = true
	var ammo: int = k.ammo
	k.tick(.1,doctor.intent)
	check(k.ammo == ammo and k.beam_healing,"healing wins simultaneous hold inputs")
	second.position = Vector3(3,.01,-8)
	second.health = 100
	aim(doctor,second)
	doctor.intent.secondary_held = true
	k.tick(.1,doctor.intent)
	check(k.patient == second,"aiming at a new patient switches immediately")
	check(friend.benefits.has_kind("aftercare"),"switching preserves the previous patient's treatment")
	var cover: Node3D = Geometry.box(world,Vector3(12,4,.5),Vector3(0,2,-4),Color.GRAY)
	await step()
	var hp: float = second.health
	k.tick(.1,doctor.intent)
	near(second.health,hp,"beam never heals through a wall")
	check(k.patient == second and not k.beam_healing,"obstruction grace retains selection without beam healing")
	k.tick(.1,doctor.intent)
	check(k.patient == null,"blocked beam disconnects after grace")
	cover.queue_free()
	await reset()
	friend.statuses.apply("max_health",enemy,5,.4)
	friend.statuses.apply("bleed",enemy,5,5)
	friend.statuses.apply("root",enemy,2)
	friend.health = 100
	doctor.intent.bomb = true
	k.tick(0,doctor.intent)
	check(friend.statuses.effects.is_empty(),"prescription clears wound, bleed and root")
	near(friend.effective_max_health(),250,"cleanse restores the health ceiling")
	near(friend.health,135,"cleanse heals after removing wound")
	near(friend.benefits.reduction(),.7,"prescription grants 70% damage reduction")
	resolver.damage(enemy,friend,100,"rifle",resolver.new_cast(enemy))
	near(friend.health,105,"prescription reduces incoming damage")
	friend.benefits.tick(1.1)
	near(friend.benefits.reduction(),0,"prescription protection expires")
	await reset()
	doctor.aim_direction = Vector3.UP
	doctor.intent.bomb = true
	k.tick(0,doctor.intent)
	near(k.bomb_cd,0,"invalid prescription target does not spend cooldown")

func buff_tests() -> void:
	await reset()
	var k := doctor.kit as DoctorKit
	var emitted: int = resolver.new_cast(friend)
	doctor.intent.ultimate = true
	k.tick(0,doctor.intent)
	check(doctor.state == "doctor_ultimate" and k.ultimate_charge == 100,"ultimate prepares before consuming charge")
	doctor.intent.ultimate = false
	doctor.state_time = 0
	k.tick(0,doctor.intent)
	check(friend.benefits.has_kind("exemplary") and k.ultimate_charge == 0,"valid completion applies buff and consumes charge")
	near(friend.benefits.damage_multiplier(),1.4,"ultimate grants 40% outgoing damage")
	near(friend.benefits.speed_multiplier(),1.3,"ultimate grants 30% movement speed")
	near(friend.benefits.reduction(),.4,"ultimate grants 40% damage reduction")
	check(not friend.benefits.grant("exemplary",second,8),"second doctor cannot stack or refresh active ultimate")
	friend.benefits.grant("prescription",doctor,1,.7)
	near(friend.benefits.reduction(),.7,"damage reduction chooses strongest rather than adding")
	enemy.health = 250
	resolver.damage(friend,enemy,50,"rifle",emitted)
	near(enemy.health,200,"already emitted attack retains unbuffed damage")
	friend.kit.ultimate_charge = 0
	resolver.damage(friend,enemy,50,"rifle",resolver.new_cast(friend))
	near(enemy.health,130,"new direct attack receives damage buff")
	near(friend.kit.ultimate_charge,4.5,"bonus damage does not generate extra ultimate charge")
	resolver.damage(friend,enemy,10,"bleed",resolver.new_cast(friend))
	near(enemy.health,120,"bleed does not receive damage buff")
	doctor.position = Vector3(60,.01,0)
	friend.benefits.tick(2)
	check(friend.benefits.has_kind("exemplary"),"ultimate survives separation from the doctor")
	friend.benefits.tick(6)
	check(not friend.benefits.has_kind("exemplary"),"ultimate expires after eight seconds")
	await reset()
	doctor.intent.ultimate = true
	k.tick(0,doctor.intent)
	friend.position = Vector3(0,.01,-30)
	doctor.state_time = 0
	doctor.intent.ultimate = false
	k.tick(0,doctor.intent)
	check(k.ultimate_charge == 100 and doctor.state == "ready","invalid ultimate completion retains charge")

func shield_setup() -> MarshalKit:
	await reset()
	marshal.position = Vector3(0,.01,0)
	friend.position = Vector3(0,.01,2)
	enemy.position = Vector3(0,.01,-8)
	hunter.position = Vector3(12,.01,-8)
	doctor.position = Vector3(-12,.01,0)
	marshal.aim_direction = Vector3.FORWARD
	marshal.intent.secondary_held = true
	var k := marshal.kit as MarshalKit
	k.tick(0,marshal.intent)
	await step()
	return k

func shield_tests() -> void:
	var k: MarshalKit = await shield_setup()
	near(k.barrier_hp,1200,"barrier starts with 1200 durability")
	near(k.movement_scale(),.65,"shield retains 65% movement")
	var hit: Dictionary = resolver.attack_ray(enemy,Vector3(3.9,4,-6),Vector3(3.9,4,3),[],1)
	check(hit.get("collider") == k.barrier,"barrier protects the full eight-by-four-and-a-half-metre surface")
	check(resolver.attack_ray(enemy,Vector3(4.1,4,-6),Vector3(4.1,4,3),[],1).is_empty(),"shots beyond shield edge bypass it")
	check(resolver.attack_ray(friend,Vector3(0,1,2),Vector3(0,1,-6),[],1).is_empty(),"friendly ranged attacks pass through")
	check(resolver.attack_ray(enemy,Vector3(0,1,3),Vector3(0,1,1),[],1).is_empty(),"rear attack not crossing surface bypasses shield")
	check(not marshal.permits("primary") and not marshal.permits("dash"),"shield blocks shooting and dash")
	var id: int = resolver.new_cast(enemy)
	k.barrier.receive_damage(enemy,100,id)
	k.barrier.receive_damage(enemy,100,id)
	near(k.barrier_hp,1100,"same cast cannot damage barrier twice")
	marshal.intent.deflect = true
	k.tick(0,marshal.intent)
	check(marshal.state == "marshal_shield" and marshal.benefits.has_kind("resolve"),"Iron Resolve works while holding shield")
	marshal.intent.secondary_held = false
	marshal.intent.deflect = false
	k.tick(0,marshal.intent)
	k.tick(1,marshal.intent)
	near(k.barrier_hp,1100,"lowered shield waits before regeneration")
	k.tick(1,marshal.intent)
	check(k.barrier_hp > 1100,"lowered shield regenerates after delay")
	marshal.intent.secondary_held = true
	k.tick(0,marshal.intent)
	k.barrier.receive_damage(enemy,2000,resolver.new_cast(enemy))
	check(k.barrier_hp == 0 and marshal.state == "ready" and k.break_remaining == 4,"barrier break lowers shield and enforces downtime")
	k.tick(3,marshal.intent)
	check(marshal.state == "ready" and k.barrier_hp == 0,"broken shield cannot immediately be raised")
	k.tick(1,marshal.intent)
	k.tick(.1,marshal.intent)
	check(k.barrier_hp > 0,"shield starts regenerating after broken downtime")

func weapon_barrier_tests() -> void:
	var k: MarshalKit = await shield_setup()
	aim(enemy,marshal)
	(enemy.kit as NimbusKit).fire(false)
	near(marshal.health,550,"Nimbus rifle cannot hit shield owner")
	check(k.barrier_hp < 1200,"Nimbus rifle damages barrier")
	var before: float = k.barrier_hp
	(enemy.kit as NimbusKit).fire(true)
	near(k.barrier_hp,before-150,"Nimbus ultimate damages barrier without executing")
	hunter.position = enemy.position + Vector3(1,0,0)
	aim(hunter,marshal)
	before = k.barrier_hp
	(hunter.kit as SlayerKit).fire(false)
	check(k.barrier_hp < before and marshal.health == 550,"Slayer pellets hit shield rather than owner")
	var ball := CombatProjectile.new()
	ball.source = enemy
	ball.direction = Vector3.BACK
	ball.cast_id = resolver.new_cast(enemy)
	world.add_child(ball)
	ball.position = Vector3(0,1.3,-1.8)
	before = k.barrier_hp
	ball._physics_process(.05)
	near(k.barrier_hp,before-24,"generic projectile damages shield")
	for kind: String in ["knife","axe"]:
		var projectile := SlayerProjectile.new()
		projectile.source = hunter
		projectile.kind = kind
		projectile.direction = Vector3.BACK
		world.add_child(projectile)
		projectile.position = Vector3(0,1.3,-1.8)
		before = k.barrier_hp
		projectile._physics_process(.05)
		check(projectile.is_queued_for_deletion() and k.barrier_hp < before,kind + " stops at the barrier")
	var snare := HunterSnare.new()
	snare.source = hunter
	snare.flying = true
	world.add_child(snare)
	snare.position = Vector3(0,1.3,-1.8)
	snare.velocity = Vector3.BACK * 20
	before = k.barrier_hp
	snare._physics_process(.05)
	check(snare.is_queued_for_deletion() and k.barrier_hp < before,"thrown snare is intercepted")
	before = k.barrier_hp
	var hp: float = marshal.health
	resolver.splash(enemy,Vector3(0,1,-2.2),3,80,"bomb",resolver.new_cast(enemy))
	near(k.barrier_hp,before-80,"explosion damages barrier once despite multiple protected actors")
	near(marshal.health,hp,"explosion cannot damage owner through shield")
	k.barrier_hp = 10
	resolver.splash(enemy,Vector3(0,1,-2.2),3,80,"bomb",resolver.new_cast(enemy))
	near(marshal.health,hp,"shield-breaking explosion does not also penetrate")
	await shield_setup()
	k = marshal.kit as MarshalKit
	var bomb := PocketBomb.new()
	bomb.source = enemy
	bomb.cast_id = resolver.new_cast(enemy)
	world.add_child(bomb)
	bomb.position = Vector3(0,1,-1.8)
	bomb.velocity = Vector3.BACK * 10
	bomb._physics_process(.05)
	check(bomb.velocity.z < 0,"bomb bounces away from hostile barrier")
	bomb.queue_free()

func mobility_tests() -> void:
	await reset()
	var d := doctor.kit as DoctorKit
	check(d.start_call(),"House Call accepts reachable ally")
	near(d.mobility_cd,4,"House Call uses four-second cooldown")
	for i: int in 60: d.move_override(1.0/60)
	near(doctor.global_position.distance_to(friend.global_position),2,"House Call stops two metres from ally",.1)
	check(doctor.state == "ready","House Call returns normal control")
	await reset()
	var cover: Node3D = Geometry.box(world,Vector3(5,4,.5),Vector3(0,2,-4),Color.GRAY)
	await step()
	check(not d.start_call() and d.mobility_cd == 0,"blocked House Call does not spend cooldown")
	cover.queue_free()
	await reset()
	d.start_call()
	doctor.statuses.apply("root",enemy,1)
	d.move_override(.1)
	check(doctor.state == "ready" and d.mobility_cd == 4,"root interrupts House Call without refund")
	await reset()
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-12,.01,0)
	enemy.position = Vector3(0,.01,-3)
	marshal.intent.aim = Vector3.FORWARD
	marshal.aim_direction = Vector3.FORWARD
	marshal.intent.hover = true
	var m := marshal.kit as MarshalKit
	await step()
	m.tick(0,marshal.intent)
	for i: int in 30: m.move_override(1.0/60)
	near(enemy.health,205,"Forward March deals 45 on first contact")
	near(enemy.velocity.y,8,"Forward March launches enemy upward")
	enemy.intent = CombatIntent.new()
	for i: int in 10: enemy.motor.tick(1.0/60,enemy.intent)
	check(enemy.global_position.y > .8,"launch produces a visible airborne gravity arc")
	check(marshal.state == "ready","enemy impact stops the advance")
	await reset()
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-12,.01,0)
	enemy.position = Vector3(0,.01,-3)
	enemy.state = "guard"
	enemy.aim_direction = Vector3.BACK
	marshal.intent.hover = true
	marshal.aim_direction = Vector3.FORWARD
	await step()
	m.tick(0,marshal.intent)
	for i: int in 30: m.move_override(1.0/60)
	near(enemy.health,250,"frontal shared guard blocks advance damage")
	near(enemy.motor.external_velocity.y,0,"blocked advance does not launch")
	check(marshal.state == "stagger","guard staggers advancing marshal")

func offensive_tests() -> void:
	await reset()
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-12,.01,0)
	enemy.position = Vector3(0,.01,-8)
	marshal.aim_direction = Vector3.FORWARD
	marshal.intent.bomb = true
	var m := marshal.kit as MarshalKit
	await step()
	m.tick(0,marshal.intent)
	marshal.intent.bomb = false
	m.tick(.39,marshal.intent)
	near(enemy.health,250,"Breach Line has damage-free warning")
	m.tick(.8,marshal.intent)
	near(enemy.health,175,"overlapping breach explosions hit each enemy once")
	check(m.breach_index == 10,"barrage progresses through ten explosions")
	await reset()
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-12,.01,0)
	enemy.position = Vector3(0,6,-8)
	marshal.aim_direction = (enemy.position + Vector3.UP - marshal.muzzle()).normalized()
	marshal.intent.bomb = true
	await step()
	m.tick(0,marshal.intent)
	marshal.intent.bomb = false
	m.tick(2,marshal.intent)
	near(enemy.health,175,"Breach Line follows 3D aim to airborne targets")
	await reset()
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-12,.01,0)
	enemy.position = Vector3(0,.01,-9.5)
	marshal.aim_direction = Vector3.FORWARD
	enemy.set_physics_process(true)
	await step(4)
	enemy.set_physics_process(false)
	m.verdict_direction = Vector3.FORWARD
	m.cast_id = resolver.new_cast(marshal)
	m.verdict()
	near(enemy.health,150,"Verdict reaches grounded targets beyond old eight-metre range")
	check(enemy.state == "stagger","Verdict applies its brief stagger")
	await reset()
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-12,.01,0)
	enemy.position = Vector3(0,3,-8)
	m.cast_id = resolver.new_cast(marshal)
	m.verdict()
	near(enemy.health,250,"airborne targets above elevation band avoid Verdict")

func lifecycle_tests() -> void:
	await reset()
	friend.benefits.grant("exemplary",doctor,8)
	doctor.die()
	check(not friend.benefits.has_kind("exemplary"),"doctor death retires her buffs immediately")
	await reset()
	friend.benefits.grant("ward",doctor,3,15)
	doctor.select_hero("marshal")
	check(not friend.benefits.has_kind("ward"),"source hero switch clears owned treatment")
	check(doctor.kit is MarshalKit and doctor.health == 550,"runtime selection installs new kit, visuals and health")
	doctor.select_hero("doctor")
	await reset()
	friend.benefits.grant("exemplary",doctor,8)
	friend.reset_actor()
	check(friend.benefits.effects.is_empty(),"recipient respawn clears beneficial modifiers")
	var input := CombatIntent.new()
	input.aim_origin = doctor.position + Vector3.UP * 1.2
	friend.health = 100
	CareTactics.apply(doctor,input)
	check(input.secondary_held,"doctor bot requests healing for injured teammate")
	var k := marshal.kit as MarshalKit
	marshal.state = "marshal_shield"
	k.cancel(true)
	check(not k.barrier.active(),"cancel removes active shield protection")
	for hero: String in HeroRoster.IDS:
		var counts: Dictionary = {}
		for slot: int in 6:
			var id: String = HeroRoster.team_hero(slot,hero)
			counts[id] = counts.get(id,0)+1
		check(counts == {"marshal":1,"huddle":1,"doctor":1,"nimbus":1,"slayer":2} and HeroRoster.team_hero(0,hero) == hero,"balanced team composition for " + hero)
		var runners: int = 0
		var tank_frontline: bool = true
		for slot: int in range(1,6):
			if HeroRoster.bot_role(slot,hero) == "frontline_subway": runners += 1
			if HeroRoster.team_hero(slot,hero) == "marshal": tank_frontline = HeroRoster.bot_role(slot,hero) == "frontline"
		check(runners == 1 and tank_frontline,"one damage bot covers the subway while the tank leads for " + hero)

func edge_tests() -> void:
	await reset()
	friend.health = 100
	friend.spawn_protected = true
	near(resolver.heal(doctor,friend,50,"test"),0,"care cannot reach into protected spawn rooms")
	friend.spawn_protected = false
	doctor.spawn_protected = true
	near(resolver.heal(doctor,friend,50,"test"),0,"care cannot originate in protected spawn rooms")
	doctor.spawn_protected = false
	friend.benefits.grant("ward",doctor,.6,15)
	friend.benefits.tick(2)
	near(friend.health,109,"healing expiry is correct with a large timestep")
	friend.health = 100
	friend.benefits.grant("ward",doctor,.6,15)
	for i: int in 120: friend.benefits.tick(1.0/60)
	near(friend.health,109,"healing expiry is independent of timestep")
	await reset()
	var d := doctor.kit as DoctorKit
	doctor.intent.ultimate = true
	d.tick(0,doctor.intent)
	doctor.close.stagger()
	check(d.pending_patient == null and d.ultimate_charge == 100,"interrupted doctor preparation keeps unspent ultimate")
	await reset()
	var m := marshal.kit as MarshalKit
	marshal.intent.ultimate = true
	m.tick(0,marshal.intent)
	marshal.close.stagger()
	check(m.ultimate_charge == 0 and marshal.state == "stagger","interrupted Verdict does not refund ultimate")
	await reset()
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-12,.01,0)
	enemy.position = Vector3(0,.01,-8)
	var cover: Node3D = Geometry.box(world,Vector3(6,5,.5),Vector3(0,2.5,-4),Color.GRAY)
	await step()
	marshal.intent.bomb = true
	marshal.aim_direction = Vector3.FORWARD
	m.tick(0,marshal.intent)
	marshal.intent.bomb = false
	m.tick(2,marshal.intent)
	near(enemy.health,250,"solid wall stops barrage and splash behind it")
	cover.queue_free()
	await reset()
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-12,.01,0)
	var defender: HeroActor = spawn("marshal",1,Vector3(0,.01,-6))
	defender.aim_direction = Vector3.BACK
	defender.intent.secondary_held = true
	var defense := defender.kit as MarshalKit
	defense.tick(0,defender.intent)
	defense.barrier_hp = 10
	marshal.aim_direction = Vector3.FORWARD
	marshal.intent.bomb = true
	await step()
	m.tick(0,marshal.intent)
	marshal.intent.bomb = false
	m.tick(2,marshal.intent)
	near(defender.health,550,"shield-breaking Breach Line explosion still protects its owner")
	check(defense.barrier_hp == 0 and m.breach_index == m.data().breach_count,"barrage ends at the hostile barrier even when breaking it")
	defender.queue_free()
	await reset()
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-12,.01,0)
	enemy.position = Vector3(0,.01,-9.5)
	enemy.set_physics_process(true)
	await step(6)
	enemy.set_physics_process(false)
	cover = Geometry.box(world,Vector3(6,5,.5),Vector3(0,2.5,-4),Color.GRAY)
	await step()
	m.verdict_direction = Vector3.FORWARD
	m.cast_id = resolver.new_cast(marshal)
	m.verdict()
	near(enemy.health,250,"wall blocks Verdict at ten-metre range")
	cover.queue_free()
	await shield_setup()
	m = marshal.kit as MarshalKit
	enemy.position = Vector3(0,.01,1.5)
	await step()
	aim(enemy,marshal)
	(enemy.kit as NimbusKit).fire(false)
	check(marshal.health < 550 and m.barrier_hp == 1200,"attack originating behind shield surface can hit owner")
	await shield_setup()
	m = marshal.kit as MarshalKit
	marshal.intent.melee = true
	marshal._physics_process(1.0/60)
	check(marshal.state == "melee_windup" and not m.barrier.active(),"shared melee lowers held barrier before commitment")
	await reset()
	friend.benefits.grant("exemplary",doctor,8)
	friend.intent.move = Vector3.RIGHT
	for i: int in 30:
		friend.motor.tick(1.0/60,friend.intent)
	check(friend.velocity.x > 7.5 and friend.velocity.length() <= friend.tuning.speed_limit,"speed buff raises running speed while retaining global cap")
	var duration: float = friend.benefits.remaining("exemplary")
	paused = true
	await create_timer(.05,true,false,true).timeout
	near(friend.benefits.remaining("exemplary"),duration,"pause freezes beneficial durations")
	paused = false

func scene_tests() -> void:
	HeroRoster.selected = "doctor"
	var arena: Node3D = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var training: TrainingManager = arena.training
	training.start_care_drill("doctor")
	await step(3)
	check(training.player.kit is DoctorKit and training.bots.size() == 4,"doctor training exercise creates three patients and flanker")
	check(training.bots[0].team == training.player.team,"training patients are friendly")
	if DisplayServer.get_name() != "headless":
		Input.action_press("aim")
		var controls: CombatIntent = training.player.controller.gather_intent(0)
		Input.action_release("aim")
		check(controls.secondary_held and not controls.aim_held,"doctor right hold heals without triggering shoulder aim")
		Input.action_press("primary")
		controls = training.player.controller.gather_intent(0)
		Input.action_release("primary")
		check(controls.primary_held,"doctor left hold supplies sustained firing input")
	training.start_care_drill("marshal")
	await step(3)
	check(training.player.kit is MarshalKit and training.bots.size() == 4,"marshal exercise creates protected ally and three attackers")
	arena.queue_free()
	await step(3)
	check(get_nodes_in_group("barriers").is_empty(),"scene exit frees all barriers")
	HeroRoster.selected = "marshal"
	arena = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var city: CityMatch = arena.match_controller
	city.freeze_ai = true
	await step(4)
	check(city.player.kit is MarshalKit and city.actors.size() == 12,"city creates selected main tank and full roster")
	for team: int in 2:
		var counts: Dictionary = {}
		for actor: HeroActor in city.actors:
			if actor.team == team: counts[actor.tuning.hero_id] = counts.get(actor.tuning.hero_id,0)+1
		check(counts == {"marshal":1,"huddle":1,"doctor":1,"nimbus":1,"slayer":2},"live city team %d has the intended five-hero composition" % team)
	city.toggle_menu()
	city.select_hero("doctor")
	check(not paused and not city.menu_open and city.player.kit is DoctorKit,"city selection in spawn switches to doctor and resumes play")
	check(city.player.kit.ultimate_charge == 0,"city selection does not grant a free ultimate")
	city.player.kit.ultimate_charge = 73
	city.player.die()
	city.respawn_actor(city.player)
	check(city.player.kit is DoctorKit and city.player.kit.ultimate_charge == 73,"doctor respawns with selected kit and retained charge")
	check(city.player.benefits.effects.is_empty(),"city respawn clears old beneficial effects")
	arena.queue_free()
	await step(3)
	check(get_nodes_in_group("actors").is_empty() and get_nodes_in_group("barriers").is_empty(),"city exit leaves no actors or barriers")

func marshal_revision_tests() -> void:
	await reset()
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-12,.01,0)
	marshal.aim_direction = Vector3.FORWARD
	var m := marshal.kit as MarshalKit
	var t := marshal.tuning as MarshalTuning
	near(t.barrier_offset,1.6,"shield stands farther forward")
	near(t.verdict_range,16,"Verdict has sixteen-metre reach")
	near(m.barrier.frame().origin.z,-1.6,"visible shield and attack surface share the new offset")
	var camera_driver := PlayerController.new()
	camera_driver.actor = marshal
	marshal.add_child(camera_driver)
	marshal.state = "marshal_shield"
	for i: int in 45: camera_driver._process(1.0/60)
	near(camera_driver.arm.spring_length,4.2,"shielding smoothly pulls the camera back")
	near(camera_driver.camera.fov,82,"shield camera retains normal field of view")
	var wall: Node3D = Geometry.box(world,Vector3(8,6,.5),Vector3(0,3,2.5),Color.GRAY)
	await step(4)
	check(camera_driver.arm.get_hit_length() < camera_driver.arm.spring_length,"shield camera still retracts against nearby cover")
	wall.queue_free()
	marshal.state = "ready"
	for i: int in 45: camera_driver._process(1.0/60)
	near(camera_driver.arm.spring_length,camera_driver.camera_distance,"releasing shield returns to the ordinary shoulder distance")
	camera_driver.queue_free()
	await reset()
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-12,.01,0)
	enemy.position = Vector3(0,.01,-13)
	enemy.set_physics_process(true)
	await step(5)
	enemy.set_physics_process(false)
	marshal.aim_direction = Vector3.FORWARD
	marshal.intent.ultimate = true
	m.tick(0,marshal.intent)
	marshal.intent.ultimate = false
	near(m.ultimate_charge,0,"leap slam spends charge on commitment")
	var peak: float = 0
	var premature: bool = false
	for i: int in 90:
		if marshal.state == "marshal_verdict": m.move_override(1.0/60)
		peak = maxf(peak,marshal.position.y)
		if marshal.position.y > .1 and enemy.health < 250: premature = true
		await step(1)
	check(peak > 1.5,"Verdict physically leaps more than 1.5 metres")
	check(marshal.position.z < -5 and marshal.position.z >= -6.05,"Verdict leaps forward up to six metres")
	near(marshal.position.x,0,"Verdict retains its committed forward direction")
	near(marshal.velocity.length(),0,"landing stops movement during recovery",.1)
	check(not premature,"Verdict cannot apply its slam damage in the air")
	near(enemy.health,150,"landing hits a grounded enemy thirteen metres away")
	check(marshal.state == "marshal_recovery","landing enters explicit slam recovery")
	var impacts: int = 0
	for entry: Dictionary in resolver.events:
		if entry.event == "impact" and entry.ability == "marshals_verdict": impacts += 1
	check(impacts == 1,"leap produces exactly one landing impact")
	await reset()
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-12,.01,0)
	marshal.aim_direction = Vector3.FORWARD
	marshal.intent.ultimate = true
	m.tick(0,marshal.intent)
	for i: int in 22: m.move_override(1.0/60)
	check(marshal.position.y > .5,"leap is already airborne before interruption")
	marshal.close.stagger()
	check(marshal.state == "stagger" and m.verdict_warning == null,"stagger interrupts leap and removes its warning")
	near(m.ultimate_charge,0,"interrupted leap does not refund ultimate")
	await reset()
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-12,.01,0)
	var ceiling: Node3D = Geometry.box(world,Vector3(4,.4,4),Vector3(0,2.5,0),Color.GRAY)
	await step()
	marshal.aim_direction = Vector3.FORWARD
	marshal.intent.ultimate = true
	m.tick(0,marshal.intent)
	peak = 0
	for i: int in 100:
		if marshal.state == "marshal_verdict": m.move_override(1.0/60)
		peak = maxf(peak,marshal.position.y)
		await step(1)
	check(peak < .6 and marshal.state == "marshal_recovery","low ceiling truncates leap safely and still permits a landed slam")
	ceiling.queue_free()
	await reset()
	marshal.position = Vector3(0,12,0)
	doctor.position = Vector3(-12,.01,0)
	marshal.intent.ultimate = true
	m.tick(0,marshal.intent)
	marshal.reset_actor()
	check(marshal.state == "ready" and not m.verdict_launched and m.verdict_warning == null,"reset clears airborne slam state and warning")

func marshal_forward_tests() -> void:
	await reset()
	var m := marshal.kit as MarshalKit
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-12,.01,0)
	var wall: Node3D = Geometry.box(world,Vector3(10,8,.5),Vector3(0,4,-3),Color.GRAY)
	await step()
	marshal.aim_direction = Vector3.FORWARD
	marshal.intent.ultimate = true
	m.tick(0,marshal.intent)
	marshal.intent.ultimate = false
	for i: int in 90:
		if marshal.state == "marshal_verdict": m.move_override(1.0 / 60)
		await step(1)
	check(marshal.position.z > -2.8 and marshal.position.z < -1,"forward leap stops at solid walls")
	check(marshal.state == "marshal_recovery","blocked leap still slams on landing")
	wall.queue_free()
	var wave: AudioStreamWAV = ProceduralSound.marshal_slam()
	check(wave == ProceduralSound.marshal_slam(),"heavy slam audio is cached")
	near(wave.get_length(),.9,"heavy slam has a long rumbling tail")
	var peak_sample: int = 0
	for index: int in wave.data.size() / 2:
		peak_sample = maxi(peak_sample,absi(wave.data.decode_s16(index * 2)))
	check(peak_sample > 20000 and peak_sample < 32767,"slam sound has a strong unclipped transient")
	var effect := MarshalImpact.spawn(world,Vector3.ZERO)
	effect.set_process(false)
	effect._process(.3)
	check(effect.rings[0].scale.x > 4 and effect.rings.size() == 3,"landing expands multiple large shockwave rings")
	check(effect.debris.size() == 20,"landing throws visible debris")
	effect._process(1)
	await step()
	check(not is_instance_valid(effect),"landing effect expires cleanly")
