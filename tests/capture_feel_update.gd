extends SceneTree
var world: Node3D
var a: HeroActor
var b: HeroActor
var camera: Camera3D
var label: Label
var manifest: Array[Dictionary] = []
var hero: String
func _initialize() -> void: call_deferred("run")
func step(n: int = 1) -> void:
	for i: int in n:
		await physics_frame
		await process_frame
func reset(distance: float = 2.6) -> void:
	CombatEffect.clear_transients(self)
	a.reset_actor(Vector3(0,.01,0))
	b.reset_actor(Vector3(0,.01,-distance))
	b.intent.aim = Vector3.BACK
	await step(3)
func shot(kind: String, frame_camera: bool = true) -> void:
	var center: Vector3 = a.body_point(1)
	if a.state in ["throw_pair","captured"]: center = (a.body_point(1)+b.body_point(1))*.5
	if frame_camera:
		camera.global_position = center+Vector3(4.5,2.1,5)
		camera.look_at(center)
	label.text = "%s / %s\nSTATE %s | MOVEMENT %s" % [HeroRoster.display_name(hero).to_upper(),kind.to_upper(),a.state,a.motor.mode]
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "res://artifacts/feel-captures/%s-%s.png" % [hero,kind]
	root.get_texture().get_image().save_png(path)
	manifest.append({"hero":hero,"capture":kind,"path":path,"state":a.state,"motor":a.motor.mode,"target_state":b.state,"target_hp":b.health})
	print("CAPTURE ",hero," ",kind," ",a.state,"/",a.motor.mode)
func run() -> void:
	TrainingInputs.install()
	root.size = Vector2i(1280,720)
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	world.add_child(CombatResolver.new())
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("304953")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d8ebf3")
	environment.environment.ambient_light_energy = .7
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-30,0)
	sun.shadow_enabled = true
	world.add_child(sun)
	Geometry.box(world,Vector3(100,1,100),Vector3(0,-.5,0),Color("647c7c"))
	a = HeroActor.new()
	b = HeroActor.new()
	b.team = 1
	world.add_child(a)
	world.add_child(b)
	camera = Camera3D.new()
	camera.fov = 53
	world.add_child(camera)
	camera.current = true
	var canvas := CanvasLayer.new()
	world.add_child(canvas)
	label = Label.new()
	label.position = Vector2(24,20)
	label.add_theme_font_size_override("font_size",24)
	label.add_theme_constant_override("outline_size",8)
	label.add_theme_color_override("font_outline_color",Color("10232d"))
	canvas.add_child(label)
	var numbers := DamageNumbers.new()
	numbers.viewer = a
	numbers.font = ThemeDB.fallback_font
	canvas.add_child(numbers)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/feel-captures"))
	for selected: String in ["nimbus","slayer","marshal"]:
		hero = selected
		a.select_hero(hero)
		b.select_hero(hero)
		await reset(10)
		await shot("idle")
		a.intent.jump = true
		await step()
		a.intent.jump = false
		await shot("takeoff")
		await step(15)
		await shot("airborne")
		for i: int in 50:
			await step()
			if a.motor.grounded(): break
		await shot("landing")
		await reset(10)
		a.velocity = Vector3.FORWARD*10
		a.intent.slide = true
		await step(4)
		await shot("momentum-slide")
		await reset(10)
		a.intent.slide = true
		a.intent.dash = true
		await step()
		a.intent.dash = false
		await step(33)
		await shot("dash-slide")
		await reset(10)
		var wall: StaticBody3D = Geometry.box(world,Vector3(.3,5,6),Vector3(-.65,2.5,0),Color("9ba5a0"))
		a.reset_actor(Vector3(0,1,0))
		a.velocity = Vector3.DOWN
		await step()
		a.intent.jump = true
		await step()
		a.intent.jump = false
		await shot("wall-kick")
		wall.queue_free()
		await reset(10)
		var ledge: StaticBody3D = Geometry.box(world,Vector3(4,2,4),Vector3(0,1,-3),Color("9ba5a0"))
		a.reset_actor(Vector3(0,.01,-.2))
		a.intent.move = Vector3.FORWARD
		a.intent.jump_held = true
		for i: int in 30:
			await step()
			if a.motor.traversal.active: break
		await step(6)
		await shot("mantle-pull")
		while a.motor.traversal.active and a.motor.traversal.progress < .8: await step()
		a.intent.slide = true
		a.intent.slide_pressed = true
		await step()
		a.intent.slide_pressed = false
		for i: int in 15:
			await step()
			if not a.motor.traversal.active: break
		await shot("mantle-slide")
		ledge.queue_free()
		await reset(2)
		a.intent.stationary_melee = true
		a.intent.melee = true
		await step()
		a.intent.melee = false
		await step(6)
		await shot("melee-windup")
		await step(10)
		await shot("melee-impact")
		await reset(2)
		b.intent.guard = true
		await step(3)
		a.intent.melee = true
		a.intent.stationary_melee = true
		await step()
		a.intent.melee = false
		await step(15)
		await shot("shield-block")
		await reset(2.6)
		b.intent.guard = true
		await step(3)
		await shot("throw-ready")
		a.close.start_throw()
		await step(19)
		await shot("shield-break")
		await step(25)
		await shot("throw-lift")
		await step(23)
		await shot("throw-slam")
		for i: int in 30:
			await step()
			if b.state == "throw_release": break
		await shot("throw-recovery")
		await reset(2)
		a.intent.guard = true
		await step(5)
		a.intent.guard = false
		await step()
		var id: int = a.resolver.classify(a.resolver.new_cast(b),CombatResolver.ImpactKind.ABILITY)
		a.resolver.damage(b,a,30,"knife",id)
		await shot("parry")
		await reset(3)
		a.resolver.damage(b,a,15,"rifle",a.resolver.new_cast(b),false,false,a.position+Vector3.RIGHT*5)
		a.intent.aim = (b.body_point(1.2)-a.body_point(1.4)).normalized()
		await step()
		a.kit.fire(false)
		await step()
		await shot("gun-hit-and-hurt")
		await reset(10)
		a.kit.ammo = 0
		await step(3)
		await shot("automatic-reload")
		await reset(10)
		var clang_wall: StaticBody3D = Geometry.box(world,Vector3(3,4,.3),Vector3(0,2,-1.2),Color("9ba5a0"))
		a.intent.stationary_melee = true
		a.intent.melee = true
		await step()
		a.intent.melee = false
		await step(15)
		await shot("wall-clang")
		clang_wall.queue_free()
		await reset(2)
		a.intent.stationary_melee = true
		a.intent.melee = true
		await step()
		a.intent.melee = false
		await step(10)
		b.close.start_throw()
		await step(6)
		await shot("counter-hit")
		await reset(2)
		a.close.start_throw()
		b.close.start_throw()
		await step(19)
		await shot("throw-clash")
		if hero in ["nimbus","slayer"]:
			await reset(10)
			var controller := PlayerController.new()
			controller.actor = a
			controller.active = false
			a.add_child(controller)
			a.controller = controller
			a.set_physics_process(false)
			a.presentation.set_process(false)
			a.presentation.nameplate.hide()
			a.presentation.health_bar.hide()
			await step(20)
			await shot("normal-aim",false)
			a.intent.aim_held = true
			await step(20)
			await shot("zoomed-aim",false)
			a.controller = null
			a.set_physics_process(true)
			a.presentation.set_process(true)
			controller.queue_free()
			camera.current = true
	var file := FileAccess.open("res://artifacts/feel-captures/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	world.queue_free()
	await step(3)
	await create_timer(.25).timeout
	quit()
