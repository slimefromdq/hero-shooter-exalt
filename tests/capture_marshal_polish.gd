extends SceneTree
var world: Node3D
var source: HeroActor
var target: HeroActor
var camera: Camera3D

func _initialize() -> void: call_deferred("run")
func step(count: int = 1) -> void:
	for i: int in count:
		await physics_frame
		await process_frame
func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/marshal-polish-"+label+".png")
	print("CAPTURE ",label)
func spawn(id: String, team: int, at: Vector3) -> HeroActor:
	var actor := HeroActor.new()
	actor.tuning = HeroRoster.tuning_for(id)
	actor.actor_id = id
	actor.team = team
	actor.position = at
	world.add_child(actor)
	return actor
func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var resolver := CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(65,1,65),Vector3(0,-.5,-8),Color("3c4653"))
	for z: int in range(-26,10,2): Geometry.box(world,Vector3(24,.015,.025),Vector3(0,.008,z),Color("777d88"),false)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-55,-30,0)
	light.light_energy = 1.4
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("1b2538")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("bacada")
	env.environment.ambient_light_energy = .6
	world.add_child(env)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(13,9,12)
	camera.look_at(Vector3(0,2,-7))
	camera.fov = 60
	camera.current = true
	source = spawn("marshal",0,Vector3(0,.01,3))
	target = spawn("nimbus",1,Vector3(0,.01,-8))
	target.set_physics_process(false)
	source.intent.aim = Vector3.FORWARD
	await step(4)
	source.intent.bomb = true
	await step()
	source.intent.bomb = false
	await step(12)
	await capture("orbital-telegraph")
	await step(16)
	await capture("orbital-impact")
	await step(90)
	camera.position = Vector3(8,5,12)
	camera.look_at(Vector3(0,2,1))
	source.intent.secondary_held = true
	await step(10)
	await capture("barrier-full")
	var k := source.kit as MarshalKit
	k.barrier.receive_damage(target,850,resolver.new_cast(target))
	await step(2)
	await capture("barrier-cracks")
	k.barrier.receive_damage(target,500,resolver.new_cast(target))
	await step(1)
	await capture("barrier-break")
	source.intent.secondary_held = false
	await step(30)
	camera.position = Vector3(5,3,7)
	camera.look_at(Vector3(0,1.4,1))
	source.intent.primary = true
	await step(1)
	source.intent.primary = false
	await capture("cannon-fire")
	await step(30)
	camera.look_at(Vector3(0,1,-7))
	await capture("cannon-explosion")
	camera.look_at(Vector3(0,1.4,1))
	source.kit.start_reload()
	await step(30)
	await capture("cannon-reload")
	source.set_physics_process(false)
	source.presentation.marshal_combat.clear()
	source.presentation.overhealth_visual.clear()
	await step(8)
	world.queue_free()
	await step(5)
	quit()
