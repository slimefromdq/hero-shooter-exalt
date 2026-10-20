extends SceneTree
## Reproducible in-engine review of the new placeholder and connected HUD.
var actor: HeroActor
var kit: RelayKit
var arena: Node3D
var camera: Camera3D

func _initialize() -> void:
	call_deferred("run")

func step(count: int = 2) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func capture(label: String) -> void:
	await step(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/seeker-"+label+".png")
	print("CAPTURE seeker-",label)

func run() -> void:
	HeroRoster.selected = "relay"
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var training: TrainingManager = arena.training
	training.freeze_ai = true
	training.start_roster_drill("relay")
	actor = training.player
	actor.controller.active = false
	actor.controller = null
	actor.set_physics_process(false)
	actor.reset_actor(Vector3(0,.01,0))
	kit = actor.kit as RelayKit
	var friend: HeroActor = training.bots[0]
	friend.reset_actor(Vector3(2,.01,-3))
	friend.health = 30
	var second: HeroActor = training.bots[1]
	second.reset_actor(Vector3(-3,.01,-5))
	second.health = 40
	var third: HeroActor = training.bots[2]
	third.reset_actor(Vector3(4,.01,-7))
	third.health = 50
	var enemy: HeroActor = training.bots[3]
	enemy.reset_actor(Vector3(0,.01,-12))
	enemy.tuning.max_health = 5000
	enemy.health = 5000
	for bot: HeroActor in training.bots:
		bot.set_physics_process(false)
	camera = Camera3D.new()
	arena.add_child(camera)
	camera.current = true
	camera.position = Vector3(7,5,10)
	camera.look_at(Vector3(0,1,-3))
	camera.fov = 65
	await step(10)
	kit.assign(friend)
	kit.tick(.3,CombatIntent.new())
	await capture("model-healing")
	actor.intent.aim_origin = actor.body_point(1.2)
	actor.aim_direction = (enemy.body_point(1.2)-actor.intent.aim_origin).normalized()
	actor.intent.aim = actor.aim_direction
	var input := CombatIntent.new()
	input.secondary_pressed = true
	input.secondary_held = true
	kit.tick(1,input)
	await capture("volley-charge")
	kit.tick(0,CombatIntent.new())
	for node: Node in get_nodes_in_group("owned_attacks"):
		if node is SeekerArrow:
			node.set_physics_process(false)
			node._physics_process(.055)
	camera.position = Vector3(3,2.5,-3)
	camera.look_at(Vector3(.1,1.25,-5.5))
	camera.fov = 45
	await capture("volley-flight")
	camera.position = Vector3(7,5,10)
	camera.look_at(Vector3(0,1,-3))
	camera.fov = 65
	for node: Node in get_nodes_in_group("owned_attacks"): node.queue_free()
	kit.ultimate_charge = 0
	kit.murmuration_left = 10
	kit.update_extras()
	kit.tick(.25,CombatIntent.new())
	await capture("murmuration")
	kit.guiding_wing()
	kit.tick(.15,CombatIntent.new())
	await capture("guiding-wing")
	kit.cast_omen()
	Geometry.box(arena,Vector3(3,3,.3),Vector3(0,1.5,-9),Color("455768"))
	await step(3)
	await capture("omen-cover")
	kit.tick(6,CombatIntent.new())
	await capture("omen-expired")
	arena.queue_free()
	await step(3)
	quit()
