extends SceneTree
## Headless bot behaviour benchmark used to compare AI revisions.
## --fixed-fps 60 --script res://tests/bot_behavior_benchmark.gd -- --map=city|museum|temple --seconds=300 --seed=76 --out=res://artifacts/bench.json
## The player slot is driven by the same bot controller as the other eleven participants.

var map_name: String = "city"
var duration: int = 300
var bench_seed: int = 76
var out_path: String = ""
var difficulty: int = -1
var trace_stuck: bool = false
var tuning_paths: Array[String] = ["",""]
var round_wins: Array[int] = [0,0]
var session: CityMatch

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--map="): map_name = argument.get_slice("=",1)
		if argument.begins_with("--seconds="): duration = int(argument.get_slice("=",1))
		if argument.begins_with("--seed="): bench_seed = int(argument.get_slice("=",1))
		if argument.begins_with("--out="): out_path = argument.get_slice("=",1)
		if argument.begins_with("--difficulty="): difficulty = int(argument.get_slice("=",1))
		if argument == "--trace-stuck": trace_stuck = true
		if argument.begins_with("--tuning0="): tuning_paths[0] = argument.get_slice("=",1)
		if argument.begins_with("--tuning1="): tuning_paths[1] = argument.get_slice("=",1)
	call_deferred("run")

func frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func run() -> void:
	seed(bench_seed)
	HeroRoster.composition_seed = bench_seed
	if difficulty >= 0: root.get_node("/root/GameSettings").set_setting("bot_difficulty",difficulty)
	var scene: String = {"city":"res://scenes/city/meridian_gardens.tscn","museum":"res://scenes/museum/meridian_museum.tscn",
		"temple":"res://scenes/temple/sakura_veil.tscn"}[map_name]
	var arena: Node3D = load(scene).instantiate() as Node3D
	root.add_child(arena)
	current_scene = arena
	session = arena.match_controller as CityMatch
	session.player.controller.active = false
	var started: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec()-started < 90000: await frames(1)
	if not session.navigation_ready:
		push_error("navigation timeout")
		quit(1)
		return
	var pilot: CityBotController = {"city":CityBotController,"museum":MuseumBotController,"temple":TempleBotController}[map_name].new()
	pilot.actor = session.player
	pilot.match_controller = session
	pilot.slot = 0
	pilot.role = "frontline"
	session.player.add_child(pilot)
	session.player.controller = pilot
	if not session.player in session.bots: session.bots.append(session.player)
	if is_instance_valid(session.hud): session.hud.process_mode = Node.PROCESS_MODE_DISABLED
	for actor: HeroActor in session.actors:
		if is_instance_valid(actor.presentation): actor.presentation.process_mode = Node.PROCESS_MODE_DISABLED
		(actor.controller as CityBotController).rng.seed = bench_seed*10000+actor.team*100+actor.controller.slot
	for team: int in 2:
		if tuning_paths[team] == "": continue
		var values: Variant = JSON.parse_string(FileAccess.get_file_as_string(tuning_paths[team]))
		if values is Dictionary: TeamDirector.obtain(session,team).set("tuning",BotTuning.from_dict(values))
	if map_name == "city": session.restart_match()
	if session is TempleMatch: skip_temple_preparation()
	var rounds: int = 0
	var wall_start: int = Time.get_ticks_msec()
	var stuck_seen: Dictionary = {}
	for second: int in duration:
		await frames(60)
		if trace_stuck:
			for actor: HeroActor in session.actors:
				var controller: CityBotController = actor.controller as CityBotController
				if controller.stuck_events > int(stuck_seen.get(actor.actor_id,0)):
					stuck_seen[actor.actor_id] = controller.stuck_events
					print("STUCK t=%d %s %s at=%s goal=%s state=%s tactical=%s" % [second,actor.actor_id,actor.tuning.hero_id,
						str(actor.global_position.snapped(Vector3.ONE*.1)),str(controller.destination.snapped(Vector3.ONE*.1)),actor.state,controller.brain.tactical_state])
		var finished: bool = session.winner >= 0
		if session is TempleMatch and (session as TempleMatch).objective.finished: finished = true
		if finished:
			rounds += 1
			if session.winner in [0,1]: round_wins[session.winner] += 1
			session.restart_match()
			if session is TempleMatch: skip_temple_preparation()
	var wall_ms: int = Time.get_ticks_msec()-wall_start
	var report: Dictionary = summarise(rounds,wall_ms)
	print("BENCH ",JSON.stringify(report.aggregate))
	if out_path != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path).get_base_dir())
		var file := FileAccess.open(out_path,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t"))
	quit(0)

func skip_temple_preparation() -> void:
	var temple := session as TempleMatch
	temple.objective.preparation_remaining = 0
	temple._preparing = false
	temple.arena.builder.update_gates(temple.stages,false)

func summarise(rounds: int, wall_ms: int) -> Dictionary:
	var bots: Array[Dictionary] = []
	var totals: Dictionary = {"alive":0.0,"combat":0.0,"combat_idle":0.0,"travel":0.0,"tech":0,"jumps":0,"engagements":0,
		"outnumbered":0,"deaths":0,"deaths_alone":0,"damage":0.0,"stuck_events":0,"objective":0.0}
	var kills_by_team: Array[float] = [0.0,0.0]
	for actor: HeroActor in session.actors:
		var controller: CityBotController = actor.controller as CityBotController
		var debug: BotDebug = controller.brain.diagnostics
		var human: Dictionary = debug.human_metrics()
		bots.append({"actor":actor.actor_id,"hero":actor.tuning.hero_id,"team":actor.team,"damage":snappedf(debug.damage,1),
			"deaths":debug.deaths,"stuck_events":controller.stuck_events,"objective_seconds":snappedf(debug.objective_seconds,.1),"human":human})
		totals.alive += debug.alive_seconds
		totals.combat += debug.combat_seconds
		totals.combat_idle += debug.combat_idle_seconds
		totals.travel += debug.travel
		for kind: String in debug.movement_events:
			if kind == "jump": totals.jumps += int(debug.movement_events[kind])
			else: totals.tech += int(debug.movement_events[kind])
		totals.engagements += debug.engagements
		totals.outnumbered += debug.outnumbered_engagements
		totals.deaths += debug.deaths
		totals.deaths_alone += debug.deaths_alone
		totals.damage += debug.damage
		totals.stuck_events += controller.stuck_events
		totals.objective += debug.objective_seconds
		kills_by_team[1-actor.team] += debug.deaths
	var hops: int = 0
	var air_slides: int = 0
	var bhops: int = 0
	var bhop_peak: float = 0.0
	var link_uses: int = 0
	var link_failures: int = 0
	for actor: HeroActor in session.actors:
		hops += (actor.controller as CityBotController).hops
		var loco_counters: Dictionary = (actor.controller as CityBotController).brain.movement.locomotion.counters
		air_slides += int(loco_counters.air_dash_slides)
		bhops += int(loco_counters.bhops)
		bhop_peak = maxf(bhop_peak,float(loco_counters.bhop_peak_speed))
		link_uses += (actor.controller as CityBotController).link_uses
		link_failures += (actor.controller as CityBotController).link_failures
	var minutes: float = maxf(float(totals.alive)/60.0,.001)
	var aggregate: Dictionary = {"map":map_name,"seed":bench_seed,"seconds":duration,"rounds":rounds,"wall_ms":wall_ms,
		"combat_idle_ratio":snappedf(float(totals.combat_idle)/maxf(float(totals.combat),.001),.001),
		"combat_share":snappedf(float(totals.combat)/maxf(float(totals.alive),.001),.001),
		"mean_speed":snappedf(float(totals.travel)/maxf(float(totals.alive),.001),.01),
		"tech_per_bot_minute":snappedf(float(totals.tech)/minutes,.01),"jumps_per_bot_minute":snappedf(float(totals.jumps)/minutes,.01),
		"engagements":totals.engagements,"outnumbered_ratio":snappedf(float(totals.outnumbered)/maxf(float(totals.engagements),1),.001),
		"deaths":totals.deaths,"deaths_alone_ratio":snappedf(float(totals.deaths_alone)/maxf(float(totals.deaths),1),.001),
		"damage_per_bot_minute":snappedf(float(totals.damage)/minutes,.1),"stuck_events":totals.stuck_events,
		"objective_share":snappedf(float(totals.objective)/maxf(float(totals.alive),.001),.001),"kills_by_team":kills_by_team,
		"hops":hops,"air_dash_slides":air_slides,"bhops":bhops,"bhop_peak_speed":snappedf(bhop_peak,.1),"link_uses":link_uses,"link_failures":link_failures,"links":TraversalLinks.report_for(session.arena.get_world_3d().navigation_map),"link_stats":TraversalLinks.stats()}
	var teams: Array[Dictionary] = []
	for team: int in 2:
		var t: Dictionary = {"alive":0.0,"combat":0.0,"combat_idle":0.0,"tech":0,"deaths":0,"deaths_alone":0,"damage":0.0,"objective":0.0}
		for actor: HeroActor in session.actors:
			if actor.team != team: continue
			var debug: BotDebug = (actor.controller as CityBotController).brain.diagnostics
			t.alive += debug.alive_seconds
			t.combat += debug.combat_seconds
			t.combat_idle += debug.combat_idle_seconds
			for kind: String in debug.movement_events:
				if kind != "jump": t.tech += int(debug.movement_events[kind])
			t.deaths += debug.deaths
			t.deaths_alone += debug.deaths_alone
			t.damage += debug.damage
			t.objective += debug.objective_seconds
		var bot_minutes: float = maxf(float(t.alive)/60.0,.001)
		teams.append({"kills":kills_by_team[team],"deaths":t.deaths,"deaths_per_bot_minute":snappedf(float(t.deaths)/bot_minutes,.001),
			"deaths_alone_ratio":snappedf(float(t.deaths_alone)/maxf(1,float(t.deaths)),.001),"combat_idle_ratio":snappedf(float(t.combat_idle)/maxf(float(t.combat),.001),.001),
			"tech_per_bot_minute":snappedf(float(t.tech)/bot_minutes,.01),"damage_per_bot_minute":snappedf(float(t.damage)/bot_minutes,.1),
			"objective_share":snappedf(float(t.objective)/maxf(float(t.alive),.001),.001)})
	var hill_scores: Array = []
	if map_name == "city": hill_scores = [snappedf(session.hill.scores[0],.1),snappedf(session.hill.scores[1],.1)]
	return {"aggregate":aggregate,"bots":bots,"teams":teams,"hill_scores":hill_scores,"rounds":rounds,"round_wins":round_wins}
