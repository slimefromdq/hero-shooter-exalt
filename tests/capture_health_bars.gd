extends SceneTree

func _initialize() -> void: call_deferred("run")

func frames(count: int = 8) -> void:
	for index: int in count: await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/health-bars"))
	var arena: Node = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var city: CityMatch = arena.match_controller
	city.freeze_ai = true
	city.player.controller.active = false
	while not city.navigation_ready: await process_frame
	city.player.reset_actor(Vector3(0,.05,18))
	var controller: PlayerController = city.player.controller
	controller.yaw = 0
	controller.pitch = -.05
	var ally: HeroActor = city.bots.filter(func(actor: HeroActor) -> bool: return actor.team == city.player.team)[0]
	var enemy: HeroActor = city.bots.filter(func(actor: HeroActor) -> bool: return actor.team != city.player.team)[0]
	ally.reset_actor(Vector3(-2.5,.05,10))
	enemy.reset_actor(Vector3(2.5,.05,10))
	ally.health = ally.tuning.max_health*.5
	ally.shields = 50
	enemy.health = enemy.tuning.max_health*.5
	for size: Vector2i in [Vector2i(1440,900),Vector2i(1600,900),Vector2i(2160,900)]:
		root.size = size
		await frames()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/health-bars/city-%d.png" % size.x)
	city.return_to_training()
	await frames(15)
	var training: TrainingManager = get_first_node_in_group("training")
	training.freeze_ai = true
	training.player.controller.active = false
	training.player.reset_actor(Vector3(10,.05,-51))
	var patient: HeroActor = training.practice_range.groups.allies[0]
	patient.health = 90
	root.size = Vector2i(1600,900)
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/health-bars/training-allies.png")
	current_scene.queue_free()
	await frames()
	print("HEALTH BAR CAPTURES COMPLETE")
	quit()
