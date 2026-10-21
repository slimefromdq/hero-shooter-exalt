class_name TempleMatch
extends CityMatch
static var selected_side: int = 0
static var start_exploring: bool = false
var objective := TempleObjective.new()
var stages: Array[int] = [0,0]
var occupancy: Array = [[0,0],[0,0],[0,0],[0,0],[0,0]]
var _preparing: bool = true

func temple_definition() -> TempleMapDefinition:
	return definition as TempleMapDefinition

func fall_kill_height() -> float:
	return TempleMapDefinition.KILL_HEIGHT

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_session")
	add_to_group("city_match")
	add_to_group("temple_match")
	# Compatibility landmark for shared diagnostics; never runs KOTH scoring.
	hill = CityHill.new()
	hill.definition = definition
	add_child(hill)
	actors.append(player)
	_spawn_indices[player.get_instance_id()] = 0
	_build_pickups()
	_spawn_teams()
	hud = TempleHUD.new()
	hud.match_controller = self
	add_child(hud)
	feedback = MatchFeedback.new()
	feedback.player = player
	add_child(feedback)
	player.resolver.confirmed_hit.connect(_on_confirmed_hit)
	player.resolver.event_logged.connect(_on_combat_event)
	player.resolver.elimination.connect(feedback.on_elimination)
	objective.point_captured.connect(_point_captured)
	objective.round_ended.connect(_finish)
	restart_match()
	if start_exploring or "--explore" in OS.get_cmdline_user_args(): toggle_exploration()
	start_exploring = false

func _spawn_teams() -> void:
	for team: int in 2:
		for slot: int in 6:
			if team == player.team and slot == 0: continue
			var actor := preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
			actor.team = team
			actor.actor_id = "%s_%02d" % ["root" if team == 0 else "cloud",slot+1]
			actor.tuning = HeroRoster.tuning_for(HeroRoster.team_hero(slot,HeroRoster.selected))
			actor.position = definition.team_spawns(team)[slot]
			arena.add_child(actor)
			var controller := TempleBotController.new()
			controller.actor = actor
			controller.match_controller = self
			controller.role = HeroRoster.bot_role(slot,HeroRoster.selected)
			controller.slot = slot
			actor.add_child(controller)
			actor.controller = controller
			actors.append(actor)
			bots.append(actor)
			_spawn_indices[actor.get_instance_id()] = slot

func _build_pickups() -> void:
	for at: Vector3 in definition.small_pack_positions: _add_pickup(arena.builder.floor_position(at)+Vector3.UP*.1,75,10)
	for at: Vector3 in definition.large_pack_positions: _add_pickup(arena.builder.floor_position(at)+Vector3.UP*.1,400,15)

func restart_match() -> void:
	stages = [0,0]
	objective.reset()
	_preparing = true
	super.restart_match()
	for actor: HeroActor in actors: _orient(actor)
	arena.builder.update_gates(stages,true)
	_sync_point_labels()
	show_notice("SAKURA VEIL / FIVE POINTS / MID OPENS IN 20 SECONDS",5)

func _physics_process(delta: float) -> void:
	if menu_open: return
	_nav_check_timer -= delta
	if not navigation_ready and _nav_check_timer <= 0:
		_nav_check_timer = .25
		var region: NavigationRegion3D = arena.navigation_region
		var map: RID = arena.get_world_3d().navigation_map
		navigation_ready = region.navigation_mesh.get_polygon_count() > 0 and NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_closest_point_owner(map,definition.team_spawns(0)[0]) == region.get_rid()
		if navigation_ready:
			for actor: HeroActor in actors: actor.kit.ultimate_charge = 0
	notice_time = maxf(0,notice_time-delta)
	for actor: HeroActor in actors:
		actor.spawn_protected = is_protected(actor)
		heal_in_spawn(actor,delta)
		if actor != player:
			actor.controller.frozen = freeze_ai or exploration or objective.finished or not navigation_ready or objective.preparation_remaining > 0
	if exploration:
		if not player.alive: respawn_actor(player)
		return
	if objective.finished or not navigation_ready: return
	elapsed += delta
	occupancy = objective_occupancy()
	objective.advance(delta,occupancy)
	if _preparing and objective.preparation_remaining <= 0:
		_preparing = false
		arena.builder.update_gates(stages,false)
		show_notice("SKYBELL CROSSING UNLOCKED / CAPTURE C",4)
	for actor: HeroActor in actors:
		if actor.alive: continue
		var key: int = actor.get_instance_id()
		death_timers[key] = float(death_timers.get(key,0))+delta
		if death_timers[key] >= definition.respawn_seconds: respawn_actor(actor)
	for pickup: CityHealthPack in pickups:
		if not pickup.available: continue
		for offset: int in actors.size():
			var actor: HeroActor = actors[(_pickup_order+offset)%actors.size()]
			if actor.alive and absf(actor.global_position.y-pickup.global_position.y) < 1.5 and actor.global_position.distance_to(pickup.global_position) < 1.55:
				if pickup.try_collect(actor): break
	_pickup_order = (_pickup_order+1)%actors.size()

