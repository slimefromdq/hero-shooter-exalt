extends SceneTree

var checks: int = 0
var failures: Array[String] = []
var arena: Node3D
var session: CityMatch
var path_results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	print("PASS  " if condition else "FAIL  ", description)
	if not condition:
		failures.append(description)

func step(frames: int) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame

func path_length(path: PackedVector3Array) -> float:
	var length: float = 0.0
	for index: int in range(1, path.size()):
		length += path[index - 1].distance_to(path[index])
	return length

func query_route(team: int, role: String) -> Dictionary:
	var map: RID = arena.get_world_3d().navigation_map
	var previous: Vector3 = session.definition.team_spawns(team)[0]
	var length: float = 0.0
	var connected: bool = true
	var collision_snags: Array[String] = []
	var segments: Array[Dictionary] = []
	for target: Vector3 in session.definition.route_points(team, role):
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, previous, target, true)
		var reached: bool = not path.is_empty() and path[-1].distance_to(target) < 1.5 and path[0].distance_to(previous) < 1.5
		connected = connected and reached
		length += path_length(path)
		var original_mask: int = session.player.collision_mask
		session.player.collision_mask = 1
		for index: int in range(1, path.size()):
			var collision := KinematicCollision3D.new()
			if session.player.test_move(Transform3D(Basis.IDENTITY, path[index - 1] + Vector3.UP * 0.08), path[index] - path[index - 1], collision):
				if absf(collision.get_normal().y) < 0.7:
					collision_snags.append(str(collision.get_position()))
		session.player.collision_mask = original_mask
		segments.append({"from": str(previous), "to": str(target), "connected": reached, "length": path_length(path), "endpoint": str(path[-1]) if not path.is_empty() else "empty"})
		previous = target
	var result: Dictionary = {"team": team, "role": role, "connected": connected, "length_m": length, "walk_seconds": length / 6.0, "collision_snags": collision_snags, "segments": segments}
	path_results.append(result)
	print("NAV ROUTE  ", JSON.stringify(result))
	return result

