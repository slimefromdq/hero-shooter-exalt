class_name CityMatch
extends Node

## Offline 6v6 session. The training session retains its own rules and reset flow.
var arena: Node3D
var definition: CityMapDefinition
var player: HeroActor
var actors: Array[HeroActor] = []
var bots: Array[HeroActor] = []
var pickups: Array[CityHealthPack] = []
var hill: CityHill
var hud: Node
var menu_open: bool = false
var debug_view: bool = false
var exploration: bool = false
var freeze_ai: bool = false
var navigation_ready: bool = false
var elapsed: float = 0.0
var winner: int = -1
var notice: String = "MERIDIAN GARDENS  /  THE HILL OPENS IN 20 SECONDS"
var notice_time: float = 5.0
var death_timers: Dictionary = {}
var eliminations: Array[int] = [0, 0]
var round_serial: int = 0
var _spawn_indices: Dictionary = {}
var _nav_check_timer: float = 0.0
var _pickup_order: int = 0
const SPAWN_HEAL_PER_SECOND: float = 200.0
var feedback: MatchFeedback

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_session")
	add_to_group("city_match")
	if definition == null:
		definition = preload("res://resources/maps/meridian_gardens.tres") as CityMapDefinition
	hill = CityHill.new()
	hill.definition = definition
	hill.ownership_changed.connect(_on_ownership_changed)
	hill.round_won.connect(_on_round_won)
	add_child(hill)
	actors.append(player)
	_spawn_indices[player.get_instance_id()] = 0
	_build_pickups()
	_build_spawn_gates()
	_spawn_teams()
	var hud_script: Script = load("res://scripts/city/city_hud.gd")
	if hud_script != null:
		hud = hud_script.new()
		hud.match_controller = self
		add_child(hud)
	player.resolver.confirmed_hit.connect(_on_confirmed_hit)
	player.resolver.event_logged.connect(_on_combat_event)
	feedback = MatchFeedback.new()
	feedback.player = player
	add_child(feedback)
	player.resolver.elimination.connect(feedback.on_elimination)
	restart_match()

func _physics_process(delta: float) -> void:
	if menu_open:
		return
	_nav_check_timer -= delta
	if not navigation_ready and _nav_check_timer <= 0.0:
		_nav_check_timer = 0.25
		var world_map: RID = arena.get_world_3d().navigation_map
		var region: NavigationRegion3D = arena.get("navigation_region") as NavigationRegion3D
		navigation_ready = is_instance_valid(region) and region.navigation_mesh != null and region.navigation_mesh.get_polygon_count() > 0 and world_map.is_valid() and NavigationServer3D.map_get_iteration_id(world_map) > 0 and NavigationServer3D.map_get_closest_point_owner(world_map, definition.team_spawns(0)[0]) == region.get_rid()
		if navigation_ready:
			# The asynchronous city bake is preparation time, not earned match charge.
			for actor: HeroActor in actors:
				actor.kit.ultimate_charge = 0.0
	notice_time = maxf(0.0, notice_time - delta)
	for actor: HeroActor in actors:
		if not is_instance_valid(actor):
			continue
		actor.spawn_protected = is_protected(actor)
		heal_in_spawn(actor, delta)
		if actor != player and is_instance_valid(actor.controller):
			actor.controller.frozen = freeze_ai or exploration or winner >= 0 or not navigation_ready
	if not navigation_ready or exploration or winner >= 0:
		return
	elapsed += delta
	hill.advance(delta, actors)
	for actor: HeroActor in actors:
		if not is_instance_valid(actor) or actor.alive:
			continue
		var key: int = actor.get_instance_id()
		death_timers[key] = float(death_timers.get(key, 0.0)) + delta
		if float(death_timers[key]) >= definition.respawn_seconds:
			respawn_actor(actor)
	# Shared pickups have deterministic round-robin priority when actors overlap.
	for pickup: CityHealthPack in pickups:
		if not pickup.available:
			continue
		for offset: int in actors.size():
			var actor: HeroActor = actors[(_pickup_order + offset) % actors.size()]
			if not actor.alive:
				continue
			var distance: Vector3 = actor.global_position - pickup.global_position
			if absf(distance.y) <= 1.5 and Vector2(distance.x, distance.z).length_squared() <= 1.55 * 1.55:
				if pickup.try_collect(actor):
					break
	_pickup_order = (_pickup_order + 1) % maxi(1, actors.size())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("training_menu") or event.is_action_pressed("pause"):
		toggle_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reset_scenario"):
		restart_match()
	elif event.is_action_pressed("debug_view"):
		debug_view = not debug_view

