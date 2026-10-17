extends SceneTree
## Render actual gameplay and generate the original procedural colony portrait.
var arena: Node3D
var training: TrainingManager
var camera: Camera3D
var h: HeroActor
var driver: PlayerController

func _initialize() -> void:
	call_deferred("run")

func step(count: int = 1) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func capture(caption: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/huddle-"+caption+".png")
	print("CAPTURE ",caption)

func run() -> void:
	HeroRoster.selected = "huddle"
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	training = arena.training
	training.freeze_ai = true
	h = training.player
	driver = h.controller
	h.controller = null
	camera = Camera3D.new()
	arena.add_child(camera)
	camera.current = true
	training.despawn_bots()
	h.reset_actor(Vector3(0,.01,11))
	h.intent.aim = Vector3.FORWARD
	training.hud.visible = false
	camera.position = Vector3(1.6,2,7.8)
	camera.look_at(Vector3(0,1.2,11))
	camera.fov = 38
	await step(8)
	await capture("portrait")
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var height: int = image.get_height()
	var crop: Image = image.get_region(Rect2i(image.get_width()/2-height/3,0,height*2/3,height))
	crop.resize(256,384,Image.INTERPOLATE_LANCZOS)
	crop.save_png("res://assets/portraits/huddle.png")
	training.hud.visible = true
	h.controller = driver
	training.start_huddle_drill()
	training.freeze_ai = true
	h.controller = null
	camera.position = Vector3(7,4,16)
	camera.look_at(Vector3(0,1.2,7))
	camera.fov = 65
	h.intent.secondary_held = true
	await step(45)
	await capture("regroup")
	h.intent.secondary_held = false
	var friend: HeroActor = training.bots[0]
	h.intent.aim = (friend.position+Vector3.UP*1.2-h.position-Vector3.UP*1.4).normalized()
	h.intent.deflect = true
	await step()
	h.intent.deflect = false
	await step(8)
	await capture("screen")
	h.intent.aim = Vector3(0,.3,-1).normalized()
	h.intent.hover = true
	await step()
	h.intent.hover = false
	await step(9)
	await capture("scatterbound")
	training.reset_scenario()
	training.freeze_ai = true
	h.controller = null
	h.intent.aim = Vector3.FORWARD
	h.intent.bomb = true
	await step()
	h.intent.bomb = false
	await step(13)
	await capture("wingbeat")
	training.reset_scenario()
	training.freeze_ai = true
	h.controller = null
	h.position = Vector3(0,.01,3)
	for i: int in 3: training.bots[i+1].position = Vector3(-1.5+i*1.5,.01,-2)
	friend = training.bots[0]
	friend.position = Vector3(8,.01,4)
	camera.position = Vector3(8,5,8)
	camera.look_at(Vector3(0,1,-1))
	h.intent.aim = Vector3.FORWARD
	h.intent.ultimate = true
	await step()
	h.intent.ultimate = false
	await step(10)
	await capture("wave-warning")
	await step(35)
	await capture("wave")
	await step(20)
	await capture("wave-displacement")
	training.toggle_menu()
	await step(3)
	await capture("training-menu")
	training.toggle_menu()
	arena.queue_free()
	await step(4)
	await city_review()
	quit()

func sample_performance() -> Dictionary:
	var process_ms: float = 0
	var physics_ms: float = 0
	var draw_calls: float = 0
	var render_objects: float = 0
	for i: int in 60:
		await step()
		process_ms += Performance.get_monitor(Performance.TIME_PROCESS)*1000
		physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		render_objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	return {"process_ms":process_ms/60,"physics_ms":physics_ms/60,"draw_calls":draw_calls/60,"render_objects":render_objects/60}

func city_review() -> void:
	HeroRoster.selected = "huddle"
	arena = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var city: CityMatch = arena.match_controller
	city.freeze_ai = true
	city.player.controller.active = false
	city.player.position = Vector3(0,.01,16)
	city.player.intent.aim = Vector3.FORWARD
	var colonies: Array[HeroActor] = []
	for actor: HeroActor in city.actors:
		if actor.kit is HuddleKit: colonies.append(actor)
	colonies[1].position = Vector3(3,.01,10)
	await step(20)
	await capture("city-shoulder")
	city.toggle_menu()
	await step(3)
	await capture("city-menu")
	city.toggle_menu()
	camera = Camera3D.new()
	arena.add_child(camera)
	camera.current = true
	camera.position = Vector3(7,4,22)
	camera.look_at(Vector3(1,1,13))
	await step(20)
	var with_colonies: Dictionary = await sample_performance()
	for actor: HeroActor in colonies: actor.select_hero("nimbus")
	await step(20)
	var baseline: Dictionary = await sample_performance()
	var file := FileAccess.open("res://artifacts/huddle-performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"resolution":str(root.size),"renderer":RenderingServer.get_video_adapter_name(),"two_colonies":with_colonies,"same_view_with_nimbus":baseline},"\t"))
	print("PERFORMANCE ",JSON.stringify({"huddle":with_colonies,"nimbus":baseline}))
	arena.queue_free()
	await step(4)
