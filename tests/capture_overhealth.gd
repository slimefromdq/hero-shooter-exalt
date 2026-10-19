extends SceneTree
var arena: Node3D
var training: TrainingManager
var ally: HeroActor
var foe: HeroActor

func _initialize() -> void: call_deferred("run")

func step(count: int = 1) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/overhealth-"+label+".png")
	print("CAPTURE ",label)

func spawn(id: String, team: int, at: Vector3) -> HeroActor:
	var a := HeroActor.new()
	a.tuning = HeroRoster.tuning_for(id)
	a.team = team
	a.actor_id = id
	arena.add_child(a)
	a.position = at
	a.set_physics_process(false)
	return a

func run() -> void:
	HeroRoster.selected = "marshal"
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	training = arena.training
	training.freeze_ai = true
	training.despawn_bots()
	training.player.controller.active = false
	training.player.set_physics_process(false)
	training.player.reset_actor(Vector3(0,.01,12))
	ally = spawn("doctor",0,Vector3(2,.01,6))
	foe = spawn("slayer",1,Vector3(-3,.01,1))
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.position = Vector3(8,5,18)
	camera.look_at(Vector3(0,1.6,7))
	camera.fov = 65
	camera.current = true
	await step(5)
	training.player.shields = 60
	training.player.intent.deflect = true
	training.player.kit.tick(0,training.player.intent)
	training.player.intent.deflect = false
	foe.overhealth.grant(foe,75,5)
	await step(14)
	await capture("rally-training")
	training.player.resolver.damage(foe,ally,75,"rifle",training.player.resolver.new_cast(foe))
	await step(1)
	await capture("break-training")
	training.player.overhealth.tick(5)
	foe.overhealth.tick(5)
	await step(18)
	await capture("expired-training")
	for a: HeroActor in [training.player,ally,foe]: a.presentation.overhealth_visual.voice.stop()
	await step(8)
	arena.queue_free()
	await step(5)
	arena = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var city: CityMatch = arena.match_controller
	city.freeze_ai = true
	city.player.controller.active = false
	city.player.reset_actor(Vector3(0,.01,18))
	for a: HeroActor in get_nodes_in_group("actors"):
		a.set_physics_process(false)
		if a != city.player and a.team == city.player.team: ally = a
	ally.reset_actor(Vector3(2,.01,12))
	var city_camera := Camera3D.new()
	arena.add_child(city_camera)
	city_camera.position = Vector3(8,5,24)
	city_camera.look_at(Vector3(0,1.6,14))
	city_camera.current = true
	await step(5)
	city.player.shields = 60
	city.player.intent.deflect = true
	city.player.kit.tick(0,city.player.intent)
	city.player.intent.deflect = false
	await step(12)
	await capture("rally-city")
	for a: HeroActor in get_nodes_in_group("actors"): a.presentation.overhealth_visual.voice.stop()
	await step(8)
	arena.queue_free()
	await step(5)
	quit()