func _spawn_teams() -> void:
	var roles: Array[String] = ["frontline", "frontline", "frontline", "flank_left", "flank_right", "high_ground"]
	for team: int in 2:
		var positions: Array[Vector3] = definition.team_spawns(team)
		for slot: int in 6:
			if team == 0 and slot == 0:
				continue
			var actor := preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
			actor.team = team
			actor.actor_id = "%s_%02d" % ["lantern" if team == 0 else "crown", slot + 1]
			actor.tuning = HeroRoster.tuning_for("slayer" if HeroRoster.selected == "slayer" and slot in [1,3] else "nimbus")
			actor.position = positions[slot]
			arena.add_child(actor)
			var controller_script: Script = load("res://scripts/city/city_bot_controller.gd")
			var controller: Node = controller_script.new()
			controller.actor = actor
			controller.match_controller = self
			controller.role = roles[slot]
			controller.slot = slot
			actor.add_child(controller)
			actor.controller = controller
			actors.append(actor)
			bots.append(actor)
			_spawn_indices[actor.get_instance_id()] = slot

func _build_pickups() -> void:
	for at: Vector3 in definition.small_pack_positions:
		_add_pickup(at, 75.0, 10.0)
	for at: Vector3 in definition.large_pack_positions:
		_add_pickup(at, 400.0, 15.0)

func _add_pickup(at: Vector3, healing: float, cooldown: float) -> void:
	var pickup := CityHealthPack.new()
	pickup.name = "Health_%s_%02d" % ["Large" if healing >= 400 else "Small", pickups.size() + 1]
	pickup.heal_amount = healing
	pickup.respawn_seconds = cooldown
	pickup.position = at
	pickup.collected.connect(_on_pickup_collected)
	arena.add_child(pickup)
	pickups.append(pickup)

func _build_spawn_gates() -> void:
	for team: int in 2:
		var z: float = 54.0 if team == 0 else -54.0
		var colour := Color("63d6eb") if team == 0 else Color("ec9f95")
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(colour, 0.12)
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = 0.5
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		for gate_index: int in 3:
			var body := StaticBody3D.new()
			body.name = "LanternSafetyGate" if team == 0 else "CrownSafetyGate"
			body.collision_layer = 4 if team == 0 else 8
			body.collision_mask = 0
			body.position = Vector3(-8 if gate_index == 0 else (8 if gate_index == 1 else 0), 2.5 if gate_index < 2 else -1.0, z)
			var size := Vector3(7.5, 5.0, 0.18) if gate_index < 2 else Vector3(6.0, 10.0, 0.18)
			var shape := BoxShape3D.new()
			shape.size = size
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
			if gate_index < 2:
				var mesh := MeshInstance3D.new()
				var plane := BoxMesh.new()
				plane.size = size
				mesh.mesh = plane
				mesh.material_override = material
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				body.add_child(mesh)
			arena.add_child(body)

func restart_match() -> void:
	if not is_instance_valid(hill):
		return
	get_tree().paused = false
	menu_open = false
	winner = -1
	if is_instance_valid(hud): hud.hit_timer = 0.0
	elapsed = 0.0
	exploration = false
	freeze_ai = false
	death_timers.clear()
	eliminations = [0, 0]
	_pickup_order = 0
	round_serial += 1
	for transient: Node in get_tree().get_nodes_in_group("transient"):
		transient.queue_free()
	player.resolver.clear_round()
	feedback.reset()
	for actor: HeroActor in actors:
		var slot: int = int(_spawn_indices.get(actor.get_instance_id(), 0))
		actor.spawn_position = definition.team_spawns(actor.team)[slot]
		actor.reset_actor(actor.spawn_position)
		actor.kit.ultimate_charge = 0.0
		actor.infinite_resources = false
		actor.invulnerable = false
		actor.spawn_protected = true
		actor.collision_mask = 11 if actor.team == 0 else 7
		actor.aim_direction = Vector3.FORWARD if actor.team == 0 else Vector3.BACK
		actor.rotation.y = 0.0 if actor.team == 0 else PI
	for pickup: CityHealthPack in pickups:
		pickup.reset()
	hill.reset()
	_update_menu_visibility()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	show_notice("MERIDIAN GARDENS  /  HILL UNLOCKS IN %d SECONDS" % int(definition.unlock_seconds), 5.0)

func respawn_actor(actor: HeroActor) -> void:
	var earned_charge: float = actor.kit.ultimate_charge
	actor.reset_actor(actor.spawn_position)
	actor.kit.ultimate_charge = earned_charge
	actor.collision_mask = 11 if actor.team == 0 else 7
	actor.spawn_protected = true
	actor.aim_direction = Vector3.FORWARD if actor.team == 0 else Vector3.BACK
	actor.rotation.y = 0.0 if actor.team == 0 else PI
	death_timers.erase(actor.get_instance_id())
	if actor == player:
		show_notice("BACK IN THE FIGHT  /  ULTIMATE CHARGE RETAINED")

