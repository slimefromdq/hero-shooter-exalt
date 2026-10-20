extends SceneTree
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int = 3) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func run() -> void:
	for scene: String in ["res://scenes/city/meridian_gardens.tscn","res://scenes/museum/meridian_museum.tscn"]:
		HeroRoster.selected = "samson"
		var arena: Node3D = load(scene).instantiate()
		root.add_child(arena)
		current_scene = arena
		var session: CityMatch = arena.match_controller
		session.player.controller.active = false
		session.freeze_ai = true
		await frames(5)
		for actor: HeroActor in session.actors: actor.set_physics_process(false)
		var source: HeroActor = session.player
		for id: String in ["samson","stitch","wisp","relay"]:
			session.winner = -1
			if session is MuseumMatch: (session as MuseumMatch).objective.phase = "capture"
			source.select_hero(id)
			source.reset_actor(Vector3(0,1.3,0))
			source.set_physics_process(false)
			source.aim_direction = Vector3.FORWARD
			if source.kit is SamsonKit:
				(source.kit as SamsonKit).gain_evidence()
				source.state = "samson_cross"
			elif source.kit is StitchKit:
				(source.kit as StitchKit).start_conceal()
				(source.kit as StitchKit).launch_hook()
			elif source.kit is WispKit:
				var input := CombatIntent.new()
				input.deflect = true
				source.kit.tick(0,input)
			else:
				var seeker := source.kit as RelayKit
				seeker.murmuration_left = 10
				seeker.recipient = source
				seeker.recipient_life = source.life_serial
				seeker.sync_birds()
			if source.kit is WispKit: check(source.state == "wisp_phase","round fixture exercised actual Rogue phase")
			if source.kit is StitchKit: check(source.concealed() and (source.kit as StitchKit).hook_flying,"round fixture exercised concealed hook")
			if source.kit is RelayKit: check((source.kit as RelayKit).birds.size() == 3,"round fixture exercised three companion birds")
			var target: HeroActor
			for actor: HeroActor in session.actors:
				if actor.team != source.team:
					target = actor
					break
			target.reset_actor(Vector3(0,1.3,-8))
			target.set_physics_process(false)
			var before: float = target.health
			session._on_round_won(0)
			# Actors keep ordinary movement ticking on the result screen.
			# Idle kit updates must not recreate cancelled companions/effects.
			source.kit.tick(1.0/60,CombatIntent.new())
			check(source.state == "ready" and not source.concealed() and not source.ability_damage_immune(),"round end cancels active state: "+id+" / "+scene)
			check(source.resolver.damage(source,target,100,"projectile",source.resolver.new_cast(source)) == "immune" and target.health == before,"finished round blocks delayed damage: "+id)
			source.health = 1
			check(source.resolver.heal(source,source,100,"guiding_spirit") == 0,"finished round blocks healing: "+id)
			if source.kit is SamsonKit: check((source.kit as SamsonKit).evidence == 0,"round end clears Evidence")
			if source.kit is StitchKit: check(not (source.kit as StitchKit).hook_flying,"round end clears hook")
			if source.kit is RelayKit: check((source.kit as RelayKit).birds.is_empty(),"round end removes companion birds")
			await frames()
			var owned: int = 0
			for node: Node in get_nodes_in_group("owned_attacks"):
				if node.get("source") == source: owned += 1
			check(owned == 0,"finished round releases owned effects: "+id)
			session.restart_match()
			session.freeze_ai = true
			for actor: HeroActor in session.actors: actor.set_physics_process(false)
			check(session.winner == -1 and source.alive and source.state == "ready","restart restores clean playable life: "+id)
		arena.queue_free()
		await frames(4)
	print("WAVE 1 ROUND: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/wave-1-round-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
