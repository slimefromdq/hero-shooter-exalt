extends SceneTree
## Personalities, mood, human indecision and team callouts.
var world: Node3D
var resolver: CombatResolver
var director: TeamDirector
var a: HeroActor
var healer: HeroActor
var player: HeroActor
var foe: HeroActor
var actors: Array = []
var brain: BotBrain
var checks: int = 0
var failures: Array[String] = []
var objective: Dictionary = {"position":Vector3(0,0,-10),"phase":"fight","urgency":.5,"radius":7.0}

func _initialize() -> void:
	call_deferred("run")
	create_timer(240.0).timeout.connect(func() -> void:
		print("FAIL  personality test timed out")
		quit(1))

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
	actor.actor_id = "%s_%d_%d" % [id,team,actors.size()]
	actor.team = team
	actor.position = at
	world.add_child(actor)
	actor.set_physics_process(false)
	actors.append(actor)
	return actor

func fresh_brain(traits: Dictionary = {}, seed_value: int = 5) -> BotBrain:
	var made := BotBrain.new()
	made.setup(a,director,seed_value)
	if not traits.is_empty(): made.personality = traits
	return made

func neutral(overrides: Dictionary) -> Dictionary:
	var traits: Dictionary = {"archetype":"test","aggression":0.0,"caution":0.0,"teamplay":0.0,"flank":0.0,"patience":0.0,"flair":.3,"chattiness":.5,"tilt_prone":.5}
	traits.merge(overrides,true)
	return traits

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(80,1,80),Vector3(0,-.5,0),Color.GRAY)
	a = spawn("nimbus",0,Vector3(0,.01,0))
	healer = spawn("doctor",0,Vector3(3,.01,2))
	player = spawn("slayer",0,Vector3(-3,.01,2))
	foe = spawn("nimbus",1,Vector3(0,.01,-12))
	director = TeamDirector.obtain(world,0)
	await step(2)
	a.aim_direction = Vector3.FORWARD
	# Seeded variety.
	var kinds: Dictionary = {}
	for seed_value: int in 24:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var traits: Dictionary = BotPersonality.roll(rng)
		kinds[traits.archetype] = true
		if seed_value < 2: check(absf(float(traits.aggression)) <= .5 and float(traits.flair) >= 0 and float(traits.flair) <= 1,"rolled traits stay in range (%s)" % traits.archetype)
	check(kinds.size() >= 5,"a lobby gets a mix of archetypes (%d kinds)" % kinds.size())
	# Traits shape goals in the same situation.
	brain = fresh_brain(neutral({"aggression":.4,"caution":-.3}))
	var bold := brain
	for i: int in 4:
		resolver.combat_time += .2
		bold.decide([a,healer,foe],objective)
	var bold_scores: Dictionary = bold.scores.duplicate()
	bold.diagnostics.detach()
	brain = fresh_brain(neutral({"aggression":-.3,"caution":.4,"patience":.4}))
	for i: int in 4:
		resolver.combat_time += .2
		brain.decide([a,healer,foe],objective)
	check(float(bold_scores.pressure) > float(brain.scores.pressure),"a hothead wants to pressure more than a turtle")
	check(float(brain.scores.retreat) >= float(bold_scores.retreat) and float(brain.scores.hold) > float(bold_scores.hold),"a turtle is quicker to back off and happier to hold")
	# Mood.
	brain.on_elimination(a,foe,[] as Array[HeroActor])
	check(brain.confidence > 0,"a kill builds confidence")
	brain.on_elimination(foe,a,[] as Array[HeroActor])
	brain.on_elimination(foe,a,[] as Array[HeroActor])
	check(brain.confidence < 0,"deaths knock confidence down")
	check(brain.tilt > 0 and brain.nemesis_id == foe.get_instance_id(),"dying twice to the same enemy tilts the bot and marks a nemesis")
	brain.set_difficulty(3)
	for i: int in 6: brain.on_elimination(foe,a,[] as Array[HeroActor])
	check(brain.tilt <= BotSkillProfile.for_level(3).tilt_cap+.001,"Expert tilt stays capped")
	brain.diagnostics.detach()
	# Human indecision: near-equal goals are sometimes swapped, more often at low skill.
	var flips: Array[int] = [0,0]
	for pair: int in 2:
		var level: int = 0 if pair == 0 else 3
		brain = fresh_brain(neutral({}),900+pair)
		brain.set_difficulty(level)
		brain.skill = BotSkillProfile.for_level(level)
		for i: int in 200:
			brain.scores = {"contest":.6,"hold":.55,"pressure":.3,"flank":0.0,"commit":0.0,"protect":0.0,"support":0.0,"retreat":.1,"regroup":.1,"investigate":0.0}
			brain.tactical_state = "contest"
			if brain.pick_goal() != "contest": flips[pair] += 1
		brain.diagnostics.detach()
	check(flips[0] > flips[1],"Beginners waver between close options more than Experts (%d vs %d of 200)" % flips)
	check(flips[0] < 120,"the best option still usually wins")
	# Callouts: names, rate limits, pings.
	brain = fresh_brain(neutral({"chattiness":1.0}))
	resolver.combat_time += 10
	director.said.clear()
	director.last_say = -99.0
	director.report(a,{},[] as Array[int],resolver.combat_time,actors,objective)
	director.report(healer,{},[] as Array[int],resolver.combat_time,actors,objective)
	var heard: Array = []
	director.team_comms.connect(func(speaker: String, hero: String, text: String, kind: String) -> void: heard.append([speaker,hero,text,kind]))
	check(director.say(a,"ult","Ult ready.",resolver.combat_time),"a callout is delivered")
	check(not director.say(a,"ult","Ult ready.",resolver.combat_time+.5),"callouts are rate limited")
	check(heard.size() == 1 and str(heard[0][2]) == "Ult ready.","the team channel receives the line")
	check(director.name_for(a) != director.name_for(healer) and director.name_for(a) != "Bot","teammates get distinct names")
	player.controller = PlayerController.new()
	check(director.name_for(player) == "You","the human is shown as You")
	resolver.combat_time += 3
	director.last_time = resolver.combat_time
	director.player_ping(player)
	check(director.help_requested(player),"the V ping registers a help request")
	check(heard.any(func(line: Array) -> bool: return str(line[2]) == "On my way!"),"a support acknowledges the ping")
	var comms: TeamComms = TeamComms.attach(director,player)
	await step(1)
	comms.on_message("Wren","doctor","On my way!","ack")
	check(comms.box.get_child_count() >= 1,"team comms render on screen")
	player.controller.free()
	player.controller = null
	brain.diagnostics.detach()
	world.queue_free()
	await step(3)
	print("BOT PERSONALITY: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
