extends SceneTree
## Human-fair perception: view cone, peripheral motion, hearing, felt hits, prediction, glances.
var world: Node3D
var resolver: CombatResolver
var a: HeroActor
var b: HeroActor
var brain: BotBrain
var director: TeamDirector
var checks: int = 0
var failures: Array[String] = []
var objective: Dictionary = {"position":Vector3(0,0,-10),"phase":"fight","urgency":.5,"radius":7.0}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func step(count: int = 1) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func spawn(id: String, team: int, at: Vector3) -> HeroActor:
	var actor := HeroActor.new()
	actor.tuning = HeroRoster.tuning_for(id)
	actor.actor_id = id+str(team)
	actor.team = team
	actor.position = at
	world.add_child(actor)
	actor.set_physics_process(false)
	return actor

func place(at: Vector3, velocity: Vector3 = Vector3.ZERO) -> void:
	b.global_position = at
	b.velocity = velocity

func fresh() -> void:
	if brain != null: brain.diagnostics.detach()
	a.reset_actor(Vector3(0,.01,0))
	b.reset_actor(Vector3(0,.01,-12))
	a.aim_direction = Vector3.FORWARD
	director.clear()
	brain = BotBrain.new()
	brain.setup(a,director,11)
	brain.set_difficulty(1)
	await step(2)

func tick(seconds: float = .2) -> void:
	resolver.combat_time += seconds
	brain.decide([a,b],objective)

func seen() -> bool:
	return b.get_instance_id() in brain.perception.visible_ids

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(120,1,120),Vector3(0,-.5,0),Color.GRAY)
	a = spawn("nimbus",0,Vector3.ZERO)
	b = spawn("slayer",1,Vector3(0,0,-12))
	director = TeamDirector.obtain(world,0)
	await fresh()
	tick()
	check(seen(),"enemy inside the view cone is seen")
	await fresh()
	place(Vector3(0,.01,12))
	tick()
	check(not seen() and not brain.perception.observations.has(b.get_instance_id()),"silent enemy directly behind is not seen")
	place(Vector3(0,.01,1.8))
	tick()
	check(seen(),"point-blank enemy is felt regardless of facing")
	await fresh()
	# 75 degrees off-axis: outside the 50 degree focus cone, inside the 100 degree peripheral band.
	var side: Vector3 = Vector3(sin(deg_to_rad(75)),0,-cos(deg_to_rad(75)))*12+Vector3.UP*.01
	place(side)
	for i: int in 4: tick()
	check(not seen(),"stationary enemy in peripheral vision goes unnoticed")
	place(side,Vector3(5,0,0))
	tick(.05)
	check(not seen(),"peripheral motion is not registered instantly")
	for i: int in 3: tick()
	check(seen(),"moving enemy in peripheral vision registers after the delay")
	check(brain.perception.peripheral_detections > 0,"peripheral detection is counted for diagnostics")
	await fresh()
	place(Vector3(2,.01,14))
	tick()
	resolver.new_cast(b)
	tick()
	var id: int = b.get_instance_id()
	check(brain.perception.observations.has(id) and not seen(),"gunfire behind is heard without granting sight")
	if brain.perception.observations.has(id):
		var entry: Dictionary = brain.perception.observations[id]
		check(Vector3(entry.position).distance_to(b.global_position) < 6.0,"heard position is near but fuzzed")
		check(str(entry.source) == "cast" and str(entry.state) == "unknown","heard entries carry no live state")
	check(not brain.ready_to_attack(),"a heard enemy cannot be attacked")
	var look: Vector3 = brain.look_direction(a.body_point(1.45),Vector3.FORWARD)
	check(look.normalized().dot((b.global_position-a.global_position).normalized()) > .6,"attention turns toward the sound")
	await fresh()
	place(Vector3(3,.01,40))
	tick()
	resolver.new_cast(b)
	brain.skill = brain.skill.duplicate() as BotSkillProfile
	brain.skill.hearing_scale = .6
	brain.perception.skill = brain.skill
	tick()
	check(not brain.perception.observations.has(b.get_instance_id()),"distant gunfire beyond hearing range is ignored")
	await fresh()
	place(Vector3(-6,.01,10))
	tick()
	var hub: BotHearing = BotHearing.obtain(resolver)
	hub.on_impact(b,a,20,false,false,b.body_point(1.2),0,1,"")
	tick()
	check(not brain.perception.hit_from.is_empty(),"incoming hit registers its direction")
	var turn: Vector3 = brain.look_direction(a.body_point(1.45),Vector3.FORWARD)
	check(turn.normalized().dot((b.body_point(1.2)-a.body_point(1.45)).normalized()) > .95,"bot turns toward an unseen attacker")
	var memory := {"position":Vector3.ZERO,"velocity":Vector3(4,0,0),"seen":0.0,"uncertainty":1.0}
	check(BotPerception.predicted(memory,.5).distance_to(Vector3(2,0,0)) < .01,"lost enemy position is dead-reckoned")
	check(BotPerception.predicted(memory,10).x <= 4.8+.01,"dead reckoning is capped")
	check(BotPerception.uncertainty(memory,2) > 8.0,"uncertainty grows with time")
	await fresh()
	place(Vector3(0,.01,60))
	brain.skill = brain.skill.duplicate() as BotSkillProfile
	brain.skill.glance_interval = 1.0
	var deviated: bool = false
	for i: int in 40:
		resolver.combat_time += .1
		brain.now = resolver.combat_time
		var dir: Vector3 = brain.look_direction(a.body_point(1.45),Vector3.FORWARD)
		if dir.normalized().dot(Vector3.FORWARD) < .5: deviated = true
	check(deviated,"idle bots periodically glance to check flanks")
	var calm := BotSkillProfile.for_level(0)
	check(calm.glance_interval == 0 and calm.cone_degrees < BotSkillProfile.for_level(3).cone_degrees,"Beginner has tunnel vision; Expert has wider awareness")
	brain.diagnostics.detach()
	world.queue_free()
	await step(3)
	print("BOT SENSES: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
