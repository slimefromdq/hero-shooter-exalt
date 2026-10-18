extends SceneTree
var world: Node3D
var a: HeroActor
var b: HeroActor
var camera: Camera3D
var caption: Label
func _initialize() -> void: call_deferred("capture")
func step(frames: int = 1) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame
func save_image(name: String, text: String) -> void:
	caption.text = text
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://artifacts/slayer-task2-"+name+".png") == OK)
	print("CAPTURE ",name)
func spawn(hero: String, team: int, at: Vector3) -> HeroActor:
	var actor: HeroActor = preload("res://scenes/actors/hero_actor.tscn").instantiate()
	actor.tuning = HeroRoster.tuning_for(hero)
	actor.actor_id = hero
	actor.team = team
	actor.position = at
	world.add_child(actor)
	return actor
func reset() -> void:
	CombatEffect.clear_transients(self)
	a.reset_actor(Vector3(0,.01,0))
	b.reset_actor(Vector3(14,.01,-10))
	a.aim_direction = Vector3.FORWARD
	a.intent.aim = Vector3.FORWARD
	a.set_physics_process(true)
	b.set_physics_process(false)
	a.visible = true
	b.visible = true
	await step(3)
func projectile(kind: String) -> SlayerProjectile:
	var p := SlayerProjectile.new()
	p.source = a
	p.kind = kind
	p.direction = Vector3.FORWARD
	world.add_child(p)
	p.position = Vector3(0,3,0)
	p.set_physics_process(false)
	return p
func capture() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var resolver := CombatResolver.new()
	world.add_child(resolver)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("182331")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("ccd9f4")
	environment.environment.ambient_light_energy = .65
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-48,-25,0)
	light.light_energy = 1.8
	Geometry.box(world,Vector3(100,1,100),Vector3(0,-.5,0),Color("303946"))
	for index: int in range(-10,11): Geometry.box(world,Vector3(40,.006,.016),Vector3(0,.006,index*2),Color("4c586a"),false)
	a = spawn("slayer",0,Vector3(0,.01,0))
	b = spawn("nimbus",1,Vector3(14,.01,-10))
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 52
	var canvas := CanvasLayer.new()
	world.add_child(canvas)
	caption = Label.new()
	canvas.add_child(caption)
	caption.position = Vector2(36,30)
	caption.add_theme_font_size_override("font_size",28)
	await reset()
	camera.position = Vector3(5,2.8,4)
	camera.look_at(Vector3(0,1,0))
	a.intent.move = Vector3.RIGHT
	(a.kit as SlayerKit).start_boot()
	await save_image("boot-start","BOOT RUSH / startup")
	await step(10)
	camera.position = a.position + Vector3(5,2.5,4)
	camera.look_at(a.body_point(1.0))
	await save_image("boot-curve","BOOT RUSH / live right steering, crimson-silver path")
	await reset()
	b.position = Vector3(1.25,.01,-6)
	b.set_physics_process(true)
	a.intent.move = Vector3.RIGHT
	await step(2)
	(a.kit as SlayerKit).start_boot()
	while a.boot_pair == null: await step()
	camera.position = a.position + Vector3(4,2.4,3)
	camera.look_at((a.position+b.position)*.5+Vector3.UP)
	await save_image("boot-contact","BOOT RUSH / contact shockwave and attached pose")
	while a.boot_pair != null: await step()
	await step(2)
	await save_image("boot-kick","BOOT RUSH / established automatic victim launch")
	await reset()
	camera.position = Vector3(4,2.8,4)
	camera.look_at(a.body_point(1.3))
	a.intent.ultimate = true
	await step()
	a.intent.ultimate = false
	await step(18)
	await save_image("axe-windup","HEADS WILL ROLL / charging and anticipation")
	await reset()
	a.set_physics_process(false)
	a.visible = false
	b.visible = false
	var p: SlayerProjectile = projectile("axe")
	for index: int in 4:
		if index > 0: p._physics_process(.05)
		camera.position = p.position + Vector3(5,.6,0)
		camera.look_at(p.position+Vector3.UP*.2)
		await save_image("axe-side-%d" % index,"AXE / side / t=%.2f s / local blade-normal spin" % (index*.05))
	camera.position = p.position + Vector3(0,.6,-5)
	camera.look_at(p.position+Vector3.UP*.2)
	await save_image("axe-front","AXE / frontal / cutting plane follows travel")
	camera.position = p.position + Vector3(0,.6,5)
	camera.look_at(p.position+Vector3.UP*.2)
	await save_image("axe-trailing","AXE / trailing / travel frame and spin are separate")
	p.queue_free()
	await step(2)
	p = projectile("knife")
	camera.position = Vector3(.65,3.45,-.7)
	camera.look_at(p.position+Vector3(0,0,-.12))
	await save_image("knife-detail","SILVER KNIFE / tapered blade, ridge, cutting edge and wrapped grip")
	for index: int in 12: p._physics_process(.015)
	camera.position = Vector3(13,5,-10)
	camera.look_at(Vector3(0,2.8,-12))
	await save_image("knife-arc","KNIFE / physical gravity arc, same path for visible model and sweep")
	await reset()
	a.set_physics_process(false)
	b.position = Vector3(0,.01,-4)
	camera.position = Vector3(3,2.4,-1)
	camera.look_at(Vector3(0,1.1,-4))
	await step(2)
	p = projectile("knife")
	p.position = Vector3(0,1.1,0)
	p._physics_process(.05)
	await save_image("knife-hit","KNIFE / piercing contact and restrained bleed application")
	await reset()
	a.set_physics_process(false)
	b.position = Vector3(0,.01,-4)
	camera.position = Vector3(3,2.6,-1)
	camera.look_at(Vector3(0,1.2,-4))
	await step(2)
	p = projectile("axe")
	p.position = Vector3(0,1.1,0)
	p._physics_process(.2)
	await save_image("axe-hit","AXE / heavy impact, magical fragments and max-health wound")
	for cue: String in ["boot_start","boot_wind","boot_hit","boot_kick","axe_draw","axe_release","axe_hit","knife","knife_hit"]:
		ProceduralSound.slayer_wave(cue).save_to_wav("res://artifacts/slayer-task2-"+cue+".wav")
	a.presentation.clear_feedback()
	var stop_time: int = Time.get_ticks_msec()+150
	while Time.get_ticks_msec() < stop_time: await process_frame
	world.queue_free()
	await step(3)
	quit()
