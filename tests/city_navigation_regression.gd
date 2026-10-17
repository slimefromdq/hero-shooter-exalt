extends SceneTree

func _initialize() -> void: call_deferred("run")

func step(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func run() -> void:
	var arena: Node3D = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var session: CityMatch = arena.match_controller
	session.freeze_ai = true
	var camera: PlayerController = session.player.controller
	camera.active = false
	while not session.navigation_ready: await step(1)
	session.set_physics_process(false)
	for bot: HeroActor in session.bots:
		bot.set_physics_process(false)
		bot.alive = false
	var driver := CityBotController.new()
	driver.actor = session.player
	driver.match_controller = session
	session.player.add_child(driver)
	session.player.controller = driver
	session.player.reset_actor(Vector3(.841088,.001,37.24998))
	session.player.health = 50
	driver.entered_hill = true
	session.freeze_ai = false
	var origin: Vector3 = session.player.position
	# Temporarily unavailable pedestrian layers reproduce an empty steering result
	# while a low-health actor still needs to reach a valid cache across the street.
	driver.navagent.navigation_layers = 0
	await step(150)
	var failures: Array[String] = []
	var results: Dictionary = {
		"empty steering triggers a navigation detour": driver.stuck_events > 0,
		"recovery does not teleport the actor": session.player.position.distance_to(origin) < .1 and driver.recovery_warps == 0,
		"recovery respects the two-hertz path budget": driver.path_update_count <= ceili(driver.elapsed*2)+2}
	driver.navagent.navigation_layers = 1
	await step(540)
	results["injured bot reaches the requested surface health pack after navigation resumes"] = session.player.position.distance_to(Vector3(24,0,28)) < 1.55
	results["healing intent uses the available shared health pack"] = driver.seeking_health and driver.health_target == session.pickups[3]
	results["ordinary actor rules remain active"] = session.player.alive and not session.player.infinite_resources
	for caption: String in results:
		print("PASS  " if results[caption] else "FAIL  ",caption)
		if not results[caption]: failures.append(caption)
	print("RESULT: ",results.size()," checks, ",failures.size()," failures")
	var file := FileAccess.open("res://artifacts/city-navigation-regression.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results.size(),"failures":failures,"end_position":str(session.player.position),"detours":driver.stuck_events},"\t"))
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
