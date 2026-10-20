extends "res://tests/roster_input_test.gd"
## Rendered input-through-controller coverage for new flight and surface hang.
var arena: Node

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/wave-1-"+label+".png")

func run() -> void:
	HeroRoster.selected = "wisp"
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var training: TrainingManager = arena.training
	training.freeze_ai = true
	training.scenario = 1
	training.reset_scenario()
	training.despawn_bots()
	var actor: HeroActor = training.player
	var controller := actor.controller as PlayerController
	controller.yaw = 0
	controller.pitch = .35
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	actor.reset_actor(Vector3(0,3,11))
	await step(5)
	await press("deflect")
	check(actor.state == "wisp_phase","native E starts Rogue flight")
	var start: Vector3 = actor.position
	event("move_forward",true)
	event("jump",true)
	await step(8)
	event("move_forward",false)
	event("jump",false)
	check(actor.position.y > start.y+.15 and actor.position.z < start.z-.05,"native W plus Space rises and advances")
	await capture("rogue-flight")
	start = actor.position
	event("slide",true)
	await step(8)
	event("slide",false)
	check(actor.position.y < start.y-.2,"native Shift descends during E")
	await step(100)
	check(actor.state == "ready" and not actor.damage_immune(),"native E expires and restores vulnerability")
	actor.select_hero("stitch")
	actor.reset_actor(Vector3(0,.1,11))
	controller.pitch = 0
	controller.yaw = 0
	var wall := Geometry.box(arena,Vector3(6,5,.4),Vector3(0,2.5,6),Color("516875"))
	await step(5)
	await press("deflect")
	await step(20)
	await press("hover")
	await step(48)
	check(actor.state == "stitch_hang","native Q reels to terrain and hangs")
	check(actor.concealed(),"native hook preserves invisibility")
	await capture("stitch-hang")
	var held: Vector3 = actor.position
	await step(90)
	check(actor.position.is_equal_approx(held),"native hang remains stable")
	await press("jump")
	check(actor.state == "ready" and actor.velocity.y > 0,"native Space releases hang with wall jump")
	actor.reset_actor(Vector3(0,.1,11))
	await step(5)
	await press("deflect")
	await step(20)
	await press("hover")
	await step(48)
	await press("hover")
	check(actor.state == "ready" and actor.concealed(),"native Q toggles hang release during cooldown")
	wall.queue_free()
	actor.reset_actor(Vector3(0,.1,11))
	var target: HeroActor = training.spawn_bot(0,Vector3(0,.1,3))
	await step(5)
	await press("deflect")
	await step(20)
	await press("primary",20)
	check(target.health <= 205 and not actor.concealed(),"native concealed LMB performs damaging slicing lunge")
	check(target.statuses.effects.has("bleed"),"native lunge inflicts bleed")
	await capture("stitch-lunge")
	actor.reset_actor(Vector3(0,.1,5))
	target.reset_actor(Vector3(0,.1,3))
	await step(3)
	await press("primary")
	check(target.health <= 190,"native close attack uses heavier scissors")
	await capture("stitch-scissors")
	training.toggle_menu()
	arena.queue_free()
	await step(4)
	print("WAVE 1 INPUT: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/wave-1-input-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
