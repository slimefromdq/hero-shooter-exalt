extends SceneTree
## Team brain: fight odds, orders (push / group up / fall back / cleanup / hold), gathering
## instead of trickling in, focus calls, mobility-based flank roster, ult economy, health packs.
var world: Node3D
var resolver: CombatResolver
var director: TeamDirector
var a: HeroActor
var tank: HeroActor
var healer: HeroActor
var foes: Array[HeroActor] = []
var actors: Array = []
var brain: BotBrain
var checks: int = 0
var failures: Array[String] = []
var objective: Dictionary = {"position":Vector3(0,0,-10),"phase":"fight","urgency":1.0,"radius":7.0,"secured":false,"desperate":false}

func _initialize() -> void:
	call_deferred("run")
	create_timer(240.0).timeout.connect(func() -> void:
		print("FAIL  team test timed out")
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
	actor.spawn_position = at+Vector3(0,0,30 if team == 0 else -30)
	actors.append(actor)
	return actor

## Runs the director's strategic update as the bots would, advancing time.
func think(seconds: float = .5) -> void:
	resolver.combat_time += seconds
	var now: float = resolver.combat_time
	for ally: HeroActor in [a,tank,healer]:
		if ally.alive: director.report(ally,{},[] as Array[int],now,actors,objective)
	director.next_update = -1
	brain.decide(actors,objective)
	director.next_update = -1
	director.report(a,brain.perception.observations,brain.perception.visible_ids,now,actors,objective)

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(120,1,120),Vector3(0,-.5,0),Color.GRAY)
	a = spawn("wisp",0,Vector3(0,.01,0))
	tank = spawn("marshal",0,Vector3(3,.01,1))
	healer = spawn("doctor",0,Vector3(-3,.01,2))
	foes.append(spawn("nimbus",1,Vector3(0,.01,-14)))
	foes.append(spawn("doctor",1,Vector3(4,.01,-16)))
	foes.append(spawn("dynamo",1,Vector3(-4,.01,-15)))
	director = TeamDirector.obtain(world,0)
	await step(2)
	a.aim_direction = Vector3.FORWARD
	brain = BotBrain.new()
	brain.setup(a,director,41)
	think()
	think()
	check(director.order == "push","even numbers push the objective")
	check(director.odds > .3 and director.odds < .8,"even fight odds read as roughly even (%.2f)" % director.odds)
	check(director.focus_id == foes[1].get_instance_id(),"focus call picks the enemy support")
	foes[1].health = foes[1].effective_max_health()*.15
	think()
	check(brain.target_id == foes[1].get_instance_id(),"bot joins the focus on the weakened support")
	# Flank roster comes from mobility and health, not slots.
	check(director.flankers.has(a.get_instance_id()) and not director.flankers.has(tank.get_instance_id()) and not director.flankers.has(healer.get_instance_id()),"the mobile DPS is chosen to flank; tank and healer are not")
	check(director.assignment(a) == "flank","flanker receives the flank intention")
	# Losing two teammates: no trickling in, fall back and group up.
	tank.alive = false
	healer.alive = false
	think(2.5)
	check(director.order in ["fall_back","group_up"],"down two players the team falls back (%s)" % director.order)
	check(director.fight_odds(objective.position,30,resolver.combat_time) < .3,"odds collapse when outnumbered")
	check(director.gather_point != Vector3.INF and director.gather_point.distance_to(objective.position) > 8,"a gather point sits back from the objective")
	a.global_position = Vector3(0,.01,25)
	foes[0].global_position = Vector3(30,.01,-40)
	foes[1].global_position = Vector3(32,.01,-40)
	foes[2].global_position = Vector3(34,.01,-40)
	brain.perception.reset()
	director.reports.clear()
	for i: int in 4: think(.5)
	if director.order == "fall_back": think(2.5)
	check(brain.tactical_state == "regroup","out of sight, the bot regroups instead of trickling in (%s)" % brain.tactical_state)
	var plan: Dictionary = TacticalQuery.plan(brain,objective.position)
	check(plan.mode == "gather" and Vector3(plan.center).distance_to(director.gather_point) < .1,"regrouping heads for the team gather point")
	# Respawned teammates gather; the team pushes together again.
	tank.alive = true
	healer.alive = true
	tank.global_position = director.gather_point
	healer.global_position = director.gather_point+Vector3(2,0,0)
	a.global_position = director.gather_point+Vector3(-2,0,0)
	think(2.5)
	think(.5)
	check(director.order == "push","once regrouped the team pushes together (%s)" % director.order)
	# Desperation overrides caution.
	tank.alive = false
	healer.alive = false
	objective.desperate = true
	think(.5)
	check(director.order == "push","a team about to lose pushes even when outnumbered")
	objective.desperate = false
	tank.alive = true
	healer.alive = true
	# Ult economy.
	director.order = "cleanup"
	director.odds = .9
	check(director.ult_gate(a,resolver.combat_time) < 1.0,"ultimates are held when the fight is already won")
	director.order = "push"
	director.ally_ults[tank.get_instance_id()] = {"time":resolver.combat_time,"position":a.global_position}
	check(director.ult_gate(a,resolver.combat_time) > 1.0,"a teammate's ultimate invites a follow-up combo")
	director.ally_ults.clear()
	# Health packs: depends on context, not a flat threshold.
	a.health = a.effective_max_health()*.55
	healer.global_position = Vector3(200,0,200)
	brain.allies = [tank]
	brain.threat = {}
	check(brain.wants_health(),"half health with no healer around and no fight: go get a pack")
	healer.global_position = a.global_position+Vector3(2,0,0)
	brain.allies = [tank,healer]
	check(not brain.wants_health(),"with a healer nearby the same wound does not justify a detour")
	brain.diagnostics.detach()
	world.queue_free()
	await step(3)
	print("BOT TEAM: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