func objective_occupancy() -> Array:
	var result: Array = [[0,0],[0,0],[0,0],[0,0],[0,0]]
	for actor: HeroActor in actors:
		if not actor.objective_eligible() or is_protected(actor): continue
		for index: int in 5:
			if temple_definition().contains_point(index,actor.global_position): result[index][actor.team] += 1
	return result

func _point_captured(index: int, team: int) -> void:
	_sync_point_labels()
	show_notice("%s SECURED / %s / +2:00" % [String.chr(65+index),"ROOT TEAM" if team == 0 else "CLOUD TEAM"],4)
	var old: Array[int] = stages.duplicate()
	stages = [objective.spawn_stage(0),objective.spawn_stage(1)]
	for actor: HeroActor in actors:
		var team_index: int = actor.team
		actor.spawn_position = temple_definition().spawns(team_index,stages[team_index])[int(_spawn_indices[actor.get_instance_id()])]
		if old[team_index] != stages[team_index] and temple_definition().room_bounds(team_index,old[team_index]).has_point(actor.global_position):
			actor.motor.interrupt_mobility()
			actor.global_position = actor.spawn_position
			actor.velocity = Vector3.ZERO
			_orient(actor)
		if actor.controller is TempleBotController: actor.controller.invalidate_route()
	arena.builder.update_gates(stages,false)

func _sync_point_labels() -> void:
	for index: int in arena.builder.point_labels.size():
		var team: int = objective.owners[index]
		arena.builder.point_labels[index].modulate = Color("63d6eb") if team == 0 else (Color("ec9f95") if team == 1 else Color("ffe3b0"))

func _finish(team: int) -> void:
	# 2 denotes a finished draw to the existing session/combat lock interface.
	super._on_round_won(team if team >= 0 else 2)
	show_notice("STALEMATE / THE TEMPLE HOLDS ITS SECRETS" if team < 0 else ("ROOT TEAM VICTORY" if team == 0 else "CLOUD TEAM VICTORY"),10000)

func respawn_actor(actor: HeroActor) -> void:
	super.respawn_actor(actor)
	_orient(actor)

func apply_pending_hero() -> void:
	super.apply_pending_hero()
	_orient(player)

func _orient(actor: HeroActor) -> void:
	actor.rotation.y = 0 if actor.team == 0 else PI
	actor.aim_direction = Vector3.FORWARD if actor.team == 0 else Vector3.BACK
	if actor.controller is PlayerController: actor.controller.yaw = actor.rotation.y

func spawn_contains(at: Vector3, team: int) -> bool:
	return temple_definition().room_bounds(team,stages[team]).has_point(at)

func is_protected(actor: HeroActor) -> bool:
	return is_instance_valid(actor) and actor.alive and spawn_contains(actor.global_position,actor.team)

func enforce_spawn_exclusion(actor: HeroActor, before: Vector3) -> void:
	var enemy: AABB = temple_definition().room_bounds(1-actor.team,stages[1-actor.team])
	if not enemy.has_point(actor.global_position) and enemy.intersects_segment(before,actor.global_position) == null: return
	actor.motor.interrupt_mobility()
	actor.motor.external_velocity = Vector3.ZERO
	actor.velocity = Vector3.ZERO
	actor.global_position = before if not enemy.has_point(before) else temple_definition().room_center(1-actor.team,stages[1-actor.team])+Vector3(0,.1,12 if actor.team == 0 else -12)

func goal_index(team: int) -> int:
	# Reinforce an actively threatened owned point before pushing the next one.
	for index: int in 5:
		if objective.owners[index] == team and objective.eligible(index,1-team) and occupancy[index][1-team] > 0: return index
	return objective.target(team)

func bot_objective_context(team: int) -> Dictionary:
	var index: int = goal_index(team)
	return {"position":temple_definition().POINTS[index],"radius":18.0,"phase":"temple_%d_%d" % [round_serial,index],"urgency":1.0 if objective.overtime or occupancy[index][1-team] > 0 else .7,"secured":objective.owners[index] == team and occupancy[index][1-team] == 0}
