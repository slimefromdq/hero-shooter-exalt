class_name CityBotController
extends Node
## City participants use the same intent, ammunition, cooldowns and damage rules as the player.
## Only tactical selection is throttled. Movement and navigation following run every physics tick.

var actor: HeroActor
var match_controller: Node
var role: String = "frontline"
var slot: int = 0
var active: bool = true
var frozen: bool = false
var navagent: NavigationAgent3D
var target: HeroActor
var destination: Vector3
var remembered_aim: Vector3 = Vector3.FORWARD
var route: Array[Vector3] = []
var route_index: int = 0
var think_timer: float = 0.0
var path_timer: float = 0.0
var combat_timer: float = 0.0
var elapsed: float = 0.0
var stuck_time: float = 0.0
var longest_stuck: float = 0.0
var stuck_events: int = 0
var recovery_warps: int = 0
var decision_count: int = 0
var path_update_count: int = 0
var distance_travelled: float = 0.0
var previous_position: Vector3
var sample_position: Vector3
var movement_sample: float = 0.0
var separation: Vector3 = Vector3.ZERO
var sees_target: bool = false
var seeking_health: bool = false
var health_target: Node3D
var entered_hill: bool = false
var detour_until: float = 0.0
var care_request: CombatIntent
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 8407 + slot * 103 + actor.team * 1009
	think_timer = float(slot % 5) * .04
	path_timer = float(slot % 6) * .08
	combat_timer = .7 + float(slot % 4) * .12
	previous_position = actor.global_position
	sample_position = previous_position
	remembered_aim = Vector3.FORWARD if actor.team == 0 else Vector3.BACK
	navagent = NavigationAgent3D.new()
	navagent.name = "CityNavigationAgent"
	navagent.path_desired_distance = .6
	navagent.target_desired_distance = 1.1
	navagent.path_height_offset = 0.0
	navagent.radius = .48
	navagent.height = 1.9
	navagent.max_speed = actor.tuning.ground_speed
	navagent.avoidance_enabled = false
	actor.add_child(navagent)
	load_route()

func load_route() -> void:
	route.clear()
	if is_instance_valid(match_controller) and match_controller.definition != null:
		var route_role: String = role
		for point: Vector3 in match_controller.definition.route_points(actor.team, route_role):
			route.append(point)
	route_index = 0
	destination = route[0] if not route.is_empty() else Vector3.ZERO
	entered_hill = false

