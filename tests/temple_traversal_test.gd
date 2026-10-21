extends "res://tests/temple_integration_test.gd"

func run() -> void:
	arena = load("res://scenes/temple/sakura_veil.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var m: TempleMatch = arena.match_controller
	m.freeze_ai = true
	arena.player.controller.active = false
	arena.player.controller = null
	while not m.navigation_ready: await process_frame
	m.set_physics_process(false)
	for bot: HeroActor in m.bots:
		bot.process_mode = Node.PROCESS_MODE_DISABLED
		bot.collision_layer = 0
	for sector: int in 2:
		for entry: Dictionary in arena.builder.routes:
			if entry.kind == "main" and entry.sector == sector:
				await walk("main %d" % sector,arena.definition.POINTS[sector],arena.definition.POINTS[sector+1],entry.points)
	for kind: String in ["lower","upper"]:
		for entry: Dictionary in arena.builder.routes:
			if entry.kind == kind and entry.sector == 0:
				await walk(kind+" circuit",entry.points[0],entry.points[-1],entry.points)
	var p: HeroActor = arena.player
	p.set_physics_process(false)
	p.reset_actor(Vector3(0,16.08,12))
	var intent := CombatIntent.new()
	intent.move = Vector3.FORWARD
	intent.aim = Vector3.FORWARD
	for frame: int in 10: p.motor.tick(1.0/60,intent)
	intent.dash = true
	p.motor.tick(1.0/60,intent)
	intent.dash = false
	intent.slide = true
	for frame: int in 34: p.motor.tick(1.0/60,intent)
	check(p.position.z < 5 and p.position.y > 15.5,"dash chain crosses the actual broad mid court with floor support")
	p.reset_actor(Vector3(-3.4,-10,104))
	intent = CombatIntent.new()
	intent.move = Vector3.LEFT
	intent.aim = Vector3.FORWARD
	intent.jump = true
	p.motor.tick(1.0/60,intent)
	check(p.velocity.y > 0 and p.velocity.x > 0,"ravine retaining wall permits an actual outward wall kick")
	p.reset_actor(Vector3(-102.5,.05,98.2))
	intent = CombatIntent.new()
	intent.move = Vector3.FORWARD
	intent.aim = Vector3.FORWARD
	intent.jump_held = true
	for frame: int in 45: p.motor.tick(1.0/60,intent)
	check(p.position.y > 1.4,"side courtyard plinth supports a held mantle")
	var file := FileAccess.open("res://artifacts/temple/traversal.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"walks":walks},"\t"))
	file.close()
	print("TEMPLE TRAVERSAL %d checks, %d failures" % [checks,failures.size()])
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
