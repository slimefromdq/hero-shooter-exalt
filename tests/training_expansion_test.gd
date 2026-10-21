extends SceneTree
var failures: int = 0
var checks: int = 0
var arena: Node3D
var training: TrainingManager
func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",caption)
func step(frames: int = 1) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame
func run() -> void:
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	training = arena.training
	training.despawn_bots()
	training.freeze_ai = true
	var player: HeroActor = training.player
	player.controller.active = false
	player.set_physics_process(false)
	await step(2)
	check(not training.no_cooldowns and not training.prevent_death,"training overrides default off")
	var tank := training.spawn_tank_dummy()
	check(tank.health == 600 and tank.tuning.max_health == 600,"tank dummy has 600 HP")
	training.player.resolver.damage(player,tank,999,"rifle",player.resolver.new_cast(player))
	check(not tank.alive,"tank dummy can die")
	tank.reset_actor()
	check(tank.health == 600,"tank dummy respawns with 600 HP")
	training.despawn_bots()
	for hero: String in HeroRoster.IDS:
		var dummy := training.spawn_hero(hero)
		check(dummy.tuning.hero_id == hero and dummy.health == HeroRoster.tuning_for(hero).max_health,"native dummy health / "+hero)
		check(dummy.controller.profile == BotController.Profile.STATIONARY,"stationary behavior / "+hero)
		training.set_behavior(dummy,"Strafing")
		check(dummy.controller.profile == BotController.Profile.STRAFE,"switch to strafing / "+hero)
		training.despawn_bots()
	await step(2)
	var bot := training.spawn_hero("nimbus")
	bot.set_physics_process(false)
	player.training_prevent_death = true
	player.health = 50
	player.resolver.damage(bot,player,999,"rifle",player.resolver.new_cast(bot))
	check(player.alive and player.health == 1,"lethal damage clamps at 1 HP")
	player.training_prevent_death = false
	player.resolver.damage(bot,player,999,"rifle",player.resolver.new_cast(bot))
	check(not player.alive,"death works when prevention disabled")
	player.reset_actor()
	for hero: String in HeroRoster.IDS:
		player.select_hero(hero)
		player.kit.shot_cd = .4
		player.kit.ammo = 1
		player.kit.reloading = true
		player.kit.reload_remaining = .3
		player.state = "ready"
		player.kit.deflect_cd = 5
		player.kit.bomb_cd = 5
		player.motor.dash_charges = 0
		TrainingResources.restore(player)
		check(player.kit.deflect_cd == 0 and player.kit.bomb_cd == 0 and player.motor.dash_charges == player.tuning.dash_capacity,"restore availability / "+hero)
		check(player.kit.shot_cd == .4 and player.kit.ammo == 1 and player.kit.reloading and player.kit.reload_remaining == .3,"restore preserves cadence ammo reload / "+hero)
		player.kit.reloading = false
	player.select_hero("nimbus")
	player.reset_actor(Vector3(0,.1,11))
	bot.reset_actor(Vector3(0,.1,13))
	for mode: String in ["Melee only","Throw only","Shield defense","Mixed close combat"]:
		training.set_behavior(bot,mode)
		bot.controller.action_timer = 0
		var intent: CombatIntent = bot.controller.gather_intent(.1)
		check(not intent.primary and not intent.hover and not intent.deflect and not intent.bomb and not intent.ultimate,"close combat restricts hero and ranged actions / "+mode)
	training.workshop.parkour.start()
	var route: TrainingParkour = training.workshop.parkour
	check(not route.reach_checkpoint(TrainingParkour.CHECKPOINTS[2]),"parkour rejects out-of-order checkpoint")
	for point: Vector3 in TrainingParkour.CHECKPOINTS:
		check(route.reach_checkpoint(point),"parkour accepts next checkpoint")
	check(not route.running and route.checkpoint == 6,"parkour finishes after all checkpoints")
	route.start()
	route.reach_checkpoint(TrainingParkour.CHECKPOINTS[0])
	route.elapsed = 20
	route.recover()
	check(player.global_position.distance_to(route.recovery) < .01 and route.elapsed == 20,"checkpoint recovery preserves time")
	route.running = false
	training.no_cooldowns = true
	training.prevent_death = true
	training.select_hero("slayer")
	check(training.no_cooldowns and training.prevent_death and player.training_no_cooldowns and player.training_prevent_death,"overrides survive hero changes and exercise resets")
	training.workshop.start_parry()
	player.set_physics_process(false)
	var attacker: HeroActor = training.bots[0]
	attacker.set_physics_process(false)
	player.aim_direction = (attacker.global_position-player.global_position).normalized()
	player.close.parry_left = .12
	var parry_cast: int = player.resolver.classify(player.resolver.new_cast(attacker),CombatResolver.ImpactKind.ABILITY)
	check(player.resolver.damage(attacker,player,10,"knife",parry_cast) == "parried" and training.workshop.parries == 1,"perfect parry increments success counter")
	player.close.parry_left = 0
	player.resolver.damage(attacker,player,10,"knife",player.resolver.new_cast(attacker))
	check(training.workshop.misses == 1,"unparried hit increments practice miss counter")
	training.infinite_ammo = true
	player.training_infinite_ammo = true
	player.kit.ammo = 1
	player.kit.consume_ammo()
	check(player.kit.ammo == 1,"infinite ammunition does not empty magazine or force reload")
	training.workshop.stop_all()
	player.controller.active = false
	player.training_prevent_death = true
	player.set_physics_process(true)
	player.global_position = Vector3(0,-9,11)
	await step(2)
	check(player.alive and player.health == 1 and player.global_position.y > -1,"training fall prevention recovers a living player at 1 HP")
	player.set_physics_process(false)
	check(not training.workshop.parry_active and not training.workshop.parkour.running,"exercise cleanup stops drills")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	arena.queue_free()
	await step(3)
	quit(1 if failures else 0)
