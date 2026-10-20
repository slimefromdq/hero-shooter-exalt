extends SceneTree
## Original portraits and actual engine frames, generated from the playable models.
var stage: Node3D
var camera: Camera3D

class ViewerSession extends Node:
	var player: HeroActor
	var debug_view: bool = false

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
	for id: String in ["stitch"]:
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
	if not OS.get_cmdline_user_args().has("--portraits-only"): await conceal_review()
	stage.queue_free()
	await step(4)
	if OS.get_cmdline_user_args().has("--portraits-only"):
		quit()
		return
	quit()

func conceal_review() -> void:
	var observer := HeroActor.new()
	observer.tuning = HeroRoster.tuning_for("nimbus")
	observer.team = 1
	stage.add_child(observer)
	observer.global_position = Vector3(0,.01,-8)
	observer.set_physics_process(false)
	observer.presentation.set_process(false)
	observer.presentation.visible = false
	var session := ViewerSession.new()
	session.player = observer
	stage.add_child(session)
	session.add_to_group("game_session")
	var doll := HeroActor.new()
	doll.tuning = HeroRoster.tuning_for("stitch")
	doll.team = 0
	stage.add_child(doll)
	doll.position.y = .01
	doll.set_physics_process(false)
	var k := doll.kit as StitchKit
	k.start_conceal()
	await step(4)
	assert(not doll.presentation.visible,"distant observer must lose complete doll presentation")
	await capture("stitch-concealed-far")
	observer.global_position.z = -4
	await step(4)
	assert(doll.presentation.visible,"near observer must see translucent proximity clue")
	await capture("stitch-concealed-near")
	k.reveal("capture")
	await step(4)
	await capture("stitch-revealed")
