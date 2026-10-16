extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var arena: Node = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.training.freeze_ai = true
	for index: int in 45:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var image: Image = root.get_texture().get_image()
	image.save_png("res://artifacts/training.png")
	arena.training.toggle_menu()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/training-console.png")
	arena.training.toggle_menu()
	var controller: PlayerController = arena.player.controller
	controller.pitch = -0.28
	controller.yaw = -0.35
	arena.player.controller = null
	# Submit one launch pulse even if the renderer batches several physics ticks.
	var launch := CombatIntent.new()
	launch.hover = true
	arena.player.motor.tick(1.0 / 60.0, launch)
	for index: int in 25:
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/hover.png")
	print("HOVER CAPTURE MODE: ", arena.player.motor.mode)
	arena.training.scenario = 6
	arena.training.freeze_ai = false
	arena.training.reset_scenario()
	controller.pitch = -.12
	controller.yaw = 0.0
	for index: int in 5:
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/guard-drill.png")
	arena.player.reset_actor(arena.training.bots[0].global_position + Vector3(0,0,2.2))
	arena.player.intent.guard = true
	for index: int in 40:
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/guard-block.png")
	print("GUARD CAPTURE: player HP=",arena.player.health," bot state=",arena.training.bots[0].state)
	print("CAPTURED: artifacts/training.png, training-console.png and hover.png")
	arena.queue_free()
	await process_frame
	quit()
