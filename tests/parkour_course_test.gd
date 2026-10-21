extends SceneTree
var failures: int = 0
var arena: Node3D
func _initialize() -> void: call_deferred("run")
func step() -> void:
	await physics_frame
	await process_frame
func run() -> void:
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var training: TrainingManager = arena.training
	training.despawn_bots()
	var player: HeroActor = training.player
	var camera_controller: PlayerController = player.controller
	camera_controller.active = false
	var heroes: Array[String] = HeroRoster.IDS.duplicate()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hero="): heroes.assign([arg.trim_prefix("--hero=")])
	for hero: String in heroes:
		player.controller = camera_controller
		training.select_hero(hero)
		training.despawn_bots()
		player.controller = null
		training.workshop.parkour.start()
		var route: TrainingParkour = training.workshop.parkour
		var tick: int = 0
		var last_checkpoint: int = 0
		var stall: int = 0
		while route.running and tick < 6500:
			var destination: Vector3 = TrainingParkour.CHECKPOINTS[route.checkpoint]
			var offset: Vector3 = destination-player.global_position
			var input := CombatIntent.new()
			input.move = (offset*Vector3(1,0,1)).normalized() if Vector2(offset.x,offset.z).length() > .8 else Vector3.ZERO
			input.aim = input.move if not input.move.is_zero_approx() else Vector3.FORWARD
			input.jump_held = true
			input.jump = tick%35 == 0 and route.checkpoint != 4
			input.dash = route.checkpoint == 3 and tick%180 == 0
			input.slide = route.checkpoint == 4
			input.slide_pressed = route.checkpoint == 4 and tick%120 == 0
			# Mantle the ramp approach before holding crouch through the slide lane.
			if route.checkpoint == 4 and player.global_position.x > 150:
				input.slide = false
				input.jump = tick%35 == 0
			player.intent = input
			await step()
			tick += 1
			if route.checkpoint != last_checkpoint:
				last_checkpoint = route.checkpoint
				stall = 0
			else: stall += 1
			if stall > 1800: break
		var ok: bool = route.checkpoint == 6
		print("PASS " if ok else "FAIL ","shared movement course / ",hero," / checkpoint ",route.checkpoint," / time ",route.elapsed," / position ",player.global_position)
		if not ok: failures += 1
		route.running = false
	player.controller = camera_controller
	arena.queue_free()
	await process_frame
	print("PARKOUR COURSE: %d heroes, %d failures" % [heroes.size(),failures])
	quit(1 if failures else 0)
