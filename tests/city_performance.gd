extends SceneTree
## Run rendered at 1920x1080 without --fixed-fps. Measures actual presented frame intervals.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var arena: Node3D = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var session: CityMatch = arena.match_controller
	session.freeze_ai = true
	var player: HeroActor = session.player
	(player.controller as PlayerController).active = false
	var start_wait: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec() - start_wait < 30000:
		await process_frame
	player.reset_actor(Vector3(0, .08, 16))
	player.kit.ultimate_charge = 35
	var controller: PlayerController = player.controller
	controller.pitch = -.08
	controller.yaw = 0
	# Keep twelve live combatants processing normal hit/cooldown logic throughout the sample.
	# Enlarged health pools are benchmark-only; production Nimbus remains 250 HP.
	for index: int in session.actors.size():
		var actor: HeroActor = session.actors[index]
		actor.tuning.max_health = 100000
		actor.health = actor.tuning.max_health
		if actor != player:
			actor.reset_actor(Vector3((-1 if index % 2 else 1) * (4 + index % 3 * 2.5), .08, (6 if actor.team == 0 else -6) + index % 3 * 2))
			actor.controller.entered_hill = true
			actor.controller.route_index = actor.controller.route.size() - 1
			actor.controller.destination = Vector3(actor.position.x, .05, actor.position.z)
		actor.kit.ultimate_charge = 35
	session.freeze_ai = false
	var warm: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - warm < 5000:
		await process_frame
	var intervals: Array[float] = []
	var draw_calls: Array[float] = []
	var cpu_ms: Array[float] = []
	var start: int = Time.get_ticks_usec()
	var previous: int = start
	while Time.get_ticks_usec() - start < 20000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		intervals.append(float(now - previous) / 1000.0)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		cpu_ms.append((Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		previous = now
	var seconds: float = float(Time.get_ticks_usec() - start) / 1000000.0
	intervals.sort()
	var total_draws: float = 0
	for value: float in draw_calls: total_draws += value
	var report: Dictionary = {"resolution": root.size, "renderer": RenderingServer.get_current_rendering_method(),
		"device": RenderingServer.get_video_adapter_name(), "frames": intervals.size(), "seconds": seconds,
		"average_fps": intervals.size() / seconds, "p95_frame_ms": intervals[int(intervals.size() * .95)],
		"p99_frame_ms": intervals[int(intervals.size() * .99)], "average_draw_calls": total_draws / maxf(1, draw_calls.size()),
		"alive_actors": session.team_count(0) + session.team_count(1), "physics_hz": Engine.physics_ticks_per_second}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var output := FileAccess.open("res://artifacts/city-performance.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print("CITY PERFORMANCE ", JSON.stringify(report))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/city-performance.png")
	arena.queue_free()
	await process_frame
	var audio_release: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - audio_release < 250:
		await process_frame
	quit(0 if float(report.average_fps) >= 60.0 else 1)
