class_name BotDebug
extends RefCounted
## Metrics never feed perception. Weak signal connections die with the controller.
var actor: HeroActor
var history: Array[Dictionary] = []
var idle_seconds: float = 0.0
var objective_seconds: float = 0.0
var damage: float = 0.0
var deaths: int = 0
var bomb_attempts: int = 0
var early_detonations: int = 0
var casts: Dictionary = {}
var hit_casts: Dictionary = {}
var origins: Dictionary = {}
var recent_casts: Dictionary = {}
var last_bomb_attempts: int = 0
# Human-likeness counters (overhaul baseline): movement tech, combat stillness and isolation.
var alive_seconds: float = 0.0
var combat_seconds: float = 0.0
var combat_idle_seconds: float = 0.0
var travel: float = 0.0
var movement_events: Dictionary = {}
var engagements: int = 0
var outnumbered_engagements: int = 0
var deaths_alone: int = 0
var last_allies_near: int = 0
var was_engaged: bool = false
var last_position: Vector3 = Vector3.INF

func setup(owner: HeroActor) -> void:
	actor = owner
	actor.resolver.event_logged.connect(on_event)
	actor.resolver.cast_started.connect(on_cast_started)
	actor.movement_confirmed.connect(on_movement)

func on_movement(kind: String, _at: Vector3, _direction: Vector3, _normal: Vector3, _strength: float) -> void:
	if kind == "landing": return
	movement_events[kind] = int(movement_events.get(kind,0))+1

func detach() -> void:
	if not is_instance_valid(actor) or not is_instance_valid(actor.resolver): return
	if actor.resolver.event_logged.is_connected(on_event): actor.resolver.event_logged.disconnect(on_event)
	if actor.resolver.cast_started.is_connected(on_cast_started): actor.resolver.cast_started.disconnect(on_cast_started)
	if actor.movement_confirmed.is_connected(on_movement): actor.movement_confirmed.disconnect(on_movement)

func on_cast_started(source: HeroActor, id: int) -> void:
	if source != actor: return
	var activation: String = str({"slayer_knife":"knife","slayer_trap":"snare","slayer_axe_windup":"axe",
		"huddle_pulse":"wingbeat","huddle_wave_start":"wave","huddle_wave":"wave","wisp_heist_start":"grand_heist"}.get(actor.state,""))
	origins[id] = {"tick":Engine.get_physics_frames(),"life":actor.life_serial,"activation":str(recent_casts.get(activation,""))}
	if origins.size() > 2048: origins.erase(origins.keys()[0])

func canonical(ability: String) -> String:
	if ability == "projectile":
		if actor.tuning.hero_id == "huddle": return "seeds"
		if actor.tuning.hero_id == "wisp": return "grand_heist"
		if actor.tuning.hero_id == "relay": return "spirit_bolts"
	if ability in ["minigun","pistols","lightning"]: return "rifle"
	if actor.tuning.hero_id == "wisp" and ability in ["shotgun","soulburst","rogue_burst"]: return "soulbreaker"
	return str({"street_sweeper":"shotgun","silver_knife":"knife","heads_will_roll":"axe","boot_rush":"boot",
		"snare_toss":"snare","ultimate_shot":"ultimate","storm_dominion":"storm","seed_spitter":"seeds",
		"seed":"seeds","seed_swarm":"seeds","ballet":"grand_heist","spectral_finale":"grand_heist",
		"forward_march":"march","breach_line":"breach","marshals_verdict":"verdict",
		"personal_space":"wingbeat","nobody_gets_squished":"wave","bug_wave":"wave",
		"talon_volley":"spirit_bolts"}.get(ability,ability))

func cast_key(ability: String, tick: int, life: int) -> String:
	return "%d:%d:%s" % [life,tick,ability]

