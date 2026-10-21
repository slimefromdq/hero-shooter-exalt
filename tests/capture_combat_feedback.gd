extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var mode: String = "training"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
	var path: String = "res://scenes/training/combat_sandbox.tscn"
	if mode == "city": path = "res://scenes/city/meridian_gardens.tscn"
	if mode == "museum": path = "res://scenes/museum/meridian_museum.tscn"
	var arena: Node3D = load(path).instantiate()
	root.add_child(arena)
	current_scene = arena
	var session: Node = arena.training if mode == "training" else arena.match_controller
	session.freeze_ai = true
	var player: HeroActor = session.player
	player.controller.active = false
	player.set_physics_process(false)
	for actor: HeroActor in get_nodes_in_group("actors"):
		actor.set_physics_process(false)
		actor.spawn_protected = false
	player.reset_actor(Vector3(0,.1,11) if mode == "training" else Vector3(0,.4,24))
	if mode == "museum":
		session.objective.phase = "capture"
		player.reset_actor(Vector3(-16,.1,33))
	player.spawn_protected = false
	player.controller.yaw = 0
	player.controller.pitch = 0
	var enemy: HeroActor = session.bots[0]
	enemy.reset_actor(player.global_position+Vector3(0,0,-7))
	enemy.team = 1-player.team
	enemy.spawn_protected = false
	enemy.health = 600
	enemy.tuning.max_health = 600
	for index: int in 30: await process_frame
	for dimensions: Vector2i in [Vector2i(1600,900),Vector2i(2560,1080)]:
		root.size = dimensions
		for index: int in 8: await process_frame
		player.health = player.tuning.max_health*.08
		var resolver: CombatResolver = player.resolver
		resolver.impact_confirmed.emit(enemy,player,20,false,false,player.global_position+Vector3(8,1,-6),0,resolver.new_cast(enemy),"rifle")
		resolver.impact_confirmed.emit(enemy,player,20,false,false,player.global_position+Vector3(-8,1,4),0,resolver.new_cast(enemy),"rifle")
		var hud: CanvasLayer = session.hud
		var overlay: CombatFeedback
		for child: Node in hud.numbers.get_children():
			if child is CombatFeedback: overlay = child
		overlay.low_alpha = .35
		resolver.damage(player,enemy,90,"rifle",resolver.new_cast(player),true)
		overlay.set_process(false)
		overlay.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/feedback-%s-%d.png" % [mode,dimensions.x])
		overlay.skull_left = .6
		overlay.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/feedback-skull-%s-%d.png" % [mode,dimensions.x])
		overlay.clear()
		overlay.set_process(true)
	if mode == "training":
		root.size = Vector2i(1600,900)
		session.toggle_menu()
		for index: int in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/training-workshop-menu.png")
		for child: Node in session.hud.menu.get_children():
			if child is GameMenu:
				child.visible = false
				child.advanced.visible = true
		for index: int in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/training-workshop-console.png")
	print("Captured combat feedback / "+mode)
	quit()
