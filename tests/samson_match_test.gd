extends SceneTree
## 120 seconds of ordinary seeded mixed-roster physics, AI and combat.
var failures: Array[String] = []
var casts: Dictionary = {}
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
	resolver.event_logged.connect(func(entry: Dictionary) -> void:
		if entry.event in ["cast","complete","arrival","protect"]:
			casts[entry.ability] = int(casts.get(entry.ability,0))+1)
	resolver.confirmed_heal.connect(func(source: HeroActor,_target: HeroActor,amount: float) -> void:
		if source.kit is SamsonKit: healing += amount)
	resolver.confirmed_hit.connect(func(source: HeroActor,_target: HeroActor,amount: float,_head: bool,_execute: bool) -> void:
		if source.kit is SamsonKit: damage += amount)
	var start: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec()-start < 60000: await step(1)
	check(session.navigation_ready,"navigation ready for Samson mixed-roster match")
	var falls: int = 0
	var samples: Array[Dictionary] = []
	for second: int in 120:
		await step(60)
		for actor: HeroActor in session.actors:
			if actor.alive and actor.global_position.y < -6: falls += 1
			if actor.kit is SamsonKit:
				var k := actor.kit as SamsonKit
				if k.charges < 0 or k.charges > k.data().intervene_charges:
					failures.append("Samson charge count escaped bounds")
		if second%30 == 29:
			samples.append({"second":second+1,"damage":damage,"healing":healing,"casts":casts.duplicate()})
			print("SAMSON MATCH ",JSON.stringify(samples[-1]))
	check(session.actors.size() == 12,"mixed match retains twelve actors")
	check(falls == 0,"mixed match has no live terrain falls")
	check(damage > 0,"Samson bots deal actual Deposition damage")
	check(healing > 0,"Samson bots rescue and heal real allies")
	check(int(casts.get("cross_examination",0)) > 0,"bots channel Cross-Examination in actual combat")
	check(int(casts.get("cease_and_desist",0)) > 0,"bots deploy notice in actual combat")
	var file := FileAccess.open("res://artifacts/samson-match-%s.json" % ("museum" if museum else "city"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"seed":76,"seconds":120,"checks":checks,"failures":failures,"casts":casts,"damage":damage,"healing":healing,"falls":falls,"samples":samples},"\t"))
	arena.queue_free()
	await step(3)
	print("SAMSON MATCH RESULT: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
