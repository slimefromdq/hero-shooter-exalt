extends SceneTree
## Natural mixed-roster stress run, followed by a bot-driven unopposed route
## drill so every checkpoint is exercised even if the natural round defends A.
var arena: Node3D
var session: MuseumMatch
var checks: int = 0
var failures: Array[String] = []
var snapshots: Array[Dictionary] = []
var transitions: Array[String] = []
var duration: float = 600
var windows: Dictionary = {}
var persistent_stalls: Array[Dictionary] = []
var staged_results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func run() -> void:
	var seed_value: int = 76
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): seed_value = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--seconds="): duration = float(arg.trim_prefix("--seconds="))
	HeroRoster.composition_seed = seed_value
	seed(seed_value)
	MuseumMatch.selected_side = 1 if "--defend" in OS.get_cmdline_user_args() else 0
	arena = load("res://scenes/museum/meridian_museum.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	session = arena.match_controller
	session.player.controller.active = false
	var pilot := MuseumBotController.new()
	pilot.actor = session.player
	pilot.match_controller = session
	pilot.slot = 0
	session.player.add_child(pilot)
	session.player.controller = pilot
	session.bots.append(session.player)
	# Suppress visual-only animation/HUD work in headless stress runs. Actor,
	# motor, abilities, projectiles, navigation and all collision remain live.
	session.hud.process_mode = Node.PROCESS_MODE_DISABLED
	for actor: HeroActor in session.actors:
		actor.presentation.process_mode = Node.PROCESS_MODE_DISABLED
		actor.controller.rng.seed = seed_value*10000+actor.team*100+actor.controller.slot
		windows[actor.get_instance_id()] = {"at":actor.global_position,"stall":0.0}
	session.phase_changed.connect(func(phase: String) -> void: transitions.append(phase))
	session.checkpoint_reached.connect(func(index: int) -> void: transitions.append("cp%d" % index))
	var start: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec()-start < 30000: await frames(1)
	check(session.navigation_ready,"navigation ready for seeded simulation")
	var falls: int = 0
	var worst_stuck: float = 0
	var recovery_warps: int = 0
	for second: int in int(duration):
		await frames(60)
		for actor: HeroActor in session.actors:
			if actor.global_position.y < -6: falls += 1
			var window: Dictionary = windows[actor.get_instance_id()]
			var moved: float = actor.global_position.distance_to(window.at)
			var objective_at: Vector3 = session.payload.global_position if session.phase == "escort" else session.definition.hill_center
			var near_objective: bool = actor.global_position.distance_to(objective_at) < (6.0 if session.phase == "escort" else 11.0)
			var expected: bool = actor.alive and session.winner < 0 and session.phase != "preparation" and not near_objective and actor.global_position.distance_to(actor.controller.destination) > 2.5 and actor.state in ["ready","reload"]
			window.stall = window.stall+1 if expected and moved < .65 else 0.0
			window.at = actor.global_position
			worst_stuck = maxf(worst_stuck,window.stall)
			if window.stall == 8:
				persistent_stalls.append({"second":second,"hero":actor.tuning.hero_id,"team":actor.team,"at":str(actor.global_position),"goal":str(actor.controller.destination)})
		if second%30 == 0:
			var row := {"second":second,"phase":session.phase,"capture":session.capture_progress,"payload":session.payload_distance,"winner":session.winner,"positions":[]}
			for actor: HeroActor in session.actors:
				row.positions.append({"hero":actor.tuning.hero_id,"team":actor.team,"at":str(actor.global_position),"stuck":actor.controller.stuck_time,"assignment":actor.controller.assignment})
			snapshots.append(row)
			print("MUSEUM SIM ",seed_value," ",second,"s ",session.phase," capture=",session.capture_progress," payload=",session.payload_distance)
	check(falls == 0,"natural match has no out-of-bounds falls")
	for actor: HeroActor in session.actors: recovery_warps += actor.controller.recovery_warps
	check(recovery_warps == 0,"bot routes need no recovery teleports")
	check(persistent_stalls.is_empty(),"independent position sampling finds no persistent eight-second route stalls")
	check(session.elapsed > 30,"natural simulation advances beyond preparation")
	var natural_result := {"phase":session.phase,"capture":session.capture_progress,"payload":session.payload_distance,"checkpoint":session.checkpoint_index,"winner":session.winner}
	# Real combat starts at each unlocked leg too, so later terrain is not
	# validated only by an unopposed drill when the natural defense holds CP1.
	for stage: int in 3:
		session.restart_match()
		pilot.frozen = false
		session.objective.phase = "escort"
		session.objective.preparation_remaining = 0
		session.objective.checkpoint_index = stage
		var distance: float = session.museum_definition().checkpoint_distances()[stage-1] if stage > 0 else 0.0
		session.objective.payload_distance = distance
		session.objective.time_remaining = 180
		session._relocate(stage+1,mini(2,stage+1))
		session.payload.move_to_distance(distance)
		for actor: HeroActor in session.actors:
			session.respawn_actor(actor)
			windows[actor.get_instance_id()] = {"at":actor.global_position,"stall":0.0}
		var stage_falls: int = 0
		var stage_contests: int = 0
		var stage_progress: float = distance
		for second: int in 60:
			await frames(60)
			stage_progress = maxf(stage_progress,session.payload_distance)
			if session.occupancy[0] > 0 and session.occupancy[1] > 0: stage_contests += 1
			for actor: HeroActor in session.actors:
				if actor.global_position.y < -6: stage_falls += 1
		check(stage_falls == 0,"checkpoint %d combat has no terrain falls" % (stage+1))
		check(stage_progress > distance+.1 or stage_contests > 0,"checkpoint %d combat supports live escort or contested defense" % (stage+1))
		staged_results.append({"stage":stage+1,"seconds":60,"start_distance":distance,"furthest_distance":stage_progress,"contest_samples":stage_contests,"falls":stage_falls})
		print("MUSEUM STAGED COMBAT ",JSON.stringify(staged_results[-1]))
	# Safe controlled drill: remove enemy pressure, retain six full-kit attackers,
	# and ask ordinary bot navigation to capture then escort the entire authored route.
	session.restart_match()
	pilot.frozen = false
	transitions.clear()
	for actor: HeroActor in session.actors:
		if actor.team == 1:
			actor.set_physics_process(false)
			actor.global_position = Vector3(190,1.5,-35)
		else:
			actor.invulnerable = true
			actor.controller.slot = 0 if actor == session.player else int(session._spawn_indices[actor.get_instance_id()])%4
	var drill_seconds: int = 0
	while session.winner < 0 and drill_seconds < 300:
		await frames(60)
		drill_seconds += 1
		if drill_seconds%30 == 0: print("MUSEUM DRILL ",drill_seconds,"s ",session.phase," capture=",session.capture_progress," payload=",session.payload_distance)
	check("escort" in transitions,"walking bots capture all three thirds and release payload")
	for index: int in [1,2,3]: check("cp%d" % index in transitions,"walking escorts reach checkpoint %d" % index)
	check(session.winner == 0,"bot-driven route drill completes at final dock")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/museum"))
	var file := FileAccess.open("res://artifacts/museum/simulation-%d-%s.json" % [seed_value,"defend" if session.player.team == 1 else "attack"],FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed":seed_value,"seconds":duration,"checks":checks,"failures":failures,"falls":falls,"worst_stuck":worst_stuck,"persistent_stalls":persistent_stalls,"recovery_warps":recovery_warps,"natural_result":natural_result,"staged_combat":staged_results,"drill_seconds":drill_seconds,"transitions":transitions,"snapshots":snapshots},"  "))
	print("MUSEUM SIMULATION ",checks," checks; ",failures.size()," failures")
	arena.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
