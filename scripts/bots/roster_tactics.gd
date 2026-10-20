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
	if a.kit is StitchKit:
		# Stitch training uses the perception-driven tactical controller.
		input.primary_held = is_instance_valid(enemy) and not a.concealed()
		return
	if a.kit is RelayKit:
		var k := a.kit as RelayKit
		if is_instance_valid(friend) and k.can_assign(friend) and (not is_instance_valid(k.recipient) or friend.health < friend.effective_max_health()*.65):
			input.aim = (friend.body_point(1.2)-input.aim_origin).normalized()
			input.bomb = true
		elif not is_instance_valid(k.recipient) and a.health < a.effective_max_health()*.6:
			input.aim = Vector3.UP
			input.bomb = true
		input.deflect = k.valid_friend(k.recipient,k.recipient_life) and k.recipient.health < k.recipient.effective_max_health()*.75
		if is_instance_valid(enemy) and not input.bomb:
			input.aim = (enemy.body_point(1.2)+enemy.velocity*distance/k.data().arrow_speed-input.aim_origin).normalized()
			input.hover = k.mobility_cd <= 0
			input.secondary_pressed = not k.volley_charging and k.volley_cd <= 0 and k.shot_cd <= 0
			input.secondary_held = input.secondary_pressed or k.volley_charging and k.volley_age < k.data().volley_charge
		var allies: int = 0
		for other: HeroActor in a.get_tree().get_nodes_in_group("actors"):
			if k.valid_friend(other) and k.sight(other) and other.health < other.effective_max_health()*.85: allies += 1
		input.ultimate = is_instance_valid(enemy) and allies >= 2 and k.ultimate_charge >= 100 and not k.ultimate_active()
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
		if a.state == "wisp_phase":
			wisp_flight(a,input,enemy.global_position)
			return
		wisp_air_controls(a,input,a.health < a.effective_max_health()*.45)
		input.secondary_pressed = k.shells > 0 and (enemy.statuses.soul_count(a) >= 3 or enemy.health+enemy.shields+enemy.overhealth.value() <= k.estimated_burst(distance,enemy.statuses.soul_count(a))) and distance < k.data().burst_range
		input.deflect = distance < 12 and a.health < a.effective_max_health()*.45 and k.deflect_cd <= 0
		input.ultimate = distance < k.data().heist_range and k.ultimate_charge >= 100 and enemy.statuses.soul_count(a) >= 2
		if input.ultimate: input.aim = (enemy.body_point(1)+enemy.velocity*(distance/k.data().heist_speed+k.data().heist_warning)*.6-input.aim_origin).normalized()
		if a.state == "ready" and k.steps > 0 and k.shells < k.data().shell_limit and distance > 5 and distance < k.data().burst_range:
			var direction: Vector3 = (enemy.global_position-a.global_position).cross(Vector3.UP).normalized()
			if safe_step(a,direction):
				input.hover = true
				input.aim = direction
		input.bomb = input.bomb or distance < 16 and a.motor.grounded() and k.bomb_cd <= 0 and safe_step(a,(enemy.global_position-a.global_position)*Vector3(1,0,1)) and a.resolver.ray(a.body_point(2),a.body_point(6),[a.get_rid()],1).is_empty()
		input.jump_held = k.glide_left > 0

static func wisp_escape(a: HeroActor, threat: Vector3) -> Vector3:
	var away: Vector3 = ((a.global_position-threat)*Vector3(1,0,1)).normalized()
	if away.is_zero_approx(): away = a.global_basis.z
	var best: Vector3 = Vector3.ZERO
	var score: float = -INF
	for direction: Vector3 in [away,away.rotated(Vector3.UP,PI/3),away.rotated(Vector3.UP,-PI/3)]:
		var at: Vector3 = a.global_position+direction*.8
		if a.test_move(a.global_transform,direction*.8): continue
		var ground: Dictionary = a.resolver.ray(at+Vector3.UP,at-Vector3.UP*7,[a.get_rid()],1)
		if ground.is_empty() or ground.normal.y < .7: continue
		var city: Node = a.get_tree().get_first_node_in_group("city_match")
		if city != null and city.definition.spawn_bounds(1-a.team).has_point(at): continue
		var covered: bool = not a.resolver.attack_ray(a,at+Vector3.UP,threat+Vector3.UP,[a.get_rid()],1).is_empty()
		var value: float = at.distance_to(threat)+(3.0 if covered else 0.0)
		if value > score:
			score = value
			best = direction
	return best

static func wisp_safe_landing(a: HeroActor) -> bool:
	var hit: Dictionary = a.resolver.ray(a.body_point(.1),a.global_position-Vector3.UP*18,[a.get_rid()],1)
	if hit.is_empty() or hit.normal.y < .85: return false
	var at: Vector3 = hit.position
	var city: Node = a.get_tree().get_first_node_in_group("city_match")
	if city != null and city.definition.spawn_bounds(1-a.team).has_point(at): return false
	return true

static func wisp_air_controls(a: HeroActor, input: CombatIntent, escaping: bool) -> void:
	var k := a.kit as WispKit
	input.jump_held = k.leap_active and k.glide_left > 0
	if k.leap_active and not k.diving and a.velocity.y <= 0 and (escaping or k.glide_left < .4) and wisp_safe_landing(a): input.bomb = true

static func wisp_flight(a: HeroActor, input: CombatIntent, threat: Vector3) -> void:
	var direction: Vector3 = wisp_escape(a,threat)
	# Rise gently only with overhead clearance; never climb over an unlandable void.
	if not direction.is_zero_approx() and a.motor.grounded(): direction += Vector3.UP*.5
	direction = direction.normalized()
	if a.test_move(a.global_transform,direction*.7): direction = Vector3.ZERO
	input.flight_move = direction
	input.move = direction*Vector3(1,0,1)

static func stitch_surface(a: HeroActor, toward: Vector3) -> Vector3:
	var flat: Vector3 = (toward-a.global_position)*Vector3(1,0,1)
	# Probe above prey for walls, then a floor point before prey. Never hook actors.
	var points: Array[Vector3] = [toward+Vector3.UP*3,a.global_position+flat.normalized()*minf(flat.length()*.7,(a.tuning as StitchTuning).hook_range*.7)]
	for point: Vector3 in points:
		var direction: Vector3 = (point-a.body_point(1)).normalized()
		var hit: Dictionary = a.resolver.attack_ray(a,a.body_point(1),a.body_point(1)+direction*(a.tuning as StitchTuning).hook_range,[a.get_rid()])
		if hit.is_empty() or hit.get("collider") is HeroActor or hit.get("collider") is CombatStructure or hit.get("collider") is CombatBarrier: continue
		return hit.position
	return Vector3.INF