func on_event(entry: Dictionary) -> void:
	if not is_instance_valid(actor) or entry.actor != actor.actor_id: return
	var ability: String = canonical(str(entry.ability))
	var key: String = cast_key(ability,int(entry.tick),actor.life_serial)
	if entry.event == "death":
		deaths += 1
		if last_allies_near == 0: deaths_alone += 1
	if entry.event == "detonate" and "trigger=shot" in str(entry.details):
		early_detonations += 1
		last_bomb_attempts = bomb_attempts
	if entry.event == "cast":
		if str(entry.ability) == "ultimate" and actor.kit is NimbusKit: return
		if ability not in ["rifle","shotgun","cannon","sidearm","knife","axe","boot","snare","ultimate","bomb","march","breach","verdict","seeds","wingbeat","wave","shock","storm","lodestone","grand_heist","soulbreaker","spirit_bolts","omen","guiding_spirit","guiding_wing","spirit_jump","murmuration"]: return
		if not casts.has(key): casts[key] = ability
		recent_casts[ability] = key
	if entry.event in ["damage","execution"]:
		var details: String = str(entry.details)
		var cast_id: int = -1
		for field: String in details.split(" "):
			if field.begins_with("cast="): cast_id = int(field.trim_prefix("cast="))
			elif field.begins_with("applied="): damage += float(field.trim_prefix("applied="))
		if ability == "bleed": return
		var origin: Dictionary = origins.get(cast_id,{})
		if not origin.is_empty():
			key = cast_key(ability,int(origin.tick),int(origin.life))
			if str(origin.get("activation","")) != "": key = origin.activation
		# Persistent fields create tick casts; aggregate them under their activation.
		if ability in ["storm","lodestone","lightning","bleed"]:
			var activation: String = {"lightning":"stormcharge","bleed":"knife"}.get(ability,ability)
			key = str(recent_casts.get(activation,key))
		hit_casts[key] = ability
	# Bounded identifiers; aggregate reports remain useful over long sessions.
	if casts.size() > 4096: casts.erase(casts.keys()[0])
	if hit_casts.size() > 4096: hit_casts.erase(hit_casts.keys()[0])

func decision(now: float, state: String, utilities: Dictionary) -> void:
	history.append({"time":snappedf(now,.01),"state":state,"scores":utilities.duplicate()})
	if history.size() > 24: history.pop_front()

func tick(delta: float, brain: BotBrain, input: CombatIntent) -> void:
	if input.move.length() < .1 and not brain.movement.intentional_hold and input.primary == false and input.primary_held == false and input.secondary_held == false: idle_seconds += delta
	if actor.global_position.distance_to(brain.context.get("position",Vector3.INF)) < float(brain.context.get("radius",7)): objective_seconds += delta
	if not actor.alive:
		last_position = Vector3.INF
		was_engaged = false
		return
	alive_seconds += delta
	last_allies_near = brain.follow_up
	if last_position != Vector3.INF: travel += minf(actor.global_position.distance_to(last_position),2.0)
	last_position = actor.global_position
	var engaged: bool = brain.visible_target()
	if engaged:
		combat_seconds += delta
		if Vector2(actor.velocity.x,actor.velocity.z).length() < 1.0: combat_idle_seconds += delta
		if not was_engaged:
			engagements += 1
			if brain.nearby_enemies >= brain.follow_up+3: outnumbered_engagements += 1
	was_engaged = engaged

func human_metrics() -> Dictionary:
	var minutes: float = maxf(alive_seconds/60.0,.001)
	var tech: int = 0
	for kind: String in movement_events:
		if kind != "jump": tech += int(movement_events[kind])
	return {"alive_seconds":snappedf(alive_seconds,.1),"combat_seconds":snappedf(combat_seconds,.1),
		"combat_idle_ratio":snappedf(combat_idle_seconds/maxf(combat_seconds,.001),.001),
		"mean_speed":snappedf(travel/maxf(alive_seconds,.001),.01),"movement_events":movement_events.duplicate(),
		"tech_per_minute":snappedf(tech/minutes,.01),"jumps_per_minute":snappedf(int(movement_events.get("jump",0))/minutes,.01),
		"engagements":engagements,"outnumbered_engagements":outnumbered_engagements,"deaths_alone":deaths_alone}

func summary() -> Dictionary:
	var rates: Dictionary = {}
	for key: String in casts:
		var ability: String = casts[key]
		if not rates.has(ability): rates[ability] = {"casts":0,"hits":0}
		rates[ability].casts += 1
		if hit_casts.has(key): rates[ability].hits += 1
	return {"damage":damage,"deaths":deaths,"idle_seconds":idle_seconds,"objective_seconds":objective_seconds,
		"ability_casts":rates,"bomb_shot_attempts":bomb_attempts,"early_detonations":early_detonations,"human":human_metrics()}

static func export_tree(tree: SceneTree, path: String = "user://bot_metrics.json") -> Error:
	var bots: Array[Dictionary] = []
	for owner: HeroActor in tree.get_nodes_in_group("actors"):
		if owner.controller == null or owner.controller.get("brain") == null: continue
		var brain: BotBrain = owner.controller.brain
		bots.append({"actor":owner.actor_id,"hero":owner.tuning.hero_id,"team":owner.team,"difficulty":brain.skill.title,
			"state":brain.tactical_state,"team_intention":brain.team_intention,"metrics":brain.diagnostics.summary(),
			"navigation_failures":owner.controller.stuck_events,"sight_queries":brain.perception.ray_count,
			"position_queries":brain.movement.query_count,"decisions":brain.diagnostics.history})
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"bots":bots},"\t"))
	return OK