func gather_intent(delta: float) -> CombatIntent:
	var intent := CombatIntent.new()
	intent.aim = remembered_aim
	intent.aim_origin = actor.global_position + Vector3.UP * 1.45
	if not active or frozen or not actor.alive or not is_instance_valid(match_controller):
		return intent
	if match_controller.freeze_ai or match_controller.exploration or match_controller.winner >= 0:
		return intent
	if not match_controller.navigation_ready:
		return intent
	elapsed += delta
	think_timer -= delta
	path_timer -= delta
	combat_timer -= delta
	if think_timer <= 0.0:
		think_timer += .2
		decide()
		if actor.kit is CareKit:
			care_request = CombatIntent.new()
			care_request.aim_origin = actor.global_position + Vector3.UP * 1.45
			CareTactics.apply(actor,care_request)
		if actor.kit is DoctorKit:
			var patient: HeroActor = CareTactics.ally(actor)
			if is_instance_valid(patient):
				var back: Vector3 = (actor.global_position - patient.global_position).normalized()
				destination = patient.global_position + back * 5
	if path_timer <= 0.0:
		path_timer += .5
		navagent.target_position = destination
		path_update_count += 1
	var move := follow_path()
	var horizontal_distance: float = Vector2(actor.global_position.x - destination.x, actor.global_position.z - destination.z).length()
	if horizontal_distance < 1.25 and absf(actor.global_position.y - destination.y) < 1.0:
		move = Vector3.ZERO
	# Separation only steers locally; strategic paths remain on the baked pedestrian mesh.
	if move.length_squared() > .01:
		move = (move + separation * .7).limit_length(1.0)
		move = avoid_wall(move)
	intent.move = move
	if is_instance_valid(target) and target.alive and sees_target and not actor.spawn_protected and not target.spawn_protected:
		var offset: Vector3 = target.global_position - actor.global_position
		var distance: float = offset.length()
		intent.aim = remembered_aim
		# Close attacks retain their normal forward commitment. Guarding responds to an actual tell.
		if distance < 3.5 and target.state in ["melee_windup", "melee_active"] and actor.close.guard_meter > 30:
			intent.guard = true
		elif actor.close.incoming_throw() != null and rng.randf() > .45:
			intent.throw_action = true
		elif combat_timer <= 0.0:
			if distance < 4.7 and actor.permits("melee") and target.health <= actor.tuning.melee_damage:
				intent.melee = true
				combat_timer = .9
			elif distance < 2.5 and rng.randf() < .28 and actor.permits("throw"):
				intent.throw_action = true
				combat_timer = 1.4
			elif distance < 35.0:
				intent.primary = true
				combat_timer = .72 + rng.randf_range(0.0, .22)
				if actor.kit.ammo == 0:
					intent.reload = true
			if distance > 9 and distance < 25 and actor.kit.bomb_cd <= 0 and rng.randf() < .10:
				intent.bomb = true
			if actor.kit.deflect_cd <= 0 and actor.health < actor.tuning.max_health * .55 and rng.randf() < .15:
				intent.deflect = true
			if actor.kit.ultimate_charge >= 100 and target.health / target.tuning.max_health <= .20:
				intent.ultimate = true
			if actor.kit is SlayerKit:
				var hunter := actor.kit as SlayerKit
				intent.primary = distance < 21.0
				intent.hover = distance > 10 and distance < 25 and hunter.knives > 0
				intent.deflect = distance > 4 and distance < 13 and hunter.deflect_cd <= 0
				intent.bomb = distance < 13 and hunter.snares > 0 and rng.randf() < .22
				intent.ultimate = distance < 14 and hunter.ultimate_charge >= 100
	else:
		if move.length_squared() > .03:
			intent.aim = move.normalized()
		if actor.kit.ammo < actor.tuning.magazine and actor.state == "ready":
			intent.reload = true
	if actor.kit is CareKit and care_request != null:
		for action: String in ["aim","primary","primary_held","secondary_held","aim_held","reload","hover","deflect","bomb","ultimate","melee","guard","throw_action"]:
			intent.set(action,care_request.get(action))
		if not care_request.move.is_zero_approx(): intent.move = avoid_wall(care_request.move)
	watch_progress(delta, intent.move)
	return intent

func decide() -> void:
	decision_count += 1
	separation = Vector3.ZERO
	var best: HeroActor = null
	var best_score: float = INF
	var origin: Vector3 = actor.global_position + Vector3.UP * 1.45
	for other: HeroActor in match_controller.actors:
		if other == actor or not other.alive:
			continue
		var offset: Vector3 = actor.global_position - other.global_position
		var distance: float = offset.length()
		if distance < 1.65 and absf(offset.y) < 1.1:
			offset.y = 0
			separation += offset.normalized() * (1.65 - distance) / 1.65
		if other.team == actor.team or other.spawn_protected or distance > 42:
			continue
		if distance < best_score and actor.resolver.visible(origin, other, [actor.get_rid()]):
			best = other
			best_score = distance
	target = best
	sees_target = is_instance_valid(target)
	if sees_target:
		var error := Vector3(rng.randf_range(-.55,.55), rng.randf_range(-.25,.25), rng.randf_range(-.55,.55))
		remembered_aim = (target.global_position + Vector3.UP * 1.1 + error - origin).normalized()
	if elapsed < detour_until:
		return
	seeking_health = false
	if actor.health / actor.effective_max_health() < .4:
		health_target = match_controller.available_health_pack(actor)
		if is_instance_valid(health_target):
			seeking_health = true
			destination = health_target.global_position
			return
	health_target = null
	if not route.is_empty() and not entered_hill:
		if actor.global_position.distance_to(route[route_index]) < 2.2:
			route_index += 1
			if route_index >= route.size():
				entered_hill = true
				route_index = route.size() - 1
		if not entered_hill:
			destination = route[route_index]
			return
	# Positions on the ring distribute the whole team, keeping four entrances open.
	var lane: int = slot % 6
	var hill_points: Array[Vector3] = [Vector3(-6,.05,-5),Vector3(6,.05,5),Vector3(-6,.05,5),Vector3(6,.05,-5),Vector3(-2,.05,6),Vector3(2,.05,-6)]
	var hold: Vector3 = hill_points[(lane + actor.team * 3) % hill_points.size()]
	if role == "high_ground" and match_controller.hill.owner_team == actor.team and not match_controller.hill.contested:
		hold = Vector3(23.0 if actor.team == 0 else -23.0,6.5,10.0 if actor.team == 0 else -10.0)
	# A short push closes only when finishing a weak enemy; bots do not abandon the objective to chase spawns.
	if sees_target and target.health < actor.tuning.melee_damage and actor.global_position.distance_to(target.global_position) < 6:
		destination = target.global_position
	else:
		destination = hold

