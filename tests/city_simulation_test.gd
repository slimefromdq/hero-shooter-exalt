extends SceneTree
## Run with --fixed-fps 60 --script res://tests/city_simulation_test.gd -- --seconds=600 --seed=76
## The real actor physics/combat/match pipeline is used. The player slot receives ordinary AI intent.

var arena: Node3D
var session: CityMatch
var checks: int = 0
var failures: Array[String] = []
var duration: int = 600
var simulation_seed: int = 76
var captures: Array[int] = [0,0]
var contest_seconds: float = 0
var deaths: int = 0
var rounds: int = 0
var health_collections: int = 0
var visited_subway: Array[bool] = [false,false]
var visited_arcade: Array[bool] = [false,false]
var visited_high: Array[bool] = [false,false]
var falls: Array[String] = []
var persistent_stalls: Array[Dictionary] = []
var windows: Dictionary = {}
var worst_stall: float = 0
var lowest_y: float = 100
var total_travel: float = 0
var healing_total: float = 0
var barrier_hits: int = 0
var bot_statistics: Array[Dictionary] = []
var max_heights: Array[float] = [-100.0,-100.0]

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="): duration = int(argument.get_slice("=",1))
		if argument.begins_with("--seed="): simulation_seed = int(argument.get_slice("=",1))
	call_deferred("run")

func step(frames: int) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame
		if is_instance_valid(session):
			for actor: HeroActor in session.actors:
				if actor.alive:
					if actor.position.y < -3.5 and absf(actor.position.x) < 8 and absf(actor.position.z) < 12:
						visited_arcade[actor.team] = true
					max_heights[actor.team] = maxf(max_heights[actor.team],actor.global_position.y)
					var position: Vector3 = actor.global_position
					if position.y >= 6.4 and position.y <= 6.8 and absf(position.x) >= 20.5 and absf(position.x) <= 25.5 and absf(position.z) <= 18.0:
						visited_high[actor.team] = true

func check(condition: bool, description: String) -> void:
	checks += 1
	print("PASS  " if condition else "FAIL  ", description)
	if not condition: failures.append(description)

