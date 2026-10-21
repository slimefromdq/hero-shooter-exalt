extends SceneTree

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",caption)

func step(count: int = 5) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	world.add_child(CombatResolver.new())
	var actor := HeroActor.new()
	world.add_child(actor)
	actor.set_physics_process(false)
	var controller := PlayerController.new()
	controller.actor = actor
	controller.active = false
	actor.add_child(controller)
	controller.set_process_unhandled_input(false)
	await step()
	for hero: String in HeroRoster.IDS:
		actor.select_hero(hero)
		for size: Vector2i in [Vector2i(1600,900),Vector2i(1280,800),Vector2i(2560,1080)]:
			root.size = size
			await step()
			var bounds: Rect2 = root.get_visible_rect()
			var head: Vector2 = controller.camera.unproject_position(actor.global_position + Vector3.UP * 1.95)
			var feet: Vector2 = controller.camera.unproject_position(actor.global_position + Vector3.UP * .1)
			check(bounds.has_point(head),"%s %s: head remains visible" % [hero,size])
			check(bounds.has_point(feet),"%s %s: full hero fits within wider framing" % [hero,size])
			check(head.x < bounds.get_center().x,"%s %s: shoulder offset keeps hero left of aim" % [hero,size])
			check(is_equal_approx(controller.camera.fov,82.0),"%s %s: normal view uses wider 82 degree FOV" % [hero,size])
			actor.motor.set_crouched(true)
			actor.motor.mode = "crouch"
			await step(40)
			var low_head: Vector2 = controller.camera.unproject_position(actor.global_position + Vector3.UP * (1.95-actor.motor.posture_lowering()))
			var low_feet: Vector2 = controller.camera.unproject_position(actor.global_position + Vector3.UP * .1)
			check(bounds.has_point(low_head) and bounds.has_point(low_feet),"%s %s: crouched hero fits the lowered camera" % [hero,size])
			check(absf(controller.rig.global_position.y-actor.global_position.y-(controller.camera_height-.7)) < .01,"%s %s: crouch camera settles 0.7 m lower" % [hero,size])
			actor.motor.set_crouched(false)
			actor.motor.mode = "ground"
	var wall: Node3D = Geometry.box(world,Vector3(5,5,.15),Vector3(0,1.75,.9),Color.GRAY)
	await step()
	check(controller.arm.get_hit_length() < controller.camera_distance * .75,"camera pulls in before entering a nearby wall")
	wall.queue_free()
	await step()
	check(absf(controller.arm.get_hit_length() - controller.camera_distance) < .05,"camera restores close shoulder distance after wall clears")
	actor.intent.aim_held = true
	await step(60)
	check(absf(controller.camera.fov - 42.0) < .05,"aiming uses 42 degree FOV")
	check(absf(controller.arm.spring_length - controller.camera_distance * .8) < .05,"aiming retains its collision-aware closer offset")
	print("CAMERA FRAMING: %d checks, %d failures" % [checks,failures])
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
