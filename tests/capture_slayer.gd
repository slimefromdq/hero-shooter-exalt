extends SceneTree
## Scripted renderer inspection, not a substitute for a human control-feel playtest.
var arena: Node3D
var training: TrainingManager
var player: HeroActor
var controller: PlayerController

func _initialize() -> void:
	call_deferred("capture")

func step(frames: int = 1) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame

func save_image(caption: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/slayer-" + caption + ".png")
	print("CAPTURE: slayer-",caption," state=",player.state," position=",player.position)

func reset_target(at: Vector3 = Vector3(0,.01,4)) -> HeroActor:
	training.reset_scenario()
	player.controller = null
	player.position = Vector3(0,.01,11)
	player.intent.aim = Vector3.FORWARD
	controller.yaw = 0
	controller.pitch = -.08
	var target: HeroActor = training.bots[0]
	target.reset_actor(at)
	target.tuning.max_health = 1000
	target.health = 1000
	return target

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
	await step(20)
	await save_image("training")
	controller.yaw = PI - .4
	controller.pitch = -.05
	await step(3)
	await save_image("portrait")
	var target: HeroActor = reset_target(Vector3(0,.01,5))
	await step(3)
	player.intent.aim = (target.position + Vector3.UP * 1.1 - controller.camera.global_position).normalized()
	player.intent.aim_origin = controller.camera.global_position
	player.aim_direction = player.intent.aim
	(player.kit as SlayerKit).fire(false)
	await save_image("shotgun")
	print("SHOT DAMAGE: ",(player.kit as SlayerKit).last_shot_damage)
	await step(8)
	await save_image("damage-feedback")
	target = reset_target(Vector3(0,.01,-4))
	await step(3)
	(player.kit as SlayerKit).throw_knife()
	await step(3)
	await save_image("knife-windup")
	await step(16)
	await save_image("knife-trail")
	target = reset_target(Vector3(0,.01,3))
	await step(3)
	(player.kit as SlayerKit).start_boot()
	await step(13)
	await save_image("boot")
	await step(25)
	print("BOOT TARGET HP: ",target.health)
	target = reset_target(Vector3(0,.01,6))
	await step(3)
	(player.kit as SlayerKit).deploy_trap()
	await step(6)
	await save_image("trap-throw")
	await step(6)
	await save_image("trap-drop")
	await step(55)
	var trap: HunterSnare = (player.kit as SlayerKit).traps.back()
	target.position = trap.position + Vector3(0,0,-.7)
	await step(5)
	await save_image("snare")
	target = reset_target(Vector3(0,.01,5))
	await step(3)
	player.intent.ultimate = true
	await step()
	player.intent.ultimate = false
	await step(27)
	await save_image("axe-windup")
	await step(20)
	await save_image("axe-flight")
	await step(20)
	await save_image("wound")
	print("AXE VICTIM: hp=",target.health," effective_max=",target.effective_max_health())
	# Victim HUD explicitly exposes the disabled half of the base health bar.
	player.statuses.apply("max_health",target,8,.5)
	await save_image("victim-hud")
	target = reset_target(Vector3(0,.01,8.7))
	await step(3)
	player.intent.throw_action = true
	await step()
	player.intent.throw_action = false
	await step(19)
	await save_image("grab")
	while player.state == "throw_pair" and player.close.pair_progress < .45: await step()
	await save_image("throw-lift")
	while player.state == "throw_pair" and player.close.pair_progress < .74: await step()
	await save_image("throw-slam")
	await step(30)
	print("THROW VICTIM HP: ",target.health," PLAYER STATE: ",player.state)
	player.controller = controller
	training.toggle_menu()
	await save_image("console")
	training.toggle_menu()
	ProceduralSound.slayer_wave("shotgun").save_to_wav("res://artifacts/slayer-shotgun.wav")
	for actor: HeroActor in get_nodes_in_group("actors"):
		actor.presentation.sound.stop()
		actor.presentation.sound.stream = null
	# Let the audio mixer acknowledge stopped voices before shutting down the engine.
	var stop_time: int = Time.get_ticks_msec() + 100
	while Time.get_ticks_msec() < stop_time: await process_frame
	arena.queue_free()
	await step(3)
	quit()
