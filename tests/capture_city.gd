extends SceneTree

var arena: Node3D
var session: CityMatch
var camera: Camera3D

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for index: int in count:
		await process_frame

func photograph(file_name: String, at: Vector3, toward: Vector3, fov: float = 68.0) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov
	camera.position = at
	camera.look_at(toward)
	camera.current = true
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/city-frames/" + file_name + ".png")
	print("CITY PHOTO ", file_name)

func run() -> void:
	arena = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	session = arena.match_controller
	session.freeze_ai = true
	(arena.player.controller as PlayerController).active = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/city-frames"))
	camera = Camera3D.new()
	camera.far = 500
	arena.add_child(camera)
	var wait_start: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec() - wait_start < 30000:
		await frames(1)
	await frames(60)
	if is_instance_valid(session.hud): session.hud.visible = false
	await photograph("01-meridian-gardens", Vector3(-31, 13, 40), Vector3(3, 7, -6), 66)
	await photograph("02-conservatory", Vector3(9, 2.1, 20), Vector3(-1, 5.5, -3), 76)
	await photograph("03-garden-walk", Vector3(-46, 2.2, 21), Vector3(-24, 5, -9), 72)
	await photograph("04-lantern-market", Vector3(26.9, 2.2, 15), Vector3(35, 3.3, -2), 72)
	await photograph("05-lower-meridian", Vector3(0, -3.2, 31), Vector3(1, -3.2, 12), 76)
	await photograph("06-arcane-viaduct", Vector3(37, 9, 20), Vector3(-5, 15, -25), 76)
	await photograph("10-meridian-exchange", Vector3(5.8, -3.1, 14.2), Vector3(-1.0, -2.9, -9.0), 78)
	await photograph("11-exchange-shops", Vector3(-5.5, -3.0, 5), Vector3(-12.0, -3.0, -1), 76)
	await photograph("12-supported-promenade", Vector3(14.8, 2.2, 10), Vector3(19, 5.0, 1), 74)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 165
	camera.position = Vector3(0, 150, 0)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	await frames(12)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/city-frames/07-overhead.png")
	session.hud.visible = true
	session.hud.overview_open = true
	session.debug_view = true
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/city-frames/08-resource-atlas.png")
	session.hud.underground_view = true
	await frames(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/city-frames/13-arcade-atlas.png")
	session.hud.underground_view = false
	session.hud.overview_open = false
	session.debug_view = false
	var player: HeroActor = arena.player
	player.reset_actor(Vector3(0, .08, 18))
	player.kit.ultimate_charge = 35
	var controller: PlayerController = player.controller
	controller.yaw = .0
	controller.pitch = -.1
	controller.camera.current = true
	session.hill.advance(20, session.actors)
	session.freeze_ai = false
	for index: int in session.bots.size():
		var bot: HeroActor = session.bots[index]
		bot.reset_actor(Vector3((-1 if index % 2 == 0 else 1) * (5 + index % 3 * 3), .08, (5 if bot.team == 1 else 14) - index % 3 * 5))
		bot.kit.ultimate_charge = 35
	await frames(150)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/city-frames/09-shoulder-combat.png")
	print("CITY CAPTURE COMPLETE")
	arena.queue_free()
	await process_frame
	# Fixed-FPS captures can finish faster than the audio mix thread releases its last block.
	var audio_release: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - audio_release < 250:
		await process_frame
	quit()
