extends SceneTree
var arena: Node3D
var checks: int = 0
var failures: Array[String] = []
var walks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func step(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",caption)
	if not ok: failures.append(caption)

func walk(caption: String, from: Vector3, to: Vector3, via: Array = []) -> void:
	var p: HeroActor = arena.player
	var map: RID = arena.get_world_3d().navigation_map
	var a: Vector3 = NavigationServer3D.map_get_closest_point(map,from)
	var b: Vector3 = NavigationServer3D.map_get_closest_point(map,to)
	var path := PackedVector3Array()
	var stops: Array = via.duplicate()
	stops.append(b)
	path.append(a)
	for stop: Vector3 in stops:
		path.append(stop)
	p.reset_actor(a+Vector3.UP*.1)
	p.invulnerable = true
	await step(3)
	var next: int = 0
	var arrived: bool = false
	var frames: int = 0
	for frame: int in 4200:
		frames = frame
		if Vector2(p.position.x-b.x,p.position.z-b.z).length() < 1.5 and absf(p.position.y-b.y) < 1:
			arrived = true
			break
		while next < path.size() and Vector2(p.position.x-path[next].x,p.position.z-path[next].z).length() < .8 and absf(p.position.y-path[next].y) < 1:
			next += 1
		var intent := CombatIntent.new()
		if next < path.size():
			intent.move = ((path[next]-p.position)*Vector3(1,0,1)).normalized()
			intent.aim = intent.move
		p.intent = intent
		await step(1)
		if not p.alive: break
	p.intent = CombatIntent.new()
	check(arrived and p.alive,caption+" is physically walkable without jumps or abilities")
	walks.append({"route":caption,"arrived":arrived,"seconds":frames/60.0,"end":str(p.position),"target":str(b),"next":str(path[next]) if next < path.size() else "done","index":next,"path_size":path.size()})
	if not arrived:
		for collision_index: int in p.get_slide_collision_count():
			var collision: KinematicCollision3D = p.get_slide_collision(collision_index)
			print("WALK COLLISION ",collision.get_normal()," ",collision.get_position()," ",collision.get_collider())
			if collision.get_collider() == arena.builder.architecture.collision_body:
				var shape_node: CollisionShape3D = collision.get_collider_shape() as CollisionShape3D
				print("WALK SHAPE ",shape_node.position," ",shape_node.shape)
		print("WALK MOTOR ",p.velocity," ",p.state," ",p.motor.mode," grounded=",p.motor.grounded())
	print("WALK ",walks[-1])

func run() -> void:
	arena = load("res://scenes/temple/sakura_veil.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var m: TempleMatch = arena.match_controller
	m.freeze_ai = true
	var controller: PlayerController = arena.player.controller
	controller.active = false
	var start: int = Time.get_ticks_msec()
	while not m.navigation_ready and Time.get_ticks_msec()-start < 60000: await step(1)
	check(m.navigation_ready,"navigation ready before match begins")
	m.set_physics_process(false)
	arena.player.controller = null
	for bot: HeroActor in m.bots: bot.controller.frozen = true
	check(m.actors.size() == 12 and m.team_count(0) == 6 and m.team_count(1) == 6,"two teams of six")
	m.objective.preparation_remaining = 0
	arena.builder.update_gates(m.stages,false)
	var people: Array = [[0,0],[0,0],[1,0],[0,0],[0,0]]
	m.objective.advance(24,people)
	check(m.stages == [1,0] and m.spawn_contains(arena.player.position,0),"capture advances protected room and relocates its occupant")
	people = [[0,0],[0,0],[0,0],[1,0],[0,0]]
	m.objective.advance(18,people)
	check(m.stages == [2,0],"enemy second activates mid forward spawn")
	people = [[0,0],[0,0],[0,0],[0,1],[0,0]]
	m.objective.advance(18,people)
	check(m.stages == [1,0] and m.spawn_contains(arena.player.position,0),"lost territory safely evacuates old protected room")
	var before: Vector3 = arena.player.position
	arena.player.position = m.temple_definition().room_center(1,0)
	m.enforce_spawn_exclusion(arena.player,before)
	check(arena.player.position.is_equal_approx(before),"ability relocation cannot invade enemy spawn")
	m.restart_match()
	m.freeze_ai = true
	m.objective.preparation_remaining = 0
	arena.builder.update_gates(m.stages,false)
	for bot: HeroActor in m.bots: bot.controller.frozen = true
	# Real actor physics uses this map's fall threshold, including recovery depths.
	arena.player.reset_actor(Vector3(0,-10,60))
	await step(2)
	check(arena.player.alive,"lower ravine elevations survive the old -8 m threshold")
	arena.player.position = Vector3(0,-49,60)
	await step(2)
	check(not arena.player.alive,"falls below -48 m resolve an actual death")
	arena.player.controller = controller
	m.restart_match()
	m.freeze_ai = true
	m.toggle_exploration()
	var time_before: float = m.objective.time_remaining
	m.set_physics_process(true)
	await step(60)
	check(m.exploration and m.objective.time_remaining == time_before,"Explore pauses rules and bots")
	arena.player.die()
	await step(2)
	check(arena.player.alive,"Explore recovers a lethal fall automatically")
	m.toggle_exploration()
	m.restart_match()
	m.objective.preparation_remaining = 0
	m._preparing = false
	arena.builder.update_gates(m.stages,false)
	# A reproducible three-minute live 6v6 simulation exercises the shared kits,
	# ordinary movement, route adapters and real captures under combat pressure.
	var initial: Array[Vector3] = []
	for bot: HeroActor in m.bots: initial.append(bot.position)
	Engine.time_scale = 8
	while m.elapsed < 180 and not m.objective.finished: await process_frame
	Engine.time_scale = 1
	var moved: int = 0
	var lower: int = 0
	var upper: int = 0
	var longest: float = 0
	for index: int in m.bots.size():
		var bot: HeroActor = m.bots[index]
		var brain: TempleBotController = bot.controller
		if brain.distance_travelled > 30: moved += 1
		lower += int(brain.route_visits.get("lower",0))
		upper += int(brain.route_visits.get("upper",0))
		longest = maxf(longest,brain.longest_stuck)
	check(moved == 11,"all bots leave their rooms and travel")
	check(lower > 0 and upper > 0,"bot teams use lower and upper flank assignments")
	check(m.objective.owners[2] >= 0 or m.occupancy[2][0]+m.occupancy[2][1] > 0,"live teams reach and fight over mid")
	var metrics: Dictionary = {"checks":checks,"failures":failures,"walks":walks,"owners":m.objective.owners,"bots_moved":moved,"lower_assignments":lower,"upper_assignments":upper,"longest_stuck_seconds":longest,"simulation_seconds":m.elapsed}
	var file := FileAccess.open("res://artifacts/temple/integration.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	file.close()
	print("TEMPLE INTEGRATION ",JSON.stringify(metrics))
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
