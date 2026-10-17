class_name HuddleTactics
extends RefCounted

static func apply(a: HeroActor, input: CombatIntent) -> void:
	var k := a.kit as HuddleKit
	for action: String in ["primary","primary_held","secondary_held","aim_held","hover","deflect","bomb","ultimate","melee","guard","throw_action","dash"]: input.set(action,false)
	var threat: HeroActor = CareTactics.enemy(a)
	var friend: HeroActor = CareTactics.ally(a)
	var low: bool = a.health < a.effective_max_health()*.45
	var distance: float = a.global_position.distance_to(threat.global_position) if is_instance_valid(threat) else INF
	if is_instance_valid(threat):
		input.aim = (threat.global_position+Vector3.UP*1.2-input.aim_origin).normalized()
		input.primary_held = distance < k.data().seed_range
		input.bomb = distance < k.data().pulse_radius and k.bomb_cd <= 0
		if a.state == "huddle_wave": input.move = (threat.global_position-a.global_position)*Vector3(1,0,1)
		var targets: int = 0
		for enemy: HeroActor in a.get_tree().get_nodes_in_group("actors"):
			if enemy.alive and enemy.team != a.team and a.global_position.distance_to(enemy.global_position) < 18 and a.resolver.visible(input.aim_origin,enemy,[a.get_rid()]): targets += 1
		input.ultimate = targets >= 2 and k.ultimate_charge >= 100 and not low
	# Retreat before regrouping; spend the last flight charge only to escape.
	if low and distance < 12 and k.scatter_charges > 0:
		var escape: Vector3 = (a.global_position-threat.global_position).normalized()
		escape.y = .15
		escape = escape.normalized()
		if not a.test_move(a.global_transform,escape*k.data().scatter_distance):
			input.aim = escape
			input.hover = true
			input.primary_held = false
	elif distance > 10 and distance < 20 and k.scatter_charges > 1 and not low:
		var direction: Vector3 = input.aim
		var destination: Vector3 = a.global_position+direction*k.data().scatter_distance
		if not a.test_move(a.global_transform,direction*k.data().scatter_distance) and k.supported(destination): input.hover = true
	if a.health < a.effective_max_health()*.8 and a.last_hit_age > 1.5 and distance > 10 and (k.regroup_cd <= 0 or a.state == "huddle_regroup"):
		input.secondary_held = true
		input.primary_held = false
		input.hover = false
		input.ultimate = false
		input.move = Vector3.ZERO
	input.reload = k.ammo == 0 and not input.secondary_held
	if k.deflect_cd <= 0 and not input.secondary_held:
		if is_instance_valid(friend) and friend.last_hit_age < 1.5 and a.global_position.distance_to(friend.global_position) < k.data().screen_range and a.resolver.visible(input.aim_origin,friend,[a.get_rid()]):
			input.aim = (friend.global_position+Vector3.UP*1.2-input.aim_origin).normalized()
			input.deflect = true
			input.primary_held = false
			input.hover = false
			input.ultimate = false
		elif a.last_hit_age < 1 and is_instance_valid(threat): input.deflect = true
