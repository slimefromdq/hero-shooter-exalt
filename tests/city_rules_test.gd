extends SceneTree

var checks: int = 0
var failures: Array[String] = []
var world: Node3D
var resolver: CombatResolver

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	print("PASS  " if condition else "FAIL  ", description)
	if not condition: failures.append(description)

func actor_at(team_id: int, at: Vector3) -> HeroActor:
	var actor := preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
	actor.team = team_id
	actor.position = at
	world.add_child(actor)
	actor.set_physics_process(false)
	return actor

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	var definition := load("res://resources/maps/meridian_gardens.tres") as CityMapDefinition
	var hill := CityHill.new()
	hill.definition = definition
	world.add_child(hill)
	var a: HeroActor = actor_at(0, Vector3(4, 0, 4))
	var b: HeroActor = actor_at(1, Vector3(40, 0, 0))
	var both: Array[HeroActor] = [a, b]
	hill.reset()
	hill.advance(19.0, both)
	check(hill.owner_team == -1 and hill.capture_progress == 0, "hill stays locked for twenty seconds")
	hill.advance(1.0, both)
	check(hill.unlocked and hill.capture_progress == 0, "unlock boundary does not retroactively capture")
	hill.advance(4.0, both)
	check(hill.owner_team == -1 and is_equal_approx(hill.capture_progress, .8), "capture requires five uncontested seconds")
	b.position = Vector3(-4, 0, 4)
	hill.advance(2.0, both)
	check(hill.contested and is_equal_approx(hill.capture_progress, .8), "both teams freeze capture while contested")
	b.position.x = 40
	hill.advance(1.0, both)
	check(hill.owner_team == 0 and hill.captures[0] == 1, "five seconds gives ownership exactly once")
	check(is_zero_approx(hill.scores[0]), "capture time is not credited as ownership score")
	a.position.x = 40
	hill.advance(7.0, both)
	check(is_equal_approx(hill.scores[0], 7.0), "empty owned hills continue scoring one percent per second")
	b.position.x = -4
	hill.advance(2.0, both)
	check(is_equal_approx(hill.scores[0], 7.0), "a lone enemy pauses ownership scoring")
	check(is_equal_approx(hill.capture_progress, .4), "a lone enemy begins recapture")
	b.position.x = 40
	hill.advance(1.0, both)
	check(is_equal_approx(hill.capture_progress, .2), "empty partial capture decays")
	a.position = Vector3(0, -5, 0)
	b.position = Vector3(0, 6.5, 0)
	hill.advance(.1, both)
	check(hill.occupancy == [0, 0], "subway and elevated occupants cannot capture the ground hill")
	check(not hill.contains(Vector3(0, 2.51, 0)) and hill.contains(Vector3(9.9, .01, 8.9)), "hill uses explicit horizontal and height bounds")
	a.position = Vector3.ZERO
	a.alive = false
	hill.advance(.1, both)
	check(hill.occupancy[0] == 0, "dead actors cannot occupy the hill")
	a.alive = true
	a.position.x = 40
	hill.advance(150.0, both)
	check(hill.winner == 0 and hill.scores[0] == 100, "score caps at one hundred and ends the round")
	hill.reset()
	check(hill.owner_team == -1 and hill.winner == -1 and hill.scores[0] == 0 and hill.captures == [0, 0] and hill.unlock_remaining == 20, "hill reset clears all round state")
	var small := CityHealthPack.new()
	world.add_child(small)
	var large := CityHealthPack.new()
	large.heal_amount = 400
	large.respawn_seconds = 15
	world.add_child(large)
	a.health = 250
	check(not small.try_collect(a) and small.available, "full health leaves a shared pickup available")
	a.health = 100
	a.shields = 17
	a.kit.ammo = 3
	a.kit.ultimate_charge = 21
	check(small.try_collect(a) and a.health == 175 and small.cooldown_remaining == 10, "small pack heals seventy-five and begins ten-second cooldown")
	check(a.shields == 17 and a.kit.ammo == 3 and a.kit.ultimate_charge == 21, "healing grants no shields, ammunition or ultimate")
	check(not small.try_collect(b), "either team cannot consume an unavailable shared pack")
	small._process(10)
	check(small.available and small.cooldown_remaining == 0, "small pickup returns after exactly ten seconds")
	a.health = 1
	check(large.try_collect(a) and a.health == 250, "large pickup caps healing at Nimbus maximum health")
	large.reset()
	a.tuning.max_health = 500
	a.health = 100
	check(large.try_collect(a) and a.health == 500, "four hundred healing fills a five-hundred-HP tank from one hundred")
	large.reset()
	a.tuning.max_health = 600
	a.health = 100
	check(large.try_collect(a) and a.health == 500, "large pickup restores the full four hundred HP to a higher-health actor")
	large._process(14.9)
	check(not large.available, "large pickup remains unavailable before fifteen seconds")
	large._process(.11)
	check(large.available, "large pickup respawns after fifteen seconds")
	a.health = 450
	check(large.try_collect(a) and a.health == 600, "tank healing clamps to missing health without overheal")
	large.reset()
	check(large.available and large.cooldown_remaining == 0, "pickup reset removes old cooldowns")
	a.health = 600
	a.spawn_protected = true
	check(not a.permits("primary") and not a.permits("melee") and not a.permits("bomb") and a.permits("reload"), "spawn protection prevents offensive actions while retaining reload")
	check(resolver.damage(a, b, 45, "rifle", resolver.new_cast()) == "immune", "protected attackers cannot damage opponents")
	a.spawn_protected = false
	b.spawn_protected = true
	check(resolver.damage(a, b, 45, "bomb", resolver.new_cast()) == "immune", "protected defenders reject damage including bombs")
	check(not a.close.valid_target(b, 100, -1), "protected defenders cannot be grabbed through a spawn entrance")
	check(definition.small_pack_positions.size() == 6 and definition.large_pack_positions.size() == 2, "resource defines exactly eight shared health pickups")
	check(definition.team_spawns(0).size() == 6 and definition.team_spawns(1).size() == 6, "resource defines twelve team spawn slots")
	for team_id: int in 2:
		var path: Array[Vector3] = definition.route_points(team_id, "frontline")
		var length: float = definition.team_spawns(team_id)[0].distance_to(path[0])
		for index: int in range(1, path.size()): length += path[index - 1].distance_to(path[index])
		print("MAIN ROUTE team=", team_id, " authored length=", length, "m walk=", length / 6.0, "s")
	print("RESULT: ", checks, " checks, ", failures.size(), " failures")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/city-rules.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
