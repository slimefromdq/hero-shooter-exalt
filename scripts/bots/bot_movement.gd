class_name BotMovement
extends RefCounted
var selected_position: Vector3 = Vector3.ZERO
var position_timer: float = -1
var side: float = 1.0
var strafe_until: float = 0.0
var query_count: int = 0
var intentional_hold: bool = false
var traversal_check_at: float = 0.0
var mantle_until: float = 0.0
var last_query: Dictionary = {}
var last_candidates: Array = []
var locomotion := BotLocomotion.new()

func destination(brain: BotBrain, fallback: Vector3, map: RID, route_pending: bool) -> Vector3:
	var a: HeroActor = brain.actor
	if brain.now < position_timer: return selected_position
	intentional_hold = false
	position_timer = brain.now+.4
	if selected_position == Vector3.ZERO: selected_position = fallback
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0:
		selected_position = fallback
		return fallback
	# While still travelling an authored route, only a nearby visible fight diverts the bot.
	var gathering: bool = brain.tactical_state == "regroup" and brain.team_order in ["group_up","fall_back"]
	# Travelling an authored route, only a fight in reach (or one met at the waypoint)
	# diverts the bot; spotting someone far across the map does not stop it walking.
	var fight_in_reach: bool = brain.visible_target() and (a.global_position.distance_to(Vector3(brain.threat.position)) <= brain.hero_profile.maximum_range+4.0 or a.global_position.distance_to(fallback) < 8.0)
	if route_pending and not fight_in_reach and not gathering:
		selected_position = fallback
		return fallback
	if brain.perception.incoming_thread:
		selected_position = a.global_position
		intentional_hold = true
		return selected_position
	var query: Dictionary = TacticalQuery.plan(brain,fallback)
	if query.mode == "travel":
		selected_position = fallback
		return fallback
	var result: Dictionary = TacticalQuery.select(brain,query,map,self)
	last_query = query
	last_candidates = result.candidates
	var best: Vector3 = result.point
	if best == Vector3.INF: best = fallback
	if best.distance_to(a.global_position) > 2:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map,a.global_position,best,true)
		query_count += 1
		if path.is_empty() or path[-1].distance_to(best) > 1.5: best = fallback
	elif brain.visible_target():
		intentional_hold = true
	selected_position = best
	if is_instance_valid(brain.director): brain.director.reserve(a,best,brain.now)
	return best

func safe_travel(a: HeroActor, direction: Vector3, distance: float, rise: float = 0.0) -> bool:
	if direction.is_zero_approx(): return false
	var motion: Vector3 = direction.normalized()*distance
	if not RedThread.constrain(a,motion).is_equal_approx(motion): return false
	if a.test_move(a.global_transform,motion): return false
	var end: Vector3 = a.global_position+motion
	var floor_hit: Dictionary = a.resolver.ray(end+Vector3.UP*maxf(1,rise),end-Vector3.UP*3,[a.get_rid()],1)
	query_count += 1
	if floor_hit.is_empty() or floor_hit.normal.y < .7: return false
	var session: Node = a.get_tree().get_first_node_in_group("city_match")
	return session == null or not session.definition.spawn_bounds(1-a.team).has_point(end)

func apply(brain: BotBrain, input: CombatIntent, recovering: bool) -> void:
	if recovering and brain.actor.state not in ["marshal_march","marshal_verdict"]: return
	var a: HeroActor = brain.actor
	if a.kit is WispKit and a.state == "wisp_phase":
		input.move = RosterTactics.wisp_escape(a,brain.threat.get("position",a.global_position-a.global_basis.z*5))
		return
	if a.state in ["marshal_march","marshal_verdict"]:
		input.move = Vector3.ZERO
		var marshal_kit := a.kit as MarshalKit
		if a.state == "marshal_march" and not CareTactics.marshal_safe_lane(a,marshal_kit.march_direction,marshal_kit.march_left):
			marshal_kit.finish_march(false)
			return
		if not brain.threat.is_empty():
			var toward: Vector3 = ((Vector3(brain.threat.position)-a.global_position)*Vector3(1,0,1)).normalized()
			if a.state == "marshal_march" and CareTactics.marshal_safe_lane(a,toward,marshal_kit.march_left):
				input.move = toward
		return
	if a.state in ["slayer_boot_start","slayer_boot_active"]:
		if not brain.threat.is_empty(): input.move = ((brain.threat.position-a.global_position)*Vector3(1,0,1)).normalized()
		return
	if a.state == "huddle_wave":
		if not brain.threat.is_empty(): input.move = (brain.threat.position-a.global_position)*Vector3(1,0,1)
		return
	locomotion.apply(brain,self,input)
	if input.move.length() > .5 and a.state == "ready":
		# Shared traversal probes determine whether a held mantle or wall kick is legal.
		if brain.level >= 2 and not a.motor.grounded() and a.velocity.y > 0: input.jump_held = true
		if brain.level >= 2 and brain.now >= traversal_check_at:
			traversal_check_at = brain.now+.35
			var forward: Vector3 = input.move.normalized()
			var wall: Dictionary = a.resolver.ray(a.body_point(.5),a.body_point(.5)+forward*.9,[a.get_rid()],1)
			query_count += 1
			if not wall.is_empty() and absf(wall.normal.y) < .2:
				var over: Vector3 = wall.position-wall.normal*.55
				var top: Dictionary = a.resolver.ray(Vector3(over.x,a.global_position.y+a.tuning.mantle_height+.1,over.z),Vector3(over.x,a.global_position.y+.25,over.z),[a.get_rid()],1)
				query_count += 1
				if not top.is_empty() and top.normal.y > .85 and selected_position.y > a.global_position.y+.5:
					input.jump = a.motor.grounded()
					mantle_until = brain.now+.35
				elif not a.motor.grounded() and a.motor.traversal.wall_cooldown <= 0 and safe_travel(a,wall.normal,1.5):
					input.jump = true
		if brain.now < mantle_until: input.jump_held = true

func reset() -> void:
	locomotion.reset()
	selected_position = Vector3.ZERO
	last_query = {}
	last_candidates = []
	position_timer = -1
	strafe_until = 0
	intentional_hold = false
	traversal_check_at = 0
	mantle_until = 0
