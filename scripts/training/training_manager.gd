class_name TrainingManager
extends Node

const PROFILES: Array[String] = ["Stationary", "Strafing", "Ranged", "Close attacker", "Sparring", "Guard trainer", "Slayer hunter", "Marshal", "Doctor", "Huddle", "Relay", "Dynamo", "Wisp"]
const SCENARIOS: Array[String] = ["Live fire", "Rifle laboratory", "Tracking", "Close quarters", "Throw crossfire", "Traversal route", "Guard drill", "Slayer hunt", "Doctor rounds", "Marshal drill", "Huddle rescue", "Practice range", "Relay circuit", "Dynamo siege", "Wisp ballet"]
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
var guard_test_range: float = 2.4
var guard_test_interval: float = 1.6
var bot_max_health: float = 250.0
var player_max_health: float = 250.0
var scenario: int = 11
var feedback: MatchFeedback
var practice_range: PracticeRange
var spawn_serial: int = 0
var hits: int = 0
var eliminations: int = 0
var damage_total: float = 0.0
var elapsed: float = 0.0
var care_drill_clock: float = 0.0
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
	player_max_health = player.tuning.max_health
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("training")
	add_to_group("game_session")
	feedback = MatchFeedback.new()
	feedback.player = player
	add_child(feedback)
	player.resolver.elimination.connect(feedback.on_elimination)
	hud = TrainingHUD.new()
	hud.training = self
	add_child(hud)
	player.resolver.confirmed_hit.connect(on_hit)
	player.resolver.event_logged.connect(on_event)
	reset_scenario()

func enter_city() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/city/meridian_gardens.tscn")

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
				if bot.get_meta("station","") == "allies": bot.health = bot.tuning.max_health*.5
				death_timers.erase(key)
	if scenario in [8,12] and bots.size() >= 4:
		care_drill_clock += delta
		if care_drill_clock >= 1.0:
			care_drill_clock = 0
			for index: int in 3:
				var friend: HeroActor = bots[index]
				if friend.alive:
					player.resolver.damage(bots[3],friend,12,"rifle",player.resolver.new_cast(bots[3]))
					if index == 1 and friend.statuses.effects.is_empty(): friend.statuses.apply("bleed",bots[3],5,5)
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
	if player.controller is PlayerController: (player.controller as PlayerController).clear_action_queue()
	menu_open = not menu_open
	get_tree().paused = menu_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED
	hud.menu.visible = menu_open
	if menu_open:
		hud.sync_menu()

func show_notice(message: String) -> void:
	notice = message
	notice_time = 3.0

func spawn_bot(profile: int, at: Vector3 = Vector3.INF, built_in: bool = false, team_id: int = 1) -> HeroActor:
	var manual_count: int = 0
	for existing: HeroActor in bots:
		if not existing.get_meta("built_in",false): manual_count += 1
	if not built_in and manual_count >= 8:
		show_notice("MAXIMUM 8 ACTIVE TARGETS")
		return null
	spawn_serial += 1
	var bot := preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
	bot.set_meta("built_in",built_in)
	bot.team = team_id
	bot.tuning = HeroRoster.tuning_for({6:"slayer",7:"marshal",8:"doctor",9:"huddle",10:"relay",11:"dynamo",12:"wisp"}.get(profile,"nimbus"))
	bot.actor_id = "%s_%02d" % [PROFILES[profile].to_lower().replace(" ", "_"), spawn_serial]
	bot.position = Vector3(-4 + bots.size() * 3, 0.1, -7 - bots.size() * 2) if at == Vector3.INF else at
	arena.add_child(bot)
	if profile < 10 or target_health_override: bot.tuning.max_health = bot_max_health
	bot.health = bot.tuning.max_health
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
	controller.guard_trigger_range = guard_test_range
	controller.guard_attack_interval = guard_test_interval
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
	if is_instance_valid(practice_range): practice_range.queue_free()
	if is_instance_valid(hud): hud.hit_timer = 0.0
	despawn_bots()
	CombatEffect.clear_transients(get_tree())
	player.tuning.max_health = player_max_health
	player.reset_actor(Vector3(0, 0.1, 11))
	player.invulnerable = god_mode
	player.infinite_resources = infinite
	player.resolver.clear_round()
	feedback.reset()
	practice_range = null
	spawn_serial = 0
	hits = 0
	eliminations = 0
	damage_total = 0.0
	elapsed = 0.0
	route_running = false
	target_health_override = false
	match scenario:
		12:
			for index: int in 3:
				var friend: HeroActor = spawn_bot(0,Vector3(-5+index*5,.1,3-index*3),false,player.team)
				friend.actor_id = "Circuit_ally_%d" % (index+1)
				friend.health = 80
			spawn_bot(2,Vector3(8,.1,-12))
		13:
			for index: int in 3: spawn_bot(1,Vector3(-3+index*3,.1,-8-index))
			spawn_bot(7,Vector3(6,.1,-15))
		14:
			spawn_bot(1,Vector3(0,.1,-2))
			spawn_bot(2,Vector3(-7,.1,-8))
			spawn_bot(12,Vector3(8,.1,-14))
		11:
			player.reset_actor(Vector3(0,.1,-28))
			practice_range = PracticeRange.new()
			practice_range.training = self
			arena.add_child(practice_range)
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
		6:
			spawn_bot(BotController.Profile.GUARD_TRAINER,Vector3(0,.1,7.2))
		7:
			spawn_bot(BotController.Profile.STATIONARY,Vector3(0,.1,4))
			spawn_bot(BotController.Profile.STRAFE,Vector3(4,.1,-4))
			spawn_bot(6,Vector3(-5,.1,-8))
		8:
			for index: int in 3:
				var friend: HeroActor = spawn_bot(0,Vector3(-4+index*4,.1,2-index*2))
				friend.team = player.team
				friend.select_hero("nimbus")
				friend.actor_id = "Patient_%d" % (index+1)
				friend.health = 100
			var attacker: HeroActor = spawn_bot(2,Vector3(7,.1,-10))
			attacker.actor_id = "Flanker"
		9:
			var friend: HeroActor = spawn_bot(0,Vector3(0,.1,14))
			friend.team = player.team
			friend.select_hero("nimbus")
			friend.actor_id = "Protected_ally"
			for index: int in 3:
				var attacker: HeroActor = spawn_bot(2,Vector3(-4+index*4,.1,-4-index*2))
				attacker.controller.target = friend
		10:
			player.health = player.effective_max_health()*.6
			var friend: HeroActor = spawn_bot(0,Vector3(0,.1,3))
			friend.team = player.team
			friend.actor_id = "Garden_neighbor"
			for i: int in 3:
				var attacker: HeroActor = spawn_bot(2,Vector3(-3+i*3,.1,-5))
				attacker.controller.target = friend
	show_notice("EXERCISE %02d  /  %s" % [scenario + 1, SCENARIOS[scenario].to_upper()])

