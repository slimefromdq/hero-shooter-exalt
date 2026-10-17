extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func step(frames: int = 1) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame

func scene_is(path: String) -> bool:
	for index: int in 600:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get_script().resource_path == path: return true
	return false

func run() -> void:
	HeroRoster.selected = "slayer"
	var arena: Node3D = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var training: TrainingManager = arena.training
	training.freeze_ai = true
	await step(3)
	check(training.player.kit is SlayerKit,"training scene instantiates selected Slayer kit")
	check(training.player.controller is PlayerController,"Slayer uses the original shoulder camera and player controller")
	check(training.bots[0].kit is NimbusKit,"training ranged enemy retains Nimbus's original kit")
	check(training.player.motor.traversal != null and training.player.close != null,"Slayer owns shared traversal and close-combat components")
	training.toggle_menu()
	check(paused and training.menu_open,"training pause console works for Slayer")
	training.select_hero("nimbus")
	check(training.player.kit is NimbusKit and paused,"hero selection safely rebuilds kit and console while paused")
	training.start_slayer_hunt()
	check(not paused and not training.menu_open and training.player.kit is SlayerKit,"one-click Slayer hunt selects hero and resumes play")
	check(training.bots.size() == 3 and training.bots[2].kit is SlayerKit,"hunt drill includes stationary, moving and live Slayer targets")
	var hunter: HeroActor = training.bots[2]
	var ai: BotController = hunter.controller
	training.freeze_ai = true
	ai.frozen = false
	ai.action_timer = 0
	hunter.global_position = Vector3(0,.01,5)
	training.player.global_position = Vector3(0,.01,11)
	var request: CombatIntent = ai.gather_intent(.5)
	check(request.primary and request.deflect,"Slayer training AI requests shotgun and offensive boot at close range")
	hunter.global_position = Vector3(0,.01,-5)
	ai.action_timer = 0
	request = ai.gather_intent(.5)
	check(request.hover and request.primary,"Slayer AI keeps knives available during stronger midrange gun pressure")
	training.freeze_ai = false
	training.god_mode = true
	await step(1500)
	var casts: Array[String] = []
	for event: Dictionary in arena.resolver.events:
		if event.actor == hunter.actor_id: casts.append(event.ability)
	check(casts.has("silver_knife") or casts.has("street_sweeper"),"live training bot resolves actual Slayer attacks")
	check(hunter.kit.ammo <= 6 and (hunter.kit as SlayerKit).knives <= 2,"Slayer AI obeys finite ammunition and charges")
	training.freeze_ai = true
	training.player.controller.active = false
	training.player.statuses.apply("max_health",hunter,8,.5)
	training.refill_all()
	check(training.player.health == 275 and training.player.statuses.effects.is_empty(),"training refill restores Slayer's 275 HP and cleanses temporary wounds")
	training.select_hero("slayer")
	training.player.global_position = Vector3(0,.01,11)
	var kit := training.player.kit as SlayerKit
	kit.deploy_trap()
	await step(12)
	var old_trap: WeakRef = weakref(kit.traps.back())
	var old_player: WeakRef = weakref(training.player)
	training.toggle_menu()
	training.enter_city()
	check(await scene_is("res://scripts/city/city_arena.gd"),"selected Slayer transitions from paused training into real city")
	await step(5)
	check(old_trap.get_ref() == null and old_player.get_ref() == null,"scene transition releases old actor, kit and owned trap")
	var city: CityMatch = current_scene.match_controller
	city.freeze_ai = true
	check(city.player.kit is SlayerKit and city.bots.size() == 11,"6v6 city includes selected Slayer and full roster")
	var slayers: int = 0
	for bot: HeroActor in city.bots:
		if bot.kit is SlayerKit: slayers += 1
	check(slayers == 3,"Slayer city roster has two hunters per team including the player")
	var start: int = Time.get_ticks_msec()
	while not city.navigation_ready and Time.get_ticks_msec() - start < 20000:
		await process_frame
	check(city.navigation_ready,"city navigation bakes with mixed hero roster")
	check(city.player.kit.ultimate_charge < 1,"city starts Slayer at ordinary zero ultimate charge")
	city.player.controller.active = false
	city.player.reset_actor(Vector3(8,.01,8))
	city.player.spawn_protected = false
	kit = city.player.kit as SlayerKit
	var enemy: HeroActor
	for bot: HeroActor in city.bots:
		if bot.team != city.player.team:
			enemy = bot
			break
	enemy.reset_actor(Vector3(8,.01,2))
	enemy.spawn_protected = false
	enemy.intent.aim = Vector3.BACK
	city.player.controller = null
	city.player.aim_direction = Vector3.FORWARD
	await step(3)
	city.player.intent.aim_origin = city.player.global_position + Vector3.UP * 1.05
	kit.fire(false)
	if enemy.health == 250:
		print("CITY SHOT DIAGNOSTIC position=",city.player.position," enemy=",enemy.position," pellets=",kit.last_shot_pellets," protected=",city.player.spawn_protected,"/",enemy.spawn_protected," state=",city.player.state)
		print("CITY RAY: ",city.player.resolver.ray(city.player.muzzle(),enemy.position + Vector3.UP,[city.player.get_rid()]))
	check(enemy.health < 250,"Slayer shotgun damages ordinary city actors outside protected rooms")
	check(city.hud.hit_text.to_float() > 7,"city hit marker reports aggregate shotgun damage")
	kit.ultimate_charge = 73
	city.player.die()
	city.respawn_actor(city.player)
	check(city.player.alive and city.player.kit is SlayerKit and city.player.kit.ultimate_charge == 73,"city respawn preserves selected hero and earned ultimate")
	check(city.player.kit.ammo == 6 and city.player.statuses.effects.is_empty(),"city respawn resets shells and life-bound statuses")
	city.select_hero("nimbus")
	check(city.player.kit is NimbusKit and city.player.kit.ultimate_charge == 0,"city selection restarts match into original Nimbus rules")
	city.select_hero("slayer")
	check(city.player.kit is SlayerKit and city.player.kit.ultimate_charge == 0,"city selection restarts fairly with Slayer")
	city.toggle_menu()
	city.return_to_training()
	check(await scene_is("res://scripts/training/arena.gd"),"city returns to selected Slayer training from pause")
	await step(5)
	check(get_nodes_in_group("game_session").size() == 1 and get_nodes_in_group("combat_resolver").size() == 1,"transitions retain exactly one session and damage authority")
	check(current_scene.player.kit is SlayerKit and get_nodes_in_group("city_health_packs").is_empty(),"hero selection persists while city entities are cleaned up")
	print("SLAYER INTEGRATION RESULT: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/slayer-integration-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	current_scene.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
