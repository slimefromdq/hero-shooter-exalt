extends "res://tests/care_heroes_test.gd"
## Real physics, authoritative damage/healing, and deterministic boundary checks.
var seeker: HeroActor
var k: RelayKit

func fresh() -> void:
	for node: Node in get_nodes_in_group("transient"): node.queue_free()
	seeker.reset_actor(Vector3(0,.01,0))
	friend.reset_actor(Vector3(0,.01,-8))
	second.reset_actor(Vector3(3,.01,-8))
	enemy.reset_actor(Vector3(0,.01,-16))
	marshal.reset_actor(Vector3(0,.01,-24))
	enemy.tuning.max_health = 5000
	enemy.health = 5000
	marshal.tuning.max_health = 5000
	marshal.health = 5000
	k = seeker.kit as RelayKit
	resolver.clear_round()
	aim(seeker,enemy)
	await step()

func arrow(amount: float = 60.0, index: int = -1, group: SeekerVolley = null) -> SeekerArrow:
	var shot := k.spawn_arrow(amount,index,group)
	shot.set_physics_process(false)
	return shot

func run() -> void:
	TrainingInputs.install()
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(200,1,200),Vector3(0,-.5,0),Color.GRAY)
	seeker = spawn("relay",0,Vector3.ZERO)
	friend = spawn("nimbus",0,Vector3(0,0,-8))
	second = spawn("doctor",0,Vector3(3,0,-8))
	enemy = spawn("nimbus",1,Vector3(0,0,-16))
	marshal = spawn("nimbus",1,Vector3(0,0,-24))
	await step(3)
	await healing_cases()
	await omen_cases()
	await arrow_cases()
	await projectile_edge_cases()
	await ultimate_cases()
	await movement_cases()
	await lifecycle_cases()
	world.queue_free()
	await step(3)
	print("RESULT: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/seeker-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)

func healing_cases() -> void:
	await fresh()
	check(HeroRoster.display_name("relay") == "Seeker" and HeroRoster.tuning_for("seeker").hero_id == "relay","visible rename and compatible alias")
	check(k.assign(friend),"assign visible teammate")
	friend.health = 10
	k.tick_spirit(.25)
	near(friend.health,10,"transfer delays healing")
	k.tick_spirit(1)
	near(friend.health,35,"passive healing has no resource cost")
	k.fire()
	check(k.shot_cd > 0 and k.recipient == friend and k.ammo == 1,"infinite arrows and passive bird coexist")
	k.start_reload()
	check(not k.reloading,"bow never reloads")
	var wall := Geometry.box(world,Vector3(6,4,.5),Vector3(0,2,-4),Color.GRAY)
	await step()
	k.tick_spirit(4.9)
	near(friend.health,157.5,"heals through first 4.9 seconds of occlusion")
	check(k.recipient == friend,"grace retains assignment")
	wall.queue_free()
	await step()
	k.tick_spirit(.1)
	near(k.sight_lost,0,"regaining sight resets grace")
	wall = Geometry.box(world,Vector3(6,4,.5),Vector3(0,2,-4),Color.GRAY)
	await step()
	friend.health = 10
	k.tick_spirit(6)
	near(friend.health,135,"large timestep heals exactly five seconds behind cover")
	check(k.recipient == null,"five seconds of continuous sight loss returns bird")
	wall.queue_free()
	await step()
	k.transfer_cd = 0
	check(k.assign(friend),"reassign after return")
	k.transfer_left = 0
	friend.position.z = -65
	await step()
	k.tick_spirit(.1)
	check(k.recipient == friend,"65m boundary is valid")
	friend.position.z = -65.01
	await step()
	var hp := friend.health
	k.tick_spirit(.1)
	near(friend.health,hp,"range violation grants no grace healing")
	check(k.recipient == null,"range violation returns immediately")
	k.transfer_cd = 0
	check(k.assign(seeker),"self assignment permitted")
	k.transfer_left = 0
	seeker.health = 40
	check(k.guiding_wing(),"Wing accepts assigned self")
	near(seeker.health,100,"Wing heals sixty")
	near(seeker.benefits.speed_multiplier(),1.3,"Wing grants thirty percent speed")
	check(not k.guiding_wing(),"Wing has real cooldown")
	seeker.benefits.tick(2)
	near(seeker.benefits.speed_multiplier(),1,"Wing speed expires")
	k.recall()
	k.deflect_cd = 0
	check(not k.guiding_wing() and k.deflect_cd == 0,"invalid Wing spends no cooldown")
	await fresh()
	k.assign(friend)
	k.transfer_left = 0
	wall = Geometry.box(world,Vector3(6,4,.5),Vector3(0,2,-4),Color.GRAY)
	await step()
	check(not k.guiding_wing(),"Wing requires current sight even within passive grace")
	wall.queue_free()
	await step()

func omen_cases() -> void:
	await fresh()
	check(k.cast_omen(),"Omen marks aimed visible enemy")
	near(k.omen_left,6,"Omen lasts six seconds")
	near(k.mobility_cd,12,"Omen cooldown is twelve seconds")
	k.assign(friend)
	check(k.reveals(enemy,seeker) and k.reveals(enemy,friend) and not k.reveals(enemy,second),"reveal restricted to Seeker and main recipient")
	resolver.damage(seeker,enemy,100,"melee",resolver.new_cast(seeker))
	near(enemy.health,4880,"Omen boosts all Seeker damage twenty percent")
	resolver.damage(second,enemy,100,"projectile",resolver.new_cast(second))
	near(enemy.health,4780,"Omen does not boost teammates")
	k.transfer_cd = 0
	k.assign(second)
	check(not k.reveals(enemy,friend) and k.reveals(enemy,second),"reassignment transfers reveal permission")
	k.tick(5.99,CombatIntent.new())
	check(k.reveals(enemy,seeker),"reveal lasts through final fraction of Omen")
	k.tick(.01,CombatIntent.new())
	check(not k.reveals(enemy,seeker) and k.omen_target == null,"Omen and reveal expire exactly")
	k.mobility_cd = 0
	seeker.aim_direction = Vector3.UP
	check(not k.cast_omen() and k.mobility_cd == 0,"Omen miss spends no cooldown")
	aim(seeker,enemy)
	k.cast_omen()
	enemy.reset_actor()
	check(not k.valid_omen(),"target respawn invalidates Omen immediately")

func arrow_cases() -> void:
	await fresh()
	var shot := arrow()
	shot._physics_process(.3)
	near(enemy.health,4940,"primary projectile body hit deals sixty")
	await fresh()
	shot = arrow()
	shot.global_position = Vector3(0,1.75,-14)
	shot.direction = Vector3.FORWARD
	shot._physics_process(.05)
	near(enemy.health,4895,"arrow headshot is 1.75x")
	await fresh()
	var input := CombatIntent.new()
	input.secondary_pressed = true
	input.secondary_held = true
	k.tick(.5,input)
	check(k.volley_charging,"secondary begins charge")
	k.fire()
	check(get_nodes_in_group("owned_attacks").is_empty(),"charging prevents primary")
	k.tick(.5,input)
	k.tick(0,CombatIntent.new())
	var shots: Array[Node] = get_nodes_in_group("owned_attacks")
	check(shots.size() == 5,"full volley releases exactly five arrows")
	var central: SeekerArrow
	for node: Node in shots:
		var a := node as SeekerArrow
		a.set_physics_process(false)
		near(a.damage_amount,28,"full-charge arrow damage")
		if a.orbit_index < 0: central = a
	check(central != null,"volley has one central arrow")
	var outer: SeekerArrow = shots[1] as SeekerArrow
	near((outer.global_position-central.global_position).dot(central.direction),-.6,"outer arrow trails central by 0.6m")
	var p0 := outer.orbit_point(0)
	var p1 := outer.orbit_point(.125)
	check(absf((p1-p0).dot(outer.right)) > .1,"outer arrow follows a changing spiral")
	central._physics_process(.3)
	check(central.volley.locked and central.volley.patient() == enemy,"central confirmed hit locks volley")
	for node: Node in shots:
		if node != central: (node as SeekerArrow)._physics_process(.4)
	near(enemy.health,4860,"all five volley arrows converge for 140 body damage")
	await fresh()
	var group := SeekerVolley.new()
	shot = arrow(22,0,group)
	group.acquire(enemy)
	enemy.reset_actor()
	shot._physics_process(.02)
	check(shot.homing_lost,"homing invalidation continues without reacquisition")
	await fresh()
	k.volley_age = 1
	k.release_volley()
	shots = get_nodes_in_group("owned_attacks")
	for node: Node in shots: node.set_physics_process(false)
	var wall := Geometry.box(world,Vector3(6,4,.1),Vector3(0,2,-6),Color.GRAY)
	await step()
	for node: Node in shots: (node as SeekerArrow)._physics_process(.3)
	near(enemy.health,5000,"cover intercepts central and orbiting arrows")
	check(not (shots[0] as SeekerArrow).volley.locked,"wall impact does not unlock homing")
	wall.queue_free()
	await step()
	await fresh()
	input = CombatIntent.new()
	input.secondary_pressed = true
	input.secondary_held = true
	k.tick(.1,input)
	k.tick(0,CombatIntent.new())
	check(get_nodes_in_group("owned_attacks").is_empty(),"early charge release cancels")
	k.tick(.4,input)
	k.cancel()
	check(not k.volley_charging,"interruption cancels charge")

func ultimate_cases() -> void:
	await fresh()
	k.assign(friend)
	k.transfer_left = 0
	friend.health = 20
	second.health = 30
	seeker.health = 40
	k.murmuration_left = 10
	k.ultimate_charge = 0
	k.update_extras()
	check(k.extras.size() == 2 and k.birds.size() == 3,"Murmuration creates two extra birds")
	check(k.extras[0].target != friend and k.extras[1].target != friend and k.extras[0].target != k.extras[1].target,"three healing recipients are distinct")
	k.tick_spirit(1)
	near(friend.health,53.75,"main bird receives 35 percent healing boost")
	near(second.health,63.75,"automatic bird heals second ally")
	near(seeker.health,73.75,"automatic bird can heal Seeker")
	near(k.ultimate_charge,0,"ultimate healing cannot charge next ultimate")
	k.transfer_cd = 0
	k.assign(second)
	check(k.extras[0].target != second and k.extras[1].target != second,"main reassignment moves conflicting automatic bird")
	# Isolate piercing from swoops by returning all birds to non-healing orbits.
	k.recall()
	k.extras.clear()
	var shot := arrow()
	shot._physics_process(.4)
	near(enemy.health,4940,"piercing first enemy takes full damage")
	near(marshal.health,4940,"piercing second enemy takes full damage")
	shot._physics_process(.1)
	near(enemy.health,4940,"piercing never repeats damage to an actor")
	await fresh()
	k.assign(friend)
	k.transfer_left = 0
	k.murmuration_left = 10
	k.update_extras()
	seeker.position = Vector3(0,.01,-7)
	second.position = Vector3(3,.01,-8)
	await step()
	k.arrow_hit(enemy)
	k.arrow_hit(enemy)
	near(enemy.health,4850,"each hit triggers three 25-damage swoops without cooldown")
	check(k.swoop_flashes.size() == 6,"every eligible swoop has feedback")
	var charge := k.ultimate_charge
	k.murmuration_left = .1
	k.tick_spirit(.2)
	check(k.extras.is_empty() and k.birds.size() == 1,"expiration removes automatic channels and meshes")
	check(k.swoop_flashes.is_empty(),"expiration clears pending swoop visuals")
	var hp := enemy.health
	k.arrow_hit(enemy)
	near(enemy.health,hp,"post-expiration hit cannot swoop")
	near(k.ultimate_charge,charge,"swoops and ultimate healing do not recharge ultimate")
	await fresh()
	k.assign(friend)
	k.transfer_left = 0
	k.murmuration_left = 10
	k.update_extras()
	var removed: HeroActor = spawn("nimbus",0,Vector3(4,.01,-8))
	removed.health = 1
	k.extras.clear()
	k.update_extras()
	check(k.extras[0].target == removed,"automatic bird prioritizes most injured candidate")
	removed.queue_free()
	await step()
	k.tick(.1,CombatIntent.new())
	check(k.extras[0].target != removed and k.birds.size() == 3,"freed automatic recipient safely transfers without companion duplication")
	# Restore the fixture if this automatic slot selected one of the named allies.
	if not is_instance_valid(second): second = spawn("doctor",0,Vector3(3,.01,-8))
	if not is_instance_valid(friend): friend = spawn("nimbus",0,Vector3(0,.01,-8))

func projectile_edge_cases() -> void:
	for fps: int in [30,60,144]:
		await fresh()
		var input := CombatIntent.new()
		input.primary_held = true
		for frame: int in fps: k.tick(1.0/fps,input)
		var count: int = 0
		for node: Node in get_nodes_in_group("owned_attacks"):
			if node is SeekerArrow:
				count += 1
				node.set_physics_process(false)
		check(count == 2 and k.ammo == 1,"0.8s infinite bow cadence at %d FPS" % fps)
	await fresh()
	var group := SeekerVolley.new()
	var shot := arrow(22,0,group)
	var wall := Geometry.box(world,Vector3(.14,.14,.14),shot.orbit_point(.02),Color.GRAY)
	await step()
	shot._physics_process(.04)
	check(shot.is_queued_for_deletion(),"outer arrow collides along actual curved path")
	check(not group.locked,"outer collision cannot acquire central lock")
	wall.queue_free()
	await step()
	await fresh()
	# Refill is a training command and must retire automatic birds immediately.
	k.murmuration_left = 10
	k.update_extras()
	k.refill()
	check(k.birds.size() == 1 and k.extras.is_empty(),"refill immediately removes automatic birds and channels")
	await fresh()
	enemy.state = "deflect"
	enemy.aim_direction = Vector3.BACK
	group = SeekerVolley.new()
	shot = arrow(22,-1,group)
	shot.piercing = true
	shot._physics_process(.2)
	check(shot.source == enemy and shot.reflections == 1,"Seeker arrow uses ordinary deflection")
	check(shot.kit == null and shot.volley == null and not shot.piercing,"deflection clears homing, piercing and offensive callbacks")
	check(not group.locked,"deflected central arrow never acquires lock")
	await fresh()
	enemy.invulnerable = true
	group = SeekerVolley.new()
	shot = arrow(22,-1,group)
	shot._physics_process(.3)
	check(not group.locked,"immune central impact never acquires lock")
	await fresh()
	k.murmuration_left = 10
	var additional: Array[HeroActor] = []
	for z: float in [-32.0,-40.0,-48.0]:
		additional.append(spawn("nimbus",1,Vector3(0,.01,z)))
	await step()
	shot = arrow()
	shot.direction = Vector3.FORWARD
	shot.initialize(Vector3(0,1.2,0))
	shot._physics_process(.6)
	near(enemy.health,4940,"unlimited piercing preserves first target damage")
	near(marshal.health,4940,"unlimited piercing preserves second target damage")
	for other: HeroActor in additional:
		near(other.health,other.tuning.max_health-60,"piercing continues beyond two enemies at full damage")
		other.queue_free()
	await step()
	await fresh()
	k.murmuration_left = 10
	shot = arrow()
	k.murmuration_left = .01
	k.tick_spirit(.02)
	check(shot.piercing,"launched arrow retains piercing after ultimate expiration")
	var charge := k.ultimate_charge
	shot._physics_process(.4)
	near(enemy.health,4940,"late ultimate arrow deals ordinary damage without swoops")
	near(k.ultimate_charge,charge,"ultimate cast snapshot prevents late damage recharge")
	await fresh()
	k.murmuration_left = 10
	shot = arrow()
	wall = Geometry.box(world,Vector3(6,4,.1),Vector3(0,2,-20),Color.GRAY)
	await step()
	shot._physics_process(.4)
	near(enemy.health,4940,"piercing hits enemy before wall")
	near(marshal.health,5000,"world cover stops unlimited piercing")
	wall.queue_free()
	await step()

func movement_cases() -> void:
	await fresh()
	seeker.position.y = 4
	seeker.motor.coyote = 0
	await step()
	var input := CombatIntent.new()
	input.jump = true
	input.jump_held = true
	seeker.motor.tick(.01,input)
	check(k.jump_used and k.bomb_cd == 5,"fresh airborne Space triggers five-second spirit jump")
	check(seeker.velocity.y > 10,"spirit jump has upward impulse")
	k.bomb_cd = 0
	seeker.velocity.y = -2
	seeker.motor.tick(.01,input)
	check(seeker.velocity.y < 0,"only one spirit jump per airtime")
	input.jump = false
	k.jump_used = false
	seeker.motor.tick(.01,input)
	check(not k.jump_used,"holding jump never activates spirit jump")
	seeker.statuses.effects.root = {"remaining":1.0,"strength":0.0}
	input.jump = true
	seeker.motor.tick(.01,input)
	check(not k.jump_used,"root prevents spirit jump")

func lifecycle_cases() -> void:
	await fresh()
	k.assign(friend)
	friend.reset_actor()
	k.tick_spirit(.1)
	check(k.recipient == null,"recipient respawn detaches bird")
	k.transfer_cd = 0
	k.assign(friend)
	friend.team = 1
	k.tick_spirit(.1)
	check(k.recipient == null,"team change detaches bird")
	friend.team = 0
	k.transfer_cd = 0
	k.assign(friend)
	friend.spawn_protected = true
	k.tick_spirit(.1)
	check(k.recipient == null,"protected room detaches bird")
	friend.spawn_protected = false
	k.transfer_cd = 0
	k.assign(friend)
	k.murmuration_left = 10
	k.update_extras()
	seeker.die()
	check(k.recipient == null and k.extras.is_empty() and k.birds.is_empty() and k.omen_target == null,"owner death clears all companion and mark state")
	seeker.reset_actor(Vector3.ZERO)
	k.tick(0,CombatIntent.new())
	check(k.birds.size() == 1 and k.recipient == null and not k.jump_used,"respawn creates one clean companion")
	k.murmuration_left = 10
	k.update_extras()
	seeker.select_hero("doctor")
	check(k.birds.is_empty() and k.extras.is_empty(),"hero switch clears old companion state synchronously")
	await step()
	seeker.select_hero("relay")
	k = seeker.kit as RelayKit
	var removed := spawn("nimbus",0,Vector3(0,0,-5))
	k.assign(removed)
	removed.queue_free()
	await step()
	k.tick_spirit(.1)
	check(k.recipient == null,"removed recipient is safely detached")
