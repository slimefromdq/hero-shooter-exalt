class_name MuseumMatch
extends CityMatch
signal phase_changed(phase: String)
signal checkpoint_reached(index: int)
signal spawn_stage_changed(attacker: int, defender: int)
signal round_ended(team: int)
static var selected_side: int = 0
static var start_exploring: bool = false
var objective := MuseumObjective.new()
var payload: MuseumPayload
var phase: String:
	get: return objective.phase
var capture_progress: float:
	get: return objective.capture_progress
var payload_distance: float:
	get: return objective.payload_distance
var checkpoint_index: int:
	get: return objective.checkpoint_index
var time_remaining: float:
	get: return objective.time_remaining
var overtime: bool:
	get: return objective.overtime
var occupancy: Array[int] = [0,0]

func museum_definition() -> MuseumMapDefinition:
	return definition as MuseumMapDefinition

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("game_session")
	add_to_group("city_match")
	add_to_group("museum_match")
	objective.definition = museum_definition()
	objective.phase_changed.connect(_phase_change)
	objective.checkpoint_reached.connect(_checkpoint)
	objective.round_ended.connect(_finish)
	# Kept only for compatibility with shared city tactics; never advances/scorers.
	hill = CityHill.new()
	hill.definition = definition
	add_child(hill)
	actors.append(player)
	_spawn_indices[player.get_instance_id()] = 0
	_build_pickups()
	_spawn_teams()
	payload = MuseumPayload.new()
	payload.session = self
	arena.add_child(payload)
	hud = MuseumHUD.new()
	hud.match_controller = self
	add_child(hud)
	player.resolver.confirmed_hit.connect(_on_confirmed_hit)
	player.resolver.event_logged.connect(_on_combat_event)
	feedback = MatchFeedback.new()
	feedback.player = player
	add_child(feedback)
	player.resolver.elimination.connect(feedback.on_elimination)
	restart_match()
	if start_exploring: toggle_exploration()

func _spawn_teams() -> void:
	for team: int in 2:
		for slot: int in 6:
			if team == player.team and slot == 0: continue
			var actor := preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
			actor.team = team
			actor.actor_id = "%s_%02d" % ["attack" if team == 0 else "defend",slot+1]
			actor.tuning = HeroRoster.tuning_for(HeroRoster.team_hero(slot,HeroRoster.selected))
			actor.position = definition.team_spawns(team)[slot]
			arena.add_child(actor)
			var controller := MuseumBotController.new()
			controller.actor = actor
			controller.match_controller = self
			controller.role = HeroRoster.bot_role(slot,HeroRoster.selected)
			controller.slot = slot
			actor.add_child(controller)
			actor.controller = controller
			actors.append(actor)
			bots.append(actor)
			_spawn_indices[actor.get_instance_id()] = slot

func restart_match() -> void:
	museum_definition().attacker_stage = 0
	museum_definition().defender_stage = 0
	objective.reset()
	super.restart_match()
	for actor: HeroActor in actors: _orient(actor)
	payload.reset_cart()
	occupancy = [0,0]
	arena.builder.update_gates(true)
	phase_changed.emit("preparation")
	spawn_stage_changed.emit(0,0)
	show_notice("MERIDIAN MUSEUM  /  SECURE THE ASTROLABE, ESCORT THE ARTIFACT",6)

func _physics_process(delta: float) -> void:
	if menu_open: return
	if not navigation_ready:
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
			actor.controller.frozen = freeze_ai or exploration or winner >= 0 or not navigation_ready or (phase == "preparation" and actor.team == 0)
	if not navigation_ready or exploration or winner >= 0: return
	elapsed += delta
	occupancy = objective_occupancy()
	objective.advance(delta,occupancy[0],occupancy[1])
	payload.move_to_distance(payload_distance)
	for actor: HeroActor in actors:
		if actor.alive: continue
		var key: int = actor.get_instance_id()
		death_timers[key] = float(death_timers.get(key,0))+delta
		if death_timers[key] >= definition.respawn_seconds: respawn_actor(actor)
	for pickup: CityHealthPack in pickups:
		if not pickup.available: continue
		for offset: int in actors.size():
			var actor: HeroActor = actors[(_pickup_order+offset)%actors.size()]
			var diff: Vector3 = actor.global_position-pickup.global_position
			if actor.alive and absf(diff.y) <= 1.5 and Vector2(diff.x,diff.z).length() <= 1.55:
				if pickup.try_collect(actor): break
	_pickup_order = (_pickup_order+1)%actors.size()

func objective_occupancy() -> Array[int]:
	var result: Array[int] = [0,0]
	for actor: HeroActor in actors:
		if not actor.objective_eligible() or is_protected(actor): continue
		if phase == "capture":
			var at: Vector3 = actor.global_position-definition.hill_center
			if absf(at.x) <= definition.hill_half_extents.x and absf(at.z) <= definition.hill_half_extents.z and at.y >= definition.hill_min_height and at.y <= definition.hill_max_height: result[actor.team] += 1
		elif phase == "escort":
			var diff: Vector3 = actor.global_position-payload.global_position
			if Vector2(diff.x,diff.z).length() > museum_definition().escort_radius or absf(diff.y) > museum_definition().escort_height: continue
			if player.resolver.ray(actor.body_point(1),payload.global_position+Vector3.UP,[actor.get_rid(),payload.get_rid()],1).is_empty(): result[actor.team] += 1
	return result

func respawn_actor(actor: HeroActor) -> void:
	super.respawn_actor(actor)
	_orient(actor)

func apply_pending_hero() -> void:
	var changed: bool = pending_hero != ""
	super.apply_pending_hero()
	if changed: _orient(player)

