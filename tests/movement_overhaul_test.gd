extends SceneTree

var world: Node3D
var actor: HeroActor
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",description)

func step(frames: int = 1) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame

func reset(at: Vector3 = Vector3(0,.01,10)) -> void:
	actor.reset_actor(at)
	actor.intent.aim = Vector3.FORWARD
	await step(3)

func dash() -> void:
	actor.intent.dash = true
	await step()
	actor.intent.dash = false

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	world.add_child(CombatResolver.new())
	Geometry.box(world,Vector3(200,1,200),Vector3(0,-.5,0),Color.GRAY)
	actor = preload("res://scenes/actors/hero_actor.tscn").instantiate()
	world.add_child(actor)
	await reset()
	for hero: String in ["nimbus","slayer","marshal","doctor","huddle","relay","dynamo","wisp"]:
		actor.select_hero(hero)
		await reset()
		check(actor.motor.dash_charges == 2 and actor.motor.can_dash(),hero+" starts with two available shared dashes")
		check(is_equal_approx(actor.tuning.air_steering,9 if hero == "wisp" else 5.625),hero+" uses reduced air steering")
	actor.select_hero("nimbus")
	await reset()
	await dash()
	check(actor.motor.dash_charges == 1 and not actor.motor.can_dash(),"buildup spends one charge and prevents overlap")
	var remaining: float = actor.motor.dash_cd
	await dash()
	check(actor.motor.dash_charges == 1 and actor.motor.dash_cd < remaining,"repeated buildup input cannot spend another charge")
	await step(36)
	await dash()
	check(actor.motor.dash_charges == 0,"second dash is usable before first recharge")
	await step(36)
	await dash()
	check(actor.motor.dash_charges == 0 and actor.motor.mode != "dash_windup","third dash is rejected")
	actor.motor.tick_dash_recharge(actor.motor.dash_cd+.01)
	check(actor.motor.dash_charges == 1 and actor.motor.dash_cd > 4.2,"charges recharge sequentially")
	actor.motor.tick_dash_recharge(4.3)
	check(actor.motor.dash_charges == 2 and actor.motor.dash_cd == 0,"second recharge reaches capacity")
	await reset()
	await dash()
	actor.motor.interrupt_mobility()
	check(actor.motor.dash_charges == 1 and actor.motor.dash_cd > 0,"interrupting a dash does not refund it")
	actor.infinite_resources = true
	await step()
	check(actor.motor.dash_charges == 2 and actor.motor.dash_cd == 0,"infinite resources refill both charges")
	actor.infinite_resources = false
	await reset()
	var input := CombatIntent.new()
	input.aim = Vector3(0,.6,-.8)
	actor.motor.dash_airborne = true
	for move: Vector3 in [Vector3.FORWARD,Vector3.BACK,Vector3.RIGHT,Vector3.LEFT,Vector3(1,0,-1).normalized()]:
		input.move = move
		var direction: Vector3 = actor.motor.requested_dash_direction(input)
		check(is_equal_approx(direction.length(),1),"WASD dash direction is normalized "+str(move))
		if move == Vector3.FORWARD: check(direction.y > .59,"forward air dash preserves aim pitch")
		if move == Vector3.BACK: check(direction.y < -.59,"backward air dash reverses aim pitch")
		if move == Vector3.RIGHT: check(direction.dot(Vector3.RIGHT) > .99,"strafe air dash ignores aim pitch")
	input.move = Vector3.ZERO
	check(actor.motor.requested_dash_direction(input).is_equal_approx(input.aim),"no-input air dash uses camera aim")
	actor.motor.dash_airborne = false
	check(actor.motor.requested_dash_direction(input).y == 0,"ground dash remains horizontal")
	await reset()
	await dash()
	await step(33)
	actor.intent.slide = true
	actor.intent.slide_pressed = true
	await step()
	actor.intent.slide_pressed = false
	check(actor.motor.mode != "slide","fresh crouch after a ground dash cannot use residual momentum")
	await reset()
	actor.velocity = Vector3.FORWARD*6
	actor.intent.slide = true
	await step()
	check(actor.motor.mode == "slide","ordinary running still enters a slide")
	await reset()
	actor.motor.mantle_slide_left = .2
	actor.motor.mantle_slide_direction = Vector3.FORWARD
	actor.intent.slide = true
	actor.intent.slide_pressed = true
	await step()
	actor.intent.slide_pressed = false
	check(actor.motor.mode == "slide" and actor.motor.slide_source == "mantle" and actor.velocity.length() > 7.8,"fresh post-mantle crouch supplies a forward slide")
	check(actor.motor.mantle_slide_left == 0,"mantle slide opportunity is consumed")
	await reset()
	actor.motor.mantle_slide_left = .02
	actor.intent.slide = true
	await step(4)
	actor.intent.slide_pressed = true
	await step()
	check(actor.motor.mode != "slide","expired mantle window rejects the speed boost")
	await reset(Vector3(0,20,10))
	actor.velocity.y = -15
	actor.intent.aim = Vector3(0,.6,-.8)
	actor.intent.melee = true
	await step()
	actor.intent.melee = false
	actor.intent.aim = Vector3.RIGHT
	await step()
	check(actor.close.melee_direction == Vector3.RIGHT,"melee can aim during pre-lunge windup")
	await step(5)
	actor.intent.aim = Vector3.LEFT
	await step(6)
	check(actor.close.melee_direction == Vector3.RIGHT,"melee commits its direction when lunge starts")
	check(absf(actor.velocity.y) < .01,"air melee suspends falling for a bounded window")
	await step(20)
	check(actor.velocity.y < 0,"gravity resumes after air melee suspension")
	check(absf(actor.position.x-6) < .05,"air melee retains six-meter travel")
	await reset(Vector3(0,20,10))
	actor.intent.aim = Vector3.UP
	actor.intent.melee = true
	await step()
	actor.intent.melee = false
	await step(29)
	check(actor.position.y > 24 and actor.velocity.y < 0,"upward melee moves in 3D without retaining free upward velocity")
	for fresh: bool in [false,true]:
		await reset(Vector3(0,.6,10))
		actor.motor.dash_airborne = true
		actor.motor.dash_slide_locked = true
		actor.motor.slide_rearmed = false
		actor.motor.dash_direction = Vector3(0,-.6,-.8)
		actor.motor.dash_current_speed = 20
		actor.motor.transition("dash",.38)
		actor.intent.slide = fresh
		actor.intent.slide_pressed = fresh
		await step()
		actor.intent.slide_pressed = false
		await step(4)
		check((actor.motor.mode == "slide") == fresh,"downward air dash converts only with fresh crouch: "+str(fresh))
		if not fresh:
			actor.intent.slide = false
			await step()
			actor.intent.slide = true
			actor.intent.slide_pressed = true
			await step()
			check(actor.motor.mode != "slide","late crouch cannot bypass missed air-dash landing timing")
	await reset(Vector3(0,20,10))
	var victim := preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
	victim.team = 1
	victim.position = Vector3(0,22,10)
	world.add_child(victim)
	actor.close.melee_direction = Vector3.UP
	check(actor.close.valid_melee_target(victim),"upward melee can acquire a target above the player")
	actor.close.melee_direction = Vector3.DOWN
	check(not actor.close.valid_melee_target(victim),"3D melee cone rejects a target opposite the aimed direction")
	victim.queue_free()
	# Mantle acquisition is more generous without relaxing landing clearance.
	var high_ledge: Node3D = Geometry.box(world,Vector3(5,2.3,4),Vector3(-30,1.15,-2),Color.GRAY)
	await reset(Vector3(-30,.01,1.1))
	check(actor.motor.traversal.try_mantle(Vector3.FORWARD),"mantle catches a 2.3m ledge from the extended reach")
	actor.motor.interrupt_mobility()
	var low_ceiling: Node3D = Geometry.box(world,Vector3(6,.3,6),Vector3(-30,3.5,-2),Color.GRAY)
	await reset(Vector3(-30,.01,1.1))
	check(not actor.motor.traversal.try_mantle(Vector3.FORWARD),"forgiving mantle still rejects insufficient headroom")
	low_ceiling.queue_free()
	high_ledge.queue_free()
	var kick_wall: Node3D = Geometry.box(world,Vector3(.4,40,30),Vector3(-10.7,20,0),Color.GRAY)
	await reset(Vector3(-10,10,0))
	actor.velocity = Vector3.FORWARD*25
	actor.aim_direction = Vector3.FORWARD
	check(actor.motor.traversal.try_wall_jump(Vector3.FORWARD),"facing-led wall jump finds the side wall")
	check(actor.velocity.x >= 2.99 and actor.velocity.z < -20 and actor.velocity.length() <= 26.001,"fast wall jump preserves minimum outward clearance within speed cap")
	actor.motor.traversal.reset()
	actor.velocity = Vector3(0,0,6)
	actor.aim_direction = Vector3.LEFT
	check(actor.motor.traversal.try_wall_jump(Vector3.LEFT) and actor.velocity.x > 8.9 and absf(actor.velocity.z) < .001 and actor.velocity.y >= 9.49,"head-on wall kick launches up and back without sideways movement")
	kick_wall.queue_free()
	await reset(Vector3(0,20,10))
	actor.intent.stationary_melee = true
	actor.intent.melee = true
	await step()
	actor.intent.melee = false
	await step(8)
	check(not actor.close.melee_airborne and actor.position.y < 20 and absf(actor.position.z-10) < .01,"stationary training melee grants no lunge or suspension")
	await reset()
	actor.velocity = Vector3.FORWARD*10
	actor.intent.slide = true
	actor.intent.move = Vector3.RIGHT
	actor.motor.transition("slide")
	await step(30)
	check(actor.motor.mode == "slide" and actor.velocity.x > 1 and actor.velocity.z < -6,"WASD slightly bends an ongoing slide while retaining forward travel")
	check(actor.motor.slide_velocity.length() < 10,"slide steering does not add speed")
	await reset()
	actor.velocity = Vector3.FORWARD*10
	actor.intent.slide = true
	actor.intent.move = Vector3.BACK
	actor.motor.transition("slide")
	await step(12)
	check(absf(actor.velocity.x) < .01 and actor.velocity.z < -8,"opposing slide input cannot invent sideways motion or reverse the slide")
	# Exercise the real mantle handoff, not just the post-mantle opportunity.
	var ledge: Node3D = Geometry.box(world,Vector3(6,2,8),Vector3(30,1,-3),Color.GRAY)
	await reset(Vector3(30,.01,1.2))
	actor.intent.move = Vector3.FORWARD
	actor.intent.jump_held = true
	for frame: int in 40:
		await step()
		if actor.motor.traversal.active: break
	check(actor.motor.traversal.active,"held jump catches a reachable ledge")
	for frame: int in 30:
		if actor.motor.traversal.duration-actor.motor.traversal.elapsed <= .12: break
		await step()
	actor.motor.traversal.carried_velocity = Vector3(5,0,-6)
	actor.intent.slide = true
	actor.intent.slide_pressed = true
	await step()
	actor.intent.slide_pressed = false
	await step(9)
	actor.intent.jump_held = false
	check(actor.motor.mode == "slide" and actor.motor.slide_source == "mantle","fresh late-mantle crouch buffers into a real mantle slide")
	check(absf(actor.velocity.x) < .01 and actor.velocity.z < -6,"mantle slide exits straight across the ledge despite sideways approach momentum")
	# A wall kick leaves floor contact false and carries momentum away from
	# the wall. The mantle slide must reset it before the landing tick moves.
	await reset(Vector3(30,1.1,1.2))
	actor.intent.move = Vector3.FORWARD
	actor.intent.jump_held = true
	for frame: int in 40:
		await step()
		if actor.motor.traversal.active: break
	check(actor.motor.traversal.active,"airborne approach catches the tall-wall mantle")
	for frame: int in 30:
		if actor.motor.traversal.duration-actor.motor.traversal.elapsed <= .08: break
		await step()
	actor.motor.traversal.carried_velocity = Vector3(5,0,18)
	actor.intent.slide = true
	actor.intent.slide_pressed = true
	await step()
	actor.intent.slide_pressed = false
	for frame: int in 10:
		await step()
		if not actor.motor.traversal.active: break
	check(actor.motor.mode == "slide" and actor.motor.slide_source == "mantle","airborne mantle starts its buffered slide in the landing tick")
	check(actor.velocity.z < -7.9 and absf(actor.velocity.x) < .01,"mantle slide replaces backward and sideways wall-kick momentum with forward speed")
	var slide_start: Vector3 = actor.position
	await step(5)
	check(actor.position.z < slide_start.z-.5,"wall-kick mantle slide continues forward over the roof")
	await reset(Vector3(30,.01,1.2))
	actor.intent.move = Vector3.FORWARD
	actor.intent.jump_held = true
	actor.intent.slide = true
	actor.intent.slide_pressed = true
	await step()
	actor.intent.slide_pressed = false
	await step(38)
	check(actor.motor.slide_source != "mantle","holding crouch before mantle completion window cannot earn a mantle boost")
	await reset(Vector3(30,.01,1.2))
	actor.intent.move = Vector3.FORWARD
	actor.intent.jump_held = true
	for frame: int in 45:
		await step()
		if actor.motor.traversal.active: break
	for frame: int in 30:
		if actor.motor.traversal.duration-actor.motor.traversal.elapsed <= .08: break
		await step()
	actor.intent.slide = true
	actor.intent.slide_pressed = true
	actor.intent.jump = true
	await step()
	actor.intent.jump = false
	actor.intent.slide_pressed = false
	await step(6)
	check(actor.velocity.y > 0 and actor.motor.slide_source != "mantle","buffered exit jump takes priority over mantle slide")
	await reset(Vector3(30,.01,1.2))
	actor.intent.move = Vector3.FORWARD
	actor.intent.jump_held = true
	for frame: int in 40:
		await step()
		if actor.motor.traversal.active: break
	actor.motor.mantle_slide_buffered = true
	actor.motor.interrupt_mobility()
	check(not actor.motor.traversal.active and not actor.motor.mantle_slide_buffered,"interruption clears pending mantle slide")
	ledge.queue_free()
	await reset()
	await dash()
	var recharge_before: float = actor.motor.dash_cd
	paused = true
	for frame: int in 8: await process_frame
	check(actor.motor.dash_cd == recharge_before,"pausing freezes dash recharge")
	paused = false
	await reset()
	await dash()
	await step(10)
	var committed: Vector3 = actor.motor.dash_direction
	actor.intent.move = Vector3.RIGHT
	actor.intent.aim = Vector3.LEFT
	await step(10)
	check(actor.motor.dash_direction == committed,"active dash cannot be redirected by camera or WASD")
	var distances: Array[float] = []
	for speed: float in [22.0,20.0]:
		await reset()
		actor.tuning.dash_speed = speed
		await dash()
		await step(9)
		var start: Vector3 = actor.position
		while actor.motor.mode in ["dash","dash_windup"]: await step()
		distances.append(start.distance_to(actor.position))
	check(distances[1]/distances[0] > .84 and distances[1]/distances[0] < .94,"new dash travels approximately ten percent less than old dash")
	actor.tuning.dash_speed = 20
	distances.clear()
	for friction: float in [3.6,4.0]:
		await reset()
		actor.tuning.slide_friction = friction
		actor.velocity = Vector3.FORWARD*10
		actor.intent.slide = true
		actor.motor.transition("slide")
		var start: Vector3 = actor.position
		while actor.motor.mode == "slide":
			await step()
		distances.append(start.distance_to(actor.position))
	check(distances[1]/distances[0] > .87 and distances[1]/distances[0] < .93,"flat slide travels approximately ten percent less from equal entry speed")
	actor.tuning.slide_friction = 4
	print("MOVEMENT_OVERHAUL_RESULT ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
