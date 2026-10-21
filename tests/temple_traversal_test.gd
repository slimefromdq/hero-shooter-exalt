extends "res://tests/temple_integration_test.gd"
func run() -> void:
	arena = load("res://scenes/temple/sakura_veil.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var m: TempleMatch = arena.match_controller
	m.freeze_ai = true
	arena.player.controller.active = false
	arena.player.controller = null
	var started: int = Time.get_ticks_msec()
	while not m.navigation_ready and Time.get_ticks_msec()-started<60000: await process_frame
	check(m.navigation_ready,"navigation ready within timeout")
	if not m.navigation_ready:
		quit(1)
		return
	m.set_physics_process(false)
	arena.player.set_physics_process(false)
	for door: MuseumSpawnDoor in arena.builder.spawn_gates: door.queue_free()
	for bot: HeroActor in m.bots:
		bot.process_mode = Node.PROCESS_MODE_DISABLED
		bot.collision_layer = 0
	for pad: TempleJumpPad in arena.builder.pads: pad.set_physics_process(false)
	await step(2)
	var selected: PackedStringArray = []
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--routes="): selected = argument.trim_prefix("--routes=").split(",")
	for entry: Dictionary in arena.builder.walk_routes:
		if not selected.is_empty() and entry.id not in selected: continue
		for reverse: bool in [false,true]:
			var path: Array = entry.points.duplicate()
			if reverse: path.reverse()
			await walk(entry.id+(" reverse" if reverse else " forward"),path[0],path[-1],path)
	var file := FileAccess.open("res://artifacts/temple/traversal.json" if selected.is_empty() else "res://artifacts/temple/traversal-followup.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"walks":walks},"\t"))
	print("TEMPLE TRAVERSAL %d checks, %d failures" % [checks,failures.size()])
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func walk(caption: String, from: Vector3, to: Vector3, via: Array = []) -> void:
	var p: HeroActor = arena.player
	p.reset_actor(from+Vector3.UP*.08)
	var next: int = 0
	var arrived: bool = false
	var frames: int = 0
	for frame: int in 6000:
		frames = frame
		if Vector2(p.position.x-to.x,p.position.z-to.z).length()<1.2 and absf(p.position.y-to.y)<.5:
			arrived = true
			break
		while next<via.size() and Vector2(p.position.x-via[next].x,p.position.z-via[next].z).length()<.65 and absf(p.position.y-via[next].y)<.8: next += 1
		var intent := CombatIntent.new()
		if next<via.size():
			intent.move = ((Vector3(via[next])-p.position)*Vector3(1,0,1)).normalized()
			intent.aim = intent.move
		p.motor.tick(1.0/60,intent)
		if frame%240==0: await process_frame
		if p.position.y < -48: break
	check(arrived,caption+" is physically walkable without jumps or abilities")
	walks.append({"route":caption,"arrived":arrived,"seconds":frames/60.0,"end":str(p.position),"target":str(to),"next":str(via[next]) if next<via.size() else "done"})
	if not arrived: print("WALK FAILURE ",walks[-1])