func refill_all() -> void:
	if not player.alive:
		player.reset_actor()
	player.statuses.cleanse()
	player.health = player.effective_max_health()
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
			bot.health = bot.effective_max_health() * fraction
	show_notice("TARGET HEALTH  /  %d%%" % int(fraction * 100))

func apply_bot_settings() -> void:
	for bot: HeroActor in bots:
		var controller: BotController = bot.controller as BotController
		controller.reaction_delay = reaction
		controller.error_chance = error_chance
		controller.aggression = aggression
		controller.guard_trigger_range = guard_test_range
		controller.guard_attack_interval = guard_test_interval
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

func start_guard_drill() -> void:
	scenario = 6
	freeze_ai = false
	reset_scenario()
	if menu_open:
		toggle_menu()

func export_events() -> void:
	var file := FileAccess.open("user://combat_events.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(player.resolver.events, "\t"))
		show_notice("EVENT LOG SAVED  /  user://combat_events.json")

func on_hit(source: HeroActor, _target: HeroActor, amount: float, head: bool, executed: bool) -> void:
	if source == player:
		hits += 1
		damage_total += amount
		hud.hit_timer = 0.8
		hud.hit_head = head
		hud.hit_text = "FINAL NOTICE" if executed else ("%d  HEADSHOT" % int(amount) if head else str(int(amount)))

func on_event(entry: Dictionary) -> void:
	if entry["event"] == "death" and entry["actor"] != player.actor_id:
		eliminations += 1
		show_notice("TARGET NEUTRALIZED  /  " + str(entry["actor"]).to_upper())
	elif entry["event"] in ["counterthrow", "block", "deflect"]:
		show_notice(str(entry["event"]).to_upper() + "  /  " + str(entry["actor"]).to_upper())

func select_hero(id: String) -> void:
	HeroRoster.selected = id
	player.select_hero(id)
	player.actor_id = id
	player_max_health = player.tuning.max_health
	reset_scenario()
	hud.rebuild_menu()
	show_notice(id.to_upper() + " SELECTED")

func start_slayer_hunt() -> void:
	select_hero("slayer")
	scenario = 7
	freeze_ai = false
	reset_scenario()
	if menu_open: toggle_menu()

func start_care_drill(id: String) -> void:
	select_hero(id)
	scenario = 8 if id == "doctor" else 9
	freeze_ai = false
	reset_scenario()
	if menu_open: toggle_menu()

func start_huddle_drill() -> void:
	select_hero("huddle")
	scenario = 10
	freeze_ai = false
	reset_scenario()
	show_notice("RMB regroup / E shield the neighbor / Q reach the raised decks / 2 sweep attackers away")
	if menu_open: toggle_menu()

func start_roster_drill(id: String) -> void:
	select_hero(id)
	scenario = {"relay":12,"dynamo":13,"wisp":14}[id]
	freeze_ai = false
	reset_scenario()
	show_notice({"relay":"RMB assign / 1 recall and recharge / E blast / 2 overclock allies","dynamo":"RMB prespin / E preview, LMB place, RMB rotate / 1 pull / 2 storm","wisp":"Pistols mark / Q loads shells / RMB core detonates / 1 lift / E phase"}[id])
	if menu_open: toggle_menu()
