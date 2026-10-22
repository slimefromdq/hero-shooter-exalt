class_name TacticalQuery
extends RefCounted
## Environment query for "where should I stand?". Candidates are sampled on a ring shaped
## by the bot's goal, snapped to the navmesh and scored with simple considerations:
## range band, line of sight (wanted when shooting, avoided when reloading or hurt, which
## produces natural peek/hide cycles), cover from other enemies, height, team spacing,
## the team danger map, objective leash, travel cost and hysteresis.

const CANDIDATES: int = 14

## Builds the sampling plan for the current tactical state.
static func plan(brain: BotBrain, fallback: Vector3) -> Dictionary:
	var a: HeroActor = brain.actor
	var state: String = brain.tactical_state
	var has_threat: bool = not brain.threat.is_empty()
	var threat_at: Vector3 = BotPerception.predicted(brain.threat,brain.now) if has_threat else Vector3.INF
	var desired: float = (brain.hero_profile.minimum_range+brain.hero_profile.maximum_range)*.5
	var result: Dictionary = {"mode":"objective","center":fallback,"inner":0.0,"outer":5.0,"bearing":Vector3.ZERO,"arc":PI,"desired":desired,"threat":threat_at,"wants_los":true}
	var ammo_fraction: float = float(a.kit.ammo)/maxf(1,float(a.tuning.magazine))
	var hurt: bool = a.health < a.effective_max_health()*.5 and a.last_hit_age < 1.5
	var needs_cover: bool = a.kit.reloading or (ammo_fraction < .2 and a.tuning.magazine > 1) or hurt
	if state == "regroup" and brain.team_order in ["group_up","fall_back"] and is_instance_valid(brain.director) and brain.director.gather_point != Vector3.INF:
		result.mode = "gather"
		result.center = brain.director.gather_point
		result.inner = 0.0
		result.outer = 5.0
		result.wants_los = false
		if has_threat: result.bearing = ((brain.director.gather_point-threat_at)*Vector3(1,0,1)).normalized()
		result.arc = PI*.8
	elif state in ["retreat","regroup"]:
		result.mode = "retreat"
		result.center = a.global_position
		result.inner = 5.0
		result.outer = 12.0
		result.wants_los = false
		if has_threat: result.bearing = ((a.global_position-threat_at)*Vector3(1,0,1)).normalized()
		if not brain.allies.is_empty():
			var nearest: HeroActor = brain.allies[0]
			for ally: HeroActor in brain.allies:
				if ally.global_position.distance_to(a.global_position) < nearest.global_position.distance_to(a.global_position): nearest = ally
			result.center = nearest.global_position
			result.inner = 2.0
			result.outer = 6.0
		result.arc = PI*.6
	elif state == "support" and is_instance_valid(brain.patient):
		result.mode = "support"
		result.center = brain.patient.global_position
		result.inner = 4.0
		result.outer = 9.0
		result.wants_los = false
		if has_threat: result.bearing = ((brain.patient.global_position-threat_at)*Vector3(1,0,1)).normalized()
		result.arc = PI*.7
	elif state == "protect" and is_instance_valid(brain.patient) and has_threat:
		result.mode = "protect"
		result.center = brain.patient.global_position
		result.inner = 1.5
		result.outer = 4.0
		result.bearing = ((threat_at-brain.patient.global_position)*Vector3(1,0,1)).normalized()
		result.arc = PI*.35
	elif state == "investigate" and has_threat:
		result.mode = "investigate"
		result.center = threat_at
		result.inner = 1.0
		result.outer = clampf(BotPerception.uncertainty(brain.threat,brain.now),3.0,8.0)
	elif has_threat and (brain.visible_target() or brain.now-float(brain.threat.seen) < 2.5):
		result.mode = "cover" if needs_cover else "fight"
		result.center = threat_at
		result.inner = brain.hero_profile.minimum_range
		result.outer = brain.hero_profile.maximum_range
		if state == "commit":
			result.inner = maxf(1.5,brain.hero_profile.minimum_range*.6)
			result.outer = maxf(result.inner+2,desired)
			result.desired = brain.hero_profile.minimum_range
		result.bearing = ((a.global_position-threat_at)*Vector3(1,0,1)).normalized()
		result.arc = PI*(.75 if state == "flank" else .4)
		var objective: Vector3 = brain.context.get("position",fallback)
		var radius: float = float(brain.context.get("radius",7.0))
		if state in ["contest","hold"] and fallback.distance_to(objective) <= radius+6.0:
			# Contesting means fighting from the objective, not from max range.
			result.mode = "contest"
			result.center = objective
			result.inner = 0.0
			result.outer = radius+1.0
			result.bearing = ((threat_at-objective)*Vector3(1,0,1)).normalized()
			result.arc = PI
		if state == "flank": result.bearing = result.bearing.rotated(Vector3.UP,brain.movement.side*PI*.35)
		if needs_cover:
			result.center = a.global_position
			result.inner = 1.0
			result.outer = 5.0
			result.wants_los = false
	if result.mode == "objective":
		# Authored waypoints must be reached exactly; only spread out once at the objective.
		var objective: Vector3 = brain.context.get("position",fallback)
		if fallback.distance_to(objective) > float(brain.context.get("radius",7.0))+6.0: result.mode = "travel"
		elif not brain.threat.is_empty(): result.bearing = ((fallback-threat_at)*Vector3(1,0,1)).normalized()
	return result

