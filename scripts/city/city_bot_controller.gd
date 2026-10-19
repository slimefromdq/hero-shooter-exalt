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
var recovery_jump: bool = false
var care_request: CombatIntent
var rng := RandomNumberGenerator.new()
var brain: BotBrain
var decision_fresh: bool = false

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
	brain = BotBrain.new()
	brain.setup(actor,TeamDirector.obtain(match_controller,actor.team),8407+slot*103+actor.team*1009)
	BotDebugOverlay.install(match_controller)

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
	intent.aim_origin = actor.body_point(1.45)
	if not active or frozen or not actor.alive or not is_instance_valid(match_controller): return intent
	if match_controller.freeze_ai or match_controller.exploration or match_controller.winner >= 0 or not match_controller.navigation_ready: return intent
	elapsed += delta
	think_timer -= delta
	path_timer -= delta
	decision_fresh = think_timer <= 0
	if decision_fresh:
		think_timer += brain.skill.tactical_interval
		decide()
		# Adapters finish authored route/phase selection before tactical positioning.
		if not seeking_health and elapsed >= detour_until:
			destination = brain.movement.destination(brain,destination,navagent.get_navigation_map(),not entered_hill)
	if path_timer <= 0:
		path_timer += brain.skill.path_interval
		navagent.target_position = destination
		path_update_count += 1
	var move: Vector3 = follow_path()
	var recovering: bool = elapsed < detour_until and navagent.navigation_layers != 0
	if recovering:
		move = ((destination-actor.global_position)*Vector3(1,0,1)).normalized()
		if recovery_jump and actor.motor.grounded() and actor.permits("jump"):
			intent.jump = true
			recovery_jump = false
	var horizontal_distance: float = Vector2(actor.global_position.x-destination.x,actor.global_position.z-destination.z).length()
	if horizontal_distance < (.5 if recovering else 1.25) and absf(actor.global_position.y-destination.y) < 1:
		move = Vector3.ZERO
	if move.length_squared() > .01: move = avoid_wall((move+separation*.7).limit_length(1))
	intent.move = move
	brain.combat.execute(brain,intent,delta,decision_fresh)
	brain.movement.apply(brain,intent,recovering or seeking_health)
	remembered_aim = intent.aim
	brain.diagnostics.tick(delta,brain,intent)
	if brain.movement.intentional_hold and actor.global_position.distance_to(destination) < 3:
		stuck_time = 0
		sample_position = actor.global_position
		previous_position = actor.global_position
	else: watch_progress(delta,intent.move)
	return intent

func objective_context() -> Dictionary:
	return match_controller.bot_objective_context(actor.team)

func decide() -> void:
	decision_count += 1
	separation = Vector3.ZERO
	brain.decide(match_controller.actors,objective_context())
	target = brain.target_actor()
	sees_target = brain.visible_target()
	for other: HeroActor in brain.allies:
		var offset: Vector3 = actor.global_position-other.global_position
		var distance: float = offset.length()
		if distance < 1.65 and absf(offset.y) < 1.1:
			offset.y = 0
			separation += offset.normalized()*(1.65-distance)/1.65
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
	destination = hold

func follow_path() -> Vector3:
	if navagent == null or navagent.is_navigation_finished():
		return Vector3.ZERO
	var next: Vector3 = navagent.get_next_path_position()
	var direction: Vector3 = next - actor.global_position
	direction.y = 0
	return direction.normalized() if direction.length_squared() > .04 else Vector3.ZERO

func avoid_wall(move: Vector3) -> Vector3:
	move = StructureAvoidance.steer(actor,move,destination)
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
	if (movement.length_squared() > .12 or needs_travel) and travelled < 1.0 and actor.state in ["ready","reload","slayer_knife","slayer_trap","marshal_shield","huddle_regroup"]:
		stuck_time += movement_sample
		longest_stuck = maxf(longest_stuck, stuck_time)
	else:
		stuck_time = 0
		sample_position = actor.global_position
	movement_sample = 0
	if stuck_time >= 2.0:
		stuck_events += 1
		# Re-query a nearby navigable detour using ordinary walking or a checked jump.
		var map: RID = navagent.get_navigation_map()
		var tangent := Vector3(1,0,0) if slot % 2 == 0 else Vector3(-1,0,0)
		# The nearest polygon can be on the street above a stair pocket. Reject
		# physically blocked detours; prefer a checked ordinary jump back up.
		var walking_detour: Vector3 = Vector3.INF
		var jumping_detour: Vector3 = Vector3.INF
		var selected_detour: Vector3 = Vector3.INF
		recovery_jump = false
		for direction: Vector3 in [tangent,-tangent,Vector3.FORWARD,Vector3.BACK,(tangent+Vector3.FORWARD).normalized(),(tangent+Vector3.BACK).normalized(),(-tangent+Vector3.FORWARD).normalized(),(-tangent+Vector3.BACK).normalized()]:
			var detour: Vector3 = NavigationServer3D.map_get_closest_point(map,actor.global_position+direction*3)
			if actor.global_position.distance_to(detour) < 1.5: continue
			var needs_jump: bool = actor.test_move(actor.global_transform,detour-actor.global_position)
			if needs_jump:
				if not actor.permits("jump"): continue
				var clearance: float = maxf(.8,detour.y-actor.global_position.y+.15)
				var apex: float = actor.tuning.jump_impulse*actor.tuning.jump_impulse/(2*actor.tuning.gravity)
				if clearance > apex-.1 or actor.test_move(actor.global_transform,Vector3.UP*clearance): continue
				var raised: Transform3D = actor.global_transform
				raised.origin.y += clearance
				if actor.test_move(raised,detour-raised.origin): continue
			if needs_jump and jumping_detour == Vector3.INF: jumping_detour = detour
			if needs_jump and detour.y-actor.global_position.y > .5:
				selected_detour = detour
				recovery_jump = true
				break
			if not needs_jump and walking_detour == Vector3.INF: walking_detour = detour
		if selected_detour == Vector3.INF: selected_detour = walking_detour
		if selected_detour == Vector3.INF and jumping_detour != Vector3.INF:
			selected_detour = jumping_detour
			recovery_jump = true
		if selected_detour != Vector3.INF:
			destination = selected_detour
			detour_until = elapsed+1.5
		stuck_time = 0
		sample_position = actor.global_position

func reset_controller() -> void:
	if brain != null: brain.reset()
	care_request = null
	target = null
	health_target = null
	sees_target = false
	seeking_health = false
	detour_until = 0
	recovery_jump = false
	stuck_time = 0
	movement_sample = 0
	previous_position = actor.global_position
	sample_position = actor.global_position
	think_timer = float(slot % 5) * .04
	path_timer = .15
	combat_timer = .7
	load_route()

func _exit_tree() -> void:
	if brain != null:
		brain.diagnostics.detach()
		if is_instance_valid(brain.director): brain.director.release(actor)
	if is_instance_valid(navagent): navagent.queue_free()
