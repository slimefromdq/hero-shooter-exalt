extends SceneTree

var world: Node3D
var actor: HeroActor
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	print("PASS  " if condition else "FAIL  ",description)
	if not condition: failures.append(description)

func step(frames: int = 1) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame

func begin(velocity: Vector3, wish: Vector3 = Vector3.FORWARD) -> Vector3:
	actor.reset_actor(Vector3(0,.01,.2))
	await step(3)
	actor.velocity = velocity
	actor.intent.move = wish
	actor.intent.jump_held = true
	actor.intent.jump = true
	await step()
	actor.intent.jump = false
	return actor.motor.traversal.carried_velocity

func finish() -> void:
	for frame: int in 35:
		if not actor.motor.traversal.active: break
		await step()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var resolver := CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(60,1,60),Vector3(0,-.5,0),Color.GRAY)
	Geometry.box(world,Vector3(12,2,12),Vector3(0,1,-6.5),Color.GRAY)
	actor = preload("res://scenes/actors/hero_actor.tscn").instantiate()
	world.add_child(actor)
	var carried: Vector3 = await begin(Vector3.FORWARD * 6)
	check(actor.state == "mantle" and is_equal_approx(actor.motor.traversal.duration,.32), "mantle uses the faster 0.32 s default")
	await finish()
	check(actor.motor.traversal.elapsed >= .32 and actor.motor.traversal.elapsed < .35, "the full climb completes within 0.35 s at 60 Hz")
	check(actor.state == "ready" and actor.is_on_floor(), "completion immediately returns grounded control")
	check((actor.velocity * Vector3(1,0,1)).is_equal_approx(carried) and is_equal_approx(actor.velocity.z,-6), "running momentum is restored instead of resetting to zero")
	check(actor.global_position.z < actor.motor.traversal.landing.z - .08, "carried movement advances the capsule in the completion tick")
	var from: Vector3 = actor.global_position
	await step(6)
	check(from.z - actor.global_position.z > .55 and is_equal_approx(actor.velocity.z,-6), "holding forward flows directly into full-speed running")
	check(actor.global_position.y < 2.06, "holding auto-mantle Space alone does not jump at the top")
	await begin(Vector3.ZERO)
	await finish()
	check(is_equal_approx(actor.velocity.z,-6), "continuing forward through a slow approach builds into running speed at the exit")
	carried = await begin(Vector3(2.5,0,-12))
	actor.intent.aim = Vector3.RIGHT
	actor.intent.move = Vector3.RIGHT
	await finish()
	check((actor.velocity * Vector3(1,0,1)).is_equal_approx(carried), "diagonal high-speed momentum survives the climb without camera redirection")
	check(actor.velocity.length() > 10, "mantling does not clamp a fast approach down to ordinary run speed")
	await begin(Vector3.ZERO,Vector3.ZERO)
	await finish()
	check((actor.velocity * Vector3(1,0,1)).length() < .01, "a stationary mantle does not manufacture horizontal momentum")
	carried = await begin(Vector3.FORWARD * 6)
	while actor.motor.traversal.active and actor.motor.traversal.progress < .72:
		await step()
	actor.intent.jump_held = false
	actor.intent.jump = true
	await step()
	actor.intent.jump = false
	await finish()
	check(actor.state == "ready" and actor.velocity.y > 7.5 and not actor.is_on_floor(), "a fresh jump near the end launches on the completion tick")
	check((actor.velocity * Vector3(1,0,1)).is_equal_approx(carried), "buffered exit jump retains the same horizontal momentum")
	check(actor.global_position.y > 2.1 and actor.motor.jump_buffer == 0, "exit jump moves upward immediately and consumes its buffer once")
	await begin(Vector3.FORWARD * 6)
	actor.intent.jump = true
	await step()
	actor.intent.jump = false
	await finish()
	check(actor.is_on_floor() and actor.velocity.y <= 0, "an early press expires rather than producing an unintended rooftop jump")
	await begin(Vector3.FORWARD * 6)
	await finish()
	actor.intent.jump_held = false
	actor.intent.jump = true
	await step()
	actor.intent.jump = false
	check(actor.velocity.y > 7 and not actor.is_on_floor(), "jump is available immediately after mantle without waiting for a landing frame")
	await begin(Vector3.FORWARD * 26)
	while actor.motor.traversal.active and actor.motor.traversal.progress < .75:
		await step()
	actor.intent.jump = true
	await step()
	actor.intent.jump = false
	await finish()
	check(actor.velocity.length() <= actor.tuning.speed_limit + .001 and actor.velocity.y > 0, "a fast exit jump still obeys the combined movement speed cap")
	await begin(Vector3.FORWARD * 10)
	await step(2)
	actor.reset_actor(Vector3(8,.01,8))
	await step(12)
	check(actor.motor.traversal.carried_velocity == Vector3.ZERO and actor.velocity.length() < .01, "reset discards stored mantle momentum")
	await begin(Vector3.FORWARD * 10)
	await step(2)
	actor.close.stagger()
	await step()
	check(actor.state == "stagger" and actor.motor.traversal.carried_velocity == Vector3.ZERO and absf(actor.velocity.z) < .01, "stagger cancels the stored exit speed without releasing a movement burst")
	await begin(Vector3.FORWARD * 10)
	await step(2)
	var obstacle: Node3D = Geometry.box(world,Vector3(5,.2,6),Vector3(0,3,-1),Color.GRAY)
	for frame: int in 12:
		await step()
		if not actor.motor.traversal.active: break
	check(not actor.motor.traversal.active and actor.motor.traversal.carried_velocity == Vector3.ZERO and absf(actor.velocity.z) < .01, "an obstructed climb aborts without restoring its carried speed")
	obstacle.queue_free()
	await begin(Vector3.FORWARD * 12)
	obstacle = Geometry.box(world,Vector3(5,2,.2),Vector3(0,3,-1.7),Color.GRAY)
	await finish()
	check(actor.state == "ready" and actor.global_position.z > -1.25 and absf(actor.velocity.z) < .01, "restored exit momentum collides normally with an obstacle beyond the landing")
	print("MANTLE EXIT RESULT: %d checks, %d failures" % [checks,failures.size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/mantle-exit-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
