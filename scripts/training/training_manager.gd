class_name TrainingManager
extends Node

const PROFILES: Array[String] = ["Stationary", "Strafing", "Ranged", "Close attacker", "Sparring"]
const SCENARIOS: Array[String] = ["Live fire", "Rifle laboratory", "Tracking", "Close quarters", "Throw crossfire", "Traversal route"]
var arena: Node3D
var player: HeroActor
var bots: Array[HeroActor] = []
var hud: TrainingHUD
var menu_open: bool = false
var debug_view: bool = false
var freeze_ai: bool = false
var infinite: bool = false
var god_mode: bool = false
var target_invulnerable: bool = false
var target_shields: float = 0.0
var target_health_override: bool = false
var reaction: float = 0.22
var aggression: float = 1.0
var error_chance: float = 0.15
var bot_max_health: float = 250.0
var player_max_health: float = 250.0
var scenario: int = 0
var spawn_serial: int = 0
var hits: int = 0
var eliminations: int = 0
var damage_total: float = 0.0
var elapsed: float = 0.0
var notice: String = "WELCOME TO THE FIELD"
var notice_time: float = 4.0
var death_timers: Dictionary = {}
var route_running: bool = false
var route_time: float = 0.0
var route_best: float = 0.0
var route_falls: int = 0
var route_overshoots: int = 0
var route_accuracy: float = 0.0
var previous_route_position: Vector3

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("training")
	hud = TrainingHUD.new()
	hud.training = self
	add_child(hud)
	player.resolver.confirmed_hit.connect(on_hit)
	player.resolver.event_logged.connect(on_event)
	reset_scenario()

func _process(delta: float) -> void:
	if menu_open:
		return
	elapsed += delta
	notice_time = maxf(0.0, notice_time - delta)
	player.infinite_resources = infinite
	player.invulnerable = god_mode
	for bot: HeroActor in bots:
		if not is_instance_valid(bot):
			continue
		(bot.controller as BotController).frozen = freeze_ai
		if scenario == 4 and bot.team == 2:
			var probe_target: HeroActor = player
			if int(elapsed / 1.2) % 2 == 1 and bots.size() > 0 and bots[0].alive:
				probe_target = bots[0]
			(bot.controller as BotController).target = probe_target
		if not bot.alive:
			var key: int = bot.get_instance_id()
			death_timers[key] = float(death_timers.get(key, 0.0)) + delta
			if death_timers[key] > 3.5:
				bot.reset_actor()
				bot.shields = target_shields
				bot.invulnerable = target_invulnerable
				death_timers.erase(key)
	if route_running:
		route_time += delta
		if not player.alive:
			route_falls += 1
			route_running = false
			show_notice("ROUTE ENDED · reset and try again")
		elif player.global_position.z < -18.0 and player.global_position.x > 14.0 and player.global_position.y > 4.3:
			route_accuracy = Vector2(player.global_position.x - 18.0, player.global_position.z + 20.0).length()
			route_running = false
			if route_best == 0.0 or route_time < route_best:
				route_best = route_time
			show_notice("ROUTE COMPLETE  /  %.2f s · landing %.2f m" % [route_time, route_accuracy])
		elif player.global_position.y < 0.1 and previous_route_position.y > 1.0 and player.global_position.z < 0.0:
			route_overshoots += 1
		previous_route_position = player.global_position

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("training_menu") or event.is_action_pressed("pause"):
		toggle_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reset_scenario"):
		reset_scenario()
	elif event.is_action_pressed("refill"):
		refill_all()
	elif event.is_action_pressed("debug_view"):
		debug_view = not debug_view

func toggle_menu() -> void:
	menu_open = not menu_open
	get_tree().paused = menu_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED
	hud.menu.visible = menu_open
	if menu_open:
		hud.sync_menu()

func show_notice(message: String) -> void:
	notice = message
	notice_time = 3.0

func spawn_bot(profile: int, at: Vector3 = Vector3.INF) -> HeroActor:
	if bots.size() >= 8:
		show_notice("MAXIMUM 8 ACTIVE TARGETS")
		return null
	spawn_serial += 1
	var bot := preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
	bot.team = 1
	bot.tuning = player.tuning.duplicate() as HeroTuning
	bot.actor_id = "%s_%02d" % [PROFILES[profile].to_lower().replace(" ", "_"), spawn_serial]
	bot.position = Vector3(-4 + bots.size() * 3, 0.1, -7 - bots.size() * 2) if at == Vector3.INF else at
	arena.add_child(bot)
	bot.tuning.max_health = bot_max_health
	bot.health = bot_max_health
	bot.shields = target_shields
	bot.invulnerable = target_invulnerable
	var controller := BotController.new()
	controller.actor = bot
	controller.target = player
	controller.profile = profile
	controller.reaction_delay = reaction
	controller.error_chance = error_chance
	controller.aggression = aggression
	controller.frozen = freeze_ai
	bot.add_child(controller)
	bot.controller = controller
	bots.append(bot)
	return bot