func run() -> void:
	seed(simulation_seed)
	HeroRoster.composition_seed = simulation_seed
	print("ROSTER ",HeroRoster.composition_for(HeroRoster.selected))
	arena = load("res://scenes/city/meridian_gardens.tscn").instantiate() as Node3D
	root.add_child(arena)
	current_scene = arena
	session = arena.match_controller
	var camera_controller: PlayerController = session.player.controller as PlayerController
	camera_controller.active = false
	session.hill.ownership_changed.connect(func(team: int) -> void: captures[team] += 1)
	session.player.resolver.event_logged.connect(func(entry: Dictionary) -> void:
		if entry.get("event","") == "death": deaths += 1
		if entry.get("event","") == "barrier_hit": barrier_hits += 1)
	session.player.resolver.confirmed_heal.connect(func(_source: HeroActor, _target: HeroActor, amount: float) -> void: healing_total += amount)
	for pickup: CityHealthPack in session.pickups:
		pickup.collected.connect(func(_actor: HeroActor,_amount: float) -> void: health_collections += 1)
	var bake_start: int = Time.get_ticks_msec()
	var bake_report: int = bake_start
	while not session.navigation_ready and Time.get_ticks_msec() - bake_start < 60000:
		await step(1)
		if Time.get_ticks_msec() - bake_report > 5000:
			bake_report = Time.get_ticks_msec()
			var region: NavigationRegion3D = arena.navigation_region
			var map: RID = arena.get_world_3d().navigation_map
			print("NAV WAIT polygons=",region.navigation_mesh.get_polygon_count()," iteration=",NavigationServer3D.map_get_iteration_id(map)," owner=",NavigationServer3D.map_get_closest_point_owner(map,session.definition.team_spawns(0)[0])," region=",region.get_rid()," world_map=",map," region_map=",region.get_navigation_map()," active=",NavigationServer3D.map_is_active(map)," regions=",NavigationServer3D.map_get_regions(map)," physics=",session.is_physics_processing()," pos=",session.player.global_position)
	check(session.navigation_ready,"authored collision geometry bakes into a ready navigation map")
	if not session.navigation_ready:
		await finish()
		return
	# Register the test-only twelfth agent after the ordinary eleven-bot scene is ready.
	# This also preserves the same initial map-loading conditions as the shipped player session.
	var driver := CityBotController.new()
	driver.actor = session.player
	driver.match_controller = session
	driver.role = "frontline"
	driver.slot = 0
	session.player.add_child(driver)
	session.player.controller = driver
	for actor: HeroActor in session.actors:
		(actor.controller as CityBotController).rng.seed = simulation_seed * 10000 + actor.team * 100 + actor.controller.slot
	session.restart_match()
	for actor: HeroActor in session.actors:
		windows[actor.get_instance_id()] = {"position":actor.global_position,"stall":0.0,"reported":false}
	for second: int in duration:
		await step(60)
		if session.hill.contested: contest_seconds += 1.0
		for actor: HeroActor in session.actors:
			var controller: CityBotController = actor.controller as CityBotController
			lowest_y = minf(lowest_y,actor.global_position.y)
			if actor.global_position.y < -7.9 and not actor.actor_id in falls:
				falls.append(actor.actor_id)
			if actor.alive and actor.global_position.y < -3.0: visited_subway[actor.team] = true
			var window: Dictionary = windows[actor.get_instance_id()]
			var moved: float = actor.global_position.distance_to(window.position)
			var expected_goal: Vector3 = controller.route[controller.route_index] if not controller.entered_hill and not controller.route.is_empty() and not controller.seeking_health else controller.destination
			# Doctors deliberately follow patients rather than their initial authored route.
			if actor.kit is DoctorKit: expected_goal = controller.destination
			var expected_movement: bool = actor.alive and controller.active and not controller.frozen and actor.global_position.distance_to(expected_goal) > 2.5 and actor.state in ["ready","reload"] and not session.hill.contains(actor.global_position)
			if expected_movement and moved < .65:
				window.stall += 1.0
			else:
				window.stall = 0.0
				window.reported = false
			worst_stall = maxf(worst_stall,window.stall)
			if window.stall >= 8.0 and not window.reported:
				window.reported = true
				var record: Dictionary = {"second":second,"actor":actor.actor_id,"role":controller.role,"position":str(actor.global_position),"goal":str(controller.destination),"route_index":controller.route_index,"path_finished":controller.navagent.is_navigation_finished()}
				persistent_stalls.append(record)
				print("STALL ",JSON.stringify(record))
			window.position = actor.global_position
		if second % 30 == 29:
			var positions: Array[String] = []
			for actor: HeroActor in session.actors:
				positions.append("%s=%s r%d" % [actor.actor_id,str(actor.global_position),actor.controller.route_index])
			print("SIM ",second + 1,"s scores=",session.hill.scores," captures=",captures," contest=",contest_seconds," deaths=",deaths," positions=",positions)
		if session.winner >= 0:
			rounds += 1
			session.restart_match()
			for actor: HeroActor in session.actors:
				windows[actor.get_instance_id()] = {"position":actor.global_position,"stall":0.0,"reported":false}
	check(session.actors.size() == 12 and session.team_count(0) <= 6 and session.team_count(1) <= 6,"twelve participants remain registered across fight and reset cycles")
	check(captures[0] > 0 and captures[1] > 0,"both teams capture the hill through navigation and ordinary combat")
	check(contest_seconds > 0,"opposing teams contest the hill during the seeded simulation")
	check(persistent_stalls.is_empty(),"no bot remains physically stalled for eight seconds outside the objective")
	check(falls.is_empty(),"navigation never sends an actor below the district floor")
	check(visited_subway[0] and visited_subway[1],"both teams use the underground subway flank")
	check(visited_arcade[0] and visited_arcade[1],"both teams navigate through the shopping arcade below the control point")
	check(visited_high[0] and visited_high[1],"both teams reach the actual 6.5 metre covered promenade decks")
	var warps: int = 0
	var decisions_within_budget: bool = true
	var paths_within_budget: bool = true
	for actor: HeroActor in session.actors:
		var controller: CityBotController = actor.controller as CityBotController
		warps += controller.recovery_warps
		total_travel += controller.distance_travelled
		decisions_within_budget = decisions_within_budget and controller.decision_count <= duration * 5 + 50
		paths_within_budget = paths_within_budget and controller.path_update_count <= duration * 2 + 50
		bot_statistics.append({"actor":actor.actor_id,"hero":actor.tuning.hero_id,"role":controller.role,"active_seconds":controller.elapsed,"tactical_decisions":controller.decision_count,"path_updates":controller.path_update_count,"distance_m":controller.distance_travelled,"detours":controller.stuck_events,"warps":controller.recovery_warps})
	check(warps == 0,"bot recovery uses navigation detours without teleporting")
	check(decisions_within_budget,"tactical decision counters stay within the five hertz budget")
	check(paths_within_budget,"navigation retarget counters stay within the two hertz budget")
	check(healing_total > 0,"doctor bots restore actual teammate health in ordinary combat")
	check(barrier_hits > 0,"marshal bots intercept real ranged attacks")
	check(total_travel > duration * 3,"participants continue travelling through the district")
	if duration >= 600:
		# Stronger reload/AoE pressure can extend legitimate contests past ten minutes.
		# Exercise completion explicitly after the soak, without changing live scoring.
		var before_serial: int = session.round_serial
		for actor: HeroActor in session.actors:
			actor.global_position = session.definition.team_spawns(actor.team)[0]
		session.hill.unlocked = true
		session.hill.elapsed = session.definition.unlock_seconds+1
		session.hill.owner_team = 0
		session.hill.scores[0] = session.definition.score_to_win-.25
		session.hill.advance(.5,session.actors)
		var completed: bool = session.winner == 0
		session.restart_match()
		check(completed and session.round_serial == before_serial+1 and session.winner == -1 and session.hill.scores == PackedFloat64Array([0.0,0.0]),"post-soak normal scoring completes the round and restart clears its state")
		check(health_collections > 0,"injured participants collect shared health resources")
	await finish()

func finish() -> void:
	print("RESULT: ",checks," checks, ",failures.size()," failures")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/city-simulation-%d-%ds.json" % [simulation_seed,duration],FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed":simulation_seed,"seconds":duration,"checks":checks,"failures":failures,"captures":captures,"contest_seconds":contest_seconds,"deaths":deaths,"rounds":rounds,"health_collections":health_collections,"subway_teams":visited_subway,"arcade_teams":visited_arcade,"high_ground_teams":visited_high,"max_heights":max_heights,"lowest_y":lowest_y,"worst_stall":worst_stall,"persistent_stalls":persistent_stalls,"falls":falls,"healing_total":healing_total,"barrier_hits":barrier_hits,"total_metres_travelled":total_travel,"bots":bot_statistics},"\t"))
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
