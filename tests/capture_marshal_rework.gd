extends "res://tests/care_heroes_test.gd"

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(70,1,70),Vector3(0,-.5,-5),Color("484954"))
	for z: int in range(-25,10,5):
		Geometry.box(world,Vector3(25,.015,.035),Vector3(0,.01,z),Color("7c7d89"),false)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-55,-25,0)
	light.light_energy = 1.5
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("252935")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .5
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(12,9,7)
	camera.look_at(Vector3(0,2,-8))
	camera.current = true
	marshal = spawn("marshal",0,Vector3(0,.01,0))
	enemy = spawn("nimbus",1,Vector3(.4,.01,-3))
	hunter = spawn("slayer",1,Vector3(-.3,.01,-7))
	for a: HeroActor in [marshal,enemy,hunter]: a.set_physics_process(true)
	await step(4)
	enemy.position.z = -14
	hunter.position.x = -8
	marshal.intent.primary = true
	await step()
	marshal.intent.primary = false
	await step(5)
	await capture("cannon-flight")
	await step(100)
	marshal.reset_actor(Vector3(0,.01,0))
	enemy.reset_actor(Vector3(.4,.01,-3))
	hunter.reset_actor(Vector3(-.3,.01,-7))
	marshal.intent = CombatIntent.new()
	marshal.intent.hover = true
	await step()
	marshal.intent.hover = false
	await step(25)
	await capture("charge")
	await step(90)
	marshal.reset_actor(Vector3(0,.01,0))
	marshal.intent = CombatIntent.new()
	marshal.intent.ultimate = true
	await step()
	marshal.intent.ultimate = false
	marshal.intent.move = Vector3.RIGHT
	await step(61)
	await capture("verdict-apex")
	await step(25)
	await capture("verdict-impact")
	for a: HeroActor in [marshal,enemy,hunter]:
		a.set_physics_process(false)
		a.presentation.sound.stop()
		a.presentation.impact_sound.stop()
	await step(8)
	world.queue_free()
	await step(3)
	quit()

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/marshal-rework-"+label+".png")
	print("CAPTURE ",label)
