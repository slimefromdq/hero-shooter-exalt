extends SceneTree
## Tactical positioning: query picks fighting spots with sight, hides to reload, respects the
## range band, and the team danger map reflects reported enemies and recent deaths.
var world: Node3D
var resolver: CombatResolver
var region: NavigationRegion3D
var a: HeroActor
var b: HeroActor
var friend: HeroActor
var brain: BotBrain
var director: TeamDirector
var map: RID
var checks: int = 0
var failures: Array[String] = []
var objective: Dictionary = {"position":Vector3(0,0,-6),"phase":"fight","urgency":.5,"radius":7.0}

func _initialize() -> void:
	call_deferred("run")
	create_timer(240.0).timeout.connect(func() -> void:
		print("FAIL  positioning test timed out")
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
	actor.actor_id = id+str(team)
	actor.team = team
	actor.position = at
	world.add_child(actor)
	actor.set_physics_process(false)
	return actor

func solid(size: Vector3, at: Vector3) -> void:
	Geometry.box(world,size,at,Color.GRAY).add_to_group("positioning_geometry")

func fresh() -> void:
	if brain != null: brain.diagnostics.detach()
	a.reset_actor(Vector3(0,.01,0))
	b.reset_actor(Vector3(0,.01,-16))
	friend.reset_actor(Vector3(6,.01,4))
	a.aim_direction = Vector3.FORWARD
	director.clear()
	brain = BotBrain.new()
	brain.setup(a,director,23)
	await step(1)
	for i: int in 4:
		resolver.combat_time += .2
		brain.decide([a,b,friend],objective)

func choose() -> Dictionary:
	brain.movement.position_timer = -1
	brain.movement.selected_position = a.global_position
	var query: Dictionary = TacticalQuery.plan(brain,objective.position)
	var best: Vector3 = Vector3.INF
	var score: float = -INF
	var mode: String = query.mode
	# Several draws smooth out candidate sampling noise.
	for i: int in 4:
		var result: Dictionary = TacticalQuery.select(brain,query,map,brain.movement)
		if result.score > score:
			score = result.score
			best = result.point
	return {"point":best,"mode":mode,"query":query}

func exposed(point: Vector3) -> bool:
	return resolver.attack_ray(a,point+Vector3.UP*1.45,b.body_point(1.0),[a.get_rid()],1).is_empty()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	solid(Vector3(60,1,60),Vector3(0,-.5,0))
	# A cover wall to the bot's left, between it and the enemy line.
	solid(Vector3(4,3,.6),Vector3(-4,1.5,-3))
	region = NavigationRegion3D.new()
	var nav := NavigationMesh.new()
	nav.cell_size = .25
	nav.cell_height = .25
	nav.agent_radius = .5
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav.geometry_source_group_name = &"positioning_geometry"
	region.navigation_mesh = nav
	world.add_child(region)
	await step(2)
	region.bake_navigation_mesh(false)
	map = region.get_navigation_map()
	for i: int in 120:
		await step(1)
		NavigationServer3D.map_force_update(map)
		if NavigationServer3D.map_get_closest_point_owner(map,Vector3(10,0,10)) == region.get_rid(): break
	a = spawn("nimbus",0,Vector3.ZERO)
	b = spawn("nimbus",1,Vector3(0,0,-16))
	friend = spawn("marshal",0,Vector3(6,0,4))
	director = TeamDirector.obtain(world,0)
	await fresh()
	check(brain.visible_target(),"enemy is in view for the positioning checks")
	brain.tactical_state = "contest"
	var hold: Dictionary = choose()
	check(hold.mode == "contest","contesting bots fight from the objective")
	check(hold.point.distance_to(objective.position) <= float(objective.radius)+1.5,"contest spot stays on the point")
	brain.tactical_state = "pressure"
	var fight: Dictionary = choose()
	var distance: float = Vector2(fight.point.x-b.global_position.x,fight.point.z-b.global_position.z).length()
	check(fight.mode == "fight","visible enemy produces a fighting query")
	check(exposed(fight.point),"fighting spot keeps sight of the enemy")
	check(distance >= brain.hero_profile.minimum_range-1.5 and distance <= brain.hero_profile.maximum_range+1.5,"fighting spot sits in the hero's range band")
	a.kit.ammo = 0
	a.kit.reloading = true
	brain.tactical_state = "pressure"
	var hide: Dictionary = choose()
	check(hide.mode == "cover","reloading switches to a cover query")
	check(not exposed(hide.point),"reloading bot steps behind cover")
	check(hide.point.distance_to(a.global_position) < 7.0,"cover is sought nearby, then the bot can peek again")
	a.kit.reloading = false
	a.kit.ammo = a.tuning.magazine
	# Danger map from shared reports and deaths.
	director.report(a,brain.perception.observations,brain.perception.visible_ids,resolver.combat_time)
	director.next_update = -1
	director.report(a,brain.perception.observations,brain.perception.visible_ids,resolver.combat_time)
	check(director.danger_at(b.global_position+Vector3(0,0,3)) > director.danger_at(b.global_position+Vector3(0,0,30)),"danger is high near reported enemies and fades with distance")
	var quiet: Vector3 = Vector3(20,0,20)
	var before: float = director.danger_at(quiet)
	director._on_elimination(b,friend,[] as Array[HeroActor],"rifle",0)
	director.deaths[-1].position = quiet
	director.next_update = -1
	director.report(a,brain.perception.observations,brain.perception.visible_ids,resolver.combat_time)
	check(director.danger_at(quiet) > before,"a teammate's death marks the area as dangerous")
	check(not director.recent_threats(resolver.combat_time).is_empty(),"director remembers where enemies were reported")
	# Support: a healer positions with sight of its patient.
	await fresh()
	friend.global_position = Vector3(-6,.01,-6)
	friend.health = friend.effective_max_health()*.3
	friend.last_hit_age = 0
	brain.tactical_state = "support"
	brain.patient = friend
	var care: Dictionary = choose()
	check(care.mode == "support","injured ally produces a support query")
	check(resolver.attack_ray(a,care.point+Vector3.UP*1.45,friend.body_point(1.0),[a.get_rid()],1).is_empty(),"support spot keeps sight of the patient")
	brain.diagnostics.detach()
	world.queue_free()
	await step(3)
	print("BOT POSITIONING: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
