extends "res://tests/care_heroes_test.gd"

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	var floor_body: Node3D = Geometry.box(world,Vector3(150,1,150),Vector3(0,-.5,0),Color.GRAY)
	doctor = spawn("doctor",0,Vector3(-30,0,0))
	friend = spawn("nimbus",0,Vector3(-30,0,5))
	enemy = spawn("nimbus",1,Vector3(0,.01,-3))
	marshal = spawn("marshal",0,Vector3(0,.01,0))
	hunter = spawn("slayer",1,Vector3(0,.01,-9))
	second = spawn("doctor",0,Vector3(-30,0,10))
	await step(3)
	for fps: int in [20,30,60,120]:
		await prepare()
		start_march()
		for i: int in fps*2: marshal.kit.move_override(1.0/fps)
		near(marshal.position.z,-20,"charge distance at %d Hz" % fps,.06)
		near(enemy.health,150,"first swept enemy hit once at %d Hz" % fps)
		near(hunter.health,hunter.tuning.max_health-100,"second swept enemy hit once at %d Hz" % fps)
		check(marshal.state == "ready","charge has immediate recovery at %d Hz" % fps)
		marshal.intent.move = Vector3.RIGHT
		var before: float = marshal.position.x
		marshal.motor.tick(1.0/fps,marshal.intent)
		check(marshal.position.x > before,"normal movement resumes at %d Hz" % fps)
	await prepare()
	start_march()
	marshal.intent.move = Vector3.RIGHT
	for i: int in 100: marshal.kit.move_override(1.0/60)
	var k := marshal.kit as MarshalKit
	near(rad_to_deg(k.march_turn_used),30,"cumulative steering budget is thirty degrees",.01)
	check(marshal.position.x > 5,"charge input steers the physical path")
	var final_direction: Vector3 = k.march_direction
	marshal.intent.move = Vector3.LEFT
	k.march_left = 3
	marshal.state = "marshal_march"
	for i: int in 10: k.move_override(1.0/60)
	check(k.march_direction.is_equal_approx(final_direction),"opposite input cannot reset cumulative turn budget")
	await prepare()
	enemy.position = Vector3(.78,.3,-3)
	start_march()
	for i: int in 40: k.move_override(.05)
	near(enemy.health,150,"glancing elevated enemy is swept once")
	await prepare()
	start_march()
	marshal.statuses.apply("root",enemy,1.0)
	var rooted_at: Vector3 = marshal.position
	k.move_override(.05)
	check(marshal.state == "ready" and marshal.position.is_equal_approx(rooted_at),"root terminates charge without stored motion")
	marshal.statuses.effects.clear()
	await prepare()
	enemy.position = Vector3(-20,0,-3)
	hunter.position = Vector3(-20,0,-9)
	var ramp: Node3D = Geometry.box(world,Vector3(5,.3,14),Vector3(0,.5,-7),Color.GRAY)
	ramp.rotation.x = deg_to_rad(5)
	await step()
	start_march()
	for i: int in 40: k.move_override(.05)
	check(marshal.position.z < -18 and marshal.state == "ready","walkable incline and small descent preserve charge travel")
	ramp.queue_free()
	await step()
	await prepare()
	var wall: Node3D = Geometry.box(world,Vector3(5,5,.12),Vector3(0,2,-5),Color.GRAY)
	hunter.position = Vector3(0,.01,-5.6)
	await step()
	start_march()
	for i: int in 40: k.move_override(.05)
	check(marshal.position.z > -4.6 and marshal.position.z < -4,"thin wall stops full capsule at low frame rate")
	near(hunter.health,hunter.tuning.max_health,"sweep cannot hit through a wall")
	check(not CareTactics.marshal_safe_lane(marshal,Vector3.FORWARD,20),"bot rejects blocked charge lane")
	var brain := BotBrain.new()
	brain.actor = marshal
	marshal.state = "marshal_march"
	k.march_left = 15
	brain.movement.apply(brain,marshal.intent,false)
	check(marshal.state == "ready","active tactical bot charge aborts when its remaining lane becomes blocked")
	wall.queue_free()
	await step()
	await prepare()
	enemy.state = "guard"
	enemy.aim_direction = Vector3.BACK
	start_march()
	for i: int in 30: k.move_override(.05)
	check(marshal.state == "stagger" and enemy.health == 250,"guard stops charge through authoritative combat resolver")
	await prepare()
	var defender: HeroActor = spawn("marshal",1,Vector3(0,.01,-6))
	defender.aim_direction = Vector3.BACK
	defender.state = "marshal_shield"
	await step()
	start_march()
	for i: int in 40: k.move_override(.05)
	near((defender.kit as MarshalKit).barrier_hp,1100,"hostile barrier absorbs one charge hit")
	near(defender.health,550,"barrier protects owner")
	defender.queue_free()
	await step()
	await prepare()
	check(CareTactics.marshal_safe_lane(marshal,Vector3.FORWARD,20),"bot accepts clear grounded engagement lane")
	check(CareTactics.marshal_verdict_safe(marshal,Vector3.FORWARD),"bot accepts open sky Verdict")
	var ceiling: Node3D = Geometry.box(world,Vector3(8,.2,8),Vector3(0,3,0),Color.GRAY)
	await step()
	check(not CareTactics.marshal_verdict_safe(marshal,Vector3.FORWARD),"bot refuses Verdict under low ceiling")
	ceiling.queue_free()
	await step()
	await prepare()
	marshal.intent.ultimate = true
	k.tick(0,marshal.intent)
	marshal.intent.ultimate = false
	marshal.intent.move = Vector3.ZERO
	var peak: float = 0
	for i: int in 110:
		if i == 63: marshal.intent.move = Vector3.RIGHT
		if marshal.state == "marshal_verdict": k.move_override(1.0/60)
		peak = maxf(peak,marshal.position.y)
		await step(1)
	check(peak > 7.5 and peak < 8.5,"nineteen m/s takeoff gives approximately eight metre apex")
	check(marshal.position.x > .6,"Verdict permits late airborne steering after forward travel ends")
	check(k.verdict_direction.is_equal_approx(Vector3.FORWARD),"air steering preserves committed impact cone")
	check(marshal.state == "marshal_recovery","steered Verdict lands once")
	floor_body.queue_free()
	await step()
	await prepare()
	check(not CareTactics.marshal_safe_lane(marshal,Vector3.FORWARD,20),"bot rejects lane over lethal void")
	resolver.events.clear()
	marshal.position.y = 15
	k.ultimate_charge = 100
	marshal.intent.ultimate = true
	k.tick(0,marshal.intent)
	marshal.intent.ultimate = false
	for i: int in 240:
		if marshal.state == "marshal_verdict": k.move_override(1.0/60)
		await step(1)
	var impacts: int = 0
	for entry: Dictionary in resolver.events:
		if entry.event == "impact": impacts += 1
	check(impacts == 0 and marshal.state == "ready","missing ground times out without midair impact")
	print("RESULT: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func prepare() -> void:
	await reset()
	marshal.position = Vector3(0,.01,0)
	doctor.position = Vector3(-30,.01,0)
	friend.position = Vector3(-30,.01,5)
	second.position = Vector3(-30,.01,10)
	enemy.position = Vector3(0,.01,-3)
	hunter.position = Vector3(0,.01,-9)
	marshal.intent = CombatIntent.new()
	marshal.aim_direction = Vector3.FORWARD
	await step()

func start_march() -> void:
	marshal.intent.hover = true
	marshal.kit.tick(0,marshal.intent)
	marshal.intent.hover = false
