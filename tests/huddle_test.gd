extends SceneTree

var world: Node3D
var resolver: CombatResolver
var h: HeroActor
var friend: HeroActor
var enemy: HeroActor
var marshal: HeroActor
var k: HuddleKit
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if value else "FAIL  ",caption)
	if not value: failures.append(caption)

func near(value: float, expected: float, caption: String, tolerance: float = .05) -> void:
	check(absf(value-expected) <= tolerance,caption+" [%.3f / %.3f]" % [value,expected])

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

func reset() -> void:
	h.reset_actor(Vector3(0,.01,0))
	friend.reset_actor(Vector3(0,.01,-8))
	enemy.reset_actor(Vector3(0,.01,-16))
	marshal.reset_actor(Vector3(20,.01,0))
	for a: HeroActor in [h,friend,enemy,marshal]:
		a.set_physics_process(false)
		a.intent.aim = Vector3.FORWARD
		a.aim_direction = Vector3.FORWARD
		a.intent.aim_origin = a.position+Vector3.UP*1.2
	k = h.kit as HuddleKit
	resolver.clear_round()
	await step()

func input() -> CombatIntent:
	return CombatIntent.new()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(100,1,100),Vector3(0,-.5,0),Color.GRAY)
	h = spawn("huddle",0,Vector3.ZERO)
	friend = spawn("nimbus",0,Vector3(0,0,-8))
	enemy = spawn("nimbus",1,Vector3(0,0,-16))
	marshal = spawn("marshal",1,Vector3(20,0,0))
	await step(4)
	await healing_tests()
	await scatter_tests()
	await screen_tests()
	await all_weapons_screen_tests()
	await weapon_pulse_tests()
	await wave_tests()
	await lifecycle_tests()
	world.queue_free()
	await step()
	await scene_tests()
	print("RESULT: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/huddle-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)

func healing_tests() -> void:
	await reset()
	check(h.health == 600 and h.shields == 0,"600 health with no personal shields")
	var request := input()
	request.secondary_held = true
	k.tick(0,request)
	check(h.state == "ready" and k.regroup_cd == 0,"full-health regroup spends nothing")
	h.health = 550
	k.tick(0,request)
	h.health = 600
	k.tick(.5,request)
	check(k.regroup_cd == 0 and h.state == "ready","external healing during preparation spends no healing cooldown")
	k.tick(0,input())
	h.health = 100
	k.ultimate_charge = 0
	k.tick(0,request)
	check(h.state == "huddle_regroup","RMB begins regroup")
	near(k.movement_scale(),.6,"healing movement scale")
	var moving := input()
	moving.move = Vector3.RIGHT
	for i: int in 40: h.motor.tick(1.0/60,moving)
	near(h.velocity.x,3.6,"actual healing movement retains sixty percent ground speed")
	k.tick(.3,request)
	near(h.health,100,"preparation does not heal")
	near(k.regroup_cd,0,"cooldown waits for healing")
	k.tick(.5,request)
	near(h.health,140,"regroup restores 80 health per second")
	near(k.regroup_cd,10,"first healing tick starts cooldown")
	near(k.ultimate_charge,.8*.8,"self healing grants no additional charge")
	k.tick(2.5,request)
	near(h.health,340,"channel caps at three seconds of healing")
	check(h.state == "ready","channel completes")
	k.tick(12,request)
	check(h.state == "ready","held RMB cannot restart without release")
	k.tick(0,input())
	k.tick(0,request)
	check(h.state == "huddle_regroup","release rearms regroup")
	request.primary_held = true
	k.tick(.1,request)
	check(h.state != "huddle_regroup" and k.ammo == 9,"firing cancels healing and shoots")
	await reset()
	h.health = 595
	request = input()
	request.secondary_held = true
	k.tick(0,request)
	k.tick(.5,request)
	near(h.health,600,"healing caps at maximum health")
	h.health = 200
	h.statuses.apply("max_health",enemy,5,.5)
	near(resolver.heal(h,h,500,"regroup",false),100,"self healing respects wound")
	near(h.health,300,"wounded maximum is enforced")
	await reset()
	h.health = 300
	k.tick(0,request)
	resolver.damage(enemy,h,40,"rifle",resolver.new_cast(enemy))
	near(h.health,260,"healing grants no damage immunity")
	h.close.stagger()
	k.tick(.2,request)
	check(h.state == "stagger","stagger interrupts regroup")
	await reset()
	h.health = 300
	h.spawn_protected = true
	k.tick(0,request)
	check(h.state == "ready","spawn protection disallows regroup")
	h.spawn_protected = false

func scatter_tests() -> void:
	await reset()
	friend.position.x = 15
	await step()
	k.start_scatter()
	var start: Vector3 = h.position
	for i: int in 28: k.move_override(1.0/60)
	near(h.position.distance_to(start),10,"scatter travels ten metres")
	check(k.scatter_charges == 1,"first scatter spends one charge")
	k.start_scatter()
	check(k.scatter_charges == 0,"second charge is independently available")
	k.cancel()
	k.tick(4.99,input())
	check(k.scatter_charges == 0,"sequential recovery waits five seconds")
	k.tick(.02,input())
	check(k.scatter_charges == 1,"first charge recovers")
	k.tick(5,input())
	check(k.scatter_charges == 2 and k.scatter_timer == 0,"second charge recovers sequentially")
	await reset()
	h.aim_direction = Vector3.UP
	k.start_scatter()
	for i: int in 28: k.move_override(1.0/60)
	near(h.position.y,10.01,"scatter supports vertical travel")
	near(h.velocity.y,22,"ending flight retains momentum")
	check(is_equal_approx(h.get_node("BodyCollision").shape.radius,.38),"scatter retains ordinary collider")
	await reset()
	var wall: Node3D = Geometry.box(world,Vector3(5,5,.2),Vector3(0,2,-3),Color.GRAY)
	await step()
	k.start_scatter()
	for i: int in 28: k.move_override(1.0/60)
	check(h.position.z > -3 and h.state == "ready","wall stops scatter safely")
	wall.queue_free()
	await step()
	await reset()
	k.start_scatter()
	check(not h.permits("primary") and not h.permits("melee"),"scatter prevents firing and close combat")
	h.statuses.apply("root",enemy,2)
	check(h.state == "ready" and not h.permits("scatter"),"root cancels and blocks scatter")
	await reset()
	enemy.position = Vector3(0,.01,-3)
	await step()
	k.start_scatter()
	for i: int in 28: k.move_override(1.0/60)
	check(h.position.z > -3,"actors block scatter")

func screen_tests() -> void:
	await reset()
	var request := input()
	request.deflect = true
	k.tick(0,request)
	check(k.screen.recipient == friend,"screen selects aimed visible ally")
	var screen: HuddleScreen = k.screen
	check(screen.active() and screen.health == 250,"screen has independent durability")
	check(resolver.attack_ray(enemy,enemy.position+Vector3.UP,friend.position+Vector3.UP,[enemy.get_rid()]).get("collider") == screen,"hostile rays hit bug screen")
	check(resolver.barrier_ray(h,h.position+Vector3.UP,enemy.position+Vector3.UP).is_empty(),"friendly rays ignore screen")
	var id: int = resolver.new_cast(enemy)
	screen.receive_damage(enemy,40,id)
	screen.receive_damage(enemy,40,id)
	near(screen.health,210,"same attack damages screen once")
	var previous: Vector3 = screen.frame().origin
	friend.position.x += 2
	check(screen.frame().origin.x == previous.x+2,"screen follows recipient")
	friend.aim_direction = Vector3.RIGHT
	check(screen.frame().basis.z.dot(Vector3.LEFT) > .99,"screen follows recipient facing")
	screen.receive_damage(enemy,500,resolver.new_cast(enemy))
	check(not screen.active(),"destroyed screen stops intercepting immediately")
	await reset()
	friend.position.x = 12
	k.tick(0,request)
	check(k.screen.recipient == h,"no aimed ally falls back to self")
	k.screen._physics_process(2.6)
	check(not k.screen.active(),"screen expires")
	await reset()
	k.tick(0,request)
	screen = k.screen
	var before: float = friend.health
	resolver.splash(enemy,Vector3(0,1,-10),4,100,"bomb",resolver.new_cast(enemy))
	near(friend.health,before,"screen blocks explosion damage")
	near(screen.health,150,"explosion damages screen once")
	friend.die()
	check(not screen.active(),"recipient death ends screen")
	await reset()
	k.cast_screen()
	screen = k.screen
	friend.select_hero("doctor")
	check(not screen.active(),"recipient hero change retires screen")
	friend.select_hero("nimbus")
	await reset()
	friend.position = Vector3(20,.01,0)
	k.tick(0,request)
	screen = k.screen
	enemy.position = Vector3(0,.01,-4)
	var projectile := CombatProjectile.new()
	projectile.source = enemy
	projectile.direction = Vector3.BACK
	projectile.cast_id = resolver.new_cast(enemy)
	world.add_child(projectile)
	projectile.position = Vector3(0,1,-4)
	await step(20)
	check(not is_instance_valid(projectile) and screen.health < 250,"physical projectile damages screen")

func all_weapons_screen_tests() -> void:
	for hero: String in ["nimbus","slayer","marshal","doctor","huddle"]:
		await reset()
		friend.position.x = 15
		enemy.select_hero(hero)
		enemy.position = Vector3(0,.01,-5)
		enemy.aim_direction = Vector3.BACK
		enemy.intent.aim = Vector3.BACK
		enemy.intent.aim_origin = enemy.position+Vector3.UP*1.2
		await step()
		k.cast_screen()
		var shield: HuddleScreen = k.screen
		enemy.kit.fire(false)
		await step(8)
		check(shield.health < 250 and h.health == 600,hero+" weapon hits screen instead of Huddle")
		if hero == "nimbus":
			enemy.kit.shot_cd = 0
			var before: float = shield.health
			enemy.kit.fire(true)
			near(shield.health,before-150,"sniper ultimate hits bug screen")
		if hero == "slayer":
			for kind: String in ["knife","axe"]:
				shield.health = 250
				var shot := SlayerProjectile.new()
				shot.source = enemy
				shot.kind = kind
				shot.direction = Vector3.BACK
				world.add_child(shot)
				shot.position = Vector3(0,1.3,-1.3)
				shot._physics_process(.05)
				check(shot.is_queued_for_deletion() and shield.health < 250,kind+" stops at bug screen")
			shield.health = 250
			var snare := HunterSnare.new()
			snare.source = enemy
			snare.flying = true
			world.add_child(snare)
			snare.position = Vector3(0,1.3,-1.3)
			snare.velocity = Vector3.BACK*20
			snare._physics_process(.05)
			check(snare.is_queued_for_deletion() and shield.health < 250,"thrown snare damages bug screen")
		if hero == "nimbus":
			var bomb := PocketBomb.new()
			bomb.source = enemy
			bomb.cast_id = resolver.new_cast(enemy)
			world.add_child(bomb)
			bomb.position = Vector3(0,1,-1.3)
			bomb.velocity = Vector3.BACK*10
			bomb._physics_process(.05)
			check(bomb.velocity.z < 0,"pocket bomb bounces away from bug screen")
			bomb.queue_free()
	enemy.select_hero("nimbus")

func weapon_pulse_tests() -> void:
	await reset()
	friend.position.x = 10
	enemy.position.z = -8
	await step()
	k.fire()
	check(k.ammo == 9,"one volley consumes one ammunition")
	var seeds: int = 0
	for attack: Node in get_nodes_in_group("owned_attacks"):
		if attack is CombatProjectile and attack.source == h: seeds += 1
	check(seeds == 6,"volley emits six physical seeds")
	await step(15)
	check(enemy.health < 250,"physical seed volley hits enemy")
	await step(35)
	check(get_nodes_in_group("owned_attacks").is_empty(),"seed projectiles retire at maximum range")
	await reset()
	enemy.position = Vector3(2,.01,0)
	var request := input()
	request.bomb = true
	k.tick(0,request)
	near(enemy.health,250,"wingbeat waits for windup")
	h.state_time = 0
	k.tick(0,input())
	near(enemy.health,215,"wingbeat deals 35 damage")
	near(enemy.motor.external_velocity.x,10,"wingbeat pushes radially")
	check(not enemy.statuses.movement_disabled() and enemy.state == "ready","wingbeat adds no control lock")
	await reset()
	enemy.position = Vector3(2,.01,0)
	var wall: Node3D = Geometry.box(world,Vector3(.2,4,5),Vector3(1,2,0),Color.GRAY)
	await step()
	k.pulse()
	near(enemy.health,250,"wingbeat respects solid cover")
	wall.queue_free()
	await step()

func begin_wave() -> void:
	var request := input()
	request.ultimate = true
	k.tick(0,request)
	h.state_time = 0
	k.tick(0,input())

func wave_tests() -> void:
	await reset()
	friend.position.x = 15
	enemy.position = Vector3(1.5,.01,-4)
	var request := input()
	request.ultimate = true
	k.tick(0,request)
	check(h.state == "huddle_wave_start" and k.ultimate_charge == 100,"wave preparation retains ultimate charge")
	h.close.stagger()
	check(k.ultimate_charge == 100,"interrupted preparation retains charge")
	await reset()
	friend.position.x = 15
	enemy.position = Vector3(1.5,.01,-4)
	await step()
	begin_wave()
	check(h.state == "huddle_wave" and k.ultimate_charge == 0,"transformation consumes charge")
	check(not h.permits("primary") and not h.permits("guard") and not h.permits("melee") and not h.permits("regroup"),"wave locks other actions")
	var before: float = h.health
	resolver.damage(enemy,h,50,"rifle",resolver.new_cast(enemy))
	near(h.health,before-50,"wave takes ordinary damage")
	var from: Vector3 = h.position
	for i: int in 20: k.move_override(1.0/60)
	near(enemy.health,190,"wave strikes off-center enemy")
	k.wave_contacts(Vector3(0,.01,-4),Vector3(0,.01,-4),1.0/60)
	near(enemy.health,190,"wave damage applies only once per enemy")
	near(enemy.motor.external_velocity.length(),12,"continued push does not accumulate unbounded velocity")
	check(enemy.state == "ready","wave does not capture enemies")
	for i: int in 100: k.move_override(1.0/60)
	near(h.position.distance_to(from),24,"wave travels twenty-four metres",.15)
	check(h.state == "ready","wave ends at duration")
	await reset()
	friend.position.x = 15
	begin_wave()
	h.intent.move = Vector3.RIGHT
	k.move_override(.1)
	near(rad_to_deg(Vector3.FORWARD.angle_to(k.travel_direction)),6,"steering capped at sixty degrees per second",.1)
	h.intent.move = -k.travel_direction
	var direction: Vector3 = k.travel_direction
	k.move_override(.1)
	check(k.travel_direction.is_equal_approx(direction),"backward input cannot reverse wave")
	h.statuses.apply("slow",enemy,2,.5)
	check(h.state == "ready","slow interrupts active wave")
	await reset()
	friend.position.x = 15
	var wall: Node3D = Geometry.box(world,Vector3(8,5,.2),Vector3(0,2,-3),Color.GRAY)
	await step()
	begin_wave()
	for i: int in 30: k.move_override(1.0/60)
	check(h.state == "ready" and h.position.z > -3,"wall stops wave")
	wall.queue_free()
	await step()
	await reset()
	h.position = Vector3(49,.01,0)
	h.aim_direction = Vector3.RIGHT
	begin_wave()
	for i: int in 20: k.move_override(1.0/60)
	check(h.state == "ready" and h.position.x < 52,"unsupported edge ends wave")
	await reset()
	friend.position.x = 15
	enemy.position = Vector3(1,.01,-2)
	marshal.position = Vector3(1,.01,-3)
	marshal.aim_direction = Vector3.BACK
	marshal.state = "marshal_shield"
	await step()
	begin_wave()
	k.wave_contacts(h.position,Vector3(0,.01,-2),1.0/60)
	near(enemy.health,250,"hostile barrier blocks initial wave damage")
	check((marshal.kit as MarshalKit).barrier_hp < 1200,"wave damages intercepting barrier")
	check(enemy.motor.external_velocity.length() > 0,"physical contact can displace behind analytic barrier")

	await reset()
	friend.position.x = 15
	enemy.position = Vector3(2,.01,-3)
	var cover: Node3D = Geometry.box(world,Vector3(1,4,3),Vector3(1,2,-2),Color.GRAY)
	await step()
	begin_wave()
	k.wave_contacts(h.position,Vector3(0,.01,-3),1.0/60)
	near(enemy.health,250,"solid side cover blocks wave damage")
	near(enemy.motor.external_velocity.length(),0,"solid side cover blocks wave displacement")
	cover.queue_free()
	await step()
	await reset()
	var ramp: Node3D = Geometry.box(world,Vector3(6,.4,12),Vector3(30,1.2,-6),Color.GRAY)
	ramp.rotation.x = atan(.2)
	h.position = Vector3(30,.1,0)
	await step()
	begin_wave()
	for i: int in 40: k.move_override(1.0/60)
	check(h.position.y > 1 and h.state == "huddle_wave","wave follows walkable ramp upward")
	ramp.queue_free()
	await step()

func lifecycle_tests() -> void:
	await reset()
	k.cast_screen()
	var screen: HuddleScreen = k.screen
	k.cancel()
	check(screen.active(),"ordinary ability cancellation preserves screen")
	h.die()
	check(not screen.active(),"source death retires screen")
	await reset()
	k.cast_screen()
	screen = k.screen
	h.select_hero("doctor")
	check(not screen.active() and h.kit is DoctorKit,"hero switch retires screen")
	h.select_hero("huddle")
	k = h.kit as HuddleKit
	k.scatter_charges = 0
	k.regroup_cd = 10
	h.reset_actor()
	check(k.scatter_charges == 2 and k.regroup_cd == 0 and h.health == 600,"reset refills colony resources")
	check(CareHUD.labels(h)[0] == "SCATTERBOUND" and CareHUD.detail(h).contains("REGROUP"),"HUD exposes colony resources")

func scene_tests() -> void:
	HeroRoster.selected = "huddle"
	var arena: Node3D = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await step(4)
	var training: TrainingManager = arena.training
	training.start_huddle_drill()
	training.freeze_ai = true
	check(training.player.kit is HuddleKit and training.scenario == 10,"training selects Huddle rescue exercise")
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.action_press("aim")
		var controls: CombatIntent = training.player.controller.gather_intent(0)
		Input.action_release("aim")
		check(controls.secondary_held and not controls.aim_held,"native RMB requests regroup without zoom")
		Input.action_press("hover")
		controls = training.player.controller.gather_intent(0)
		Input.action_release("hover")
		check(controls.hover,"native Q requests Scatterbound")
		var driver: PlayerController = training.player.controller
		driver.active = false
		training.player.set_physics_process(false)
		training.player.state = "huddle_wave"
		await step(40)
		check(driver.arm.spring_length > 4.4 and driver.camera.fov > 75,"wave camera widens distance while keeping ordinary FOV")
		training.player.state = "ready"
		await step(40)
		near(driver.arm.spring_length,driver.camera_distance,"wave camera restores shoulder distance")
		driver.active = true
		training.player.set_physics_process(true)
	check(training.bots.size() == 4 and training.bots[0].team == training.player.team,"exercise has neighbor and three threats")
	var bot: HeroActor = training.spawn_bot(9,Vector3(10,.1,-5))
	check(bot.kit is HuddleKit,"Huddle training bot profile loads")
	training.toggle_menu()
	var remaining: float = training.player.kit.regroup_cd
	await step(4)
	near(training.player.kit.regroup_cd,remaining,"pause freezes Huddle cooldowns")
	training.toggle_menu()
	arena.queue_free()
	await step(4)
	check(get_nodes_in_group("barriers").is_empty(),"scene exit cleans up screens")
	HeroRoster.selected = "nimbus"
