extends SceneTree
var arena: Node3D
var camera: Camera3D

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for index: int in count: await process_frame

func photo(caption: String, at: Vector3, toward: Vector3) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 78
	camera.position = at
	camera.look_at(toward)
	camera.current = true
	await frames(8)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/museum/"+caption+".png")
	print("MUSEUM PHOTO ",caption)

func run() -> void:
	arena = load("res://scenes/museum/meridian_museum.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.match_controller.freeze_ai = true
	arena.match_controller.player.controller.active = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/museum"))
	camera = Camera3D.new()
	camera.far = 500
	arena.add_child(camera)
	await frames(60)
	arena.match_controller.hud.visible = false
	await photo("01-court",Vector3(-16,3,4),Vector3(1,4,0))
	await photo("02-giants",Vector3(19,2.5,-4),Vector3(40,5,1))
	await photo("03-terrace",Vector3(65,3,-3),Vector3(87,3,8))
	await photo("04-vault",Vector3(111,4,3),Vector3(138,5,0))
	for index: int in 4:
		var x: float = [0.0,39,86,134][index]
		await photo("0%d-overhead" % (index+5),Vector3(x+6,40,30),Vector3(x,0,0))
	arena.match_controller.hud.visible = true
	arena.match_controller.hud.overview_open = true
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/museum/09-atlas-ground.png")
	arena.match_controller.hud.underground_view = true
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/museum/10-atlas-high.png")
	arena.match_controller.hud.overview_open = false
	var player: HeroActor = arena.player
	player.reset_actor(Vector3(-10,.08,2))
	player.controller.yaw = -PI/2
	player.controller.camera.current = true
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/museum/11-player.png")
	var session: MuseumMatch = arena.match_controller
	session.notice_time = 0
	session.objective.phase = "capture"
	session.objective.capture_progress = 2.0/3
	session.objective.locked_thirds = 2
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/museum/12-capture-locks.png")
	session.objective.phase = "escort"
	session.objective.capture_progress = 1
	session.objective.checkpoint_index = 1
	session.objective.payload_distance = 72
	session._relocate(2,2)
	session.payload.move_to_distance(72)
	player.reset_actor(session.payload.global_position+Vector3(-6,.08,6))
	player.controller.yaw = -PI/4
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/museum/13-checkpoint.png")
	session.objective.checkpoint_index = 2
	session.objective.payload_distance = 142
	session.objective.time_remaining = 0
	session.objective.overtime = true
	session._relocate(3,2)
	session.payload.move_to_distance(142)
	player.reset_actor(session.payload.global_position+Vector3(-6,.08,6))
	player.controller.yaw = -PI/4
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/museum/14-overtime.png")
	session.objective.finish(0)
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/museum/15-attack-victory.png")
	session.restart_match()
	session.freeze_ai = true
	session.objective.capture_progress = 2.0/3
	session.objective.locked_thirds = 2
	session.objective.time_remaining = 0
	session.objective.finish(1)
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/museum/16-defense-victory.png")
	print("MUSEUM CAPTURE COMPLETE / 16 FRAMES")
	arena.queue_free()
	await frames(5)
	quit()
