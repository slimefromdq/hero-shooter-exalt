class_name SamsonTactics
extends RefCounted

static func choice(a: HeroActor, enemy: HeroActor, nearby_enemies: int) -> Dictionary:
	var k := a.kit as SamsonKit
	if a.state != "ready" or not a.alive: return {}
	var profile: BotHeroProfile = BotHeroProfile.for_hero("samson")
	var patient: HeroActor
	var need: float = -INF
	var pressured: int = 0
	for ally: HeroActor in a.get_tree().get_nodes_in_group("actors"):
		if not ally.alive or ally.team != a.team or a.resolver.protected_room(ally): continue
		var health: float = ally.health/ally.effective_max_health()
		var pressure: bool = ally.last_hit_age < profile.pressure_window
		if (health < profile.rescue_health or pressure) and ally.global_position.distance_to(a.global_position) < k.data().court_radius: pressured += 1
		if ally == a or not k.target_valid(ally,ally.life_serial,true,k.data().intervene_range): continue
		var offset: Vector3 = ally.global_position-a.global_position
		if a.test_move(a.global_transform,offset.normalized()*maxf(0,offset.length()-k.data().intervene_stop)): continue
		if health >= profile.rescue_health and not pressure: continue
		var threatened: bool = is_instance_valid(enemy) and ally.global_position.distance_to(enemy.global_position) < profile.diver_range
		if k.charges <= profile.escape_reserve and health >= profile.emergency_health and not threatened: continue
		var score: float = (1-health)*100+(20 if pressure else 0)+(20 if threatened else 0)-a.global_position.distance_to(ally.global_position)
		if score > need:
			need = score
			patient = ally
	if is_instance_valid(patient) and k.charges > 0 and a.permits("intervene"):
		return {"action":"hover","score":.98,"point":patient.body_point(1.2)}
	if not is_instance_valid(enemy): return {}
	var distance: float = a.global_position.distance_to(enemy.global_position)
	var flat: Vector3 = (enemy.global_position-a.global_position)*Vector3(1,0,1)
	var ground: Vector3 = a.global_position+flat.normalized()*profile.court_offset
	var floor_hit: Dictionary = a.resolver.ray(ground+Vector3.UP*3,ground-Vector3.UP*6,[],1)
	if not floor_hit.is_empty(): ground = floor_hit.position
	if k.ultimate_charge >= 100 and not k.ultimate_active() and ((pressured >= 2 and nearby_enemies > 0) or (pressured >= 1 and nearby_enemies >= 2)) and SamsonCourt.placement_clear(a,ground,a.rotation.y):
		return {"action":"ultimate","score":.94,"point":ground}
	if k.deflect_cd <= 0 and a.permits("deflect") and not enemy.statuses.stunned() and not enemy.statuses.silenced() and k.target_valid(enemy,enemy.life_serial,false,k.data().cross_range):
		if enemy.last_hit_age < profile.pressure_window or distance < profile.threat_range or enemy.motor.mode in ["dash","dash_windup","hover","hover_ascent"] or enemy.state.begins_with("melee"):
			return {"action":"deflect","score":.85,"point":enemy.body_point(1.2)}
	if k.bomb_cd <= 0 and a.permits("bomb") and distance < profile.threat_range:
		ground = enemy.global_position
		floor_hit = a.resolver.ray(ground+Vector3.UP*2,ground-Vector3.UP*4,[],1)
		if not floor_hit.is_empty(): ground = floor_hit.position
		return {"action":"bomb","score":.75,"point":ground}
	return {}

static func apply(a: HeroActor, input: CombatIntent) -> void:
	for action: String in ["primary","primary_held","secondary_held","secondary_pressed","hover","deflect","bomb","ultimate","melee","guard","throw_action"]: input.set(action,false)
	if a.state.begins_with("samson_"): return
	var enemy: HeroActor = CareTactics.enemy(a)
	var selected: Dictionary = choice(a,enemy,1 if is_instance_valid(enemy) else 0)
	if not selected.is_empty():
		input.aim = (Vector3(selected.point)-input.aim_origin).normalized()
		input.set(selected.action,true)
	elif is_instance_valid(enemy):
		input.aim = (enemy.body_point(1.2)-input.aim_origin).normalized()
		input.primary_held = true
	input.reload = a.kit.ammo == 0

