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

func destination(brain: BotBrain, fallback: Vector3, map: RID, route_pending: bool) -> Vector3:
	var a: HeroActor = brain.actor
	intentional_hold = false
	if brain.now < position_timer: return selected_position
	position_timer = brain.now+.4
	selected_position = fallback
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) == 0: return fallback
	var state: String = brain.tactical_state
	var goal: Vector3 = fallback
	if state in ["retreat","regroup"]:
		var away: Vector3 = a.global_position-Vector3(brain.threat.get("position",a.global_position-a.aim_direction))
		goal = a.global_position+away.normalized()*7
		if not brain.allies.is_empty(): goal = brain.allies[0].global_position+away.normalized()*3
	elif state == "support" and is_instance_valid(brain.patient):
		var back: Vector3 = a.global_position-brain.patient.global_position
		goal = brain.patient.global_position+back.normalized()*7
	elif state == "investigate" and not brain.threat.is_empty():
		if Vector3(brain.threat.position).distance_to(brain.context.position) < 18: goal = brain.threat.position
	elif not brain.threat.is_empty() and brain.visible_target() and (not route_pending or a.global_position.distance_to(fallback) < 8):
		var enemy: Vector3 = brain.threat.position
		var away: Vector3 = (a.global_position-enemy)*Vector3(1,0,1)
		var distance: float = away.length()
		var desired: float = (brain.hero_profile.minimum_range+brain.hero_profile.maximum_range)*.5
		if state == "commit": desired = brain.hero_profile.minimum_range
		if state == "protect" and is_instance_valid(brain.patient): goal = brain.patient.global_position+(enemy-brain.patient.global_position).normalized()*3
		elif distance < brain.hero_profile.minimum_range or distance > brain.hero_profile.maximum_range or state in ["flank","commit"]:
			goal = enemy+away.normalized().rotated(Vector3.UP,.45*side if state == "flank" else 0.0)*desired
		else:
			goal = a.global_position
			intentional_hold = true
		if goal.distance_to(brain.context.position) > 19 and state not in ["retreat","support"]: goal = fallback
	if brain.perception.incoming_thread:
		goal = a.global_position
	# Small bounded cover/angle sample; authored routes remain the strategic fallback.
	var best_score: float = -INF
	var best: Vector3 = fallback
	for offset: Vector3 in [Vector3.ZERO,Vector3(2,0,0),Vector3(-2,0,0),Vector3(0,0,2),Vector3(0,0,-2)]:
		var wanted: Vector3 = goal+offset
		var point: Vector3 = NavigationServer3D.map_get_closest_point(map,wanted)
		query_count += 1
		if point.distance_to(wanted) > 1.5: continue
		var session: Node = a.get_tree().get_first_node_in_group("city_match")
		if session != null and session.definition.spawn_bounds(1-a.team).has_point(point): continue
		var score: float = -point.distance_to(goal)*.2
		if is_instance_valid(brain.director) and brain.director.reserved(point,a.get_instance_id()): score -= 1.2
		if not brain.threat.is_empty():
			var threat_at: Vector3 = brain.perception.thread_anchor if brain.perception.incoming_thread else Vector3(brain.threat.position)
			var blocked: bool = not a.resolver.attack_ray(a,point+Vector3.UP*1.45,threat_at+Vector3.UP,[a.get_rid()],1).is_empty()
			query_count += 1
			score += (1.2 if blocked else -.7) if brain.perception.incoming_thread else (.8 if blocked else -.3) if state in ["retreat","regroup","support"] else (.3 if not blocked else -.3)
		if score > best_score:
			best_score = score
			best = point
	if best.distance_to(a.global_position) > 2:
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map,a.global_position,best,true)
		query_count += 1
		if path.is_empty() or path[-1].distance_to(best) > 1.5: best = fallback
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
	if brain.visible_target() and brain.tactical_state not in ["retreat","regroup","support"] and input.move.length() < .2:
		if brain.now >= strafe_until:
			strafe_until = brain.now+brain.rng.randf_range(.65,1.6)
			side = -1 if brain.rng.randf() < .5 else 1
		var toward: Vector3 = (brain.threat.position-a.global_position)*Vector3(1,0,1)
		var strafe: Vector3 = toward.normalized().cross(Vector3.UP)*side
		if safe_travel(a,strafe,1.1): input.move = strafe*.6
		intentional_hold = true
	# Reactions require an acquired, locally seen attack tell.
	if brain.ready_to_attack() and str(brain.threat.state) in ["melee_windup","ultimate","slayer_axe"] and brain.now > strafe_until-.3:
		if safe_travel(a,input.move,3):
			input.jump = a.motor.grounded() and brain.level >= 2
	if input.move.length() > .5 and a.state == "ready":
		if brain.tactical_state == "retreat" and brain.hero_profile.mobility > .5 and a.motor.can_dash() and safe_travel(a,input.move,a.tuning.dash_speed*a.tuning.dash_duration):
			input.dash = input.aim.dot(input.move.normalized()) > cos(deg_to_rad(8))
			input.primary = false
			input.primary_held = false
		elif brain.level >= 2 and a.velocity.length() >= a.tuning.slide_entry_speed and brain.tactical_state in ["retreat","flank"] and safe_travel(a,input.move,2):
			input.slide = true
			input.slide_pressed = not a.intent.slide
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
	position_timer = -1
	strafe_until = 0
	intentional_hold = false
	traversal_check_at = 0
	mantle_until = 0
