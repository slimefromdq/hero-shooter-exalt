extends SceneTree
var arena: Node3D
var camera: Camera3D
var profile: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func photo(caption: String, at: Vector3, toward: Vector3) -> void:
	camera.position = at
	camera.look_at(toward)
	camera.current = true
	for index: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/temple/"+caption+".png")
	profile.append({"view":caption,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)})
	print("TEMPLE PHOTO ",caption)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/temple"))
	arena = load("res://scenes/temple/sakura_veil.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.match_controller.freeze_ai = true
	arena.player.controller.active = false
	var audit_file := FileAccess.open("res://artifacts/temple/geometry-purpose-audit.json",FileAccess.WRITE)
	audit_file.store_string(JSON.stringify(arena.builder.audit,"\t"))
	audit_file.close()
	camera = Camera3D.new()
	camera.far = 1200
	camera.fov = 78
	arena.add_child(camera)
	arena.match_controller.hud.visible = false
	await photo("01-overview",Vector3(225,230,255),Vector3(0,8,0))
	for index: int in 5:
		var at: Vector3 = arena.definition.POINTS[index]
		await photo("point-"+String.chr(65+index),at+Vector3(24,13,33),at+Vector3(0,3,0))
	await photo("02-lower-gallery",Vector3(148,-2.2,24),Vector3(148,-2.2,-16))
	await photo("03-upper-gallery",Vector3(-80,18,38),Vector3(-48,18,38))
	await photo("04-skybridge",Vector3(116,19,18),Vector3(36,19,0))
	await photo("08-through-hall",Vector3(52,10,78),Vector3(52,11,96))
	await photo("09-wind-lift",Vector3(88,12,50),Vector3(76,9,46))
	arena.match_controller.hud.visible = true
	arena.match_controller.hud.overview_open = true
	await photo("05-lower-atlas",Vector3(225,230,255),Vector3.ZERO)
	arena.match_controller.hud.underground_view = true
	await photo("06-upper-atlas",Vector3(225,230,255),Vector3.ZERO)
	arena.match_controller.hud.overview_open = false
	var player: HeroActor = arena.player
	player.reset_actor(Vector3(0,16.08,12))
	player.controller.yaw = 0
	player.controller.pitch = -.1
	player.controller.camera.current = true
	arena.match_controller.objective.preparation_remaining = 0
	arena.builder.update_gates(arena.match_controller.stages,false)
	for index: int in 16: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/temple/07-shoulder.png")
	var file := FileAccess.open("res://artifacts/temple/presentation-profile.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"capture_frames":profile,"note":"Native still-view CPU and draw-call snapshots, not a combat benchmark."},"\t"))
	file.close()
	print("TEMPLE CAPTURE COMPLETE")
	arena.queue_free()
	await process_frame
	quit()
