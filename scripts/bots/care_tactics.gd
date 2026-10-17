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
		input.deflect = a.health < a.effective_max_health() * .55 and a.last_hit_age < 2
		input.hover = distance > 2 and distance < 6 and k.mobility_cd <= 0
		input.bomb = distance > 8 and distance < 22 and k.bomb_cd <= 0
		input.ultimate = distance < k.data().verdict_range - .5 and k.ultimate_charge >= 100
