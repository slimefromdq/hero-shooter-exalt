extends SceneTree
## Two 90-second 2/2/2 phases: mirrored Wave 1, then legacy mixed compositions.
var failures: Array[String] = []
var casts: Dictionary = {}
var hero_casts: Dictionary = {}
var hit_counts: Dictionary = {}
var heal_counts: Dictionary = {}
var phase_metrics: Array[Dictionary] = []
var healing: float = 0
var damage: float = 0
var checks: int = 0

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func step(frames: int) -> void:
	for i: int in frames:
		await physics_frame
		await process_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(76)
	HeroRoster.composition_seed = 76
	HeroRoster.selected = "samson"
	var museum: bool = "--museum" in OS.get_cmdline_user_args()
	var arena: Node3D = load("res://scenes/museum/meridian_museum.tscn" if museum else "res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var session: CityMatch = arena.match_controller
	session.player.controller.active = false
	var pilot: CityBotController = MuseumBotController.new() if museum else CityBotController.new()
	pilot.actor = session.player
	pilot.match_controller = session
	pilot.slot = 0
	pilot.role = "frontline"
	session.player.add_child(pilot)
	session.player.controller = pilot
	session.hud.process_mode = Node.PROCESS_MODE_DISABLED
	for actor: HeroActor in session.actors:
		actor.presentation.process_mode = Node.PROCESS_MODE_DISABLED
		actor.controller.rng.seed = 760000+actor.team*100+actor.controller.slot
	var resolver: CombatResolver = session.player.resolver
	var lineups: Array = [["samson","relay","stitch","wisp","marshal","dynamo"],["samson","relay","stitch","wisp","huddle","marshal"]]
	install_rosters(session,lineups)
	resolver.event_logged.connect(func(entry: Dictionary) -> void:
		if entry.event in ["cast","complete","arrival","protect","attach","hang"]:
			casts[entry.ability] = int(casts.get(entry.ability,0))+1
		var key: String = str(entry.actor)+":"+str(entry.ability)+":"+str(entry.event)
		hero_casts[key] = int(hero_casts.get(key,0))+1)
	resolver.confirmed_heal.connect(func(source: HeroActor,_target: HeroActor,amount: float) -> void:
		healing += amount
		heal_counts[source.tuning.hero_id] = float(heal_counts.get(source.tuning.hero_id,0))+amount)
	resolver.confirmed_hit.connect(func(source: HeroActor,_target: HeroActor,amount: float,_head: bool,_execute: bool) -> void:
		damage += amount
		hit_counts[source.tuning.hero_id] = float(hit_counts.get(source.tuning.hero_id,0))+amount)
	var start: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec()-start < 60000: await step(1)
	check(session.navigation_ready,"navigation ready for Wave 1 mixed-roster match")
	var falls: int = 0
	var samples: Array[Dictionary] = []
	var measured_start: int = Time.get_ticks_msec()
	var phase_start: int = measured_start
	var max_transient: int = 0
	for second: int in 180:
		if second == 90:
			phase_metrics.append({"phase":"mirrored_wave1","seconds":90,"wall_ms":Time.get_ticks_msec()-phase_start})
			phase_start = Time.get_ticks_msec()
			install_rosters(session,[["samson","doctor","stitch","nimbus","marshal","dynamo"],["relay","doctor","wisp","slayer","marshal","huddle"]])
		await step(60)
		max_transient = maxi(max_transient,get_nodes_in_group("transient").size())
		for actor: HeroActor in session.actors:
			if actor.alive and actor.global_position.y < -6: falls += 1
			if actor.kit is SamsonKit:
				var k := actor.kit as SamsonKit
				if k.charges < 0 or k.charges > k.data().intervene_charges:
					failures.append("Samson charge count escaped bounds")
		if second%30 == 29:
			samples.append({"second":second+1,"damage":damage,"healing":healing,"casts":casts.duplicate()})
			print("WAVE 1 MATCH ",JSON.stringify(samples[-1]))
	check(session.actors.size() == 12,"mixed match retains twelve actors")
	check(falls == 0,"mixed match has no live terrain falls")
	phase_metrics.append({"phase":"legacy_mixed","seconds":90,"wall_ms":Time.get_ticks_msec()-phase_start})
	for id: String in ["samson","stitch","wisp","relay"]:
		check(float(hit_counts.get(id,0)) > 0,"mixed-match damage exercised: "+id)
	for id: String in ["samson","relay"]:
		check(float(heal_counts.get(id,0)) > 0,"mixed-match ally healing exercised: "+id)
	check(damage > 0,"mixed bots deal actual damage")
	check(healing > 0,"support bots rescue and heal real allies")
	check(int(casts.get("cross_examination",0)) > 0,"bots channel Cross-Examination in actual combat")
	check(int(casts.get("cease_and_desist",0)) > 0,"bots deploy notice in actual combat")
	var file := FileAccess.open("res://artifacts/wave-1-match-%s.json" % ("museum" if museum else "city"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed":76,"seconds":180,"checks":checks,"failures":failures,"casts":casts,"damage":damage,"healing":healing,"falls":falls,"samples":samples,"hero_events":hero_casts,"damage_by_hero":hit_counts,"healing_by_hero":heal_counts,"phase_metrics":phase_metrics,"max_transient":max_transient},"\t"))
	arena.queue_free()
	await step(3)
	print("WAVE 1 MATCH RESULT: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func install_rosters(session: CityMatch, lineups: Array) -> void:
	var slots: Array[int] = [0,0]
	for actor: HeroActor in session.actors:
		var slot: int = slots[actor.team]
		slots[actor.team] += 1
		var id: String = lineups[actor.team][slot]
		actor.select_hero(id)
		actor.actor_id = "%s_T%d_S%d" % [id,actor.team,slot]
		actor.reset_actor(actor.spawn_position)
		actor.kit.ultimate_charge = 100
		actor.presentation.process_mode = Node.PROCESS_MODE_DISABLED
		if actor.controller is CityBotController:
			var driver := actor.controller as CityBotController
			driver.rng.seed = 760000+actor.team*100+slot
			driver.brain.reset()
		actor.set_physics_process(true)
