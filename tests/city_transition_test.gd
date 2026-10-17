extends SceneTree

var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	print("PASS  " if condition else "FAIL  ", description)
	if not condition:
		failures.append(description)

func settle(frames: int = 4) -> void:
	for index: int in frames:
		await process_frame

func wait_for_scene(script_path: String) -> bool:
	for index: int in 240:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get_script() != null and current_scene.get_script().resource_path == script_path:
			return true
	return false

func weak_actors() -> Array[WeakRef]:
	var result: Array[WeakRef] = []
	for actor: Node in get_nodes_in_group("actors"):
		result.append(weakref(actor))
	return result

func all_released(references: Array[WeakRef]) -> bool:
	for reference: WeakRef in references:
		if reference.get_ref() != null:
			return false
	return true

func add_transient(parent: Node) -> WeakRef:
	var transient := Node3D.new()
	transient.name = "TransitionCleanupProbe"
	parent.add_child(transient)
	transient.add_to_group("transient")
	return weakref(transient)

func check_session(city: bool) -> void:
	check(not paused, "scene transition leaves SceneTree unpaused")
	check(get_nodes_in_group("game_session").size() == 1, "exactly one game session survives the transition")
	check(get_nodes_in_group("combat_resolver").size() == 1, "exactly one combat resolver belongs to the active scene")
	check(get_nodes_in_group("city_match").size() == (1 if city else 0) and get_nodes_in_group("training").size() == (0 if city else 1), "active scene exposes only its own session groups")
	check(get_nodes_in_group("actors").size() == (12 if city else 2), "active scene owns exactly %d actors" % (12 if city else 2))
	check(get_nodes_in_group("transient").is_empty(), "old combat transients do not survive a scene transition")

func run() -> void:
	var arena: Node3D = load("res://scenes/city/meridian_gardens.tscn").instantiate() as Node3D
	root.add_child(arena)
	current_scene = arena
	var city: CityMatch = arena.match_controller as CityMatch
	city.freeze_ai = true
	city.player.controller.active = false
	var bake_start: int = Time.get_ticks_msec()
	while not city.navigation_ready and Time.get_ticks_msec() - bake_start < 20000:
		await process_frame
	check(city.navigation_ready, "initial city navigation completes before the normal transition case")
	city.toggle_menu()
	check(paused and city.menu_open, "city menu pauses the actual SceneTree")
	var previous_scene: WeakRef = weakref(arena)
	var previous_actors: Array[WeakRef] = weak_actors()
	var previous_transient: WeakRef = add_transient(arena)
	city.return_to_training()
	check(await wait_for_scene("res://scripts/training/arena.gd"), "CityMatch.return_to_training loads the training scene from pause")
	await settle()
	check_session(false)
	check(previous_scene.get_ref() == null and all_released(previous_actors), "city arena and every old city actor are released")
	check(previous_transient.get_ref() == null and get_nodes_in_group("city_health_packs").is_empty(), "city transient and health pickup nodes are released")
	var training: TrainingManager = get_first_node_in_group("training") as TrainingManager
	training.toggle_menu()
	check(paused and training.menu_open, "training menu pauses the actual SceneTree")
	previous_scene = weakref(current_scene)
	previous_actors = weak_actors()
	previous_transient = add_transient(current_scene)
	training.enter_city()
	check(await wait_for_scene("res://scripts/city/city_arena.gd"), "TrainingManager.enter_city loads Meridian Gardens from pause")
	city = get_first_node_in_group("city_match") as CityMatch
	check_session(true)
	check(previous_scene.get_ref() == null and all_released(previous_actors), "old training arena and both training actors are released")
	check(previous_transient.get_ref() == null, "old training transient is released")
	check(not city.navigation_ready and city.arena.navigation_region.navigation_mesh.get_polygon_count() == 0, "fresh city can be left before its asynchronous navigation bake finishes")
	previous_scene = weakref(current_scene)
	previous_actors = weak_actors()
	previous_transient = add_transient(current_scene)
	city.toggle_menu()
	city.return_to_training()
	check(await wait_for_scene("res://scripts/training/arena.gd"), "immediate pre-bake return safely loads training")
	await settle(12)
	check_session(false)
	check(previous_scene.get_ref() == null and all_released(previous_actors), "pre-bake city and all twelve actors are released")
	check(previous_transient.get_ref() == null and get_nodes_in_group("city_health_packs").is_empty(), "pre-bake city leaves no transient or pickup nodes")
	check(get_nodes_in_group("meridian_navigation_geometry").is_empty(), "cancelled city navigation leaves no source-geometry nodes")
	print("RESULT: ", checks, " checks, ", failures.size(), " failures")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/city-transitions.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	current_scene.queue_free()
	await settle(2)
	quit(0 if failures.is_empty() else 1)
