extends SceneTree

var arena: Node
var training: TrainingManager
var player: HeroActor
var bot: HeroActor
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

func cast_count() -> int:
	var count: int = 0
	for event: Dictionary in player.resolver.events:
		if event["event"] == "cast" and event["ability"] == "melee" and event["actor"] == bot.actor_id:
			count += 1
	return count

func run() -> void:
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	training = arena.training
	player = arena.player
	player.controller.active = false
	player.controller = null
	training.scenario = 6
	training.reset_scenario()
	await step(4)
	bot = training.bots[0]
	check(training.bots.size() == 1 and (bot.controller as BotController).profile == BotController.Profile.GUARD_TRAINER,"guard drill spawns the stationary melee profile")
	var requested: Dictionary = {"hover":KEY_Q,"deflect":KEY_E,"bomb":KEY_1,"ultimate":KEY_2,"slide":KEY_SHIFT,"melee":KEY_5,"throw":KEY_4,"guard":KEY_6}
	for action: String in requested:
		var key := InputEventKey.new()
		key.device = 0
		key.physical_keycode = requested[action]
		key.pressed = true
		Input.parse_input_event(key)
		await step()
		check(Input.is_action_pressed(action),"physical key activates requested binding: " + action)
		var exclusive: bool = true
		for other: String in requested:
			if other != action and Input.is_action_pressed(other): exclusive = false
		check(exclusive,"binding does not also trigger another combat action: " + action)
		key.pressed = false
		Input.parse_input_event(key)
		await step()
	for legacy: int in [KEY_V,KEY_C,KEY_F,KEY_G,KEY_X,KEY_CTRL]:
		var key := InputEventKey.new()
		key.physical_keycode = legacy
		key.pressed = true
		Input.parse_input_event(key)
		await step()
		var unused: bool = true
		for action: String in requested:
			if Input.is_action_pressed(action): unused = false
		check(unused,"old combat key is removed: " + OS.get_keycode_string(legacy))
		key.pressed = false
		Input.parse_input_event(key)
		await step()
	check(TrainingInputs.key_label("hover") == "Q" and TrainingInputs.key_label("deflect") == "E" and TrainingInputs.key_label("guard") == "6","HUD captions read the current input map")
	var anchor: Vector3 = bot.global_position
	await step(60)
	check(cast_count() == 0 and player.health == 250,"stationary trainer waits without attacking outside 2.4 m")
	player.reset_actor(anchor + Vector3(0,0,2.3))
	player.intent.guard = true
	await step(40)
	var blocked: bool = false
	for event: Dictionary in player.resolver.events:
		if event["event"] == "block" and event["actor"] == player.actor_id: blocked = true
	check(blocked and player.health == 250,"entering the range produces a shared melee strike that frontal guard stops")
	check(bot.state == "stagger","guard staggers the stationary trainer through the shared combat resolver")
	check(bot.global_position.distance_to(anchor) < .03,"guard trainer stays planted during the attack instead of lunging")
	player.intent.guard = false
	await step(110)
	check(player.health < 250 and cast_count() >= 2,"trainer repeats real damaging strikes at its configured interval")
	check(bot.global_position.distance_to(anchor) < .03,"repeated trainer strikes never chase or advance")
	training.guard_test_range = 1.0
	training.apply_bot_settings()
	player.reset_actor(anchor + Vector3(0,0,1.8))
	await step(40)
	var before: int = cast_count()
	await step(100)
	check(cast_count() == before and player.health == 250,"lowering the trigger range stops strikes beyond the new threshold")
	var controller: BotController = bot.controller as BotController
	check(is_equal_approx(controller.guard_range_ring.scale.x,1.0),"visible ground ring follows the configured attack range")
	training.guard_test_range = 2.4
	training.apply_bot_settings()
	var wall: Node3D = Geometry.box(arena,Vector3(4,3,.2),anchor + Vector3(0,1.5,.9),Color.GRAY)
	await step(4)
	before = cast_count()
	await step(90)
	check(cast_count() == before and player.health == 250,"stationary trainer respects cover before starting a strike")
	wall.queue_free()
	training.reset_scenario()
	await step(4)
	bot = training.bots[0]
	check((bot.controller as BotController).guard_reaction_time == 0 and player.health == 250,"scenario reset restores the drill and clears reaction timing")
	var spawned: HeroActor = training.spawn_bot(BotController.Profile.GUARD_TRAINER,Vector3(5,.1,6))
	check(spawned != null and is_equal_approx((spawned.controller as BotController).guard_trigger_range,2.4),"stationary melee profile is also available through ordinary bot spawning")
	training.freeze_ai = true
	training.start_guard_drill()
	await step(4)
	check(not training.freeze_ai and training.bots.size() == 1 and training.scenario == 6,"one-click guard drill clears an old AI-freeze override and resets the exercise")
	print("GUARD DRILL RESULT: %d checks, %d failures" % [checks,failures.size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/guard-drill-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
