extends SceneTree

var actor: HeroActor
var world: Node3D
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",description)

func tick(dt: float, count: int = 1) -> void:
	for i: int in count: actor.motor.tick(dt,actor.intent)

func reset(at: Vector3 = Vector3(0,.01,20)) -> void:
	actor.reset_actor(at)
	actor.intent.aim = Vector3.FORWARD
	for i: int in 3: tick(1.0/Engine.physics_ticks_per_second)

func horizontal() -> float:
	return Vector2(actor.velocity.x,actor.velocity.z).length()

func burst(dt: float) -> void:
	actor.intent.dash = true
	tick(dt)
	actor.intent.dash = false
	for i: int in 100:
		if actor.motor.mode not in ["dash","dash_windup"]: return
		tick(dt)
	check(false,"dash terminates")

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	world.add_child(CombatResolver.new())
	Geometry.box(world,Vector3(200,1,200),Vector3(0,-.5,0),Color.GRAY)
	Geometry.box(world,Vector3(8,20,.1),Vector3(-10,10,5),Color.GRAY)
	Geometry.box(world,Vector3(8,2,5),Vector3(-25,1,0),Color.GRAY)
	actor = preload("res://scenes/actors/hero_actor.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	await physics_frame
	await process_frame
	for hz: int in [30,60,144]:
		Engine.physics_ticks_per_second = hz
		await physics_frame
		var dt: float = 1.0/hz
		var label: String = " at %d Hz" % hz
		# Upstream angular steering remains the hover fallback; ordinary air
		# uses the accepted projection-based strafing covered below.
		actor.motor.mode = "hover"
		for launch_speed: float in [6.0,18.0]:
			actor.velocity = Vector3.FORWARD * launch_speed
			for i: int in hz/2:
				actor.velocity = actor.motor.steer_horizontal(actor.velocity,Vector3.RIGHT,6,false,false,dt)
			var turned: float = absf(rad_to_deg(Vector3.FORWARD.signed_angle_to(actor.velocity * Vector3(1,0,1),Vector3.UP)))
			check(absf(turned-22.5) < 1 and absf(horizontal()-launch_speed) < .001,"hover turn rate and speed at %s m/s" % launch_speed+label)
		var velocity: Vector3 = Vector3.FORWARD * 18
		for i: int in hz/2:
			velocity = actor.motor.steer_horizontal(velocity,Vector3.RIGHT*.5,6,false,false,dt)
		check(absf(rad_to_deg(Vector3.FORWARD.angle_to(velocity))-11.25) < .01 and absf(velocity.length()-18) < .001,"analog input scales turning without speed loss"+label)
		var stopped: Vector3 = actor.motor.steer_horizontal(Vector3.FORWARD*.01,Vector3.BACK,6,false,false,dt)
		check(stopped.is_zero_approx(),"opposite input stops before reversing"+label)
		check(actor.motor.steer_horizontal(stopped,Vector3.BACK,6,false,false,dt).z > 0,"input accelerates backward after stopping"+label)
		var full_brake: Vector3 = actor.motor.steer_horizontal(Vector3.FORWARD*18,Vector3.BACK,6,false,false,dt)
		var half_brake: Vector3 = actor.motor.steer_horizontal(Vector3.FORWARD*18,Vector3.BACK*.5,6,false,false,dt)
		check(absf((18-half_brake.length())*2-(18-full_brake.length())) < .001,"analog input scales braking"+label)
		var near_heading: Vector3 = Vector3.FORWARD.rotated(Vector3.UP,deg_to_rad(.01))
		velocity = actor.motor.steer_horizontal(Vector3.FORWARD*18,near_heading,6,false,false,dt)
		check(velocity.normalized().distance_to(near_heading) < .00001,"turn clamps at requested heading"+label)
		actor.tuning.air_turn_degrees = 0
		velocity = actor.motor.steer_horizontal(Vector3.FORWARD*18,Vector3.RIGHT,6,false,false,dt)
		check(velocity.distance_to(Vector3.FORWARD*18) < .001,"zero turn rate preserves heading"+label)
		actor.tuning.air_turn_degrees = 45
		velocity = Vector3.ZERO
		for i: int in hz*2:
			velocity = actor.motor.steer_horizontal(velocity,Vector3.RIGHT,6,false,false,dt)
		check(absf(velocity.length()-6) < .001 and velocity.x > 0,"air acceleration from rest stops at running speed"+label)
		reset(Vector3(0,60,20))
		actor.velocity = Vector3(0,11,-18)
		tick(dt,hz/2)
		check(absf(horizontal()-18) < .001,"neutral air retains earned speed"+label)
		actor.intent.move = Vector3.RIGHT
		tick(dt,hz/2)
		check(absf(horizontal()-18) < .001 and actor.velocity.x > 1,"air steering redirects earned overspeed without adding more"+label)
		actor.intent.move = -(actor.velocity * Vector3(1,0,1)).normalized()
		var prior: float = horizontal()
		tick(dt)
		check(horizontal() < prior and horizontal() > 0,"opposing air input brakes"+label)
		reset()
		actor.velocity = Vector3.FORWARD*18
		actor.intent.move = Vector3.FORWARD
		tick(dt,hz/2)
		check(absf(horizontal()-15) <= .21,"aligned ground input sheds excess at six meters per second squared"+label)
		actor.intent.move = Vector3.ZERO
		tick(dt,hz/2)
		check(absf(horizontal()-3) <= .81,"ground release keeps responsive braking"+label)
		actor.intent.move = Vector3.BACK
		tick(dt)
		check(actor.velocity.z <= .001,"ground reversal brakes before reversing"+label)
		reset()
		actor.velocity = Vector3.FORWARD*18
		actor.intent.move = Vector3.FORWARD
		actor.intent.jump = true
		tick(dt)
		actor.intent.jump = false
		check(actor.velocity.y > 7.9 and horizontal() > 17.7,"jump preserves horizontal momentum and ordinary lift"+label)
		for i: int in hz*2:
			tick(dt)
			if actor.motor.grounded(): break
		check(actor.motor.grounded() and horizontal() > 17.5,"landing does not impose a speed reset"+label)
		reset()
		actor.velocity = Vector3.FORWARD*18
		actor.intent.dash = true
		tick(dt)
		actor.intent.dash = false
		check(absf(horizontal()-18) < .01,"dash buildup preserves momentum"+label)
		reset()
		actor.intent.slide = true
		burst(dt)
		check(actor.motor.mode == "slide" and actor.motor.slide_source == "ground_dash","held Shift enters ground dash slide"+label)
		check(horizontal() > 9 and horizontal() < 11 and actor.motor.dash_charges == 1,"dash slide transfers decayed speed without boost or refund"+label)
		actor.intent.slide = false
		var slide_speed: float = horizontal()
		tick(dt)
		check(horizontal() <= slide_speed+.001 and horizontal() > slide_speed-.15,"slide release has no handoff speed cut"+label)
		reset(Vector3(0,30,20))
		actor.intent.aim = Vector3.UP
		var start_y: float = actor.position.y
		burst(dt)
		check(is_equal_approx(actor.motor.dash_direction.y,.5) and actor.velocity.y < 2,"upward dash uses thirty degree cap and gravity"+label)
		var apex: float = actor.position.y
		for i: int in hz:
			tick(dt)
			apex = maxf(apex,actor.position.y)
		check(apex-start_y < 2.5 and apex > start_y,"upward dash has bounded physical apex"+label)
		print("DASH_APEX hz=%d rise=%.4f" % [hz,apex-start_y])
		reset(Vector3(-10,5,5.55))
		check(actor.motor.traversal.try_wall_jump(Vector3.FORWARD) and is_equal_approx(actor.velocity.y,8),"wall jump supplies only ordinary-jump lift"+label)
		start_y = actor.position.y
		apex = start_y
		for i: int in hz:
			tick(dt)
			apex = maxf(apex,actor.position.y)
			if actor.velocity.y <= 0: break
		check(apex-start_y > 1.2 and apex-start_y < 1.5,"wall jump has reduced physical apex"+label)
		print("WALL_APEX hz=%d rise=%.4f" % [hz,apex-start_y])
		reset(Vector3(-10,5,5.55))
		actor.velocity.y = 12
		check(actor.motor.traversal.try_wall_jump(Vector3.FORWARD) and is_equal_approx(actor.velocity.y,12),"wall jump retains stronger incoming lift"+label)
		reset(Vector3(-25,.01,3.2))
		actor.velocity = Vector3.FORWARD*12
		actor.intent.move = Vector3.FORWARD
		actor.intent.jump = true
		tick(dt)
		actor.intent.jump = false
		var carried: Vector3 = actor.motor.traversal.carried_velocity
		check(actor.motor.traversal.active,"fast approach catches real mantle"+label)
		for i: int in hz:
			if not actor.motor.traversal.active: break
			tick(dt)
		check(actor.position.y > 2 and absf(horizontal()-carried.length()) < .01,"mantle exit returns entry momentum"+label)
		tick(dt)
		check(horizontal() > carried.length()-.21,"post-mantle running uses gentle excess-speed decay"+label)
		reset(Vector3(0,10,20))
		actor.velocity = Vector3(0,0,-18)
		actor.state = "guard"
		actor.intent.move = Vector3.FORWARD
		tick(dt,hz/2)
		check(horizontal() < 7,"guard brakes even while airborne"+label)
		reset(Vector3(0,10,20))
		actor.velocity = Vector3(0,0,-18)
		actor.statuses.effects["root"] = {}
		actor.motor.external_velocity = Vector3.RIGHT*8
		var x: float = actor.position.x
		tick(dt)
		check(horizontal() < .001 and actor.position.x > x and actor.motor.external_velocity.x > 0,"root stops voluntary travel but preserves enemy shove"+label)
		actor.motor.cancel()
		check(actor.motor.dash_vertical_speed == 0 and actor.motor.external_velocity.is_zero_approx(),"reset retires transient dash and knockback"+label)
		reset(Vector3(0,10,20))
		actor.motor.dash_airborne = true
		actor.intent.aim = Vector3.DOWN
		actor.intent.move = Vector3.BACK
		check(is_equal_approx(actor.motor.requested_dash_direction(actor.intent).y,.5),"backward upward request also respects cap"+label)
		actor.intent.move = Vector3.ZERO
		check(actor.motor.requested_dash_direction(actor.intent) == Vector3.DOWN,"downward dash remains unrestricted"+label)
	Engine.physics_ticks_per_second = 60
	await physics_frame
	# Real collision: the next tick must use the blocked velocity, not restore it.
	var wall: Node3D = Geometry.box(world,Vector3(10,8,.1),Vector3(0,4,15),Color.GRAY)
	await physics_frame
	await process_frame
	reset()
	actor.velocity = Vector3.FORWARD*24
	burst(1.0/60)
	actor.intent.move = Vector3.ZERO
	tick(1.0/60,10)
	check(actor.position.z > 15.3 and horizontal() < .01,"thin wall removes blocked dash momentum permanently")
	wall.queue_free()
	actor.select_hero("stitch")
	check(is_equal_approx((actor.tuning as StitchTuning).hook_release_up,9.5) and actor.tuning.wall_jump_up == 8,"Stitch hook lift remains independent of shared wall jump")
	actor.select_hero("wisp")
	actor.motor.mode = "hover"
	var wisp_velocity: Vector3 = Vector3.FORWARD*18
	for i: int in 30:
		wisp_velocity = actor.motor.steer_horizontal(wisp_velocity,Vector3.RIGHT,actor.tuning.ground_speed,false,false,1.0/60)
	check(absf(rad_to_deg(Vector3.FORWARD.angle_to(wisp_velocity))-36) < .01 and absf(wisp_velocity.length()-18) < .001,"Wisp retains its compatible angular hover steering tuning")
	world.queue_free()
	await process_frame
	print("MOMENTUM FLOW: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