func respawn_remaining(actor: HeroActor) -> float:
	if actor.alive:
		return 0.0
	return maxf(0.0, definition.respawn_seconds - float(death_timers.get(actor.get_instance_id(), 0.0)))

func spawn_contains(position: Vector3, team: int) -> bool:
	return definition.spawn_bounds(team).has_point(position)

func heal_in_spawn(actor: HeroActor, delta: float) -> void:
	if actor.alive and spawn_contains(actor.global_position, actor.team):
		actor.health = minf(actor.effective_max_health(), actor.health + SPAWN_HEAL_PER_SECOND * delta)

func is_protected(actor: HeroActor) -> bool:
	if not is_instance_valid(actor) or not actor.alive:
		return false
	# A gate breach or teleport must never let either side shoot from a safe room.
	return spawn_contains(actor.global_position, 0) or spawn_contains(actor.global_position, 1)

func available_health_pack(actor: HeroActor) -> CityHealthPack:
	var best: CityHealthPack = null
	var best_distance: float = INF
	for pickup: CityHealthPack in pickups:
		if not pickup.available:
			continue
		var distance: float = actor.global_position.distance_squared_to(pickup.global_position)
		# Avoid an underground pickup luring a surface actor through the floor.
		if absf(actor.global_position.y - pickup.global_position.y) > 3.0:
			distance += 1600.0
		if distance < best_distance:
			best_distance = distance
			best = pickup
	return best

func team_count(team: int) -> int:
	var count: int = 0
	for actor: HeroActor in actors:
		if is_instance_valid(actor) and actor.team == team and actor.alive:
			count += 1
	return count

func team_alive(team: int) -> int:
	return team_count(team)

func toggle_menu() -> void:
	menu_open = not menu_open
	get_tree().paused = menu_open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu_open else Input.MOUSE_MODE_CAPTURED
	_update_menu_visibility()

func toggle_exploration() -> void:
	exploration = not exploration
	if exploration and not player.alive:
		respawn_actor(player)
	player.invulnerable = exploration
	player.infinite_resources = exploration
	for bot: HeroActor in bots:
		bot.controller.frozen = exploration or freeze_ai
	if menu_open:
		toggle_menu()
	show_notice("EXPLORATION  /  BOTS AND MATCH CLOCK PAUSED" if exploration else "MATCH RESUMED")

func return_to_training() -> void:
	get_tree().paused = false
	menu_open = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_deferred("change_scene_to_file", "res://scenes/training/combat_sandbox.tscn")

func return_training() -> void:
	return_to_training()

func select_hero(id: String) -> void:
	HeroRoster.selected = id
	player.select_hero(id)
	player.actor_id = id.capitalize()
	for bot: HeroActor in bots:
		var slot: int = int(_spawn_indices.get(bot.get_instance_id(),0))
		bot.select_hero("slayer" if id == "slayer" and slot in [1,3] else "nimbus")
	restart_match()
	show_notice(id.to_upper() + " SELECTED / MATCH RESTARTED")

func show_notice(message: String, seconds: float = 3.0) -> void:
	notice = message
	notice_time = seconds

func _update_menu_visibility() -> void:
	if is_instance_valid(hud) and hud.has_method("sync_menu"):
		hud.call("sync_menu")

func _on_ownership_changed(team: int) -> void:
	show_notice("CONSERVATORY CAPTURED  /  " + ("LANTERN TEAM" if team == 0 else "CROWN TEAM"))

func _on_round_won(team: int) -> void:
	winner = team
	show_notice("VICTORY  /  LANTERN TEAM" if team == 0 else "ROUND COMPLETE  /  CROWN TEAM WINS", 10000.0)
	for bot: HeroActor in bots:
		bot.controller.frozen = true

func _on_pickup_collected(actor: HeroActor, amount: float) -> void:
	if actor == player:
		show_notice("MEDICAL CACHE  /  +%d HP" % int(amount), 1.8)

func _on_confirmed_hit(source: HeroActor, _target: HeroActor, amount: float, head: bool, executed: bool) -> void:
	if source == player and is_instance_valid(hud) and hud.has_method("show_hit"):
		hud.call("show_hit", amount, head, executed)

func _on_combat_event(entry: Dictionary) -> void:
	if entry.get("event", "") == "death":
		for actor: HeroActor in actors:
			if actor.actor_id == entry.get("actor", ""):
				eliminations[1 - actor.team] += 1
				break
	elif entry.get("event", "") == "block" and entry.get("actor", "") == player.actor_id:
		show_notice("PERFECT BLOCK  /  ATTACKER STAGGERED", 1.2)