func despawn_bots() -> void:
	for bot: HeroActor in bots:
		if is_instance_valid(bot):
			bot.close.cancel()
			bot.kit.cancel(true)
			bot.queue_free()
	bots.clear()
	death_timers.clear()

func reset_scenario() -> void:
	despawn_bots()
	for transient: Node in get_tree().get_nodes_in_group("transient"):
		transient.queue_free()
	player.tuning.max_health = player_max_health
	player.reset_actor(Vector3(0, 0.1, 11))
	player.invulnerable = god_mode
	player.infinite_resources = infinite
	player.resolver.clear_round()
	spawn_serial = 0
	hits = 0
	eliminations = 0
	damage_total = 0.0
	elapsed = 0.0
	route_running = false
	target_health_override = false
	match scenario:
		0: spawn_bot(BotController.Profile.RANGED, Vector3(1, 0.1, -6))
		1: spawn_bot(BotController.Profile.STATIONARY, Vector3(0, 0.1, -5))
		2: spawn_bot(BotController.Profile.STRAFE, Vector3(0, 0.1, -8))
		3: spawn_bot(BotController.Profile.SPARRING, Vector3(0, 0.1, 7))
		4:
			spawn_bot(BotController.Profile.SPARRING, Vector3(0, 0.1, 8.5))
			var probe: HeroActor = spawn_bot(BotController.Profile.RANGED, Vector3(4, 0.1, -3))
			probe.team = 2
			probe.actor_id = "crossfire_probe"
		5:
			player.reset_actor(Vector3(18, 1.1, 4))
	show_notice("EXERCISE %02d  /  %s" % [scenario + 1, SCENARIOS[scenario].to_upper()])

func refill_all() -> void:
	if not player.alive:
		player.reset_actor()
	player.health = player.tuning.max_health
	player.kit.refill()
	player.motor.dash_cd = 0.0
	player.motor.hover_cd = 0.0
	player.close.refill()
	show_notice("TRAINING REFILL · health / ammo / cooldowns / ultimate")
	player.resolver.record("refill", player, "debug")

func set_targets_health(fraction: float) -> void:
	target_health_override = fraction != 1.0
	for bot: HeroActor in bots:
		if bot.alive:
			bot.health = bot.tuning.max_health * fraction
	show_notice("TARGET HEALTH  /  %d%%" % int(fraction * 100))

func apply_bot_settings() -> void:
	for bot: HeroActor in bots:
		var controller: BotController = bot.controller as BotController
		controller.reaction_delay = reaction
		controller.error_chance = error_chance
		controller.aggression = aggression
		bot.invulnerable = target_invulnerable
		bot.shields = target_shields

func set_tuning(field: String, value: float) -> void:
	player.tuning.set(field, value)
	for bot: HeroActor in bots:
		bot.tuning.set(field, value)

func start_route() -> void:
	scenario = 5
	reset_scenario()
	route_time = 0.0
	route_running = true
	previous_route_position = player.global_position
	if menu_open:
		toggle_menu()
	show_notice("ROUTE STARTED · reach the raised finish deck")

func export_events() -> void:
	var file := FileAccess.open("user://combat_events.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(player.resolver.events, "\t"))
		show_notice("EVENT LOG SAVED  /  user://combat_events.json")

func on_hit(source: HeroActor, _target: HeroActor, amount: float, head: bool, executed: bool) -> void:
	if source == player:
		hits += 1
		damage_total += amount
		hud.hit_timer = 0.25
		hud.hit_head = head
		hud.hit_text = "FINAL NOTICE" if executed else ("%d  HEADSHOT" % int(amount) if head else str(int(amount)))

func on_event(entry: Dictionary) -> void:
	if entry["event"] == "death" and entry["actor"] != "nimbus":
		eliminations += 1
		show_notice("TARGET NEUTRALIZED  /  " + str(entry["actor"]).to_upper())
	elif entry["event"] in ["counterthrow", "block", "deflect"]:
		show_notice(str(entry["event"]).to_upper() + "  /  " + str(entry["actor"]).to_upper())
