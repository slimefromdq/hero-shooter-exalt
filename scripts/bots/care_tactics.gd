class_name CareTactics
extends RefCounted

static func ally(a: HeroActor) -> HeroActor:
	var best: HeroActor
	var score: float = -INF
	for other: HeroActor in a.get_tree().get_nodes_in_group("actors"):
		if other == a or not other.alive or other.team != a.team or a.resolver.protected_room(other): continue
		var distance: float = a.global_position.distance_to(other.global_position)
		if distance > 35: continue
		var priority: float = (1.0 - other.health / other.effective_max_health()) * 100 - distance
		if other.kit is MarshalKit: priority += 5
		if priority > score:
			score = priority
			best = other
	return best

static func enemy(a: HeroActor) -> HeroActor:
	var best: HeroActor
	var distance: float = 35
	for other: HeroActor in a.get_tree().get_nodes_in_group("actors"):
		if other.team == a.team or not other.alive or a.resolver.protected_room(other): continue
		var d: float = a.global_position.distance_to(other.global_position)
		if d < distance and a.resolver.visible(a.global_position + Vector3.UP,other,[a.get_rid()]):
			best = other
			distance = d
	return best

static func apply(a: HeroActor, input: CombatIntent) -> void:
	if not a.kit is CareKit: return
	if a.kit is ExpansionKit:
		RosterTactics.apply(a,input)
		return
	if a.kit is HuddleKit:
		HuddleTactics.apply(a,input)
		return
	input.aim_held = false
	input.primary = false
	input.primary_held = false
	input.secondary_held = false
	input.hover = false
	input.deflect = false
	input.bomb = false
	input.ultimate = false
	input.melee = false
	input.guard = false
	input.throw_action = false
	input.reload = a.kit.ammo == 0
	var threat: HeroActor = enemy(a)
	if a.kit is DoctorKit:
		var patient: HeroActor = ally(a)
		var k := a.kit as DoctorKit
		if is_instance_valid(patient):
			input.aim = (patient.global_position + Vector3.UP * 1.2 - input.aim_origin).normalized()
			var distance: float = a.global_position.distance_to(patient.global_position)
			input.secondary_held = patient.health < patient.effective_max_health() and distance <= k.data().beam_range
			if distance < 8 and not a.controller is CityBotController: input.move = Vector3.ZERO
			var injured: int = 0
			for other: HeroActor in a.get_tree().get_nodes_in_group("actors"):
				if other.alive and other.team == a.team and other.health < other.effective_max_health() - 25 and a.global_position.distance_to(other.global_position) < k.data().ward_radius: injured += 1
			input.deflect = injured >= 2 or a.health < a.effective_max_health() * .5
			input.bomb = not patient.statuses.effects.is_empty() or patient.health < patient.effective_max_health() * .35
			input.hover = (a.last_hit_age < 1.5 or (is_instance_valid(threat) and a.global_position.distance_to(threat.global_position) < 5)) and distance > 5
			input.ultimate = k.ultimate_charge >= 100 and not patient.benefits.has_kind("exemplary") and is_instance_valid(threat) and patient.global_position.distance_to(threat.global_position) < 15
		if not input.secondary_held and not input.bomb and not input.ultimate and not input.hover and is_instance_valid(threat):
			input.aim = (threat.global_position + Vector3.UP * 1.1 - input.aim_origin).normalized()
			input.primary_held = true
		if is_instance_valid(threat) and a.global_position.distance_to(threat.global_position) < 5:
			input.move = (a.global_position - threat.global_position).normalized()
	else:
		if not is_instance_valid(threat): return
		var k := a.kit as MarshalKit
		var distance: float = a.global_position.distance_to(threat.global_position)
		input.aim = (threat.global_position + Vector3.UP * 1.1 - input.aim_origin).normalized()
		input.secondary_held = distance > 9 and (a.last_hit_age < 1.5 or threat.intent.primary or threat.intent.primary_held) and k.barrier_hp > 100
		input.primary_held = not input.secondary_held and distance < 25
		input.deflect = rally_worthwhile(a)
		var forward: Vector3 = ((threat.global_position-a.global_position)*Vector3(1,0,1)).normalized()
		input.hover = distance > 3 and distance < 18 and k.mobility_cd <= 0 and marshal_safe_lane(a,forward,k.data().march_range)
		if a.state == "marshal_march":
			if not marshal_safe_lane(a,k.march_direction,k.march_left): k.finish_march(false)
			input.move = forward if marshal_safe_lane(a,forward,k.march_left) else Vector3.ZERO
		input.bomb = distance > 8 and distance < 22 and k.bomb_cd <= 0 and MarshalOrbitalTargeting.can_strike(a,input.aim,threat.body_point(.9))
		input.ultimate = distance < k.data().verdict_range - .5 and k.ultimate_charge >= 100 and marshal_verdict_safe(a,forward)

