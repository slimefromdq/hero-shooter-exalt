extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var arena: Node3D = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var session: CityMatch = arena.match_controller
	session.freeze_ai = true
	var player: HeroActor = session.player
	player.controller.active = false
	player.set_physics_process(false)
	player.reset_actor(Vector3(0,.4,24))
	player.spawn_protected = false
	player.controller.camera.current = true
	player.controller.yaw = 0.0
	player.controller.pitch = 0.0
	for index: int in session.bots.size():
		var bot: HeroActor = session.bots[index]
		bot.set_physics_process(false)
		bot.reset_actor(Vector3(-3.6 + (index % 4)*2.4,.4,17 - (index / 4)*4))
		bot.spawn_protected = false
		bot.rotation.y = PI
	for index: int in 30: await process_frame
	var helpers: Array[HeroActor] = [session.bots[0]]
	for index: int in range(5,9):
		session.feedback.on_elimination(player,session.bots[index],helpers,"rifle")
	for index: int in 3: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	root.get_texture().get_image().save_png("res://artifacts/match-feedback.png")
	print("Saved artifacts/match-feedback.png")
	quit()
