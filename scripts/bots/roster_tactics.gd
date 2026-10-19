class_name RosterTactics
extends RefCounted

static func safe_step(a: HeroActor, direction: Vector3) -> bool:
	var end: Vector3 = a.global_position+direction*(a.tuning as WispTuning).step_distance
	if a.test_move(a.global_transform,end-a.global_position): return false
	var ground: Dictionary = a.resolver.ray(end+Vector3.UP*2,end-Vector3.UP*7,[a.get_rid()],1)
	if ground.is_empty() or ground.normal.y < .85: return false
	var city: Node = a.get_tree().get_first_node_in_group("city_match")
	if city != null and city.definition.spawn_bounds(1-a.team).has_point(end): return false
	return true

static func apply(a: HeroActor, input: CombatIntent) -> void:
	if a.kit is SamsonKit:
		SamsonTactics.apply(a,input)
		return
	for action: String in ["primary","primary_held","secondary_held","secondary_pressed","aim_held","hover","deflect","bomb","ultimate","melee","guard","throw_action"]: input.set(action,false)
	input.reload = a.kit.ammo == 0
	var enemy: HeroActor = CareTactics.enemy(a)
	var friend: HeroActor = CareTactics.ally(a)
	if is_instance_valid(enemy):
		input.aim = (enemy.body_point(1.2)-input.aim_origin).normalized()
		input.primary_held = true
	var distance: float = a.global_position.distance_to(enemy.global_position) if is_instance_valid(enemy) else INF
	if a.kit is RelayKit:
		var k := a.kit as RelayKit
		if is_instance_valid(k.recipient) and k.battery < 22 and not k.ultimate_active(): input.bomb = true
		elif k.transfer_cd <= 0 and (k.battery >= 55 or k.ultimate_active()) and is_instance_valid(friend) and friend.health < friend.effective_max_health()*.85:
			if k.recipient != friend and a.resolver.attack_ray(a,a.body_point(1.4),friend.body_point(1.2),[],1).is_empty():
				input.aim = (friend.body_point(1.2)-input.aim_origin).normalized()
				input.secondary_pressed = true
		elif not is_instance_valid(k.recipient) and a.health < a.effective_max_health()*.55 and k.battery >= 40: input.bomb = true
		if is_instance_valid(enemy):
			input.deflect = enemy.body_point(1).distance_to(k.drone_position()) < k.data().shock_radius and k.battery >= 45
			input.hover = distance < 7 and a.health < a.effective_max_health()*.6 and k.mobility_cd <= 0
			if input.hover: input.move = ((a.global_position-enemy.global_position)*Vector3(1,0,1)).normalized()
		var allies: int = 0
		for other: HeroActor in a.get_tree().get_nodes_in_group("actors"):
			if other.alive and other.team == a.team and other.global_position.distance_to(k.drone_position()) < k.data().circuit_radius: allies += 1
		input.ultimate = is_instance_valid(enemy) and allies >= 2 and k.ultimate_charge >= 100
	elif a.kit is DynamoKit:
		var k := a.kit as DynamoKit
		if k.previewing:
			var point: Vector3 = a.get_meta("bot_wall_target",a.global_position+a.aim_direction*8)
			input.aim = (point-input.aim_origin).normalized()
			input.primary = true
			input.primary_held = false
			return
		if not is_instance_valid(enemy): return
		input.secondary_held = distance < 35
		input.hover = distance < 30 and k.mobility_cd <= 0
		input.bomb = distance > 5 and distance < k.data().stone_range and k.bomb_cd <= 0
		input.ultimate = distance < k.data().storm_range and k.ultimate_charge >= 100
		if input.bomb or input.ultimate: input.aim = (enemy.global_position+Vector3.UP*.05-input.aim_origin).normalized()
		if a.health < a.effective_max_health()*.65 and distance > 12 and k.deflect_cd <= 0 and not is_instance_valid(k.wall):
			var point: Vector3 = a.global_position+(enemy.global_position-a.global_position).normalized()*8
			a.set_meta("bot_wall_target",point)
			input.aim = (point-input.aim_origin).normalized()
			input.deflect = true
	elif a.kit is WispKit:
		var k := a.kit as WispKit
		if not is_instance_valid(enemy): return
		if a.state == "wisp_ballet": return
		input.secondary_pressed = k.shells > 0 and enemy.statuses.soul_count(a) >= 3 and distance < k.data().shotgun_range
		input.deflect = distance < 12 and a.health < a.effective_max_health()*.45 and k.deflect_cd <= 0
		input.ultimate = distance < 20 and k.ultimate_charge >= 100
		if a.state == "ready" and k.steps > 0 and k.shells < k.data().shell_limit and distance > 8 and distance < 23:
			var direction: Vector3 = (enemy.global_position-a.global_position).normalized()
			if safe_step(a,direction):
				input.hover = true
				input.aim = direction
		input.bomb = distance < 16 and a.motor.grounded() and k.bomb_cd <= 0 and a.resolver.ray(a.body_point(2),a.body_point(6),[a.get_rid()],1).is_empty()
		input.jump_held = k.glide_left > 0
