extends SceneTree
## Real player capsule follows the pedestrian paths with movement only: no jumps, vaults or warps.

var arena: Node3D
var session: CityMatch
var checks: int = 0
var failures: Array[String] = []
var routes: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func step(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func check(condition: bool, description: String) -> void:
	checks += 1
	print("PASS  " if condition else "FAIL  ", description)
	if not condition: failures.append(description)

func walk_route(caption: String, from: Vector3, to: Vector3) -> void:
	var player: HeroActor = session.player
	player.reset_actor(from + Vector3.UP * .08)
	player.invulnerable = true
	await step(5)
	var map: RID = arena.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	check(not path.is_empty() and path[-1].distance_to(to) < 1.5, caption + " has a connected pedestrian path")
	var next: int = 0
	var elapsed: float = 0
	var arrived: bool = false
	var lowest: float = player.position.y
	for frame: int in 1800:
		if player.global_position.distance_to(to) < 1.15:
			arrived = true
			break
		while next < path.size():
			var offset: Vector3 = path[next] - player.global_position
			if Vector2(offset.x, offset.z).length() < .65 and absf(offset.y) < .85:
				next += 1
			else: break
		var intent := CombatIntent.new()
		if next < path.size():
			var direction: Vector3 = path[next] - player.global_position
			direction.y = 0
			intent.move = direction.normalized()
			intent.aim = intent.move
		player.intent = intent
		await step(1)
		elapsed += 1.0 / 60.0
		lowest = minf(lowest, player.position.y)
	player.intent = CombatIntent.new()
	check(arrived and player.alive, caption + " is physically traversable with normal movement")
	check(lowest > -6.0, caption + " retains floor support above the death threshold")
	routes.append({"route": caption, "arrived": arrived, "seconds": elapsed, "end": str(player.position), "target": str(to), "lowest_y": lowest})
	print("WALK ", JSON.stringify(routes[-1]))

func run() -> void:
	arena = load("res://scenes/city/meridian_gardens.tscn").instantiate() as Node3D
	root.add_child(arena)
	current_scene = arena
	session = arena.match_controller
	session.freeze_ai = true
	var controller: PlayerController = session.player.controller
	controller.active = false
	session.player.controller = null
	var start: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec() - start < 30000:
		await step(1)
	check(session.navigation_ready, "navigation synchronizes before physical traversal")
	session.set_physics_process(false)
	await walk_route("Garden terrace 2 m", Vector3(-45, 0, 33), Vector3(-45, 2, 21))
	await walk_route("Wizard study 4 m", Vector3(49, 0, 12), Vector3(49, 4.2, 28))
	await walk_route("Arcane promenade 6.5 m", Vector3(42, 0, 46), Vector3(23, 6.5, 10))
	await walk_route("Lower Meridian -5 m", Vector3(18, 0, 40), Vector3(0, -5, 18))
	await walk_route("Subway return to street", Vector3(0, -5, 18), Vector3(-18, 0, 40))
	var sphere := SphereShape3D.new()
	sphere.radius = .12
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	query.transform = Transform3D(Basis.IDENTITY, controller.camera.global_position)
	var overlaps: Array[Dictionary] = arena.get_world_3d().direct_space_state.intersect_shape(query)
	check(overlaps.is_empty(), "shoulder camera remains clear of solid city geometry after traversal")
	print("RESULT: ", checks, " checks, ", failures.size(), " failures")
	var file := FileAccess.open("res://artifacts/city-traversal.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "routes": routes}, "\t"))
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
