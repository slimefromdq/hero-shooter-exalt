extends SceneTree

var failures: int = 0
var checks: int = 0
var world: Node3D
var resolver: CombatResolver
var feedback: MatchFeedback

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)

func actor(id: String, team: int) -> HeroActor:
	var result := preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
	result.actor_id = id
	result.team = team
	world.add_child(result)
	result.set_physics_process(false)
	return result

func hit(source: HeroActor, target: HeroActor, amount: float) -> void:
	resolver.damage(source, target, amount, "rifle", resolver.new_cast())

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	var player: HeroActor = actor("player", 0)
	var helper: HeroActor = actor("helper", 0)
	var enemy: HeroActor = actor("enemy", 1)
	feedback = MatchFeedback.new()
	feedback.player = player
	world.add_child(feedback)
	resolver.elimination.connect(feedback.on_elimination)
	hit(player, enemy, 10)
	hit(helper, enemy, 10)
	hit(player, enemy, 500)
	check(feedback.kills == 1 and feedback.feed[0].killer == "PLAYER", "same-frame final blow gets kill credit")
	check(feedback.feed[0].assistants == "HELPER", "recent teammate damage gets assist credit")
	check(feedback.feed.size() == 1, "death emits only one feed entry")
	enemy.reset_actor()
	hit(player, enemy, 10)
	hit(helper, enemy, 500)
	check(feedback.assists == 1, "player assist increments personal counter")
	enemy.reset_actor()
	hit(helper, enemy, 10)
	resolver.combat_time += 8.01
	hit(player, enemy, 500)
	check(feedback.feed.back().assistants == "", "expired damage does not earn assists")
	check(feedback.banner.begins_with("DOUBLE KILL"), "second rapid final blow announces double kill")
	enemy.reset_actor()
	hit(player, enemy, 500)
	check(feedback.banner.contains("TRIPLE KILL") and feedback.banner.contains("KILLING SPREE"), "triple kill and streak celebrate independently")
	feedback.clock += 4.01
	enemy.reset_actor()
	hit(player, enemy, 500)
	check(feedback.banner.begins_with("ELIMINATION") and feedback.streaks[player.get_instance_id()] == 4, "multi-kill expires while life streak continues")
	hit(enemy, player, 500)
	check(not feedback.streaks.has(player.get_instance_id()) and not feedback.chains.has(player.get_instance_id()), "death resets streak and rapid kill chain")
	player.reset_actor()
	hit(player, enemy, 10)
	enemy.reset_actor()
	enemy.die()
	check(feedback.feed.back().killer == "WORLD", "respawn discards damage from previous life")
	check(feedback.feed.size() <= 5, "feed remains bounded under repeated kills")
	feedback._process(7.1)
	check(feedback.feed.is_empty(), "feed entries expire")
	feedback.reset()
	check(feedback.kills == 0 and feedback.assists == 0 and feedback.cue_queue.is_empty() and feedback.streaks.is_empty(), "match reset clears counters, streaks and pending sounds")
	var city := CityMatch.new()
	city.definition = load("res://resources/maps/meridian_gardens.tres") as CityMapDefinition
	player.global_position = city.definition.team_spawns(0)[0]
	player.health = 10
	city.heal_in_spawn(player, .5)
	check(player.health == 110, "own spawn heals at 200 HP per second")
	city.heal_in_spawn(player, 5)
	check(player.health == player.effective_max_health(), "spawn healing caps at effective maximum")
	player.statuses.apply("max_health", enemy, 5, .2)
	player.health = 10
	city.heal_in_spawn(player, 5)
	check(player.health == player.effective_max_health(), "spawn healing respects maximum-health wounds")
	player.health = 10
	player.global_position = city.definition.team_spawns(1)[0]
	city.heal_in_spawn(player, 1)
	check(player.health == 10, "opposing spawn does not heal intruders")
	player.global_position = Vector3.ZERO
	city.heal_in_spawn(player, 1)
	check(player.health == 10, "healing stops outside spawn")
	player.alive = false
	player.global_position = city.definition.team_spawns(0)[0]
	city.heal_in_spawn(player, 1)
	check(player.health == 10, "spawn healing cannot revive dead actors")
	for kind: String in ["kill", "assist", "multi", "streak"]:
		var low: AudioStreamWAV = ProceduralSound.reward_wave(kind, 1)
		var high: AudioStreamWAV = ProceduralSound.reward_wave(kind, 6)
		check(low.data.size() > 0 and high.data.size() > 0 and (kind == "assist" or low.data != high.data), "valid escalating sound: " + kind)
	check(MatchFeedback.multi_name(4) == "QUADRUPLE KILL" and MatchFeedback.multi_name(7).contains("7"), "group kill names extend beyond quadruple")
	city.free()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
