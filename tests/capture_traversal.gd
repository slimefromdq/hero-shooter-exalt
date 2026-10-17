extends SceneTree

var arena: Node
var player: HeroActor

func _initialize() -> void:
	call_deferred("capture")

func step(frames: int) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame

func shot(caption: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/" + caption + ".png")

func capture() -> void:
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	player = arena.player
	arena.training.freeze_ai = true
	arena.training.scenario = 5
	arena.training.reset_scenario()
	var controller: PlayerController = player.controller
	controller.active = false
	player.controller = null
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	player.reset_actor(Vector3(12,.01,9.7))
	controller.pitch = -.15
	await step(4)
	await shot("mantle-approach")
	player.intent.jump_held = true
	player.intent.move = Vector3.FORWARD
	for frame: int in 60:
		await step(1)
		if player.state == "mantle": break
	print("AUTO MANTLE INPUT: held=",player.intent.jump_held," press=",player.intent.jump)
	await step(12)
	await shot("mantle-pull")
	print("MANTLE CAPTURE: ",player.state," progress=",player.motor.traversal.progress," height=",player.global_position.y)
	await step(27)
	await shot("mantle-top")
	print("MANTLE LANDING: ",player.global_position," state=",player.state)
	player.reset_actor(Vector3(11.9,.01,-.3))
	player.intent.aim = Vector3.FORWARD
	player.intent.move = Vector3.FORWARD
	controller.yaw = 0
	await step(4)
	player.intent.jump = true
	await step(1)
	player.intent.jump = false
	await step(10)
	player.velocity.z = -6
	player.intent.jump = true
	await step(1)
	player.intent.jump = false
	await step(4)
	await shot("wall-jump")
	print("WALL JUMP CAPTURE: velocity=",player.velocity," pose=",player.presentation.animator.current_animation)
	player.reset_actor(Vector3(18,.01,12))
	controller.yaw = 0
	controller.pitch = -.2
	await step(4)
	player.intent.hover = true
	await step(1)
	player.intent.hover = false
	await step(55)
	await shot("umbrella-vault")
	print("VAULT CAPTURE: height=",player.global_position.y," mode=",player.motor.mode)
	arena.queue_free()
	await process_frame
	quit()
