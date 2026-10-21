extends "res://tests/care_heroes_test.gd"
var s: HeroActor
var k: SamsonKit

func setup() -> void:
	for actor: HeroActor in [s,friend,enemy,marshal]:
		actor.reset_actor(actor.spawn_position)
		actor.set_physics_process(false)
	k = s.kit as SamsonKit
	aim(s,friend)
	await step()

func tick_cast(delta: float, count: int) -> void:
	for i: int in count:
		k.tick(delta,CombatIntent.new())
		k.move_override(delta)

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(100,1,100),Vector3(0,-.5,0),Color.GRAY)
	s = spawn("samson",0,Vector3(0,.01,0))
	friend = spawn("nimbus",0,Vector3(0,.01,-8))
	enemy = spawn("wisp",1,Vector3(3,.01,-9))
	marshal = spawn("doctor",0,Vector3(18,.01,0))
	k = s.kit as SamsonKit
	await step()
	check(k != null and s.health == 250,"Samson loads Support tuning and kit")
	check(HeroRoster.role_for("samson") == "support","Samson is registered as Support")
	for id: String in HeroRoster.IDS:
		var composition: Array[String] = HeroRoster.composition_for(id)
		var roles: Dictionary = {"tank":0,"support":0,"dps":0}
		for hero: String in composition: roles[HeroRoster.role_for(hero)] += 1
		check(composition[0] == id and roles.tank == 2 and roles.support == 2 and roles.dps == 2,"2/2/2 composition retains selected " + id)
	await intervene_tests()
	await cross_tests()
	await notice_tests()
	await court_tests()
	await weapon_and_lifecycle_tests()
	world.queue_free()
	await step()
	print("SAMSON RESULT: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/samson-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)

func intervene_tests() -> void:
	await setup()
	check(k.charges == 2 and s.motor.dash_charges == 2,"rescue and shared dash charges are independent")
	check(not k.start_intervene(null) and not k.start_intervene(enemy) and not k.start_intervene(s),"invalid/null/enemy/self rescue targets rejected")
	friend.position.z = -23
	check(not k.start_intervene(friend) and k.charges == 2,"out-of-range rescue spends nothing")
	friend.position.z = -8
	friend.spawn_protected = true
	check(not k.start_intervene(friend),"rescue rejects protected target")
	friend.spawn_protected = false
	var wall: Node3D = Geometry.box(world,Vector3(5,3,.2),Vector3(0,1,-4),Color.GRAY)
	await step()
	check(not k.start_intervene(friend) and k.charges == 2,"covered rescue spends no charge")
	wall.queue_free()
	await step()
	friend.health = 100
	check(k.start_intervene(friend) and k.charges == 1,"valid rescue spends exactly one charge")
	check(not s.permits("primary") and not s.permits("dash"),"rescue commits combat and movement")
	tick_cast(1.0/60,40)
	near(friend.health,156.875,"arrival heals selected ally")
	near(friend.overhealth.value(),60,"arrival grants ally overhealth")
	near(s.overhealth.value(),30,"arrival grants smaller self overhealth")
	check(enemy.motor.external_velocity.length() > 0,"arrival peels nearby enemy")
	tick_cast(1.0/60,10)
	near(friend.health,156.875,"arrival does not repeat every tick")
	check(k.start_intervene(friend) and k.charges == 0,"second charge can rescue already-close ally")
	near(friend.health,213.75,"close rescue resolves once immediately")
	near(k.recharge,8-50.0/60,"second cast retains first charge recharge clock")
	k.tick(k.recharge,CombatIntent.new())
	check(k.charges == 1,"first recharge returns one charge")
	near(k.recharge,8,"next sequential recharge starts at eight seconds")
	k.tick(8,CombatIntent.new())
	check(k.charges == 2 and k.recharge == 0,"both charges recover sequentially")
	await setup()
	check(k.start_intervene(friend),"target invalidation fixture launches")
	friend.die()
	k.move_override(.01)
	check(k.charges == 1 and s.state == "ready" and s.overhealth.value() == 0,"target death aborts without refund or arrival")
	await setup()
	k.start_intervene(friend)
	friend.reset_actor(friend.position)
	k.move_override(.01)
	check(s.state == "ready" and k.charges == 1,"same actor respawn invalidates rescue life")
	await setup()
	k.start_intervene(friend)
	wall = Geometry.box(world,Vector3(5,3,.2),Vector3(0,1,-4),Color.GRAY)
	await step()
	k.move_override(.1)
	check(s.state == "ready" and friend.overhealth.value() == 0,"new obstruction aborts rescue without teleport")
	wall.queue_free()
	await step()
	await setup()
	var temporary_ally: HeroActor = spawn("nimbus",0,Vector3(0,.01,-6))
	await step()
	k.start_intervene(temporary_ally)
	temporary_ally.queue_free()
	await step()
	k.move_override(.01)
	check(s.state == "ready" and k.charges == 1,"despawned rescue target aborts safely without a stale typed-reference error")
	for hz: int in [30,60,144]:
		await setup()
		k.start_intervene(friend)
		tick_cast(1.0/hz,hz)
		check(s.state == "ready" and k.charges == 1 and absf(s.position.distance_to(friend.position)-1.5) < .01,"rescue arrival stable at %d Hz" % hz)

func cross_tests() -> void:
	await setup()
	aim(s,enemy)
	check(k.aimed_enemy() == enemy,"cross targets visible hostile hero")
	check(k.start_cross(enemy),"cross acquires and begins cooldown")
	k.tick(1.49,CombatIntent.new())
	check(not enemy.statuses.stunned(),"cross does not resolve early")
	k.tick(.01,CombatIntent.new())
	check(enemy.statuses.stunned() and enemy.statuses.silenced(),"cross completes after exactly 1.5 seconds")
	near(enemy.statuses.effects.silence.remaining,3.1,"silence includes stun plus 2.5 further seconds")
	enemy.statuses.tick(.6)
	check(not enemy.statuses.stunned() and enemy.statuses.silenced(),"stun expires before silence")
	near(enemy.statuses.effects.silence.remaining,2.5,"full 2.5-second silence remains after stun")
	enemy.statuses.cleanse()
	check(not enemy.statuses.silenced(),"cleanse clears silence without deferred reapplication")
	await setup()
	k.start_cross(enemy)
	var wall: Node3D = Geometry.box(world,Vector3(14,4,.2),Vector3(0,1,-4),Color.GRAY)
	await step()
	k.tick(2,CombatIntent.new())
	check(s.state == "ready" and not enemy.statuses.stunned() and not enemy.statuses.silenced(),"broken LOS cancels without applying any disable")
	wall.queue_free()
	await step()
	await setup()
	k.start_cross(enemy)
	var cancel_input := CombatIntent.new()
	cancel_input.deflect = true
	k.tick(.1,cancel_input)
	check(s.state == "ready" and k.deflect_cd > 0,"second E cancels with cooldown committed")
	await setup()
	k.start_cross(enemy)
	s.statuses.apply("stun",enemy,.6)
	k.tick(2,CombatIntent.new())
	check(s.state == "ready" and not enemy.statuses.stunned(),"hard stun interrupts channel safely")
	for id: String in HeroRoster.IDS:
		await setup()
		enemy.select_hero(id)
		enemy.statuses.apply("silence",s,2.5)
		check(not enemy.permits("dash") and not enemy.permits("ultimate") and not enemy.permits("deflect") and not enemy.permits("bomb"),"silence blocks casts and dash on " + id)
		check(enemy.permits("primary") and enemy.permits("reload") and enemy.permits("jump") and enemy.permits("melee"),"silence preserves ordinary combat on " + id)
		check(not enemy.statuses.permits("barrier") and not enemy.statuses.permits("assign") and not enemy.statuses.permits("regroup") and not enemy.statuses.permits("care_beam"),"silence blocks nonweapon RMB starts on " + id)
	await setup()
	s.intent.move = Vector3.RIGHT
	s.intent.aim = Vector3.FORWARD
	s.motor.tick(.2,s.intent)
	s.motor.tick(.2,s.intent)
	var ready_speed: float = s.velocity.x
	s.position = s.spawn_position
	s.velocity = Vector3.ZERO
	s.motor.interrupt_mobility()
	k.start_cross(enemy)
	s.motor.tick(.2,s.intent)
	near(s.velocity.x,ready_speed,"channel has no hidden movement-speed penalty",.1)
	await setup()
	k.start_cross(enemy)
	s.intent.melee = true
	s._physics_process(.01)
	check(s.state.begins_with("melee_"),"shared melee press cancels channel and executes in the same actor tick")
	await setup()
	var temporary_enemy: HeroActor = spawn("nimbus",1,Vector3(3,.01,-6))
	await step()
	k.start_cross(temporary_enemy)
	temporary_enemy.queue_free()
	await step()
	k.tick(2,CombatIntent.new())
	check(s.state == "ready" and k.deflect_cd > 0,"despawned defendant cancels without applying disables or throwing a script error")

func make_notice(at: Vector3 = Vector3(0,0,-8)) -> SamsonNotice:
	var n := SamsonNotice.new()
	n.source = s
	n.position = at
	world.add_child(n)
	n.set_physics_process(false)
	k.notice = n
	return n

func notice_tests() -> void:
	await setup()
	var n: SamsonNotice = make_notice()
	enemy.position = Vector3(0,.01,-8)
	await step()
	check(enemy.permits("dash"),"notice telegraph does not disable early")
	n._physics_process(.2)
	check(not enemy.permits("dash") and not enemy.permits("step") and not enemy.permits("lift"),"armed notice blocks movement starts for an enemy already inside")
	near(enemy.statuses.movement_scale(),.7,"notice slows ordinary movement by thirty percent")
	check(enemy.permits("jump") and enemy.permits("primary"),"notice preserves jumping and weapons")
	enemy.statuses.cleanse()
	check(not enemy.permits("dash"),"cleanse cannot bypass live zone membership")
	enemy.position.x = k.data().notice_width/2
	check(not enemy.permits("dash"),"notice includes configured width boundary")
	enemy.position.x = k.data().notice_width/2+.01
	check(enemy.permits("dash") and enemy.statuses.movement_scale() == 1,"zone exit removes both restrictions immediately")
	enemy.position = Vector3(0,2,-8)
	check(enemy.permits("dash"),"vertical avoidance remains available")
	enemy.position = Vector3(0,.01,-8)
	enemy.motor.mode = "dash"
	enemy.motor.timer = .3
	enemy.motor.dash_direction = Vector3.RIGHT
	enemy.motor.dash_current_speed = 20
	enemy.motor.tick(.01,CombatIntent.new())
	check(enemy.motor.mode == "dash" and enemy.velocity.x > 19,"entering zone preserves committed dash travel")
	var second_notice: SamsonNotice = make_notice(Vector3(1,0,-8))
	second_notice._physics_process(.2)
	n.retire()
	enemy.motor.interrupt_mobility()
	enemy.position = Vector3(0,.01,-8)
	check(not enemy.permits("dash"),"overlapping zone continues after first is retired")
	near(enemy.statuses.movement_scale(),.7,"overlapping slows do not stack")
	second_notice.receive_damage(enemy,120,resolver.new_cast(enemy))
	check(enemy.permits("dash"),"destroyed notice stops restriction in same tick")
	await setup()
	n = make_notice()
	n._physics_process(6.2)
	check(not n.active(),"notice expires after arming plus six active seconds")

func make_court(at: Vector3 = Vector3(0,0,-5)) -> SamsonCourt:
	var c := SamsonCourt.new()
	c.source = s
	c.position = at
	world.add_child(c)
	c.set_physics_process(false)
	k.court = c
	return c

func court_tests() -> void:
	await setup()
	check(SamsonCourt.placement_clear(s,Vector3(0,0,-5),0),"court accepts supported clear footprint")
	check(not SamsonCourt.placement_clear(s,Vector3(0,0,0),0),"court rejects overlapping actor footprint")
	check(not SamsonCourt.placement_clear(s,Vector3(70,0,0),0),"court rejects unsupported ground")
	var c: SamsonCourt = make_court()
	await step()
	near(c.health,750,"court has 750 durability")
	s.position = Vector3(0,.01,-2)
	await step()
	var detour: Vector3 = StructureAvoidance.steer(s,Vector3.FORWARD,Vector3(0,0,-10))
	check(absf(detour.x) > .1,"bots choose a checked detour around court cover")
	s.position = s.spawn_position
	near(friend.overhealth.value(),75,"court grants first witness shield")
	near(friend.benefits.reduction(),.25,"court grants live damage reduction")
	check(not resolver.ray(Vector3(0,1,-2),Vector3(0,1,-8),[],1).is_empty(),"court supplies physical projectile cover")
	friend.position = Vector3(k.data().court_radius,0,-5)
	check(c.qualifies(friend),"court includes configured radius boundary")
	friend.position.x = k.data().court_radius+.01
	near(friend.benefits.reduction(),0,"court exit removes reduction immediately")
	friend.position = Vector3(2,2.01,-5)
	check(not c.qualifies(friend),"court does not protect another vertical level")
	friend.position = Vector3(0,.01,-8)
	friend.overhealth.absorb(75)
	c.update_witnesses()
	near(friend.overhealth.value(),0,"witness shield cannot repeat every frame or re-entry")
	friend.benefits.grant("prescription",marshal,1,.7)
	near(friend.benefits.reduction(),.7,"court and Doctor use strongest reduction without addition")
	friend.benefits.clear()
	check(friend.overhealth.grant(s,60,3,"intervene","intervene"),"Intervene slot is independent of court slot")
	near(friend.overhealth.value(),60,"independent shield slots do not add")
	check(not friend.overhealth.grant(s,60,3,"intervene","intervene"),"live Intervene slot cannot refresh")
	var wall: Node3D = Geometry.box(world,Vector3(6,4,.2),Vector3(0,1,-6.5),Color.GRAY)
	await step()
	near(friend.benefits.reduction(),0,"world cover blocks court eligibility")
	wall.queue_free()
	await step()
	c.receive_damage(enemy,750,resolver.new_cast(enemy))
	near(friend.benefits.reduction(),0,"destroyed court removes reduction immediately")
	near(friend.overhealth.value(),60,"destroyed court retains already-granted shield duration")
	await setup()
	c = make_court()
	k.ultimate_charge = 0
	k.tick(1,CombatIntent.new())
	near(k.ultimate_charge,0,"active court suppresses passive ultimate charge")
	c._physics_process(8)
	check(not c.active(),"court expires after eight seconds")

func weapon_and_lifecycle_tests() -> void:
	await setup()
	enemy.position = Vector3(0,.01,-12)
	friend.position.x = 10
	aim(s,enemy)
	k.fire()
	await step(20)
	check(enemy.health < enemy.tuning.max_health and k.ammo == 23,"Deposition resolves real projectile damage and ammunition")
	await setup()
	var n: SamsonNotice = make_notice()
	var c: SamsonCourt = make_court()
	friend.overhealth.grant(s,60,3,"intervene","intervene")
	s.die()
	check(not n.active() and not c.active() and friend.overhealth.value() == 0,"owner death clears zones, court and every owned shield slot")
	await step()
	s.reset_actor(s.spawn_position)
	check(k.charges == 2 and k.ammo == 24 and s.statuses.effects.is_empty(),"respawn restores clean Samson resources")
	check(CareHUD.detail(s).contains("2/2") and CareHUD.ultimate_label(s) == "ROACH COURT","HUD exposes rescue charges and court")
