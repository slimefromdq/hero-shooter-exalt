extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arena = load("res://scenes/temple/sakura_veil.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.player.controller.active = false
	while not arena.match_controller.navigation_ready: await process_frame
	var m = arena.match_controller
	m.objective.preparation_remaining = 0
	m._preparing = false
	arena.builder.update_gates(m.stages,false)
	for index: int in m.actors.size():
		var actor: HeroActor = m.actors[index]
		actor.reset_actor(Vector3(-15+(index%6)*6,16.1,14 if actor.team==0 else -14))
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.position = Vector3(28,33,35)
	camera.look_at(Vector3(0,18,0))
	camera.current = true
	var physics: Array[float] = []
	var process: Array[float] = []
	var draws: float = 0
	Engine.time_scale = 4
	for frame: int in 1020:
		await process_frame
		if frame<120: continue
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
		process.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	Engine.time_scale = 1
	physics.sort()
	process.sort()
	var result: Dictionary = {"samples":900,"simulated_combat_seconds":60,"physics_median_ms":physics[450],"physics_p95_ms":physics[855],"frame_median_ms":process[450],"frame_p95_ms":process[855],"draw_calls_mean":draws/900,"note":"900 rendered frames after 120-frame warmup at fixed 60 FPS / 4x simulation; matching initial mid-court combat placement and camera; combat is not deterministic."}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/temple"))
	var file := FileAccess.open("res://artifacts/temple/combat-profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("COMBAT PROFILE ",JSON.stringify(result))
	arena.queue_free()
	await process_frame
	quit()
