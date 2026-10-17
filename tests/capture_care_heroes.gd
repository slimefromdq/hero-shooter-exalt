extends SceneTree
## Actual rendered gameplay and original procedural character portraits.
var arena: Node3D
var training: TrainingManager
var camera: Camera3D
var driver: PlayerController

func _initialize() -> void:
	call_deferred("run")

func step(count: int = 1) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/care-" + name + ".png")
	print("CAPTURE ",name)

func portrait(id: String) -> void:
	training.player.controller = driver
	training.select_hero(id)
	training.despawn_bots()
	training.player.controller = null
	training.player.reset_actor(Vector3(0,.01,11))
	training.player.intent.aim = Vector3.FORWARD
	training.hud.visible = false
	camera.position = Vector3(1.6,2.0,7.8)
	camera.look_at(Vector3(0,1.35,11))
	camera.fov = 38
	await step(6)
	await capture(id + "-portrait")
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var width: int = image.get_width()
	var height: int = image.get_height()
	var crop: Image = image.get_region(Rect2i(width/2-height/3,0,height*2/3,height))
	crop.resize(256,384,Image.INTERPOLATE_LANCZOS)
	crop.save_png("res://assets/portraits/" + id + ".png")
	training.hud.visible = true

func run() -> void:
	HeroRoster.selected = "marshal"
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	training = arena.training
	training.freeze_ai = true
	driver = training.player.controller
	camera = Camera3D.new()
	arena.add_child(camera)
	camera.current = true
	await step(8)
	await portrait("marshal")
	await portrait("doctor")
	training.player.controller = driver
	training.start_care_drill("marshal")
	training.freeze_ai = true
	training.player.controller = null
	camera.position = Vector3(9,5,18)
	camera.look_at(Vector3(0,2,7))
	camera.fov = 64
	training.player.intent.secondary_held = true
	await step(8)
	await capture("marshal-shield")
	training.player.intent.secondary_held = false
	training.bots[1].position = Vector3(0,.01,8)
	training.player.intent.hover = true
	await step()
	training.player.intent.hover = false
	await step(17)
	await capture("forward-march-launch")
	training.reset_scenario()
	training.player.controller = null
	training.player.intent.bomb = true
	await step()
	training.player.intent.bomb = false
	await step(35)
	await capture("breach-line")
	training.player.intent.ultimate = true
	await step()
	training.player.intent.ultimate = false
	await step(30)
	await capture("verdict-windup")
	await step(25)
	await capture("verdict-landing")
	training.player.controller = driver
	training.start_care_drill("doctor")
	training.freeze_ai = true
	training.player.controller = null
	var d: HeroActor = training.player
	var friend: HeroActor = training.bots[1]
	camera.position = Vector3(7,4,15)
	camera.look_at(Vector3(0,1.2,6))
	camera.fov = 60
	d.intent.aim_origin = d.position + Vector3.UP * 1.4
	d.intent.aim = (friend.position + Vector3.UP * 1.2 - d.intent.aim_origin).normalized()
	d.intent.secondary_held = true
	await step(8)
	await capture("doctor-beam")
	d.intent.bomb = true
	await step()
	d.intent.bomb = false
	d.intent.ultimate = true
	await step()
	d.intent.ultimate = false
	await step(26)
	await capture("exemplary-condition")
	training.toggle_menu()
	await capture("training-menu")
	training.toggle_menu()
	arena.queue_free()
	await step(3)
	HeroRoster.selected = "marshal"
	arena = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var city: CityMatch = arena.match_controller
	city.freeze_ai = true
	await step(20)
	var city_driver: PlayerController = city.player.controller
	city.player.controller = null
	city.player.position = Vector3(0,.01,18)
	city.player.spawn_protected = false
	city.player.intent.aim = Vector3.FORWARD
	city.player.intent.secondary_held = true
	await step(40)
	await capture("city-marshal")
	city.player.controller = city_driver
	city.select_hero("doctor")
	city.freeze_ai = true
	city.player.controller = null
	city.player.position = Vector3(0,.01,18)
	city.player.spawn_protected = false
	var patient: HeroActor = city.bots[0]
	patient.position = Vector3(0,.01,10)
	patient.spawn_protected = false
	patient.health = 100
	await step(3)
	city.player.intent.aim_origin = city_driver.camera.global_position
	city.player.intent.aim = (patient.position + Vector3.UP * 1.2 - city.player.intent.aim_origin).normalized()
	city.player.intent.secondary_held = true
	await step(40)
	await capture("city-doctor")
	arena.queue_free()
	await step(3)
	quit()
