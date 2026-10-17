extends SceneTree

func _initialize() -> void: call_deferred("run")

func frames(count: int = 10) -> void:
	for index: int in count: await process_frame

func save_frame(label: String) -> void:
	await frames()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/crouch/%s.png" % label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/crouch"))
	var arena: Node = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	await frames()
	var training: TrainingManager = get_first_node_in_group("training")
	training.freeze_ai = true
	var actor: HeroActor = training.player
	actor.set_physics_process(false)
	var controller: PlayerController = actor.controller
	controller.active = false
	for hero: String in HeroRoster.IDS:
		actor.select_hero(hero)
		actor.global_position = Vector3(0,.05,5)
		actor.intent = CombatIntent.new()
		controller.yaw = 0
		controller.pitch = -.1
		actor.motor.set_crouched(true)
		actor.motor.mode = "crouch"
		actor.velocity = Vector3(0,0,-3)
		for size: Vector2i in [Vector2i(1440,900),Vector2i(1600,900),Vector2i(2160,900)]:
			root.size = size
			await save_frame("%s-%d" % [hero,size.x])
	# A closer side view makes feet, knee folds and the shorter silhouette clear.
	root.size = Vector2i(1600,900)
	actor.select_hero("slayer")
	actor.global_position = Vector3(0,.05,5)
	controller.set_process(false)
	var side_camera := Camera3D.new()
	arena.add_child(side_camera)
	side_camera.current = true
	side_camera.global_position = Vector3(3.5,1.6,7)
	side_camera.look_at(actor.global_position+Vector3.UP*.8)
	side_camera.fov = 48
	actor.velocity = Vector3.ZERO
	actor.motor.set_crouched(true)
	actor.motor.mode = "crouch"
	await save_frame("slayer-side-crouch")
	actor.motor.mode = "slide"
	await save_frame("slayer-side-slide")
	actor.motor.set_crouched(false)
	actor.motor.mode = "ground"
	await save_frame("slayer-side-standing")
	arena.queue_free()
	await frames()
	await create_timer(.25).timeout
	print("CROUCH CAPTURES COMPLETE")
	quit()
