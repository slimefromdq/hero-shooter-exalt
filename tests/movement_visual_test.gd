extends SceneTree
var world: Node3D
var actor: HeroActor
var failures: int = 0
var checks: int = 0
var reasons: Array[String] = []
var confirmed: Array[String] = []
var controller: PlayerController
func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",description)
func step(frames: int = 1) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame
func reset(at: Vector3 = Vector3(0,.01,5)) -> void:
	actor.reset_actor(at)
	actor.intent.aim = Vector3.FORWARD
	await step(4)
	reasons.clear()
	confirmed.clear()
func stage(reason: String, held: bool, pressed: bool, age: float, speed: float = 10) -> void:
	actor.motor.slide_feedback.clear()
	reasons.clear()
	var input := CombatIntent.new()
	input.slide = held
	input.slide_pressed = pressed
	actor.motor.slide_feedback.begin(input)
	actor.motor.slide_feedback.resolve(reason,input,age,speed)
func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	world.add_child(CombatResolver.new())
	Geometry.box(world,Vector3(100,1,100),Vector3(0,-.5,0),Color.GRAY)
	actor = preload("res://scenes/actors/hero_actor.tscn").instantiate()
	world.add_child(actor)
	controller = PlayerController.new()
	controller.actor = actor
	actor.add_child(controller)
	# Keep local feedback available while using deterministic test intents.
	actor.controller = controller
	actor.set_physics_process(false)
	actor.dash_slide_failed.connect(func(reason: String) -> void: reasons.append(reason))
	actor.movement_confirmed.connect(func(kind: String,_at: Vector3,_direction: Vector3,_normal: Vector3,_strength: float) -> void: confirmed.append(kind))
	var diagnostic: DashSlideFeedback = actor.motor.slide_feedback
	stage("",true,true,.121)
	check(reasons == ["too_early"],"expired crouch reports too early")
	stage("",true,false,99)
	check(reasons == ["too_early"],"crouch held before dash reports too early")
	stage("",false,false,99)
	check(reasons.is_empty(),"missed landing is quiet until an actual late press")
	var input := CombatIntent.new()
	input.slide_pressed = true
	diagnostic.tick(.1,input)
	check(reasons == ["too_late"],"fresh crouch after impact reports too late")
	diagnostic.tick(.01,input)
	check(reasons.size() == 1,"one failure per dash attempt")
	stage("",false,false,99)
	diagnostic.tick(.31,input)
	check(reasons.is_empty(),"unrelated crouch after the late window stays quiet")
	stage("",true,true,.12)
	check(reasons.is_empty() and not diagnostic.active,"timing boundary remains a valid success")
	stage("",true,true,.05,4)
	check(reasons == ["too_slow"],"insufficient projected momentum has a specific reason")
	stage("",false,true,.05)
	check(reasons == ["hold_crouch"],"releasing a fresh press explains the hold requirement")
	for reason: String in ["ground_dash","not_downward","wall","ceiling","expired"]:
		stage(reason,true,true,.5)
		check(reasons == [reason],"structural cause wins over timing: "+reason)
		stage(reason,false,false,99)
		check(reasons.is_empty(),"ordinary dash stays quiet: "+reason)
		input.slide_pressed = true
		diagnostic.tick(.1,input)
		check(reasons == [reason],"late attempt retains actual obstruction reason: "+reason)
	var feedback: MovementPresentation = actor.presentation.movement
	for kind: String in ["jump","mantle","mantle_slide","melee","landing"]:
		feedback.clear()
		actor.movement_confirmed.emit(kind,actor.position,Vector3.FORWARD,Vector3.UP,1)
		check(feedback.hud_left == 0,"no unwanted local icon: "+kind)
	for kind: String in ["dash","wall_jump","slide","dash_slide"]:
		feedback.clear()
		actor.movement_confirmed.emit(kind,actor.position,Vector3.FORWARD,Vector3.UP,1)
		check(feedback.hud_kind == kind and feedback.hud_left > 0,"requested local confirmation: "+kind)
	feedback.on_failure("too_early")
	actor.movement_confirmed.emit("dash_slide",actor.position,Vector3.FORWARD,Vector3.UP,1)
	check(feedback.failure_left == 0 and feedback.hud_kind == "dash_slide","successful dash slide replaces failure feedback")
	actor.movement_confirmed.emit("landing",actor.position,Vector3.FORWARD,Vector3.UP,1)
	check(feedback.hud_kind == "dash_slide","component events cannot overwrite dash-slide confirmation")
	feedback.on_failure("too_early")
	var paused_left: float = feedback.failure_left
	paused = true
	for frame: int in 5: await process_frame
	check(feedback.failure_left == paused_left,"pause freezes feedback lifetime")
	paused = false
	var bot := preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
	bot.position = Vector3(4,0,0)
	world.add_child(bot)
	bot.set_physics_process(false)
	bot.movement_confirmed.emit("dash",bot.position,Vector3.FORWARD,Vector3.UP,1)
	check(bot.presentation.movement.hud_left == 0 and bot.presentation.movement.fov_pulses.is_empty(),"bots receive no local HUD or camera accents")
	check(bot.presentation.movement.get_child_count() == 1 and (bot.presentation.movement.get_child(0) as MovementBurst).intensity == .5,"nearby bot world effects are subdued")
	bot.queue_free()
	await step(2)
	feedback.clear()
	for i: int in 5: feedback.add_fov(4)
	check(feedback.camera_offset(0,false) == 5,"positive camera accents are clamped")
	check(feedback.camera_offset(0,true) == 0,"aiming or disabled camera effects suppress offsets")
	feedback.clear()
	for i: int in 5: feedback.add_fov(-1.5)
	check(feedback.camera_offset(0,false) == -2,"landing camera accents are clamped")
	check(feedback.camera_offset(.26,false) == 0,"camera accents expire within a quarter second")
	feedback.clear()
	controller._process(0)
	var logical_aim: Vector3 = controller.gather_intent(0).aim
	feedback.add_fov(4)
	controller._process(.01)
	check(controller.gather_intent(0).aim.is_equal_approx(logical_aim),"camera accents do not redirect logical aim")
	var store: Node = root.get_node("GameSettings")
	var previous: float = store.values["movement_camera_effects"]
	store.set_setting("movement_camera_effects",0)
	check(controller.movement_camera_effects == 0,"saved movement camera toggle reaches live controller")
	var config := ConfigFile.new()
	check(config.load(store.PATH) == OK and config.get_value("settings","movement_camera_effects",1) == 0,"movement camera preference is persisted")
	store.set_setting("movement_camera_effects",previous)
	feedback.clear()
	await step(2)
	seed(1234)
	var expected: int = randi()
	seed(1234)
	feedback.clear()
	for i: int in 100: feedback.spawn("dash",actor.position,Vector3.FORWARD,Vector3.UP)
	check(randi() == expected,"procedural movement effects do not consume gameplay RNG")
	check(feedback.get_child_count() <= 10 and get_nodes_in_group("movement_effect").size() <= 64,"world effects are bounded")
	feedback.clear()
	await step(2)
	check(feedback.get_child_count() == 0,"clearing feedback removes world effects")
	actor.set_physics_process(true)
	actor.controller = null
	await reset()
	actor.intent.jump = true
	await step()
	actor.intent.jump = false
	check(confirmed.count("jump") == 1,"actual jump emits exactly one world cue")
	await reset()
	actor.intent.dash = true
	await step()
	actor.intent.dash = false
	check(confirmed.count("dash") == 0,"dash buildup does not claim launch success")
	await step(11)
	check(confirmed.count("dash") == 1,"actual dash launch confirms once")
	await reset()
	actor.intent.dash = true
	await step()
	actor.intent.dash = false
	await step(34)
	actor.intent.slide = true
	actor.intent.slide_pressed = true
	await step()
	actor.intent.slide_pressed = false
	check(reasons == ["ground_dash"],"late crouch after a real ground dash explains the airborne requirement")
	await reset(Vector3(0,1.3,5))
	actor.tuning.dash_buildup = .01
	actor.intent.aim = Vector3(0,-.6,-.8)
	actor.intent.dash = true
	await step()
	actor.intent.dash = false
	await step(12)
	check(reasons.is_empty(),"real missed airborne landing does not guess too late")
	actor.intent.slide = true
	actor.intent.slide_pressed = true
	await step()
	actor.intent.slide_pressed = false
	check(reasons == ["too_late"],"real late airborne landing press reports too late")
	actor.tuning.dash_buildup = .16
	await reset()
	actor.motor.slide_feedback.begin(CombatIntent.new())
	actor.motor.dash_airborne = true
	actor.motor.dash_direction = Vector3.FORWARD
	actor.motor.dash_current_speed = 10
	actor.motor.transition("dash",.02)
	actor.intent.slide = true
	actor.intent.slide_pressed = true
	await step()
	actor.intent.slide_pressed = false
	await step(3)
	check(reasons == ["not_downward"],"horizontal air dash already on the floor explains the downward-contact requirement")
	actor.motor.interrupt_mobility()
	check(feedback.hud_left == 0,"mobility interruption clears local feedback")
	await reset()
	actor.die()
	check(feedback.failure_left == 0 and feedback.fov_pulses.is_empty(),"death clears HUD and camera feedback")
	actor.reset_actor()
	await step()
	check(diagnostic.pending.is_empty(),"reset clears pending dash-slide diagnoses")
	print("MOVEMENT VISUAL RESULT: ",checks," checks, ",failures," failures")
	world.queue_free()
	await step(2)
	quit(1 if failures else 0)
