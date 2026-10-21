extends SceneTree
## Long, full-presentation bot matches and real cross-map scene changes.
## --headless --fixed-fps 60 --script res://tests/full_roster_soak.gd -- --seconds=1200 --seed=76
const TEAMS = [["slayer","marshal","doctor","huddle","relay","stitch"], ["nimbus","dynamo","wisp","samson","doctor","marshal"]]
var seconds: int = 1200
var seed_value: int = 76
var reports: Array[Dictionary] = []
var transitions: Array[Dictionary] = []
var failures: Array[String] = []
var arena: Node3D
var session: CityMatch
var samples: Array[Dictionary] = []
var windows: Dictionary = {}
var stalls: Array[Dictionary] = []
var falls: Array[Dictionary] = []
var rounds: int = 0
var kills: int = 0
var events: Dictionary = {}
var longest_stall: float = 0
var memory_baseline: Dictionary
var review_camera: Camera3D
var map_pass: int = 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): seconds = maxi(1,int(arg.get_slice("=",1)))
		if arg.begins_with("--seed="): seed_value = int(arg.get_slice("=",1))
	call_deferred("run")

func step(count: int = 1) -> void:
	for frame: int in count:
		await physics_frame
		await process_frame

func counts() -> Dictionary:
	return {"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"orphans":int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),"resources":int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),"static_bytes":int(Performance.get_monitor(Performance.MEMORY_STATIC)),"objects":int(Performance.get_monitor(Performance.OBJECT_COUNT)),"transients":get_nodes_in_group("transient").size(),"owned_attacks":get_nodes_in_group("owned_attacks").size()}

func save_report() -> void:
	var file := FileAccess.open("res://artifacts/full-roster-soak-%d.json" % seed_value,FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed":seed_value,"seconds_per_long_match":seconds,"teams":TEAMS,"matches":reports,"transitions":transitions,"failures":failures,"empty_tree_baseline":memory_baseline},"\t"))

func record_event(entry: Dictionary) -> void:
	var kind: String = str(entry.get("event",""))
	events[kind] = int(events.get(kind,0))+1
	if kind == "death": kills += 1

func apply_roster() -> void:
	# Production round resets deliberately rebuild a seeded six-hero composition.
	# Override only this test fixture after each reset to exercise all ten at once.
	for actor: HeroActor in session.actors:
		var slot: int = int(session._spawn_indices[actor.get_instance_id()])
		var desired: String = TEAMS[actor.team][slot]
		if actor.tuning.hero_id != desired: actor.select_hero(desired)
		actor.actor_id = "%s_t%d_s%d" % [actor.tuning.hero_id,actor.team,slot]
		var driver: CityBotController = actor.controller
		driver.role = str({"slayer":"high_ground","stitch":"flank_left","wisp":"flank_right","nimbus":"frontline_subway","huddle":"high_ground"}.get(actor.tuning.hero_id,"frontline"))
		driver.navagent.max_speed = actor.tuning.ground_speed
		driver.reset_controller()

func open_map(kind: String, index: int) -> void:
	map_pass = index
	var old: Array[WeakRef] = []
	if is_instance_valid(arena):
		old.append(weakref(arena))
		for actor: HeroActor in session.actors:
			old.append(weakref(actor))
			old.append(weakref(actor.controller))
		for node: Node in get_nodes_in_group("transient")+get_nodes_in_group("owned_attacks"):
			if not node is SlayerBurstEffect: old.append(weakref(node))
	seed(seed_value+index*1009)
	HeroRoster.composition_seed = seed_value+index*1009
	var path: String = "res://scenes/city/meridian_gardens.tscn" if kind == "city" else "res://scenes/museum/meridian_museum.tscn"
	var error: Error = change_scene_to_file(path)
	if error != OK:
		failures.append("Scene change failed: "+kind)
		return
	await scene_changed
	arena = current_scene
	session = arena.match_controller
	session.freeze_ai = true
	var old_player: PlayerController = session.player.controller
	old_player.active = false
	session.player.controller = null
	old_player.queue_free()
	for actor: HeroActor in session.actors:
		var slot: int = int(session._spawn_indices[actor.get_instance_id()])
		actor.select_hero(TEAMS[actor.team][slot])
		actor.actor_id = "%s_t%d_s%d" % [actor.tuning.hero_id,actor.team,slot]
		if actor == session.player:
			var pilot: CityBotController = MuseumBotController.new() if kind == "museum" else CityBotController.new()
			pilot.actor = actor
			pilot.match_controller = session
			pilot.slot = slot
			actor.add_child(pilot)
			actor.controller = pilot
			session.bots.append(actor)
		var driver: CityBotController = actor.controller
		driver.role = str({"slayer":"high_ground","stitch":"flank_left","wisp":"flank_right","nimbus":"frontline_subway","huddle":"high_ground"}.get(actor.tuning.hero_id,"frontline"))
		driver.navagent.max_speed = actor.tuning.ground_speed
		driver.rng.seed = seed_value+index*10000+actor.team*100+slot
		driver.reset_controller()
	var started: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec()-started < 60000: await step()
	if not session.navigation_ready: failures.append(kind+" navigation timed out")
	await step(5)
	var retained: int = 0
	for reference: WeakRef in old:
		if reference.get_ref() != null: retained += 1
	var row: Dictionary = {"destination":kind,"pass":index,"old_references":old.size(),"retained_old_nodes":retained,"actors":get_nodes_in_group("actors").size(),"resolvers":get_nodes_in_group("combat_resolver").size(),"sessions":get_nodes_in_group("game_session").size(),"counts":counts()}
	transitions.append(row)
	print("SOAK TRANSITION ",JSON.stringify(row))
	if retained > 0 or row.actors != 12 or row.resolvers != 1 or row.sessions != 1: failures.append("Transition cleanup failed: "+kind)
	session.player.resolver.event_logged.connect(record_event)
	session.freeze_ai = false
	session.restart_match()
	apply_roster()
	if DisplayServer.get_name() != "headless":
		review_camera = Camera3D.new()
		arena.add_child(review_camera)
		review_camera.current = true
		review_camera.fov = 72
		position_review_camera()

func position_review_camera() -> void:
	var focus: Vector3 = (session as MuseumMatch).payload.global_position if session is MuseumMatch and (session as MuseumMatch).phase == "escort" else session.definition.hill_center
	review_camera.global_position = focus+Vector3(15,14,24)
	review_camera.look_at(focus+Vector3.UP)

func observe(second: int) -> void:
	for actor: HeroActor in session.actors:
		var id: int = actor.get_instance_id()
		var driver: CityBotController = actor.controller
		if not windows.has(id): windows[id] = {"at":actor.global_position,"stall":0,"episode":-1,"life":actor.life_serial}
		var window: Dictionary = windows[id]
		var movement: float = actor.global_position.distance_to(window.at)
		var goal: Vector3 = driver.destination
		if not driver.entered_hill and not driver.seeking_health and not driver.route.is_empty(): goal = driver.route[mini(driver.route_index,driver.route.size()-1)]
		var expected: bool = actor.alive and session.winner < 0 and not driver.frozen and not actor.statuses.movement_disabled() and actor.state in ["ready","reload"] and actor.global_position.distance_to(goal) > 2.5 and not driver.brain.movement.intentional_hold
		if session is MuseumMatch and (session as MuseumMatch).phase == "preparation": expected = false
		if expected and movement < .65 and actor.life_serial == window.life:
			window.stall += 1
		else:
			if int(window.episode) >= 0:
				stalls[window.episode].recovered_at = second
			window.stall = 0
			window.episode = -1
		longest_stall = maxf(longest_stall,window.stall)
		if window.stall == 8:
			window.episode = stalls.size()
			stalls.append({"second":second,"hero":actor.tuning.hero_id,"actor":actor.actor_id,"at":str(actor.global_position),"goal":str(goal),"role":driver.role,"state":actor.state,"mode":actor.motor.mode,"intent":str(actor.intent.move),"path_finished":driver.navagent.is_navigation_finished(),"duration":8,"recovered_at":-1})
			print("SOAK STALL ",JSON.stringify(stalls[-1]))
		elif int(window.episode) >= 0: stalls[window.episode].duration = window.stall
		window.at = actor.global_position
		window.life = actor.life_serial
		if actor.global_position.y < -7.9 and falls.size() < 100: falls.append({"second":second,"actor":actor.actor_id,"at":str(actor.global_position)})

func play(kind: String, duration: int) -> void:
	samples = []
	windows = {}
	stalls = []
	falls = []
	rounds = 0
	kills = 0
	events = {}
	longest_stall = 0
	var phase_history: Array[Dictionary] = []
	for second: int in duration:
		await step(60)
		observe(second+1)
		if second%60 == 59 or second == duration-1:
			var snapshot: Dictionary = counts()
			snapshot.second = second+1
			snapshot.resolved_casts = session.player.resolver.resolved.size()
			snapshot.cast_metadata = session.player.resolver.impact_kinds.size()
			samples.append(snapshot)
			print("SOAK ",kind," ",second+1,"s deaths=",kills," rounds=",rounds," stalls=",stalls.size()," ",JSON.stringify(snapshot))
			if DisplayServer.get_name() != "headless":
				position_review_camera()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://artifacts/soak-%d-%d-%s-%d.png" % [seed_value,map_pass,kind,second+1])
		if session.winner >= 0:
			phase_history.append({"second":second+1,"winner":session.winner,"phase":(session as MuseumMatch).phase if session is MuseumMatch else "hill"})
			rounds += 1
			session.restart_match()
			apply_roster()
			windows.clear()
	var bots: Array[Dictionary] = []
	var seen: Dictionary = {}
	for actor: HeroActor in session.actors:
		var driver: CityBotController = actor.controller
		seen[actor.tuning.hero_id] = true
		bots.append({"hero":actor.tuning.hero_id,"team":actor.team,"active_seconds":driver.elapsed,"distance_m":driver.distance_travelled,"detours":driver.stuck_events,"warps":driver.recovery_warps,"diagnostics":driver.brain.diagnostics.summary()})
	var row: Dictionary = {"map":kind,"seconds":duration,"deaths":kills,"rounds":rounds,"natural_results":phase_history,"final_phase":(session as MuseumMatch).phase if session is MuseumMatch else "hill","final_payload_distance":(session as MuseumMatch).payload_distance if session is MuseumMatch else 0,"hero_count":seen.size(),"events":events.duplicate(),"stalls":stalls.duplicate(true),"longest_stall":longest_stall,"falls":falls.duplicate(true),"resources":samples.duplicate(true),"bots":bots}
	reports.append(row)
	if seen.size() != HeroRoster.IDS.size(): failures.append(kind+" did not exercise the full roster")
	if not falls.is_empty(): failures.append(kind+" had out-of-bounds falls")
	if not stalls.is_empty(): failures.append(kind+" had eight-second stall episodes")
	for bot: Dictionary in bots:
		if bot.warps > 0: failures.append(kind+" used a recovery teleport")
	save_report()

func run() -> void:
	await step(3)
	memory_baseline = counts()
	for index: int in 4:
		var kind: String = "city" if index%2 == 0 else "museum"
		await open_map(kind,index)
		await play(kind,seconds if index < 2 else mini(seconds,60))
	await finish()

func finish() -> void:
	var references: Array[WeakRef] = [weakref(arena)]
	for actor: HeroActor in session.actors: references.append(weakref(actor))
	arena.queue_free()
	await step(10)
	var remaining: int = 0
	for reference: WeakRef in references:
		if reference.get_ref() != null: remaining += 1
	var cleanup: Dictionary = {"destination":"empty_tree","retained_old_nodes":remaining,"actors":get_nodes_in_group("actors").size(),"sessions":get_nodes_in_group("game_session").size(),"resolvers":get_nodes_in_group("combat_resolver").size(),"counts":counts()}
	transitions.append(cleanup)
	if remaining > 0 or cleanup.actors != 0 or cleanup.sessions != 0 or cleanup.resolvers != 0: failures.append("Final empty-tree cleanup failed")
	print("SOAK CLEANUP ",JSON.stringify(cleanup))
	save_report()
	print("FULL ROSTER SOAK ",reports.size()," matches, ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
