extends SceneTree
const OUT := "res://artifacts/movement-visuals/"
var arena: Node3D
var actor: HeroActor
var camera: Camera3D
var capture_title: String = ""
var canvas: Control
var font: SystemFont
func _initialize() -> void: call_deferred("run")
func step(frames: int = 1) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame
func shot(label: String) -> void:
	capture_title = label
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+label+".png") == OK)
	print("CAPTURE ",label)
func overlay() -> void:
	canvas.draw_string(font,Vector2(28,40),capture_title,HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color.WHITE)
	MovementHUD.draw(canvas,actor,font,root.size*.5)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	HeroRoster.selected = "marshal"
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.training.freeze_ai = true
	actor = arena.training.player
	actor.controller.active = false
	await step(5)
	actor.set_physics_process(false)
	for other: HeroActor in get_nodes_in_group("actors"):
		if other != actor: other.set_physics_process(false)
	camera = Camera3D.new()
	arena.add_child(camera)
	camera.fov = 65
	var layer := CanvasLayer.new()
	arena.add_child(layer)
	canvas = Control.new()
	layer.add_child(canvas)
	font = SystemFont.new()
	canvas.draw.connect(overlay)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b1c9da")
	camera.environment = environment
	(actor.controller as PlayerController).camera.environment = environment
	for hero: String in ["marshal","slayer"]:
		actor.select_hero(hero)
		actor.set_physics_process(false)
		await step(2)
		for lighting: String in ["bright","dark"]:
			environment.background_color = Color("779baf") if lighting == "bright" else Color("111c2b")
			environment.ambient_light_energy = .8 if lighting == "bright" else .15
			for node: Node in arena.find_children("*","DirectionalLight3D",true,false):
				(node as DirectionalLight3D).light_energy = 1.0 if lighting == "bright" else .08
			for view: String in ["player","external"]:
				var player_camera: Camera3D = (actor.controller as PlayerController).camera
				if view == "player": player_camera.current = true
				else: camera.current = true
				for kind: String in ["jump","wall_jump","dash","slide","dash_slide","mantle","mantle_slide","melee","landing"]:
					actor.reset_actor(Vector3(0,.01,10))
					actor.set_physics_process(false)
					actor.aim_direction = Vector3.FORWARD
					actor.state = "melee_active" if kind == "melee" else "ready"
					actor.close.melee_direction = Vector3(0,.25,-1).normalized()
					actor.close.melee_age = .27
					actor.close.melee_airborne = kind == "melee"
					actor.motor.mode = "slide" if kind in ["slide","dash_slide","mantle_slide"] else ("dash" if kind == "dash" else "air")
					if actor.motor.mode == "slide": actor.motor.set_crouched(true)
					actor.velocity = Vector3.FORWARD*14
					actor.motor.dash_direction = Vector3.FORWARD
					actor.motor.traversal.wall_pose = .28 if kind == "wall_jump" else 0
					camera.position = actor.position+Vector3(-3,2.4,-4)
					camera.look_at(actor.body_point(.9))
					await step(2)
					var at: Vector3 = actor.body_point(1) if kind in ["melee","dash","mantle"] else (actor.body_point(.8)-Vector3.RIGHT*.36 if kind == "wall_jump" else actor.position+Vector3.UP*.08)
					actor.movement_confirmed.emit(kind,at,actor.close.melee_direction if kind == "melee" else Vector3.FORWARD,Vector3.RIGHT if kind == "wall_jump" else Vector3.UP,1)
					await shot(hero+"-"+lighting+"-"+view+"-"+kind)
			actor.presentation.movement.on_failure("too_early")
			await shot(hero+"-"+lighting+"-failure")
	print("MOVEMENT_VISUAL_CAPTURE_COMPLETE")
	arena.queue_free()
	await step(2)
	quit()
