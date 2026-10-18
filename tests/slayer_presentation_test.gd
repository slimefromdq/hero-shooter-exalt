extends SceneTree
var world: Node3D
var a: HeroActor
var b: HeroActor
var resolver: CombatResolver
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if ok: print("PASS  ", caption)
	else:
		failures.append(caption)
		push_error(caption)
func step(frames: int = 1) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame
func spawn(hero: String, team: int, at: Vector3) -> HeroActor:
	var actor: HeroActor = preload("res://scenes/actors/hero_actor.tscn").instantiate()
	actor.tuning = HeroRoster.tuning_for(hero)
	actor.team = team
	actor.position = at
	world.add_child(actor)
	return actor
func prepare() -> void:
	a.reset_actor(Vector3(0, .01, 0))
	b.reset_actor(Vector3(0, .01, -6))
	b.health = 1000
	a.intent.aim_origin = a.global_position + Vector3.UP * 1.05
	a.aim_direction = Vector3.FORWARD
	resolver.clear_round()
func shoot(enabled: bool) -> Dictionary:
	prepare()
	a.presentation.slayer_shot.enabled = enabled
	(a.kit as SlayerKit).fire()
	var kit := a.kit as SlayerKit
	return {"health": b.health, "ammo": kit.ammo, "cooldown": kit.shot_cd, "damage": kit.last_shot_damage, "pellets": kit.last_shot_pellets, "head": kit.last_shot_head, "contacts": a.presentation.slayer_shot.last_report.duplicate(true), "casts": resolver.cast_serial, "velocity": a.velocity, "position": a.position}
