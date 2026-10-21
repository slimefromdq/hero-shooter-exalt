extends SceneTree
var failures: Array[String] = []
var results: Array = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for team: int in 2:
		TempleMatch.selected_side = team
		var arena = load("res://scenes/temple/sakura_veil.tscn").instantiate()
		root.add_child(arena)
		current_scene = arena
		arena.player.controller.active = false
		var m: TempleMatch = arena.match_controller
		var started: int = Time.get_ticks_msec()
		while not m.navigation_ready and Time.get_ticks_msec()-started<60000: await process_frame
		if not m.navigation_ready:
			failures.append("navigation timeout")
			break
		m.objective.preparation_remaining = 0
		m._preparing = false
		arena.builder.update_gates(m.stages,false)
		Engine.time_scale = 4
		var elapsed: float = 0
		var next_report: float = 60
		var max_stuck: float = 0
		var falls: int = 0
		var gallery_users: Dictionary = {}
		var last_life: Dictionary = {}
		while elapsed<600:
			await physics_frame
			elapsed += 1.0/60*Engine.time_scale
			for bot: HeroActor in m.bots:
				if not bot.alive and bot.position.y < -48 and last_life.get(bot.actor_id,-1)!=bot.life_serial:
					falls += 1
					last_life[bot.actor_id] = bot.life_serial
				max_stuck = maxf(max_stuck,bot.controller.longest_stuck)
				for gallery: Dictionary in arena.definition.galleries():
					if bot.alive and bot.position.distance_to(gallery.center)<8: gallery_users[bot.actor_id] = true
			if m.objective.finished:
				m.restart_match()
				m.objective.preparation_remaining = 0
				m._preparing = false
				arena.builder.update_gates(m.stages,false)
			if elapsed>=next_report:
				print("SOAK team ",team," seconds ",int(elapsed)," owners ",m.objective.owners)
				next_report += 60
		Engine.time_scale = 1
		var pad_uses: int = 0
		var moved: int = 0
		for pad: TempleJumpPad in arena.builder.pads: pad_uses += pad.launch_count
		for bot: HeroActor in m.bots:
			if bot.controller.distance_travelled>30: moved += 1
		if moved!=11: failures.append("all bots must travel: team "+str(team))
		if pad_uses==0: failures.append("no pad use: team "+str(team))
		if gallery_users.is_empty(): failures.append("no gallery use: team "+str(team))
		if max_stuck>8: failures.append("persistent stalls: team "+str(team))
		if falls>3: failures.append("repeated accidental falls: team "+str(team))
		results.append({"team":team,"seconds":elapsed,"moved":moved,"pad_uses":pad_uses,"gallery_users":gallery_users.size(),"max_stuck":max_stuck,"falls":falls,"owners":m.objective.owners})
		print("SOAK RESULT ",JSON.stringify(results[-1]))
		arena.queue_free()
		await process_frame
	var file := FileAccess.open("res://artifacts/temple/soak.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"runs":results,"failures":failures},"\t"))
	print("TEMPLE SOAK ",failures)
	quit(0 if failures.is_empty() else 1)
