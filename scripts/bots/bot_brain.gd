class_name BotBrain
extends RefCounted
var actor: HeroActor
var perception := BotPerception.new()
var movement := BotMovement.new()
var combat := BotCombat.new()
var diagnostics := BotDebug.new()
var hero_profile: BotHeroProfile
var class_profile: BotClassProfile
var skill: BotSkillProfile
var director: TeamDirector
var context: Dictionary = {}
var allies: Array[HeroActor] = []
var target_id: int = 0
var patient: HeroActor
var threat: Dictionary = {}
var scores: Dictionary = {}
var tactical_state: String = "contest"
var team_intention: String = "contest"
var committed_until: float = 0.0
var acquired_at: float = 0.0
var now: float = 0.0
var nearby_enemies: int = 0
var follow_up: int = 0
var danger: float = 0.0
var level: int = -1
var rng := RandomNumberGenerator.new()

func setup(owner: HeroActor, shared: TeamDirector, seed_value: int) -> void:
	actor = owner
	director = shared
	rng.seed = seed_value
	hero_profile = BotHeroProfile.for_hero(actor.tuning.hero_id)
	class_profile = load("res://resources/bots/classes/%s.tres" % HeroRoster.role_for(actor.tuning.hero_id)) as BotClassProfile
	set_difficulty(int(actor.get_node("/root/GameSettings").values.get("bot_difficulty",1)))
	combat.aim = actor.aim_direction
	diagnostics.setup(actor)

func set_difficulty(value: int) -> void:
	if level == value: return
	level = clampi(value,0,3)
	skill = BotSkillProfile.for_level(level)
	acquired_at = actor.resolver.combat_time
	combat.cancel("difficulty changed")
	combat.aim_speed = 0

func target_actor() -> HeroActor:
	if not perception.observations.has(target_id): return null
	var entry: Dictionary = perception.observations[target_id]
	var other: HeroActor = entry.actor.get_ref() as HeroActor
	return other if is_instance_valid(other) and other.life_serial == int(entry.life) else null

func visible_target() -> bool:
	return target_id in perception.visible_ids and not threat.is_empty() and now-float(threat.seen) <= .25

func ready_to_attack() -> bool:
	return visible_target() and now-maxf(acquired_at,float(threat.first_seen)) >= skill.acquisition_delay

func decide(actors: Array, objective: Dictionary) -> void:
	now = actor.resolver.combat_time
	set_difficulty(int(actor.get_node("/root/GameSettings").values.get("bot_difficulty",1)))
	if hero_profile.hero != actor.tuning.hero_id and actor.tuning.hero_id in HeroRoster.IDS:
		hero_profile = BotHeroProfile.for_hero(actor.tuning.hero_id)
		class_profile = load("res://resources/bots/classes/%s.tres" % HeroRoster.role_for(actor.tuning.hero_id)) as BotClassProfile
		reset()
	var phase_changed: bool = str(context.get("phase","")) != str(objective.get("phase",""))
	context = objective
	perception.sense(actor,actors,now,skill.perception_budget)
	if is_instance_valid(director):
		director.report(actor,perception.observations,perception.visible_ids,now)
		perception.merge_shared(director.reports,now)
		team_intention = director.assignment(actor)
	allies.clear()
	follow_up = 0
	patient = null
	var patient_score: float = .05
	for other: HeroActor in actors:
		if not is_instance_valid(other) or other == actor or other.team != actor.team or not other.alive: continue
		allies.append(other)
		var distance: float = actor.global_position.distance_to(other.global_position)
		if distance < 20 and not actor.resolver.protected_room(other): follow_up += 1
		if distance > 35 or actor.resolver.protected_room(other): continue
		var missing: float = 1-other.health/other.effective_max_health()
		var pressure: float = .18 if other.last_hit_age < 1.5 else 0.0
		var exposure: int = 0
		for observation: Dictionary in perception.observations.values():
			if now-float(observation.seen) < 1 and other.global_position.distance_to(observation.position) < 10: exposure += 1
		var recoverable: float = -.5 if exposure > follow_up+1 and missing > .85 else 0.0
		var score: float = missing+pressure-distance/120.0+recoverable
		if score > patient_score:
			patient = other
			patient_score = score
	select_target()
	nearby_enemies = 0
	for observation: Dictionary in perception.observations.values():
		if now-float(observation.seen) < 1 and actor.global_position.distance_to(observation.position) < 22: nearby_enemies += 1
	var health: float = actor.health/actor.effective_max_health()
	danger = clampf((1-health)*.65+maxi(0,nearby_enemies-follow_up-1)*.2+(.2 if actor.last_hit_age < 1 else 0.0),0,1)
	var urgency: float = float(context.get("urgency",.5))
	var on_objective: bool = actor.global_position.distance_to(context.get("position",Vector3.ZERO)) < float(context.get("radius",7))
	var secured: bool = bool(context.get("secured",false))
	var opportunity: float = 0.0 if threat.is_empty() else 1-float(threat.health)/maxf(1,float(threat.maximum))
	var protect_need: float = 0.0
	if is_instance_valid(patient) and not threat.is_empty() and patient.last_hit_age < 1.5 and patient.global_position.distance_to(threat.position) < 12: protect_need = .65
	var can_commit: bool = follow_up > 0 or nearby_enemies <= 1
	scores = {"contest":.35+urgency*.35+class_profile.contest-(.3 if on_objective else 0.0)-(.18 if secured else 0.0),
		"hold":.3+class_profile.contest+(.18 if on_objective or secured else -.15),
		"pressure":.4+hero_profile.aggression*.2+(.18 if visible_target() else 0.0)-danger*.15,
		"flank":.35+class_profile.flank+hero_profile.mobility*.2+(.15 if team_intention == "flank" and follow_up > 0 else 0.0)+(.12 if hero_profile.hero == "huddle" else 0.0)-danger*.2,
		"commit":(.25+opportunity*.6+hero_profile.aggression*.2-danger*.4) if can_commit and visible_target() else 0.0,
		"protect":protect_need+class_profile.protect,"support":patient_score+class_profile.support if is_instance_valid(patient) else 0.0,
		"retreat":danger*.85+(.35 if health < class_profile.retreat_health else 0.0),
		"regroup":.7 if nearby_enemies > follow_up+2 else .1,
		"investigate":.55 if not visible_target() and not threat.is_empty() else 0.0}
	if team_intention in scores: scores[team_intention] = float(scores[team_intention])+.12*skill.coordination
	if threat.is_empty():
		for action: String in ["pressure","flank","commit","protect","investigate"]: scores[action] = 0.0
	if class_profile.role != "support": scores.support = float(scores.support)*.35
	for action: String in scores: scores[action] = clampf(float(scores[action]),0,1)
	var best: String = tactical_state
	for action: String in scores:
		if float(scores[action]) > float(scores.get(best,0.0)): best = action
	var emergency: bool = health < class_profile.retreat_health and danger > .5 and nearby_enemies > 0
	if emergency: best = "retreat"
	var invalid: bool = threat.is_empty() and tactical_state in ["commit","pressure","investigate","protect","flank"]
	if emergency or phase_changed or invalid or (now >= committed_until and float(scores[best]) >= float(scores.get(tactical_state,0.0))+.15):
		if best != tactical_state:
			tactical_state = best
			committed_until = now+.6
			diagnostics.decision(now,best,scores)
	combat.evaluate(self)

