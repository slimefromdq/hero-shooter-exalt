extends SceneTree
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func step(count: int = 1) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func run() -> void:
	var store: Node = root.get_node("GameSettings")
	var original: float = store.values.bot_difficulty
	store.set_setting("bot_difficulty",1)
	var arena: Node3D = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var training: TrainingManager = arena.training
	training.player.controller.active = false
	training.scenario = 15
	training.reset_scenario()
	check(training.bots.size() == 1 and training.bots[0].controller is TrainingTacticalController,"new Tactical Sparring scenario uses shared tactical controller")
	var bot: HeroActor = training.bots[0]
	var driver: TrainingTacticalController = bot.controller
	var origin: Vector3 = bot.global_position
	var start: int = Time.get_ticks_msec()
	while (arena.get_node("TacticalNavigation") as NavigationRegion3D).navigation_mesh.get_polygon_count() == 0 and Time.get_ticks_msec()-start < 15000: await step()
	await step(8)
	var map: RID = driver.navagent.get_navigation_map()
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map,bot.global_position,Vector3(0,0,5),true)
	check(not path.is_empty(),"training geometry bakes a connected tactical navigation map")
	await step(180)
	check(bot.global_position.distance_to(origin) > .5,"tactical training bot moves using ordinary actor physics")
	training.freeze_ai = true
	await step(2)
	var frozen: CombatIntent = driver.gather_intent(.1)
	check(frozen.move.is_zero_approx() and not frozen.primary,"training freeze gates tactical intent")
	training.freeze_ai = false
	await step(2)
	for level: int in 4:
		store.set_setting("bot_difficulty",level)
		driver.think_timer = 0
		driver.gather_intent(.016)
		check(driver.brain.level == level,"active training bot adopts "+BotSkillProfile.NAMES[level])
	var saved := ConfigFile.new()
	saved.load(store.PATH)
	check(int(saved.get_value("settings","bot_difficulty",-1)) == 3,"difficulty is saved to the existing settings file")
	check(training.hud.menu.find_child("BotDifficulty",true,false) != null or training.hud.menu.find_child("TacticalDifficulty",true,false) != null,"training provides a difficulty selector")
	check(BotDebug.export_tree(self,"res://artifacts/ai-training-metrics.json") == OK,"training diagnostics export structured bot metrics")
	bot.reset_actor(Vector3(10,.01,6))
	driver.frozen = true
	await step(3)
	driver.brain.reset()
	driver.brain.now = bot.resolver.combat_time
	driver.brain.movement.selected_position = Vector3(12,2.03,6)
	var traversal := CombatIntent.new()
	traversal.move = Vector3.RIGHT
	driver.brain.movement.apply(driver.brain,traversal,false)
	check(traversal.jump and traversal.jump_held,"Expert requests jump and held mantle at a reachable ledge")
	bot.motor.tick(1.0/60,traversal)
	check(bot.state == "mantle","Expert traversal intent enters the shared real mantle implementation")
	driver.frozen = false
	bot.select_hero("wisp")
	driver.think_timer = 0
	driver.gather_intent(.016)
	check(driver.brain.hero_profile.hero == "wisp","live hero switch refreshes tactical profile")
	bot.die()
	var dead: CombatIntent = driver.gather_intent(.1)
	check(not dead.primary and dead.move.is_zero_approx(),"dead tactical bot emits no actions")
	bot.reset_actor()
	check(driver.brain.target_id == 0 and driver.brain.combat.bomb == null,"respawn clears tactical targets and bomb references")
	training.scenario = 6
	training.reset_scenario()
	check(training.bots[0].controller is BotController and not training.bots[0].controller is TrainingTacticalController,"guard drill retains its controlled controller")
	check(training.bots[0].controller.profile == BotController.Profile.GUARD_TRAINER,"guard drill keeps its existing range and cadence behavior")
	arena.queue_free()
	await step(4)
	check(get_nodes_in_group("actors").is_empty(),"training cleanup releases actors and tactical references")
	store.set_setting("bot_difficulty",original)
	print("BOT INTEGRATION: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
