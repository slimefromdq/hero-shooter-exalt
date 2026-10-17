extends SceneTree

var arena: Node
var training: TrainingManager
var player: HeroActor
var checks: int = 0
var failures: Array[String] = []
var camera_controller: PlayerController

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	print("PASS  " if condition else "FAIL  ", description)
	if not condition: failures.append(description)

func step(frames: int) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame

func event_count(kind: String) -> int:
	var count: int = 0
	for entry: Dictionary in player.resolver.events:
		if entry["event"] == kind: count += 1
	return count

func run() -> void:
	seed(76)
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	training = arena.training
	player = arena.player
	camera_controller = player.controller as PlayerController
	player.controller.active = false
	player.controller = null # Feed deterministic intent through the same actor pipeline.
	await step(3)
	check(training.bots.size() == 15 and player.alive, "training launches into the persistent practice range")
	check(not training.infinite and not training.god_mode and not training.freeze_ai, "ordinary rules are the launch defaults")
	var camera_wall: Node3D = Geometry.box(arena, Vector3(5,5,0.35), player.global_position + Vector3(0,2.5,1.5), Color.GRAY)
	await step(4)
	check(camera_controller.arm.get_hit_length() < 2.0, "third-person camera pulls forward before entering nearby geometry")
	camera_wall.queue_free()
	await step(4)
	check(absf(camera_controller.arm.get_hit_length() - camera_controller.camera_distance) < .25, "camera restores its configured shoulder distance after obstruction clears")
	for action: String in ["primary","aim","jump","dash","slide","melee","guard","throw","hover","deflect","bomb","ultimate"]:
		check(InputMap.has_action(action), "named input action exists: " + action)
	var key := InputEventKey.new()
	key.device = 0
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await step(1)
	check(Input.is_action_pressed("move_forward"), "physical keyboard event activates the saved movement binding")
	key.pressed = false
	Input.parse_input_event(key)
	var mouse := InputEventMouseButton.new()
	mouse.device = 0
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await step(1)
	check(Input.is_action_pressed("primary"), "physical mouse event activates the saved rifle binding")
	mouse.pressed = false
	Input.parse_input_event(mouse)
	# Rifle exercise: real shots, live actor processing, target death and auto respawn.
	training.scenario = 1
	training.reset_scenario()
	await step(4)
	var target: HeroActor = training.bots[0]
	for shot: int in 6:
		player.intent.aim_origin = player.global_position + Vector3.UP * 1.2
		player.intent.aim = (target.global_position + Vector3.UP * 1.2 - player.intent.aim_origin).normalized()
		player.intent.primary = true
		await step(1)
		player.intent.primary = false
		await step(37)
	check(not target.alive and training.eliminations == 1 and training.hits == 6, "stationary scenario supports a complete six-body-shot elimination")
	await step(225)
	check(target.alive and target.health == 250, "eliminated training target respawns cleanly")
	training.scenario = 2
	training.reset_scenario()
	await step(5)
	target = training.bots[0]
	var at: Vector3 = target.global_position
	await step(90)
	check(target.global_position.distance_to(at) > 1, "strafing target follows a moving authored lane")
	training.freeze_ai = true
	await step(30)
	at = target.global_position
	await step(30)
	check(target.global_position.distance_to(at) < 0.05, "freeze AI stops bot movement intent")
	training.freeze_ai = false
	training.scenario = 0
	training.reset_scenario()
	await step(240)
	check(player.health < 250, "ranged bot perceives and damages Nimbus with physical projectiles")
	# LOS: an actual occluder between a ranged bot and Nimbus prevents firing.
	training.reset_scenario()
	target = training.bots[0]
	target.reset_actor(Vector3(0,0.1,1))
	var cover: Node3D = Geometry.box(arena, Vector3(12,5,0.8), Vector3(0,2.5,6), Color.GRAY)
	await step(3)
	var start_hp: float = player.health
	await step(80)
	check(player.health == start_hp, "ranged bot respects occluded sightlines")
	cover.queue_free()
	training.despawn_bots()
	target = training.spawn_bot(BotController.Profile.BRAWLER, player.global_position + Vector3(0,0,-2))
	await step(180)
	check(player.health < start_hp, "close attacker approaches and uses shared committed melee")
	training.scenario = 3
	training.reset_scenario()
	await step(30)
	check(event_count("cast") > 0 and training.bots[0].state == "guard", "sparring bot demonstrates held guard with a visible state")
	target = training.bots[0]
	training.reaction = 0.12
	training.error_chance = 0.0
	training.apply_bot_settings()
	target.reset_actor(player.global_position + Vector3(0,0,-1.4))
	target.intent.aim = Vector3.BACK
	await step(20)
	player.intent.throw_action = true
	await step(1)
	player.intent.throw_action = false
	await step(20)
	check(event_count("counterthrow") > 0, "sparring bot reacts to a throw with the configured delay")
	# Exercise reset while two actors are paired and transient attacks exist.
	training.freeze_ai = true
	player.reset_actor(Vector3(0,0.1,11))
	target.reset_actor(Vector3(0,0.1,9.6))
	target.close.last_throw_time = -100
	await step(3)
	player.close.start_throw()
	await step(19)
	check(player.state == "throw_pair", "integrated scenario can enter paired capture")
	training.reset_scenario()
	await step(3)
	check(player.state == "ready" and player.close.pair == null and get_nodes_in_group("owned_attacks").is_empty(), "scenario reset clears captures, projectiles, cooldowns and control restrictions")
	training.freeze_ai = false
	training.scenario = 4
	training.reset_scenario()
	await step(3)
	check(training.bots.size() == 2 and training.bots[1].team == 2, "crossfire laboratory supplies an independent-team interference probe")
	training.toggle_menu()
	check(paused and training.hud.menu.visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "training console pauses simulation and releases mouse")
	training.toggle_menu()
	check(not paused and not training.hud.menu.visible, "returning to field resumes simulation")
	training.scenario = 5
	training.reset_scenario()
	await step(4)
	check(training.bots.is_empty() and player.global_position.x > 15, "traversal scenario starts at the dedicated route")
	training.start_route()
	await step(10)
	check(training.route_running and training.route_time > 0, "timed route records elapsed movement time")
	for iteration: int in 6:
		training.scenario = iteration
		training.reset_scenario()
		await step(3)
	check(player.alive and get_nodes_in_group("actors").size() == 1, "repeated scene resets leave no orphan actors or paired states")
	print("INTEGRATION RESULT: %d checks, %d failures" % [checks, failures.size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/integration-results.json",FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"checks": checks,"failures": failures},"\t"))
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