func follow_path() -> Vector3:
	if navagent == null or navagent.is_navigation_finished():
		return Vector3.ZERO
	var next: Vector3 = navagent.get_next_path_position()
	var direction: Vector3 = next - actor.global_position
	direction.y = 0
	return direction.normalized() if direction.length_squared() > .04 else Vector3.ZERO

func avoid_wall(move: Vector3) -> Vector3:
	if move.length_squared() < .01:
		return move
	var origin: Vector3 = actor.global_position + Vector3.UP * .6
	var hit: Dictionary = actor.resolver.ray(origin, origin + move.normalized() * 1.05, [actor.get_rid()], 1)
	if not hit.is_empty():
		var normal: Vector3 = hit.normal
		if absf(normal.y) < .5:
			var tangent: Vector3 = move.slide(normal)
			if tangent.length_squared() < .05:
				tangent = Vector3(normal.z,0,-normal.x) * (1.0 if slot % 2 == 0 else -1.0)
			return tangent.normalized()
	return move

func watch_progress(delta: float, movement: Vector3) -> void:
	distance_travelled += actor.global_position.distance_to(previous_position)
	previous_position = actor.global_position
	movement_sample += delta
	if movement_sample < .5:
		return
	var travelled: float = actor.global_position.distance_to(sample_position)
	# A zero steering vector can itself be the failure: a refreshed path or local
	# separation can leave the actor stationary while its requested goal is far away.
	var needs_travel: bool = actor.global_position.distance_to(destination) > 2.0
	# Measure net progress from a stable anchor. Half-second back-and-forth motion
	# used to reset the watchdog forever even when a crowded actor made no progress.
	if (movement.length_squared() > .12 or needs_travel) and travelled < 1.0 and actor.state in ["ready","reload"]:
		stuck_time += movement_sample
		longest_stuck = maxf(longest_stuck, stuck_time)
	else:
		stuck_time = 0
		sample_position = actor.global_position
	movement_sample = 0
	if stuck_time >= 2.0:
		stuck_events += 1
		# Re-query a nearby navigable detour rather than granting teleport or parkour movement.
		var map: RID = navagent.get_navigation_map()
		var tangent := Vector3(1,0,0) if slot % 2 == 0 else Vector3(-1,0,0)
		var detour: Vector3 = NavigationServer3D.map_get_closest_point(map, actor.global_position + tangent * 3)
		if actor.global_position.distance_to(detour) > .8:
			destination = detour
			detour_until = elapsed + 1.5
		stuck_time = 0
		sample_position = actor.global_position

func reset_controller() -> void:
	care_request = null
	target = null
	health_target = null
	sees_target = false
	seeking_health = false
	detour_until = 0
	stuck_time = 0
	movement_sample = 0
	previous_position = actor.global_position
	sample_position = actor.global_position
	think_timer = float(slot % 5) * .04
	path_timer = .15
	combat_timer = .7
	load_route()
