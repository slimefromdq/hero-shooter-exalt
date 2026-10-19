extends SceneTree
## Real training and city scenes, including the unmodified player camera.
const OUT := "res://artifacts/marshal-character/"
func _initialize() -> void: call_deferred("run")
func step(count: int) -> void:
	for i: int in count: await physics_frame; await process_frame
func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+name+".png")==OK)
	print("CAPTURE ",name)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	HeroRoster.selected = "marshal"
	var training: Node3D = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(training)
	current_scene = training
	training.training.freeze_ai = true
	var player: HeroActor = training.training.player
	player.controller.active = false
	await step(8)
	assert(is_instance_valid(player.presentation.marshal_model))
	await shot("training-gameplay")
	player.controller = null
	player.intent.slide = true
	await step(10)
	await shot("training-crouch-gameplay")
	training.queue_free()
	await step(4)
	var arena: Node3D = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var city: CityMatch = arena.match_controller
	city.freeze_ai = true
	player = city.player
	player.reset_actor(Vector3(8,.01,8))
	player.controller.active = false
	var started := Time.get_ticks_msec()
	while not city.navigation_ready and Time.get_ticks_msec()-started<30000: await process_frame
	assert(city.navigation_ready)
	await step(10)
	assert(is_instance_valid(player.presentation.marshal_model))
	await shot("city-gameplay")
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.current = true
	camera.position = player.global_position+Vector3(-2.7,2,-4.6)
	camera.look_at(player.global_position+Vector3.UP*1.35)
	await step(2)
	await shot("city-character")
	var marshals: int = 1
	for bot: HeroActor in city.bots:
		if bot.kit is MarshalKit:
			assert(is_instance_valid(bot.presentation.marshal_model))
			marshals += 1
	print("MARSHAL_GAME_RENDER_COMPLETE authored_actors=",marshals)
	arena.queue_free()
	await step(4)
	quit()
