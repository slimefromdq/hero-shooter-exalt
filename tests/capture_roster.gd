extends SceneTree
## Original portraits and actual engine frames, generated from the playable models.
var stage: Node3D
var camera: Camera3D

func _initialize() -> void:
	call_deferred("run")

func step(count: int = 2) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func capture(name_value: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/roster-"+name_value+".png")
	print("CAPTURE ",name_value)

func run() -> void:
	stage = Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var resolver := CombatResolver.new()
	stage.add_child(resolver)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("182638")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e4e6ff")
	environment.environment.ambient_light_energy = .7
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35,-35,0)
	key.light_energy = 1.4
	stage.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2,3,2)
	rim.light_color = Color("b6caff")
	rim.light_energy = 2
	rim.omni_range = 8
	stage.add_child(rim)
	Geometry.box(stage,Vector3(20,1,20),Vector3(0,-.5,0),Color("263b50"))
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.fov = 36
	camera.position = Vector3(2.2,2.25,-4.7)
	camera.look_at(Vector3(0,1.13,0))
	for id: String in ["relay","dynamo","wisp"]:
		var actor := HeroActor.new()
		actor.tuning = HeroRoster.tuning_for(id)
		actor.actor_id = id
		stage.add_child(actor)
		actor.position.y = .01
		actor.set_physics_process(false)
		await step(5)
		actor.presentation.set_process(false)
		actor.presentation.health_bar.set_process(false)
		actor.presentation.health_bar.visible = false
		actor.presentation.team_ring.visible = false
		actor.presentation.nameplate.visible = false
		await capture(id+"-portrait")
		await RenderingServer.frame_post_draw
		var frame: Image = root.get_texture().get_image()
		var h: int = frame.get_height()
		var portrait: Image = frame.get_region(Rect2i(frame.get_width()/2-h/3,0,h*2/3,h))
		portrait.resize(256,384,Image.INTERPOLATE_LANCZOS)
		portrait.save_png("res://assets/portraits/"+id+".png")
		actor.queue_free()
		await step()
	stage.queue_free()
	await step(4)
	if OS.get_cmdline_user_args().has("--portraits-only"):
		quit()
		return
	await training_review()
	await city_review()
	quit()

func training_review() -> void:
	HeroRoster.selected = "relay"
	stage = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	var training: TrainingManager = stage.training
	camera = Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.position = Vector3(9,6,18)
	camera.look_at(Vector3(0,1,0))
	camera.fov = 65
	training.start_roster_drill("relay")
	training.freeze_ai = true
	var actor: HeroActor = training.player
	var driver: PlayerController = actor.controller
	actor.controller = null
	var relay := actor.kit as RelayKit
	var friend: HeroActor = training.bots[1]
	relay.assign(friend)
	await step(24)
	await capture("relay-healing")
	actor.intent.ultimate = true
	await step()
	actor.intent.ultimate = false
	await step(30)
	await capture("relay-circuit")
	actor.intent.deflect = true
	await step()
	actor.intent.deflect = false
	await step(5)
	await capture("relay-shock")
	actor.controller = driver
	training.start_roster_drill("dynamo")
	training.freeze_ai = true
	actor = training.player
	actor.controller = null
	var dynamo := actor.kit as DynamoKit
	actor.intent.secondary_held = true
	await step(115)
	await capture("dynamo-prespin")
	actor.intent.secondary_held = false
	dynamo.wall_at = Vector3(-1,.01,3)
	dynamo.wall_yaw = 0
	dynamo.wall_valid = true
	dynamo.place_wall()
	await step(6)
	await capture("dynamo-wall")
	dynamo.wall.queue_free()
	dynamo.wall = null
	await step(3)
	actor.intent.aim = (Vector3(0,.05,-8)-actor.body_point(1.4)).normalized()
	actor.intent.bomb = true
	await step()
	actor.intent.bomb = false
	await step(8)
	await capture("dynamo-lodestone-warning")
	actor.intent.ultimate = true
	await step()
	actor.intent.ultimate = false
	await step(60)
	await capture("dynamo-storm")
	actor.controller = driver
	training.start_roster_drill("wisp")
	training.freeze_ai = true
	actor = training.player
	actor.controller = null
	actor.intent.aim = Vector3(0,.2,-1).normalized()
	actor.intent.hover = true
	await step()
	actor.intent.hover = false
	await step(5)
	await capture("wisp-step")
	await step(15)
	actor.intent.deflect = true
	await step()
	actor.intent.deflect = false
	await step(5)
	await capture("wisp-phase")
	await step(45)
	actor.intent.ultimate = true
	await step()
	actor.intent.ultimate = false
	actor.intent.primary_held = true
	await step(70)
	await capture("wisp-ballet")
	actor.intent.primary_held = false
	training.toggle_menu()
	await step(3)
	await capture("training-menu")
	training.toggle_menu()
	stage.queue_free()
	await step(4)

func city_review() -> void:
	HeroRoster.selected = "wisp"
	stage = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	var city: CityMatch = stage.match_controller
	city.freeze_ai = true
	city.player.controller.active = false
	city.player.position = Vector3(0,.01,16)
	await step(20)
	await capture("city-shoulder")
	city.toggle_menu()
	await step(2)
	city.hud.menu.show_heroes()
	await step(4)
	await capture("hero-selection")
	city.toggle_menu()
	stage.queue_free()
	await step(4)