func _orient(actor: HeroActor) -> void:
	# Face the authored doors, including the east-facing admissions spawn.
	actor.aim_direction = Vector3.BACK.rotated(Vector3.UP,museum_definition().spawn_yaw(actor.team))
	actor.rotation.y = PI+museum_definition().spawn_yaw(actor.team)
	if actor.controller is PlayerController:
		actor.controller.yaw = actor.rotation.y

func _phase_change(next: String) -> void:
	if next == "escort":
		_relocate(1,1)
		show_notice("ASTROLABE SECURED  /  PAYLOAD UNLOCKED  /  +3:00",5)
	elif next == "capture": show_notice("ATTACK BEGINS  /  CAPTURE THE ASTROLABE",4)
	arena.builder.update_gates(false)
	phase_changed.emit(next)

func _checkpoint(index: int) -> void:
	if index == 1: _relocate(2,2)
	elif index == 2: _relocate(3,2)
	show_notice("CHECKPOINT %d  /  +1:30" % index if index < 3 else "ARTIFACT DELIVERED",4)
	checkpoint_reached.emit(index)

func _relocate(attack: int, defend: int) -> void:
	var old_bounds: Array[AABB] = [definition.spawn_bounds(0),definition.spawn_bounds(1)]
	var old_stages: Array[int] = [museum_definition().attacker_stage,museum_definition().defender_stage]
	var new_stages: Array[int] = [attack,defend]
	museum_definition().attacker_stage = attack
	museum_definition().defender_stage = defend
	for actor: HeroActor in actors:
		var at: Vector3 = definition.team_spawns(actor.team)[int(_spawn_indices[actor.get_instance_id()])]
		actor.spawn_position = at
		if actor.alive and old_stages[actor.team] != new_stages[actor.team] and old_bounds[actor.team].has_point(actor.global_position):
			actor.motor.interrupt_mobility()
			actor.motor.external_velocity = Vector3.ZERO
			actor.motor.slide_velocity = Vector3.ZERO
			actor.motor.jump_buffer = 0
			actor.motor.coyote = 0
			if actor.controller is PlayerController: actor.controller.clear_action_queue()
			actor.global_position = at
			actor.velocity = Vector3.ZERO
			_orient(actor)
		actor.spawn_protected = is_protected(actor)
	arena.builder.update_gates(phase == "preparation")
	spawn_stage_changed.emit(attack,defend)

func toggle_exploration() -> void:
	super.toggle_exploration()
	# Exploration freezes preparation too, so its own spawn doors must open.
	arena.builder.update_gates(phase == "preparation" and not exploration)

func _finish(team: int) -> void:
	_on_round_won(team)
	show_notice("ARTIFACT DELIVERED  /  ATTACK VICTORY" if team == 0 else "MUSEUM SECURED  /  DEFENSE VICTORY",10000)
	round_ended.emit(team)

func track_intersects(bounds: AABB) -> bool:
	# Conservative swept track corridor; includes cart width and hero clearance.
	var points: Array[Vector3] = museum_definition().payload_path
	var lock_distance: float = museum_definition().checkpoint_distances()[checkpoint_index-1] if checkpoint_index > 0 else 0.0
	var covered: float = 0
	for index: int in range(1,points.size()):
		var a: Vector3 = points[index-1]
		var b: Vector3 = points[index]
		var length: float = a.distance_to(b)
		if covered+length >= lock_distance:
			a = a.lerp(b,clampf((lock_distance-covered)/length,0,1))
			var minimum: Vector3 = a.min(b)-Vector3(2.5,.2,2.5)
			var maximum: Vector3 = a.max(b)+Vector3(2.5,3.5,2.5)
			if AABB(minimum,maximum-minimum).intersects(bounds): return true
		covered += length
	return false

func is_protected(actor: HeroActor) -> bool:
	return is_instance_valid(actor) and actor.alive and spawn_contains(actor.global_position,actor.team)

func spawn_attack_locked(actor: HeroActor) -> bool:
	# Prep keeps attackers behind closed doors. Released spawns allow firing out.
	return phase == "preparation" and actor.team == 0 and not exploration

func enforce_spawn_exclusion(actor: HeroActor, before: Vector3) -> void:
	var enemy: AABB = definition.spawn_bounds(1-actor.team)
	if not enemy.has_point(actor.global_position) and enemy.intersects_segment(before,actor.global_position) == null: return
	actor.motor.interrupt_mobility()
	actor.motor.external_velocity = Vector3.ZERO
	actor.velocity = Vector3.ZERO
	if not enemy.has_point(before):
		actor.global_position = before
	else:
		# Recover invalid placements as well as ability relocations, without giving immunity.
		var yaw: float = museum_definition().spawn_yaw(1-actor.team)
		actor.global_position = definition.spawn_center(1-actor.team)+Vector3(0,.08,6.5).rotated(Vector3.UP,yaw)

func active_objective_position() -> Vector3:
	return payload.global_position if phase == "escort" else definition.hill_center

func active_objective_caption() -> String:
	if phase == "escort":
		return ("ESCORT" if player.team == 0 else "STOP PAYLOAD")+" / CP%d" % mini(3,checkpoint_index+1)
	return "CAPTURE A" if player.team == 0 else "DEFEND A"

func bot_objective_context(team: int) -> Dictionary:
	return {"position":active_objective_position(),"radius":6.0 if phase == "escort" else 9.0,
		"phase":phase+str(checkpoint_index),"urgency":1.0 if overtime or occupancy[1-team] > 0 else .6,"secured":occupancy[team] > 0 and occupancy[1-team] == 0,
		"desperate":overtime or (team == 0 and time_remaining < 30.0)}