func select_target() -> void:
	var selected: int = 0
	var best: float = -INF
	for id: int in perception.observations:
		var entry: Dictionary = perception.observations[id]
		var distance: float = actor.global_position.distance_to(entry.position)
		var vulnerability: float = 1-float(entry.health)/maxf(1,float(entry.maximum))
		var visible: bool = id in perception.visible_ids
		var range_value: float = 1-clampf(absf(distance-(hero_profile.minimum_range+hero_profile.maximum_range)*.5)/40,0,1)
		var retaliation: int = 0
		for other: Dictionary in perception.observations.values():
			if now-float(other.seen) < 1 and other.position.distance_to(entry.position) < 10: retaliation += 1
		var score: float = range_value*.3+vulnerability*(.25+hero_profile.vulnerable_bias)+(.3 if visible else 0.0)-float(retaliation)*.045
		if actor.kit is StitchKit:
			score += .25 / maxf(1,retaliation) + int(entry.get("marks",0))*.06
		var damage_rate: float = actor.tuning.rifle_damage/maxf(.1,actor.tuning.shot_interval)
		score -= minf(.2,(float(entry.health)+float(entry.shields)+float(entry.get("overhealth",0)))/maxf(1,damage_rate)*.01)
		if entry.position.distance_to(context.get("position",Vector3.ZERO)) < 10: score += .15
		if is_instance_valid(patient) and patient.global_position.distance_to(entry.position) < 10 and patient.last_hit_age < 1.5: score += .2
		if bool(entry.get("damage_immune",false)) or str(entry.state) in ["deflect","marshal_shield"]: score -= .25
		elif now-float(entry.defense_seen) < 3: score += .12
		if bool(entry.get("channeling",false)): score += .3
		if bool(entry.get("protected",false)): score -= .2
		if int(entry.get("healing_source",0)) != 0: score -= .12
		if int(entry.get("tether_source",0)) == actor.get_instance_id(): score += .25
		if bool(entry.get("pursuing",false)) and actor.health < actor.effective_max_health()*.5: score += .15
		if id == target_id: score += .12
		if is_instance_valid(director): score -= maxf(0,director.pressure_on(id,actor.get_instance_id())-2)*.15
		if score > best:
			selected = id
			best = score
	if selected != target_id:
		target_id = selected
		acquired_at = now
		combat.cancel("target changed")
	threat = perception.observations.get(target_id,{})

func reset() -> void:
	perception.reset()
	target_id = 0
	threat = {}
	patient = null
	committed_until = 0
	tactical_state = "contest"
	movement.reset()
	combat.cancel("reset")
	combat.aim = actor.aim_direction
	if is_instance_valid(director): director.release(actor)