static func select(brain: BotBrain, query: Dictionary, map: RID, movement: BotMovement) -> Dictionary:
	var a: HeroActor = brain.actor
	var rng: RandomNumberGenerator = brain.rng
	var points: Array[Vector3] = [a.global_position,movement.selected_position]
	var center: Vector3 = query.center
	for index: int in CANDIDATES:
		var angle: float = rng.randf_range(-float(query.arc),float(query.arc))
		var base: Vector3 = query.bearing if not Vector3(query.bearing).is_zero_approx() else Vector3.FORWARD.rotated(Vector3.UP,rng.randf()*TAU)
		var radius: float = lerpf(float(query.inner),float(query.outer),sqrt(rng.randf()))
		points.append(center+base.rotated(Vector3.UP,angle)*radius)
	var session: Node = a.get_tree().get_first_node_in_group("city_match")
	var objective: Vector3 = brain.context.get("position",center)
	var leash: float = float(brain.context.get("radius",7.0))+14.0
	var others: Array[Vector3] = []
	for id: int in brain.perception.visible_ids:
		if id != brain.target_id and brain.perception.observations.has(id) and others.size() < 2:
			others.append(brain.perception.observations[id].position)
	var best: Vector3 = Vector3.INF
	var best_score: float = -INF
	var scored: Array = []
	for wanted: Vector3 in points:
		if wanted == Vector3.INF or wanted == Vector3.ZERO: continue
		var point: Vector3 = NavigationServer3D.map_get_closest_point(map,wanted)
		movement.query_count += 1
		if Vector2(point.x-wanted.x,point.z-wanted.z).length() > 1.5: continue
		if session != null and session.definition.spawn_bounds(1-a.team).has_point(point): continue
		if str(query.mode) in ["fight","contest","cover","objective"] and point.distance_to(objective) > leash+6.0 and wanted != a.global_position: continue
		var value: float = score(brain,query,point,objective,leash,others,movement)
		scored.append([point,value])
		if value > best_score:
			best_score = value
			best = point
	return {"point":best,"score":best_score,"candidates":scored}

static func score(brain: BotBrain, query: Dictionary, point: Vector3, objective: Vector3, leash: float, others: Array[Vector3], movement: BotMovement) -> float:
	var a: HeroActor = brain.actor
	var mode: String = query.mode
	var weights: BotTuning = brain.tuning()
	var value: float = -a.global_position.distance_to(point)/20.0*.5
	var threat_at: Vector3 = query.threat
	var eye: Vector3 = point+Vector3.UP*1.45
	if threat_at != Vector3.INF:
		var distance: float = Vector2(point.x-threat_at.x,point.z-threat_at.z).length()
		var band: float = maxf(3.0,(brain.hero_profile.maximum_range-brain.hero_profile.minimum_range)*.5)
		if mode in ["fight","protect","investigate","contest"]: value += (.4 if mode == "contest" else .8)*(1.0-clampf(absf(distance-float(query.desired))/band,0,1))
		var exposed: bool = a.resolver.attack_ray(a,eye,threat_at+Vector3.UP,[a.get_rid()],1).is_empty()
		movement.query_count += 1
		if bool(query.wants_los): value += (.6 if exposed else -.4)*weights.los_weight
		else: value += (-.6 if exposed else .9)*weights.cover_weight
		if brain.hero_profile.maximum_range > 12: value += clampf((point.y-threat_at.y)/4.0,-.3,.4)
	for other: Vector3 in others:
		movement.query_count += 1
		if a.resolver.attack_ray(a,eye,other+Vector3.UP,[a.get_rid()],1).is_empty(): value -= .25
	if is_instance_valid(brain.director):
		var caution: float = {"fight":.3,"contest":.15,"objective":.25}.get(mode,.5)
		value -= brain.director.danger_at(point)*caution*(1.2-brain.hero_profile.aggression*.4)*weights.danger_weight
		if brain.director.reserved(point,a.get_instance_id()): value -= 1.2
	var nearest_ally: float = INF
	for ally: HeroActor in brain.allies: nearest_ally = minf(nearest_ally,ally.global_position.distance_to(point))
	if nearest_ally < 2.5: value -= .3
	if mode == "support" and is_instance_valid(brain.patient):
		if a.resolver.attack_ray(a,eye,brain.patient.body_point(1.0),[a.get_rid()],1).is_empty(): value += .7
		else: value -= .5
		movement.query_count += 1
	var to_objective: float = point.distance_to(objective)
	var radius: float = float(brain.context.get("radius",7.0))
	var urgency: float = float(brain.context.get("urgency",.5))
	if mode not in ["retreat","support","gather"] and to_objective > leash: value -= (to_objective-leash)*.12
	if mode in ["objective","contest","fight","cover"]:
		if to_objective < radius: value += (.35+.5*urgency)*(.5 if bool(brain.context.get("secured",false)) else 1.0)*weights.objective_weight
		elif mode == "contest": value -= (to_objective-radius)*.06*weights.objective_weight
	if point.distance_to(movement.selected_position) < 2.0: value += .15
	return value