func run() -> void:
	seed(8407)
	arena = load("res://scenes/city/meridian_gardens.tscn").instantiate() as Node3D
	root.add_child(arena)
	current_scene = arena
	session = arena.match_controller as CityMatch
	session.set_physics_process(false)
	session.player.controller.active = false
	for actor: HeroActor in session.actors:
		actor.set_physics_process(false)
		if actor != session.player:
			actor.controller.frozen = true
	check(session.actors.size() == 12 and session.bots.size() == 11, "city launches one player and eleven Nimbus bots")
	check(session.team_count(0) == 6 and session.team_count(1) == 6, "city teams each start with six living participants")
	var zero_ultimate: bool = true
	var protected_spawns: bool = true
	var correct_masks: bool = true
	for actor: HeroActor in session.actors:
		zero_ultimate = zero_ultimate and actor.kit.ultimate_charge == 0.0
		protected_spawns = protected_spawns and session.spawn_contains(actor.global_position, actor.team) and actor.spawn_protected
		correct_masks = correct_masks and actor.collision_mask == (11 if actor.team == 0 else 7)
	check(zero_ultimate, "all twelve actors start at zero ultimate charge")
	check(protected_spawns, "all twelve spawn slots lie inside their protected arrival rooms")
	check(correct_masks, "actors collide with enemy safety gates and pass their own gates")
	check(session.pickups.size() == 8, "live city instantiates exactly eight shared health packs")
	var large_count: int = 0
	var subway_count: int = 0
	for pickup: CityHealthPack in session.pickups:
		if pickup.heal_amount == 400 and pickup.respawn_seconds == 15:
			large_count += 1
		if is_equal_approx(pickup.position.y, -5):
			subway_count += 1
	check(large_count == 2 and subway_count == 2, "large packs heal four hundred and two small caches occupy the subway")
	check(session.spawn_contains(Vector3(0, -4, 58), 0) and not session.spawn_contains(Vector3(0, 0, 50), 0), "spawn protection covers the subway connection and stops at the street threshold")
	var bake_start: int = Time.get_ticks_msec()
	while arena.navigation_region.navigation_mesh.get_polygon_count() == 0 and Time.get_ticks_msec() - bake_start < 30000:
		await process_frame
	await step(4)
	while NavigationServer3D.map_get_closest_point_owner(arena.get_world_3d().navigation_map, session.definition.team_spawns(0)[0]) != arena.navigation_region.get_rid() and Time.get_ticks_msec() - bake_start < 30000:
		await step(1)
	print("NAV MAP  world=", arena.get_world_3d().navigation_map, " region=", arena.navigation_region.get_navigation_map(), " regions=", NavigationServer3D.map_get_regions(arena.get_world_3d().navigation_map).size(), " polys=", arena.navigation_region.navigation_mesh.get_polygon_count())
	print("NAV DATA  active=", NavigationServer3D.map_is_active(arena.get_world_3d().navigation_map), " enabled=", arena.navigation_region.enabled, " layers=", arena.navigation_region.navigation_layers, " closest=", NavigationServer3D.map_get_closest_point(arena.get_world_3d().navigation_map, Vector3(8, 0, 51)))
	for actor: HeroActor in session.actors:
		actor.kit.ultimate_charge = 3.0 # Simulate passive charge accumulated during asynchronous setup.
	session._physics_process(0.0)
	var ready_charge_zero: bool = true
	for actor: HeroActor in session.actors:
		ready_charge_zero = ready_charge_zero and actor.kit.ultimate_charge == 0.0
	check(ready_charge_zero, "navigation warmup cannot grant passive ultimate before the round starts")
	check(session.navigation_ready and arena.navigation_region.navigation_mesh.get_polygon_count() > 0, "city bakes a pedestrian navigation mesh before match time starts")
	check(session.elapsed == 0.0 and session.hill.elapsed == 0.0, "navigation setup does not consume the twenty-second unlock")
	check(arena.get_node_or_null(session.definition.navigation_region_path) == arena.navigation_region, "map definition navigation reference resolves to the live baked region")
	for traversal: Dictionary in [{"name": "garden terrace", "from": Vector3(-45, 0, 33), "to": Vector3(-45, 2, 21)}, {"name": "wizard study balcony", "from": Vector3(49, 0, 12), "to": Vector3(49, 4.2, 28)}]:
		var navigation_map: RID = arena.get_world_3d().navigation_map
		var high_path: PackedVector3Array = NavigationServer3D.map_get_path(navigation_map, traversal["from"], traversal["to"], true)
		var destination: Vector3 = traversal["to"]
		var nearest: Vector3 = NavigationServer3D.map_get_closest_point(navigation_map, destination)
		check(not high_path.is_empty() and high_path[0].distance_to(traversal["from"]) < 1.5 and high_path[-1].distance_to(destination) < 1.5 and absf(nearest.y - destination.y) < 0.8, "%s has an ordinary navigable approach at its intended elevation" % traversal["name"])
	var main_routes: Array[Dictionary] = []
	for team: int in 2:
		var main: Dictionary = query_route(team, "frontline")
		main_routes.append(main)
		check(main.connected, "team %d main route is connected on the actual navigation mesh" % team)
		check(float(main.walk_seconds) >= 10.0 and float(main.walk_seconds) <= 11.0, "team %d main walk remains approximately ten to eleven seconds" % team)
		check(main.collision_snags.is_empty(), "team %d main path clears the actual Nimbus capsule" % team)
		for role: String in ["flank_left", "flank_right", "frontline_subway", "high_ground"]:
			var route: Dictionary = query_route(team, role)
			check(route.connected, "team %d %s route connects through its real ramps or stairs" % [team, role])
			check(route.collision_snags.is_empty(), "team %d %s path has no decorative collision snags" % [team, role])
			if role.begins_with("flank_"):
				check(float(route.walk_seconds) >= 13.0 and float(route.walk_seconds) <= 15.0, "team %d %s walk remains approximately thirteen to fifteen seconds" % [team, role])
			elif role == "high_ground":
				check(float(route.segments[1].length) < 45.0, "team %d high approach uses the neighbourhood alley without a district-wide detour" % team)
				check(float(route.segments[3].length) < 35.0, "team %d high ramp reaches its upper landing without an alternate district route" % team)
				check(float(route.segments[4].length) < 30.0, "team %d high ramp joins its permanent bridge directly" % team)
	check(absf(float(main_routes[0].walk_seconds) - float(main_routes[1].walk_seconds)) <= 0.5, "opposing main routes differ by at most half a second")
	var player: HeroActor = session.player
	var enemy: HeroActor = session.bots[-1]
	var collision := KinematicCollision3D.new()
	var from_south := Transform3D(Basis.IDENTITY, Vector3(-8, 0.08, 51))
	var from_north := Transform3D(Basis.IDENTITY, Vector3(-8, 0.08, -51))
	check(not player.test_move(from_south, Vector3(0, 0, 6), collision), "Lantern actors can physically pass their south spawn entrance")
	check(enemy.test_move(from_south, Vector3(0, 0, 6), collision) and collision.get_collider().collision_layer == 4, "Crown actors are physically blocked by the south team gate")
	check(not enemy.test_move(from_north, Vector3(0, 0, -6), collision), "Crown actors can physically pass their north spawn entrance")
	check(player.test_move(from_north, Vector3(0, 0, -6), collision) and collision.get_collider().collision_layer == 8, "Lantern actors are physically blocked by the north team gate")
	check(enemy.test_move(Transform3D(Basis.IDENTITY, Vector3(0, 8, 60)), Vector3.DOWN * 7, collision) and collision.get_collider().collision_layer == 1, "a vault cannot enter the south protected room through its roof")
	check(player.test_move(Transform3D(Basis.IDENTITY, Vector3(0, 8, -60)), Vector3.DOWN * 7, collision) and collision.get_collider().collision_layer == 1, "a vault cannot enter the north protected room through its roof")
	player.global_position = Vector3(0, 0.08, 60)
	enemy.global_position = Vector3(4, 0.08, 4)
	player.spawn_protected = false
	enemy.spawn_protected = false
	var enemy_health: float = enemy.health
	check(player.resolver.damage(player, enemy, 45, "rifle", player.resolver.new_cast()) == "immune" and enemy.health == enemy_health, "position-derived protection rejects outgoing fire before cached flags update")
	check(player.resolver.damage(player, enemy, 90, "throw", player.resolver.new_cast()) == "immune", "a throw damage packet cannot originate inside a protected room")
	player.global_position = Vector3(4, 0.08, 4)
	enemy.global_position = Vector3(0, 0.08, -60)
	check(player.resolver.damage(player, enemy, 90, "throw", player.resolver.new_cast()) == "immune", "incoming throw damage cannot hurt an actor inside protected rooms")
	enemy.global_position = Vector3(-4, 0.08, 4)
	check(player.resolver.damage(player, enemy, 45, "rifle", player.resolver.new_cast()) == "hit" and enemy.health == enemy_health - 45, "ordinary city damage resumes once both actors leave the safe rooms")
	enemy.kit.ultimate_charge = 37.0
	enemy.die()
	session._physics_process(7.99)
	check(not enemy.alive and session.respawn_remaining(enemy) > 0.0, "dead city actors remain out of play before eight seconds")
	session._physics_process(0.02)
	check(enemy.alive and enemy.health == enemy.tuning.max_health and enemy.global_position.is_equal_approx(enemy.spawn_position), "eight-second city respawn restores health at the assigned team spawn")
	check(enemy.kit.ultimate_charge == 37.0 and enemy.collision_mask == 7 and enemy.spawn_protected, "respawn retains earned ultimate charge and reapplies team gate protection")
	player.health = 80
	player.kit.ammo = 0
	player.kit.deflect_cd = 10
	player.kit.bomb_cd = 9
	player.kit.ultimate_charge = 83
	player.motor.dash_cd = 2
	player.motor.hover_cd = 3
	player.close.guard_meter = 0
	session.pickups[0].try_collect(player)
	enemy.die()
	session.hill.owner_team = 1
	session.hill.scores[1] = 42
	session.winner = 1
	session.exploration = true
	session.freeze_ai = true
	session.menu_open = true
	paused = true
	var transient := Node3D.new()
	arena.add_child(transient)
	transient.add_to_group("transient")
	session.restart_match()
	check(not paused and not session.menu_open and not session.exploration and not session.freeze_ai, "restart exits pause and exploration and restores ordinary match rules")
	check(session.elapsed == 0 and session.hill.owner_team == -1 and session.hill.scores == PackedFloat64Array([0,0]) and session.winner == -1 and session.death_timers.is_empty(), "restart clears scores, ownership, winner, elapsed time and respawn timers")
	check(session.actors.size() == 12 and session.team_count(0) == 6 and session.team_count(1) == 6, "restart restores all twelve actors without duplicating participants")
	var fully_reset: bool = true
	for actor: HeroActor in session.actors:
		fully_reset = fully_reset and actor.alive and actor.health == actor.tuning.max_health and actor.kit.ultimate_charge == 0 and actor.kit.ammo == actor.tuning.magazine and actor.kit.deflect_cd == 0 and actor.kit.bomb_cd == 0 and actor.motor.dash_cd == 0 and actor.motor.hover_cd == 0 and actor.close.guard_meter == 100 and actor.state == "ready"
	check(fully_reset, "restart restores health, ammunition, cooldowns, guard and zero ultimate for every actor")
	var packs_reset: bool = true
	for pickup: CityHealthPack in session.pickups:
		packs_reset = packs_reset and pickup.available and pickup.cooldown_remaining == 0
	check(packs_reset, "restart makes every shared health pack immediately available")
	await step(2)
	check(not is_instance_valid(transient) and get_nodes_in_group("transient").is_empty(), "restart clears all transient combat objects")
	for actor: HeroActor in session.actors:
		actor.spawn_protected = session.is_protected(actor)
	check(not player.permits("throw") and not player.permits("primary") and player.permits("reload"), "fresh arrival locks offensive actions while allowing reload and movement")
	player.kit.ultimate_charge = 37
	player.die()
	session.toggle_exploration()
	check(session.exploration and player.alive and player.invulnerable and player.infinite_resources, "exploration entered during a respawn immediately restores a movable player")
	check(player.kit.ultimate_charge == 37 and session.respawn_remaining(player) == 0, "exploration revival retains earned charge and clears the pending respawn")
	session.toggle_exploration()
	check(not session.exploration and not player.invulnerable and not player.infinite_resources, "leaving exploration restores ordinary vulnerability and resource rules")
	print("RESULT: ", checks, " checks, ", failures.size(), " failures")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/city-integration.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "routes": path_results, "nav_polygons": arena.navigation_region.navigation_mesh.get_polygon_count()}, "\t"))
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
