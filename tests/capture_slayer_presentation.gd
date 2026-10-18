extends SceneTree
## Representative live gameplay frames. Audio is exported for separate manual listening.
var arena: Node3D
var training: TrainingManager
var player: HeroActor
var controller: PlayerController
func _initialize() -> void: call_deferred("capture")
func step(frames: int = 1) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame
func save_image(caption: String) -> void:
	await RenderingServer.frame_post_draw
	var error: Error = root.get_texture().get_image().save_png("res://artifacts/slayer-phase1-" + caption + ".png")
	assert(error == OK)
	print("CAPTURE: ",caption)
func fire() -> void:
	var target: HeroActor = training.bots[0]
	player.reset_actor(Vector3(0,.01,11))
	player.controller = null
	target.reset_actor(Vector3(0,.01,5))
	target.health = 1000
	player.intent.aim = Vector3.FORWARD
	player.intent.aim_origin = player.global_position + Vector3.UP * 1.05
	player.aim_direction = Vector3.FORWARD
	await step(2)
	(player.kit as SlayerKit).fire()
func capture() -> void:
	HeroRoster.selected = "slayer"
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	training = arena.training
	training.freeze_ai = true
	training.scenario = 1
	training.reset_scenario()
	player = training.player
	controller = player.controller
	player.controller = null
	controller.yaw = .20
	controller.pitch = -.12
	await step(30)
	await fire()
	await step(1)
	await save_image("muzzle")
	await step(5)
	await save_image("recovery")
	# Show the confirmed impact from a closer observer position.
	controller.set_process(false)
	controller.camera.global_position = Vector3(2.2,2.3,7.6)
	controller.camera.look_at(Vector3(0,1.2,5))
	await fire()
	await step(1)
	await save_image("target-impact")
	await step(5)
	await save_image("impact-tail")
	# Exercise the original fallback through the same discharge.
	player.presentation.slayer_shot.enabled = false
	await fire()
	await step(1)
	await save_image("fallback")
	for cue: String in ["shotgun", "shotgun_mechanism", "shotgun_hit", "shotgun_surface"]:
		ProceduralSound.slayer_wave(cue).save_to_wav("res://artifacts/slayer-phase1-" + cue + ".wav")
	for actor: HeroActor in get_nodes_in_group("actors"): actor.presentation.clear_feedback()
	# Give the real audio mixer time to release stopped PCM buffers before exit.
	var stop_time: int = Time.get_ticks_msec() + 150
	while Time.get_ticks_msec() < stop_time: await process_frame
	arena.queue_free()
	await step(5)
	quit()