func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world, Vector3(60,1,60), Vector3(0,-.5,0), Color.GRAY)
	a = spawn("slayer",0,Vector3(0,.01,0))
	b = spawn("nimbus",1,Vector3(0,.01,-6))
	await step(4)
	var start_cast: int = resolver.cast_serial
	var old: Dictionary = shoot(false)
	old.casts -= start_cast
	start_cast = resolver.cast_serial
	var modern: Dictionary = shoot(true)
	modern.casts -= start_cast
	check(old == modern, "fallback and new effects preserve every endpoint, normal, damage, cast, ammo, cooldown and actor transform")
	check(modern.damage == 90 and modern.pellets == 10 and modern.ammo == 5, "ten close pellets still apply exactly 90 damage for one shell")
	var driver: SlayerShotPresentation = a.presentation.slayer_shot
	check(driver.last_impact_count == 1 and driver.effects.size() == 2, "ten target pellets create one muzzle and one grouped target impact")
	check(a.presentation.sound.slayer_voices.size() == 3, "one discharge layers blast, delayed mechanism and one aggregate impact voice")
	var lethal_contacts: Array[Dictionary] = driver.last_report.duplicate(true)
	lethal_contacts[1].confirmed = false
	driver.discharge(a.muzzle(),Vector3.FORWARD,lethal_contacts)
	check(driver.last_impact_count == 1, "confirmed and post-lethal contacts on one actor remain one impact cluster")
	var count: int = driver.get_child_count()
	(a.kit as SlayerKit).fire()
	check(driver.get_child_count() == count, "cooldown rejection produces no duplicate presentation")
	seed(7341)
	var expected: float = randf()
	seed(7341)
	shoot(true)
	check(randf() == expected, "shot VFX and procedural audio do not advance gameplay random state")
	prepare()
	b.invulnerable = true
	(a.kit as SlayerKit).fire()
	check(b.health == 1000 and not driver.last_report[0].confirmed and a.presentation.sound.slayer_voices.size() == 3, "immune contacts use surface feedback without inventing enemy damage")
	prepare()
	a.aim_direction = Vector3.UP
	(a.kit as SlayerKit).fire()
	check(driver.last_impact_count == 0 and a.presentation.sound.slayer_voices.size() == 2, "a miss produces blast and mechanism without a hit cue")
	var pool: Node = root.get_node("SlayerEffectPool")
	for index: int in 20:
		shoot(true)
		CombatEffect.clear_transients(self)
	check(pool.free_muzzles.size() == 16 and pool.free_impacts.size() == 48, "repeated global restart cleanup returns the full fixed pool")
	var crowd: Array[SlayerShotPresentation] = []
	for index: int in 4:
		var other := SlayerShotPresentation.new()
		other.presentation = a.presentation
		world.add_child(other)
		crowd.append(other)
		for burst: int in 16: other.spawn_burst(other.MUZZLE if burst < 4 else other.IMPACT,Vector3(0,1,-3),Vector3.BACK,Color.WHITE)
	check(get_nodes_in_group("slayer_bursts").size() == 64, "four owners can share the bounded 64-burst world pool")
	driver.spawn_burst(driver.IMPACT,Vector3(0,1,-3),Vector3.BACK,Color.WHITE)
	check(get_nodes_in_group("slayer_bursts").size() == 64, "pool exhaustion drops cosmetic effects without growing the world budget")
	for other: SlayerShotPresentation in crowd:
		other.clear()
		other.queue_free()
	var contacts: Array[Dictionary] = []
	for index: int in 10:
		contacts.append({"position": Vector3(index * 2,1,-4), "normal": Vector3.BACK, "id": index, "actor": false, "confirmed": false, "head": false})
	driver.discharge(a.muzzle(),Vector3.FORWARD,contacts)
	check(driver.last_impact_count == 4, "widely separated impacts respect four-cluster discharge cap")
	for index: int in 25: a.presentation.sound.play_slayer("shell")
	check(a.presentation.sound.slayer_voices.size() == ProceduralSound.MAX_SLAYER_VOICES, "overlapping cues have a bounded eight-voice budget")
	for index: int in 30: driver.spawn_burst(driver.IMPACT,Vector3(0,1,-3),Vector3.BACK,Color.WHITE)
	check(driver.effects.size() <= driver.MAX_LOCAL_BURSTS, "rapid effects obey the per-owner burst budget")
	var controller := PlayerController.new()
	controller.actor = a
	a.add_child(controller)
	a.controller = controller
	prepare()
	var forward: Vector3 = -controller.camera.global_basis.z
	var origin: Vector3 = controller.camera.global_position
	(a.kit as SlayerKit).fire()
	var recoil_before: float = controller.recoil
	driver._process(.01)
	check(controller.camera.global_position.is_equal_approx(origin) and (-controller.camera.global_basis.z).is_equal_approx(forward), "render camera offsets and roll preserve aim origin and forward")
	check(is_equal_approx(recoil_before,deg_to_rad((a.tuning as SlayerTuning).recoil_degrees)), "existing gameplay recoil magnitude remains exact")
	a.die()
	check(driver.get_child_count() == 0 and a.presentation.sound.slayer_voices.is_empty() and controller.camera.h_offset == 0 and controller.camera.v_offset == 0, "death clears owned bursts, overlapping audio and camera feedback")
	shoot(true)
	a.reset_actor()
	check(driver.get_child_count() == 0 and a.presentation.sound.slayer_voices.is_empty(), "restart clears all owned shotgun transients")
	shoot(true)
	a.select_hero("nimbus")
	await step(2)
	check(get_nodes_in_group("slayer_bursts").is_empty(), "hero switching frees Slayer bursts without leaving world effects")
	seed(912)
	expected = randf()
	seed(912)
	a.select_hero("slayer")
	check(randf() == expected, "switching back to Slayer does not instantiate particles or consume gameplay RNG")
	shoot(true)
	await step(70)
	check(get_nodes_in_group("slayer_bursts").is_empty() and a.presentation.sound.slayer_voices.is_empty(), "effects and voices expire without a lifecycle reset")
	for cue: String in ["shotgun", "shotgun_mechanism", "shotgun_hit", "shotgun_surface"]:
		var wave: AudioStreamWAV = ProceduralSound.slayer_wave(cue)
		check(wave.get_length() > .1 and wave.get_length() < .6 and wave.loop_mode == AudioStreamWAV.LOOP_DISABLED, cue + " synthesis is finite and cached")
	shoot(true)
	world.queue_free()
	await step(3)
	check(pool.free_muzzles.size() == 16 and pool.free_impacts.size() == 48 and get_nodes_in_group("slayer_bursts").is_empty(), "scene exit returns active bursts to the persistent pool")
	print("RESULT: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/slayer-presentation-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	if DisplayServer.get_name() != "headless":
		var mixer_release: int = Time.get_ticks_msec() + 150
		while Time.get_ticks_msec() < mixer_release: await process_frame
	quit(0 if failures.is_empty() else 1)
