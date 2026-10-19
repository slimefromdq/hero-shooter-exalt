extends SceneTree
var world: Node3D
var resolver: CombatResolver
var relay: HeroActor
var dynamo: HeroActor
var wisp: HeroActor
var friend: HeroActor
var foes: Array[HeroActor] = []
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if value else "FAIL  ",caption)
	if not value: failures.append(caption)

func near(value: float, expected: float, caption: String, tolerance: float = .06) -> void:
	check(absf(value-expected) <= tolerance,caption+" [%.3f / %.3f]" % [value,expected])

func step(count: int = 2) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func spawn(id: String, team: int, at: Vector3) -> HeroActor:
	var a := HeroActor.new()
	a.tuning = HeroRoster.tuning_for(id)
	a.actor_id = id
	a.team = team
	a.position = at
	world.add_child(a)
	a.set_physics_process(false)
	return a

func aim(a: HeroActor, point: Vector3) -> void:
	a.intent = CombatIntent.new()
	a.intent.aim_origin = a.body_point(1.2)
	a.aim_direction = (point-a.intent.aim_origin).normalized()
	a.intent.aim = a.aim_direction
	a.rotation.y = atan2(-a.aim_direction.x,-a.aim_direction.z)

func reset() -> void:
	for node: Node in get_nodes_in_group("transient"): node.queue_free()
	relay.reset_actor(Vector3(0,.01,0))
	dynamo.reset_actor(Vector3(20,.01,0))
	wisp.reset_actor(Vector3(-20,.01,0))
	friend.reset_actor(Vector3(0,.01,-8))
	for i: int in foes.size():
		foes[i].select_hero("nimbus")
		foes[i].reset_actor(Vector3(3*i,.01,-16))
		foes[i].tuning.max_health = 2000
		foes[i].health = 2000
	for a: HeroActor in [relay,dynamo,wisp,friend]+foes:
		a.set_physics_process(false)
		a.spawn_protected = false
		a.invulnerable = false
		aim(a,a.global_position+Vector3.FORWARD*20+Vector3.UP*1.2)
	resolver.clear_round()
	await step()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(140,1,140),Vector3(0,-.5,0),Color.GRAY)
	relay = spawn("relay",0,Vector3.ZERO)
	dynamo = spawn("dynamo",0,Vector3(20,0,0))
	wisp = spawn("wisp",0,Vector3(-20,0,0))
	friend = spawn("nimbus",0,Vector3(0,0,-8))
	for i: int in 3: foes.append(spawn("nimbus",1,Vector3(i*3,0,-16)))
	await step(4)
	await relay_tests()
	await dynamo_tests()
	await wall_tests()
	await wisp_tests()
	await timing_and_cover_tests()
	await lifecycle_tests()
	world.queue_free()
	await step(3)
	await scene_tests()
	print("RESULT: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/roster-expansion-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)

func relay_tests() -> void:
	await reset()
	var k := relay.kit as RelayKit
	check(relay.health == 250 and dynamo.health == 650 and wisp.health == 225,"new hero health defaults")
	check(k.assign(friend),"assign visible ally")
	friend.health = 50
	k.tick(.25,CombatIntent.new())
	near(friend.health,50,"transfer has a healing gap")
	k.tick(1,CombatIntent.new())
	near(friend.health,105,"drone heals 55 HP/s")
	near(k.battery,90,"attached drone drains ten energy per second")
	var block: Node3D = Geometry.box(world,Vector3(5,4,1),Vector3(0,2,-4),Color.GRAY)
	await step()
	k.tick(1,CombatIntent.new())
	near(friend.health,160,"attachment heals through solid cover")
	friend.position = Vector3(0,.01,-60)
	k.tick(1,CombatIntent.new())
	near(friend.health,215,"attachment persists beyond assignment range")
	check(not k.assign(foes[0]) and k.recipient == friend,"invalid enemy assignment preserves recipient")
	check(not k.assign(relay) and k.recipient == friend,"self transfer still observes shared transfer cooldown") if k.transfer_cd > 0 else check(true,"assignment cooldown expires normally")
	k.recall()
	k.tick(1,CombatIntent.new())
	near(k.battery,90,"docking recharges twenty energy per second")
	k.transfer_cd = 0
	check(k.assign(relay),"self attachment shares the drone")
	k.transfer_left = 0
	relay.health = 100
	k.tick(1,CombatIntent.new())
	near(relay.health,155,"self attachment heals at the same rate")
	k.battery = 5
	k.tick(.5,CombatIntent.new())
	check(k.recipient == null,"depletion automatically recalls")
	near(k.battery,0,"depletion does not overspend energy")
	check(not k.assign(friend),"empty battery cannot deploy")
	k.battery = 100
	k.transfer_cd = 0
	check(k.assign(relay),"battery recovery permits redeployment")
	relay.spawn_protected = true
	var docking := CombatIntent.new()
	docking.bomb = true
	k.tick(0,docking)
	check(k.recipient == null,"returning to a safe room still permits docking")
	check(not k.assign(relay),"safe rooms still prohibit healing deployment")
	relay.spawn_protected = false
	block.queue_free()
	await step()
	await reset()
	k = relay.kit as RelayKit
	foes[0].position = Vector3(5,.01,0)
	var request := CombatIntent.new()
	request.deflect = true
	k.tick(0,request)
	near(foes[0].health,1940,"Shock Delivery reaches a target beyond the former four-meter radius")
	near(k.battery,80,"shock costs twenty battery")
	await reset()
	k = relay.kit as RelayKit
	friend.health = 50
	k.battery = 0
	request = CombatIntent.new()
	request.ultimate = true
	k.tick(0,request)
	check(relay.state == "relay_circuit_start" and k.ultimate_charge == 100,"circuit preparation retains charge")
	relay.state_time = 0
	k.tick(0,CombatIntent.new())
	check(k.ultimate_active() and k.ultimate_charge == 0,"circuit begins at empty battery")
	k.tick(.5,CombatIntent.new())
	near(friend.health,90,"Full Circuit heals eighty HP per second")
	near(k.battery,0,"ultimate freezes battery")
	near(friend.benefits.fire_rate_multiplier(),1.25,"overclock grants twenty-five percent primary haste")
	near(friend.kit.primary_interval(),friend.tuning.shot_interval/1.25,"shared primary interval applies haste")
	near(k.ultimate_charge,0,"ultimate healing and passive ticks cannot recharge itself")
	check(k.assign(friend),"ultimate allows reassignment at empty battery")
	k.tick(.25,CombatIntent.new())
	friend.position = Vector3(30,.01,0)
	foes[0].position = Vector3(31,.01,0)
	var charge: float = k.ultimate_charge
	resolver.damage(relay,foes[0],50,"projectile",resolver.new_cast(relay))
	near(k.ultimate_charge,charge,"damage while circuit is active grants no charge")
	near(k.drone_position().x,30.5,"aura follows recipient relocation")
	k.tick(8,CombatIntent.new())
	check(not k.ultimate_active(),"circuit expires")
	near(friend.benefits.fire_rate_multiplier(),1,"expired circuit cannot leave active haste")
	await reset()
	k = relay.kit as RelayKit
	var other: HeroActor = spawn("relay",0,Vector3(1,.01,0))
	var second := other.kit as RelayKit
	k.circuit_left = 8
	second.circuit_left = 8
	friend.health = 50
	k.tick(.5,CombatIntent.new())
	second.tick(.5,CombatIntent.new())
	near(friend.health,90,"overlapping circuits do not stack healing")
	near(friend.benefits.fire_rate_multiplier(),1.25,"overlapping circuits do not stack haste")
	other.queue_free()
	await step()

func dynamo_tests() -> void:
	await reset()
	dynamo.position = Vector3(0,.01,0)
	var k := dynamo.kit as DynamoKit
	var request := CombatIntent.new()
	request.secondary_held = true
	k.tick(1.8,request)
	near(k.spin,1,"prespin reaches full speed")
	near(k.movement_scale(),.6,"spinning limits movement")
	near(k.ammo,180,"prespin consumes no ammunition")
	k.tick(.5,CombatIntent.new())
	near(k.spin,.5,"spin decays over one second")
	k.ammo = 100
	request = CombatIntent.new()
	request.reload = true
	k.tick(0,request)
	check(k.reloading and k.spin == 0,"reload clears spin")
	await reset()
	dynamo.position = Vector3(0,.01,0)
	k = dynamo.kit as DynamoKit
	foes[0].position = Vector3(0,.01,-8)
	foes[1].position = Vector3(3,.01,-8)
	foes[2].position = Vector3(6,.01,-8)
	k.arc(foes[0])
	near(foes[0].health,2000,"arcs never revisit the original victim")
	near(foes[1].health,1982,"first lightning bounce deals eighteen")
	near(foes[2].health,1988,"second lightning bounce deals twelve")
	await reset()
	dynamo.position = Vector3(0,.01,0)
	k = dynamo.kit as DynamoKit
	aim(dynamo,Vector3(0,0,-27))
	check(not k.aimed_ground(k.data().stone_range).is_empty(),"Lodestone can target beyond eighteen meters")
	aim(dynamo,Vector3(0,0,-34))
	check(not k.aimed_ground(k.data().storm_range).is_empty(),"Storm Dominion can target beyond twenty-five meters")
	foes[0].position = Vector3(4.8,.01,-5)
	var field := DynamoField.new()
	field.source = dynamo
	world.add_child(field)
	field.global_position = Vector3(0,.01,-5)
	field.set_physics_process(false)
	await step()
	field.pulse(false)
	near(foes[0].health,1965,"Lodestone deals its initial damage")
	var pulls: Array[Node] = get_nodes_in_group("owned_attacks")
	for pull: Node in pulls:
		if pull is MagneticPull:
			pull.set_physics_process(false)
			pull._physics_process(.3)
	near(foes[0].position.x,.8,"Lodestone pulls four meters without overshooting")
	field.queue_free()
	await step()
	await reset()
	dynamo.position = Vector3(0,.01,0)
	k = dynamo.kit as DynamoKit
	foes[0].position = Vector3(3,.01,-8)
	field = DynamoField.new()
	field.source = dynamo
	field.storm = true
	world.add_child(field)
	field.global_position = Vector3(0,.01,-8)
	field.set_physics_process(false)
	k.storm_field = field
	k.ultimate_charge = 0
	field._physics_process(.5)
	near(foes[0].health,1960,"storm ticks deal forty damage")
	check(foes[0].statuses.effects.has("slow"),"storm applies its slow")
	near(k.ultimate_charge,0,"storm damage cannot recharge its ultimate")
	field._physics_process(5.5)
	near(foes[0].health,1520,"six-second storm deals twelve ticks")
	field.queue_free()
	await step()

func wall_tests() -> void:
	await reset()
	dynamo.position = Vector3(0,.01,0)
	friend.position = Vector3(20,.01,20)
	var k := dynamo.kit as DynamoKit
	check(DynamoWall.placement_clear(dynamo,Vector3(0,.01,-5),0),"wall accepts supported clear terrain")
	check(not DynamoWall.placement_clear(dynamo,dynamo.position,0),"wall rejects actor overlap")
	check(not DynamoWall.placement_clear(dynamo,Vector3(80,0,-5),0),"wall rejects unsupported terrain")
	k.wall_at = Vector3(0,.01,-5)
	k.wall_yaw = 0
	k.wall_valid = true
	check(k.place_wall(),"place physical segmented wall")
	await step()
	check(k.wall.sections.size() == 5,"wall builds five independent sections")
	check(dynamo.test_move(dynamo.global_transform,Vector3(0,0,-8)),"wall blocks actors")
	var panel: CombatStructure = k.wall.sections[2]
	panel.receive_damage(dynamo,100,resolver.new_cast(dynamo))
	near(panel.health,250,"friendly attacks cannot damage walls")
	panel.receive_damage(foes[0],40,10001)
	panel.receive_damage(foes[0],40,10001)
	near(panel.health,210,"structure damage deduplicates by cast")
	var steering: Vector3 = StructureAvoidance.steer(dynamo,Vector3.FORWARD,Vector3(0,.01,-10))
	# Approach close enough for local wall sensing.
	dynamo.position.z = -3
	steering = StructureAvoidance.steer(dynamo,Vector3.FORWARD,Vector3(0,.01,-10))
	check(absf(steering.x) > .1,"bots choose a physical detour around a wall")
	dynamo.position = Vector3(15,.01,0)
	friend.position = Vector3(0,.01,-9)
	# Keep the firing position clear for weapons with a physical muzzle sweep.
	relay.position = Vector3(-15,.01,0)
	for id: String in HeroRoster.IDS:
		foes[0].select_hero(id)
		foes[0].position = Vector3(0,.01,0)
		aim(foes[0],Vector3(0,1.2,-8))
		panel.health = 1000
		panel.maximum = 1000
		var hp: float = friend.health
		foes[0].kit.fire(false)
		await step(18)
		check(panel.health < 1000,id+" primary damages a wall")
		near(friend.health,hp,id+" primary cannot shoot through a wall")
	foes[0].select_hero("slayer")
	foes[0].position = Vector3(0,.01,0)
	for kind: String in ["knife","axe"]:
		var before: float = panel.health
		var projectile := SlayerProjectile.new()
		projectile.source = foes[0]
		projectile.kind = kind
		projectile.direction = Vector3.FORWARD
		world.add_child(projectile)
		projectile.global_position = Vector3(0,1.2,-1)
		await step(10)
		check(panel.health < before,kind+" damages physical wall")
	foes[0].position = Vector3(0,.01,-3)
	aim(foes[0],Vector3(0,1.2,-6))
	var before: float = panel.health
	foes[0].state = "melee_active"
	foes[0].state_time = .1
	foes[0].close.melee_direction = Vector3.FORWARD
	foes[0].close.cast_id = resolver.new_cast(foes[0])
	foes[0].close.tick(.01,CombatIntent.new())
	check(panel.health < before,"shared melee damages physical wall")
	panel.health = 20
	var hp: float = friend.health
	resolver.splash(foes[0],Vector3(0,1,-4),6,80,"bomb",resolver.new_cast(foes[0]))
	near(friend.health,hp,"a breaking wall still blocks its destroying explosion")
	await step()
	check(not is_instance_valid(panel),"destroying one section opens its gap")
	check(resolver.ray(Vector3(0,1,-3),Vector3(0,1,-9),[],1).is_empty(),"destroyed section stops blocking shots")
	k.cancel(true)
	await step()
	check(get_nodes_in_group("structures").is_empty(),"wall cleanup removes physical sections")

func wisp_tests() -> void:
	await reset()
	wisp.position = Vector3(0,.01,0)
	friend.position = Vector3(20,.01,20)
	relay.position = Vector3(20,.01,10)
	foes[0].position = Vector3(0,.01,-8)
	await step()
	var k := wisp.kit as WispKit
	check(k.shells == 0,"new lives begin without banked spectral shells")
	aim(wisp,foes[0].body_point(1.2))
	for i: int in 5:
		k.shot_cd = 0
		k.fire()
	near(foes[0].health,1930,"dual pistols fire fourteen-damage shots")
	check(foes[0].statuses.soul_count(wisp) == 4,"pistol marks cap at four")
	k.shells = 1
	var before: float = foes[0].health
	k.soulbreaker()
	check(foes[0].statuses.soul_count(wisp) == 0,"precise shotgun core consumes marks")
	check(before-foes[0].health >= 68,"core delivers its damage plus the four-mark detonation")
	check(k.shells == 0,"Soulbreaker spends exactly one shell")
	await reset()
	wisp.position = Vector3(0,2,0)
	k = wisp.kit as WispKit
	aim(wisp,Vector3(0,3.2,-20))
	var request := CombatIntent.new()
	request.hover = true
	k.tick(0,request)
	check(wisp.state == "wisp_step" and k.steps == 2,"dash spends one charge")
	check(not wisp.permits("primary"),"dash prevents shooting")
	for i: int in 14: k.move_override(1.0/60)
	near(wisp.position.z,-7,"dash covers seven meters")
	check(k.shells == 1,"completed dash supplies one shell")
	k.tick(4,CombatIntent.new())
	check(k.steps == 3 and k.recharge == 0,"dash charges recharge sequentially")
	await reset()
	wisp.position = Vector3(0,.01,0)
	k = wisp.kit as WispKit
	var block: Node3D = Geometry.box(world,Vector3(6,4,.5),Vector3(0,2,-3),Color.GRAY)
	await step()
	k.tick(0,request)
	for i: int in 15:
		if wisp.state == "wisp_step": k.move_override(1.0/60)
	check(wisp.position.z > -3 and k.shells == 0,"interrupted dash cannot cross terrain or load a shell")
	block.queue_free()
	await step()
	await reset()
	k = wisp.kit as WispKit
	request = CombatIntent.new()
	request.deflect = true
	k.tick(0,request)
	check(wisp.state == "wisp_phase","phase enters a distinct defensive state")
	var hp: float = wisp.health
	resolver.damage(foes[0],wisp,100,"rifle",resolver.new_cast(foes[0]))
	near(wisp.health,hp,"phase prevents incoming damage")
	check(not wisp.statuses.apply("root",foes[0],2),"phase prevents incoming control")
	check(not wisp.permits("primary") and not wisp.permits("secondary") and not wisp.permits("step"),"phase prohibits attacks and abilities")
	wisp.state_time = 0
	k.tick(0,CombatIntent.new())
	check(wisp.state == "ready" and not wisp.invulnerable,"phase restores ordinary vulnerability")
	request = CombatIntent.new()
	request.bomb = true
	k.tick(0,request)
	near(wisp.velocity.y,12,"spectral lift supplies vertical launch")
	await reset()
	k = wisp.kit as WispKit
	request = CombatIntent.new()
	request.ultimate = true
	k.tick(0,request)
	check(k.ultimate_charge == 100 and wisp.state == "wisp_ballet_start","ballet preserves charge during preparation")
	wisp.close.stagger()
	check(k.ultimate_charge == 100 and k.ballet_left == 0,"interrupted preparation retains charge and has no finale")
	wisp.state = "ready"
	k.tick(0,request)
	wisp.state_time = 0
	k.tick(0,CombatIntent.new())
	near(k.ballet_left,4,"Death Ballet begins a full four-second window")
	k.tick(3,CombatIntent.new())
	check(k.ultimate_active(),"ballet remains active beyond its former duration")
	near(k.ultimate_charge,0,"active ballet does not recharge itself")
	k.tick(1,CombatIntent.new())
	check(not k.ultimate_active() and wisp.state == "ready","ballet ends after four seconds")
	var finales: int = 0
	for node: Node in get_nodes_in_group("owned_attacks"):
		if node is CombatProjectile and node.blast_radius > 0: finales += 1
	check(finales == 1,"completed ballet launches exactly one finale")

func lifecycle_tests() -> void:
	await reset()
	var k := relay.kit as RelayKit
	k.assign(friend)
	friend.reset_actor()
	k.tick(.2,CombatIntent.new())
	check(k.recipient == null,"recipient respawn detaches the old drone")
	k.transfer_cd = 0
	k.assign(friend)
	relay.select_hero("wisp")
	check(relay.kit is WispKit and (relay.kit as WispKit).shells == 0,"hero switch clears drone and starts Wisp without shells")
	relay.select_hero("relay")
	wisp.kit.refill()
	check((wisp.kit as WispKit).shells == 2,"training refill supplies two shells")
	foes[0].statuses.add_soul(wisp,4,3)
	wisp.die()
	check(foes[0].statuses.soul_count(wisp) == 0,"death clears source-owned soul marks")
	var observed: Dictionary = {}
	for seed_value: int in 12:
		for id: String in HeroRoster.IDS:
			var team: Array[String] = HeroRoster.composition_for(id,seed_value)
			var roles: Dictionary = {"tank":0,"support":0,"dps":0}
			for hero: String in team:
				roles[HeroRoster.role_for(hero)] += 1
				observed[hero] = true
			check(team.size() == 6 and team[0] == id and roles == {"tank":2,"support":2,"dps":2},"seed %d balanced roster includes %s" % [seed_value,id])
	check(observed.size() == 8,"seeded compositions cover all eight heroes")
	for id: String in HeroRoster.IDS:
		var elevated: int = 0
		for slot: int in range(1,6):
			if HeroRoster.bot_role(slot,id) == "high_ground": elevated += 1
		check(elevated == 1,"high-ground bot remains assigned with player "+id)

func timing_and_cover_tests() -> void:
	for fps: int in [30,60,144]:
		for id: String in ["relay","dynamo","wisp"]:
			await reset()
			var a: HeroActor = {"relay":relay,"dynamo":dynamo,"wisp":wisp}[id]
			var input := CombatIntent.new()
			input.primary_held = true
			if a.kit is DynamoKit: a.kit.spin = 1
			for frame: int in fps: a.kit.tick(1.0/fps,input)
			var expected: int = {"relay":10,"dynamo":18,"wisp":12}[id]
			near(a.tuning.magazine-a.kit.ammo,expected,id+" primary cadence at %d FPS" % fps,1)
	await reset()
	wisp.position = Vector3(0,.01,0)
	relay.position = Vector3(20,.01,10)
	friend.position = Vector3(20,.01,20)
	foes[0].position = Vector3(0,.01,-8)
	var k := wisp.kit as WispKit
	foes[0].statuses.add_soul(wisp,4,3)
	foes[0].statuses.add_soul(wisp,4,3)
	aim(wisp,foes[0].body_point(1.2)+Vector3(.85,0,0))
	await step()
	k.shells = 1
	k.soulbreaker()
	check(foes[0].statuses.soul_count(wisp) == 2,"pellet contact without a core hit preserves marks")
	foes[0].statuses.tick(3.1)
	check(foes[0].statuses.soul_count(wisp) == 0,"soul marks expire after three seconds")
	foes[0].statuses.add_soul(wisp,4,3)
	foes[0].statuses.cleanse()
	check(foes[0].statuses.soul_count(wisp) == 0,"cleanse removes soul marks")
	await reset()
	dynamo.position = Vector3(0,.01,0)
	foes[0].position = Vector3(0,.01,-8)
	foes[1].position = Vector3(4,.01,-8)
	foes[2].position = Vector3(12,.01,-8)
	var block: Node3D = Geometry.box(world,Vector3(.5,4,6),Vector3(2,2,-8),Color.GRAY)
	await step()
	(dynamo.kit as DynamoKit).arc(foes[0])
	near(foes[1].health,2000,"solid cover blocks chain lightning")
	block.queue_free()
	await step()
	var field := DynamoField.new()
	field.source = dynamo
	world.add_child(field)
	field.position = Vector3(0,.01,-8)
	field.set_physics_process(false)
	block = Geometry.box(world,Vector3(2,4,.5),Vector3(0,2,-6),Color.GRAY)
	foes[0].position = Vector3(0,.01,-4)
	await step()
	field.pulse(false)
	near(foes[0].health,2000,"cover prevents Lodestone damage and pull")
	var moving_pulls: int = 0
	for node: Node in get_nodes_in_group("owned_attacks"):
		if node is MagneticPull and node.target == foes[0]: moving_pulls += 1
	check(moving_pulls == 0,"blocked Lodestone creates no displacement")
	field.pulse(true)
	near(foes[0].health,2000,"cover prevents storm damage")
	check(not foes[0].statuses.effects.has("slow"),"cover prevents storm slow")
	block.queue_free()
	field.queue_free()
	await step()
	await reset()
	var source_id: int
	var ballet := wisp.kit as WispKit
	ballet.ballet_left = 1
	source_id = resolver.new_cast(wisp)
	ballet.ballet_left = 0
	ballet.ultimate_charge = 0
	resolver.damage(wisp,foes[0],80,"spectral_finale",source_id)
	near(ballet.ultimate_charge,0,"delayed ultimate damage cannot charge its successor")
	var storm := DynamoField.new()
	storm.source = dynamo
	storm.storm = true
	world.add_child(storm)
	(dynamo.kit as DynamoKit).storm_field = storm
	dynamo.select_hero("wisp")
	check(storm.is_queued_for_deletion() and not storm.is_physics_processing(),"same-frame hero switch immediately stops old field physics")
	storm._physics_process(.5)
	dynamo.select_hero("dynamo")
	await step()

func scene_tests() -> void:
	HeroRoster.selected = "relay"
	var arena: Node = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await step(4)
	var training: TrainingManager = arena.training
	for id: String in ["relay","dynamo","wisp"]:
		training.start_roster_drill(id)
		check(training.player.tuning.hero_id == id and training.scenario >= 12,"training selects "+id+" exercise")
		check(not training.bots.is_empty(),id+" exercise creates targets")
		check(CareHUD.detail(training.player) != "",id+" has resource HUD")
		check(CareHUD.ultimate_detail(training.player) != "",id+" ultimate HUD describes its tuning")
		var profile: int = {"relay":10,"dynamo":11,"wisp":12}[id]
		var bot: HeroActor = training.spawn_bot(profile,Vector3(20,.1,-12))
		check(bot.tuning.hero_id == id,id+" training bot profile loads")
		check(bot.controller.gather_intent(.2) is CombatIntent,id+" bot produces combat intent")
	training.toggle_menu()
	check(paused,"new hero training can pause")
	training.toggle_menu()
	arena.queue_free()
	await step(4)
	check(get_nodes_in_group("actors").is_empty() and get_nodes_in_group("structures").is_empty(),"training exit clears heroes and structures")
	HeroRoster.selected = "nimbus"
