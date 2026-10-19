extends SceneTree

var world: Node3D
var actor: HeroActor
var resolver: CombatResolver
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

func reset(at: Vector3) -> void:
	actor.reset_actor(at)
	await step(3)
	resolver.events.clear()

func casts(ability: String) -> int:
	var count: int = 0
	for event: Dictionary in resolver.events:
		if event.event == "cast" and event.ability == ability: count += 1
	return count

func kick(velocity: Vector3, wish: Vector3 = Vector3.FORWARD, aim: Vector3 = Vector3.FORWARD) -> void:
	actor.velocity = velocity
	actor.intent.move = wish
	actor.intent.aim = aim
	actor.intent.jump = true
	await step()
	actor.intent.jump = false

func run() -> void:
	TrainingInputs.install()
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(100,1,100),Vector3(0,-.5,0),Color.GRAY)
	Geometry.box(world,Vector3(4,2,3),Vector3(0,1,-2),Color.GRAY)
	Geometry.box(world,Vector3(4,3.8,3),Vector3(0,1.9,-5),Color.GRAY)
	actor = preload("res://scenes/actors/hero_actor.tscn").instantiate()
	world.add_child(actor)
	await reset(Vector3(0,.01,2.2))
	var controller := PlayerController.new()
	controller.actor = actor
	actor.add_child(controller)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await step(5)
	var held: CombatIntent = controller.gather_intent(1.0 / 60)
	# The headless display cannot capture a mouse. Its physical action state is
	# checked here; the rendered run also exercises the controller's capture gate.
	if DisplayServer.get_name() == "headless":
		check(Input.is_action_pressed("jump") and not Input.is_action_just_pressed("jump"), "holding physical Space outlives its press edge")
	else:
		check(held.jump_held and not held.jump, "captured controller retains physical Space hold after its press edge expires")
	key.pressed = false
	Input.parse_input_event(key)
	await step()
	check(not Input.is_action_pressed("jump") and not controller.gather_intent(1.0 / 60).jump_held, "releasing physical Space clears the held mantle request")
	controller.queue_free()
	await step(2)
	await reset(Vector3(0,.01,2.2))
	actor.intent.jump_held = true
	actor.intent.move = Vector3.FORWARD
	for frame: int in 65:
		await step()
		if actor.state == "mantle": break
	check(actor.state == "mantle" and not actor.intent.jump, "holding Space before reaching a ledge automatically catches it without another press")
	for frame: int in 115:
		await step()
		if casts("mantle") == 2 and actor.state == "ready": break
	check(casts("mantle") == 2 and actor.global_position.y >= 3.79, "one continuous Space hold and forward movement climb two successive tower ledges")
	check(casts("wall_jump") == 0, "automatic mantling does not generate wall kicks")
	await reset(Vector3(0,.01,.2))
	actor.intent.jump_held = true
	await step(20)
	check(casts("mantle") == 0 and actor.global_position.y < .05, "holding Space without moving into a ledge does not grab or repeatedly jump")
	actor.intent.move = Vector3.BACK
	await step(20)
	check(casts("mantle") == 0, "holding Space while moving away does not grab the ledge behind movement")
	await reset(Vector3(0,.01,2.2))
	actor.intent.jump_held = true
	actor.intent.move = Vector3.FORWARD
	await step(10)
	actor.intent.jump_held = false
	await step(32)
	check(casts("mantle") == 0 and actor.global_position.y < .05, "releasing Space before reaching the wall prevents automatic mantling")
	Geometry.box(world,Vector3(4,3.4,3),Vector3(-10,1.7,-2),Color.GRAY)
	await reset(Vector3(-10,.01,.2))
	actor.intent.jump = true
	actor.intent.jump_held = true
	actor.intent.move = Vector3.FORWARD
	await step()
	actor.intent.jump = false
	for frame: int in 25:
		await step()
		if actor.state == "mantle": break
	check(actor.state == "mantle", "a single held jump catches a higher tower as the ledge comes into reach")
	await step(40)
	check(actor.global_position.y > 3.39, "jump-to-mantle completes without releasing or pressing Space again")
	await reset(Vector3(-10,.01,.2))
	actor.intent.jump = true
	actor.intent.move = Vector3.FORWARD
	await step()
	actor.intent.jump = false
	await step(25)
	check(casts("mantle") == 0, "releasing the jump button requires another press or hold to catch a higher ledge")
	var roof: Node3D = Geometry.box(world,Vector3(5,.25,6),Vector3(0,3.6,-1),Color.GRAY)
	await reset(Vector3(0,.01,.2))
	actor.intent.jump_held = true
	actor.intent.move = Vector3.FORWARD
	await step(24)
	check(casts("mantle") == 0, "automatic mantle retains full standing clearance checks")
	roof.queue_free()
	Geometry.box(world,Vector3(.4,12,30),Vector3(19.3,6,0),Color.GRAY)
	Geometry.box(world,Vector3(.4,12,30),Vector3(30.7,6,0),Color.GRAY)
	await reset(Vector3(20,3,0))
	await kick(Vector3(0,0,-6))
	check(actor.velocity.x >= 2.9 and actor.velocity.z < -8.3, "left-wall kick favors forward facing with safe outward escape")
	var start: Vector3 = actor.global_position
	await step(8)
	check(actor.global_position.x > start.x + .3 and actor.global_position.z < start.z - .9, "the real capsule travels forward and right after the kick")
	await reset(Vector3(30,3,0))
	await kick(Vector3(0,0,-6))
	check(actor.velocity.x <= -2.9 and actor.velocity.z < -8.3, "right-wall kick favors forward facing with safe outward escape")
	await reset(Vector3(20,3,0))
	await kick(Vector3(0,0,-16))
	check(actor.velocity.z < -15.5, "facing-led kick retains faster incoming speed")
	await reset(Vector3(20,3,0))
	await kick(Vector3(0,0,-6),Vector3.ZERO,Vector3.BACK)
	check(actor.velocity.z > 8.3 and actor.velocity.x >= 2.9, "looking backward redirects the wall jump backward")
	await reset(Vector3(20,3,0))
	await kick(Vector3(0,0,6),Vector3.ZERO)
	check(actor.velocity.z < -8.3, "forward facing redirects incoming backward momentum")
	await reset(Vector3(20,3,0))
	await kick(Vector3(-4,0,-6))
	check(actor.velocity.x >= 2.9 and actor.velocity.z < -8.3, "inward momentum is replaced by facing-led travel and safe clearance")
	await reset(Vector3(20,3,0))
	await kick(Vector3(10,0,-6))
	check(actor.velocity.z < -11 and actor.velocity.x >= 2.9, "a faster incoming speed is redirected toward facing")
	await reset(Vector3(20,3,0))
	await kick(Vector3(0,12,-6))
	check(actor.velocity.y > 11, "a kick preserves stronger existing upward motion")
	await reset(Vector3(20,3,0))
	await kick(Vector3(0,0,-25))
	check(actor.velocity.length() <= actor.tuning.speed_limit + .001, "combined kick and carried momentum still obey the global speed cap")
	var wall: Node3D = Geometry.box(world,Vector3(10,12,.4),Vector3(-25,6,0),Color.GRAY)
	wall.rotation.y = PI / 4
	var normal := Vector3(1,0,1).normalized()
	var parallel := Vector3(1,0,-1).normalized()
	await reset(Vector3(-25,3,0) + normal * .8)
	await kick(parallel * 8,parallel)
	check(actor.velocity.dot(parallel) > 8.3 and actor.velocity.dot(normal) >= 2.9, "angled-wall kicks constrain facing direction against the true wall normal")
	await reset(Vector3(20,3,0))
	actor.intent.jump_held = true
	actor.intent.move = Vector3.FORWARD
	await step(22)
	check(casts("wall_jump") == 0, "holding Space beside a tall wall does not automatically kick")
	await kick(Vector3(0,0,-6))
	await step(20)
	check(casts("wall_jump") == 1, "a deliberate kick still needs a new press for subsequent wall jumps")
	print("TRAVERSAL FLOW RESULT: %d checks, %d failures" % [checks,failures.size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/traversal-flow-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