static func marshal_safe_lane(a: HeroActor, direction: Vector3, distance: float) -> bool:
	if direction.is_zero_approx(): return false
	var shape := CapsuleShape3D.new()
	shape.radius = .4
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,a.global_position+Vector3.UP*1.02)
	query.collision_mask = 1
	query.motion = direction*distance
	if not a.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	var sweep: PackedFloat32Array = a.get_world_3d().direct_space_state.cast_motion(query)
	if sweep[0] < .99: return false
	# Check the whole lane: a safe endpoint alone can hide an intervening pit.
	for index: int in int(ceil(distance/.75))+1:
		var at: Vector3 = a.global_position+direction*minf(distance,index*.75)
		var floor_hit: Dictionary = a.resolver.ray(at+Vector3.UP,at+Vector3.DOWN*2,[],1)
		if floor_hit.is_empty() or floor_hit.normal.y < cos(a.floor_max_angle): return false
		var session: Node = a.get_tree().get_first_node_in_group("city_match")
		if session != null and session.definition.spawn_bounds(1-a.team).has_point(at): return false
	return true

static func marshal_verdict_safe(a: HeroActor, direction: Vector3) -> bool:
	var t := a.tuning as MarshalTuning
	var rise: float = t.verdict_jump_speed*t.verdict_jump_speed/(2*a.tuning.gravity)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = a.motor.body_collision.shape
	query.transform = a.motor.body_collision.global_transform
	query.collision_mask = 1
	query.motion = Vector3.UP*(rise+.2)
	if a.get_world_3d().direct_space_state.cast_motion(query)[0] < .99: return false
	return marshal_safe_lane(a,direction,t.verdict_forward_range)

static func rally_worthwhile(a: HeroActor) -> bool:
	if not a.kit is MarshalKit: return false
	var kit := a.kit as MarshalKit
	if kit.deflect_cd > 0 or not kit.rally_allowed(): return false
	var credible: bool = false
	for opponent: HeroActor in a.get_tree().get_nodes_in_group("actors"):
		if not opponent.alive or opponent.team == a.team or a.resolver.protected_room(opponent): continue
		var distance: float = a.global_position.distance_to(opponent.global_position)
		if distance > 20 or not a.resolver.visible(a.body_point(1.2),opponent,[a.get_rid()]): continue
		if distance < 10 or a.last_hit_age < 1.5 or opponent.intent.primary or opponent.intent.primary_held or opponent.kit.ultimate_active():
			credible = true
			break
	if not credible: return false
	for ally: HeroActor in a.get_tree().get_nodes_in_group("actors"):
		if ally == a or not kit.rally_recipient(ally): continue
		if ally.overhealth.can_grant(a) and ally.overhealth.value() < kit.data().rally_ally_overhealth: return true
	return a.health < a.effective_max_health()*.55 and a.last_hit_age < 1.5 and a.overhealth.can_grant(a) and a.overhealth.value() < kit.data().rally_self_overhealth
