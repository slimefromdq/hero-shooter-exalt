extends SceneTree
var arena: Node
var controller: PlayerController
var sizes: Array[Vector2i] = [Vector2i(1440,900),Vector2i(1600,900),Vector2i(2160,900)]

func _initialize() -> void: call_deferred("run")

func capture(name: String) -> void:
	for index: int in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/qol/"+name+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/qol"))
	TrainingInputs.install()
	var container := Node.new()
	root.add_child(container)
	current_scene = container
	var layer := CanvasLayer.new()
	container.add_child(layer)
	var menu := GameMenu.new()
	layer.add_child(menu)
	for size: Vector2i in sizes:
		root.size = size
		menu.show_home()
		await capture("main-%d" % size.x)
		menu.show_heroes()
		await capture("heroes-%d" % size.x)
		menu.show_settings()
		await capture("settings-%d" % size.x)
	container.queue_free()
	await process_frame
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.training.freeze_ai = true
	controller = arena.player.controller
	controller.active = false
	arena.player.controller = null
	for size: Vector2i in sizes:
		root.size = size
		for hero: String in HeroRoster.IDS:
			arena.player.select_hero(hero)
			arena.player.reset_actor(Vector3(-15,.01,-35))
			controller.yaw = 0
			controller.pitch = -.12
			await capture(hero+"-%d" % size.x)
		arena.player.select_hero("nimbus")
		arena.player.controller = controller
		arena.player.set_physics_process(false)
		arena.player.motor.transition("hover")
		controller.pitch = .5
		await capture("umbrella-%d" % size.x)
		arena.player.motor.transition("ground")
		arena.player.controller = null
		arena.player.set_physics_process(true)
		controller.pitch = -.12
		arena.player.statuses.apply("root",arena.training.bots[0],10)
		arena.player.statuses.apply("bleed",arena.training.bots[0],10,1)
		await capture("cc-%d" % size.x)
		arena.training.toggle_menu()
		await capture("pause-%d" % size.x)
		arena.training.toggle_menu()
		arena.player.select_hero("slayer")
		var target: HeroActor = arena.training.bots[0]
		target.reset_actor(Vector3(0,.01,-43))
		arena.player.reset_actor(Vector3(0,.01,-41.8))
		arena.player.intent.aim = Vector3.RIGHT
		var attachment := BootAttachment.new()
		attachment.configure(arena.player,target)
		await capture("boot-attach-%d" % size.x)
		attachment.release(true)
		await capture("boot-release-%d" % size.x)
		arena.training.practice_range.reset_group("aoe")
		arena.player.select_hero("nimbus")
		arena.player.reset_actor(Vector3(-15,.01,-35))
		arena.player.intent.ultimate = true
		await physics_frame
		await process_frame
		arena.player.intent.ultimate = false
		for index: int in 40: await physics_frame
		await capture("ultimate-%d" % size.x)
	arena.queue_free()
	await process_frame
	print("QOL captures complete")
	quit()
