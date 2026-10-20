extends SceneTree
var arena: Node3D
var actor: HeroActor
var failures: int = 0
var checks: int = 0
var movement_events: Array[String] = []
func _initialize() -> void: call_deferred("run")
func step(frames: int = 1) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
func run() -> void:
	HeroRoster.selected = "nimbus"
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.training.freeze_ai = true
	actor = arena.training.player
	actor.controller = null
	for other: HeroActor in get_nodes_in_group("actors"):
		if other != actor: other.set_physics_process(false)
	actor.movement_confirmed.connect(func(kind: String,_at: Vector3,_direction: Vector3,_normal: Vector3,_strength: float) -> void: movement_events.append(kind))
	for timing: String in ["unassisted","early","late","after"]:
		movement_events.clear()
		actor.reset_actor(Vector3(18,.01,-16.60))
		actor.intent.aim = Vector3.FORWARD
		actor.intent.move = Vector3.FORWARD
		await step(4)
		actor.intent.jump = true
		await step()
		actor.intent.jump = false
		await step(19)
		actor.intent.jump = true
		actor.intent.jump_held = true
		await step()
		actor.intent.jump = false
		print("KICK ",timing," position=",actor.position," velocity=",actor.velocity)
		# Reduced shared wall lift deliberately loses the old unassisted route.
		# A committed upward air dash supplies the alternative without map edits.
		if timing != "unassisted":
			actor.intent.aim = Vector3(0,.5,-.8660254)
			actor.intent.dash = true
			await step()
			actor.intent.dash = false
		for frame: int in 80:
			await step()
			if actor.motor.traversal.active: break
		if timing == "unassisted":
			check(not actor.motor.traversal.active and not movement_events.has("mantle"),"reduced wall kick cannot reach the old unassisted 4.5m tower route")
			continue
		check(actor.motor.traversal.active,timing+" reaches real 4.5m training tower mantle using wall kick and air dash")
		if not actor.motor.traversal.active: continue
		print("MANTLE ",timing," carried=",actor.motor.traversal.carried_velocity," direction=",actor.motor.traversal.approach_direction)
		if timing == "early":
			actor.intent.slide = true
			actor.intent.slide_pressed = true
			await step()
			actor.intent.slide_pressed = false
		for frame: int in 40:
			if timing == "late" and actor.motor.traversal.duration-actor.motor.traversal.elapsed <= .1:
				actor.intent.slide = true
				actor.intent.slide_pressed = true
			await step()
			actor.intent.slide_pressed = false
			if not actor.motor.traversal.active: break
		if timing == "after":
			actor.intent.slide = true
			actor.intent.slide_pressed = true
			await step()
			actor.intent.slide_pressed = false
		print("EXIT ",timing," at=",actor.position," velocity=",actor.velocity," mode=",actor.motor.mode," source=",actor.motor.slide_source)
		check(actor.velocity.z < 0,timing+" exits the tall training tower forward")
		var start: Vector3 = actor.position
		await step(4)
		check(actor.motor.mode == "slide" and actor.position.z < start.z-.35,timing+" continues sliding forward on the actual tower roof")
		check(movement_events.count("wall_jump") == 1 and movement_events.count("mantle") == 1,timing+" confirms the actual wall jump and successful mantle once")
		check(movement_events.has("slide" if timing == "early" else "mantle_slide"),timing+" emits the matching slide effect on the real tower")
	print("TRAINING MANTLE SLIDE RESULT: ",checks," checks, ",failures," failures")
	arena.queue_free()
	await step(2)
	quit(1 if failures else 0)
