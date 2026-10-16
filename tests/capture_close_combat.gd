extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var arena: Node = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.training.scenario = 1
	arena.training.freeze_ai = true
	arena.training.reset_scenario()
	arena.training.set_process(false)
	arena.training.hud.visible = false
	var player: HeroActor = arena.player
	var target: HeroActor = arena.training.bots[0]
	player.controller.active = false
	player.controller.camera.current = false
	player.controller = null
	target.controller = null
	player.reset_actor(Vector3(0,.01,8))
	target.reset_actor(Vector3(0,.01,5.4))
	target.intent.aim = Vector3.BACK
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.position = Vector3(5.5,3.3,10)
	camera.look_at(Vector3(0,1.3,6.7))
	camera.fov = 53
	camera.current = true
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var panel := ColorRect.new()
	panel.position = Vector2(20,20)
	panel.size = Vector2(680,68)
	panel.color = Color("213a44")
	overlay.add_child(panel)
	var label := Label.new()
	label.position = Vector2(38,30)
	label.add_theme_font_size_override("font_size",20)
	label.add_theme_color_override("font_color",Color("a0eed7"))
	overlay.add_child(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/combat-frames"))
	for index: int in 8:
		await physics_frame
		await process_frame
	player.close.start_throw()
	for frame: int in 100:
		await physics_frame
		await process_frame
		label.text = "F  /  HIP THROW\nREACH → PULL → LIFT → SLAM → RELEASE"
		await RenderingServer.frame_post_draw
		if frame % 2 == 0:
			root.get_texture().get_image().save_png("res://artifacts/combat-frames/throw_%03d.png" % frame)
	print("THROW PREVIEW: target HP=",target.health," final state=",target.state)
	player.reset_actor(Vector3(0,.01,8))
	target.reset_actor(Vector3(0,.01,3.75))
	target.health = 50
	target.intent.aim = Vector3.BACK
	for index: int in 3:
		await physics_frame
		await process_frame
	player.intent.melee = true
	await physics_frame
	await process_frame
	player.intent.melee = false
	for frame: int in 70:
		await physics_frame
		await process_frame
		label.text = "V  /  STEP-IN UMBRELLA STRIKE\n2.2 m COMMITTED LUNGE  ·  ENGAGE / FINISH"
		await RenderingServer.frame_post_draw
		if frame % 2 == 0:
			root.get_texture().get_image().save_png("res://artifacts/combat-frames/melee_%03d.png" % frame)
	print("MELEE PREVIEW: target HP=",target.health," player travel=",8-player.global_position.z)
	arena.queue_free()
	overlay.queue_free()
	await process_frame
	quit()
