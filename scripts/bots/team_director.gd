class_name TeamDirector
extends Node
## Shared radio information only; the director never searches live opponents.
var reports: Dictionary = {}
var members: Dictionary = {}
var assignments: Dictionary = {}
var reservations: Dictionary = {}
var next_update: float = -1.0
var last_time: float = -1.0
## Coarse influence map of where enemies can hurt us: Vector2i cell -> danger (0..3).
const CELL: float = 4.0
const DANGER_REACH: float = 22.0
var danger: Dictionary = {}
## Recent friendly deaths {"position","time"}; places teammates died stay dangerous a while.
var deaths: Array[Dictionary] = []
var watching_eliminations: bool = false

## --- Team strategy ---------------------------------------------------------------
## The team brain. Orders: "push", "hold", "cleanup", "group_up", "fall_back".
## Uses only fair knowledge: teammates' own state, shared sightings, and the public
## kill feed (who is alive). It never reads hidden enemy positions.
const ORDER_HOLD_SECONDS: float = 2.0
const FLANK_TENURE: float = 10.0
var team: int = -1
var roster: Array = []
var context: Dictionary = {}
var order: String = "push"
var order_since: float = -99.0
var gather_point: Vector3 = Vector3.INF
var focus_id: int = 0
var odds: float = .5
var flankers: Dictionary = {}
var ally_ults: Dictionary = {}
var order_log: Array[Dictionary] = []
var watching_events: bool = false
static var dps_cache: Dictionary = {}

static func obtain(parent: Node, team: int) -> TeamDirector:
	var node_name: String = "BotTeamDirector%d" % team
	var director: TeamDirector = parent.get_node_or_null(node_name) as TeamDirector
	if director == null:
		director = TeamDirector.new()
		director.name = node_name
		parent.add_child(director)
	return director

func report(actor: HeroActor, observations: Dictionary, visible: Array[int], now: float, actors: Array = [], objective: Dictionary = {}) -> void:
	if now < last_time: clear()
	last_time = now
	team = actor.team
	members[actor.get_instance_id()] = weakref(actor)
	if not actors.is_empty() and actors.size() != roster.size():
		roster.clear()
		for other: Variant in actors:
			if is_instance_valid(other): roster.append(weakref(other))
	if not objective.is_empty(): context = objective
	if not watching_events and is_instance_valid(actor.resolver):
		watching_events = true
		actor.resolver.event_logged.connect(_on_event)
	if not watching_eliminations and is_instance_valid(actor.resolver):
		watching_eliminations = true
		actor.resolver.elimination.connect(_on_elimination.bind(actor.team))
	for id: int in visible:
		if observations.has(id): reports[id] = observations[id].duplicate()
	for id: int in reports.keys():
		if now-float(reports[id].seen) > BotPerception.MEMORY_SECONDS: reports.erase(id)
	for id: int in reservations.keys():
		if now > float(reservations[id].expires): reservations.erase(id)
	if now < next_update: return
	next_update = now+.4
	rebuild_danger(now)
	update_strategy(now)
	assignments.clear()
	var anchors: int = 0
	for id: int in members.keys():
		var ally: HeroActor = members[id].get_ref() as HeroActor
		if not is_instance_valid(ally) or not ally.alive:
			members.erase(id)
			reservations.erase(id)
			continue
		var role: String = HeroRoster.role_for(ally.tuning.hero_id)
		var intention: String = "contest"
		if ally.health/ally.effective_max_health() < .25: intention = "regroup"
		elif flankers.has(id): intention = "flank"
		elif role == "support": intention = "support"
		elif ally.tuning.hero_id in ["marshal","dynamo"] and anchors < 1:
			intention = "hold"
			anchors += 1
		else: intention = "pressure"
		assignments[id] = intention

func _on_elimination(_killer: HeroActor, victim: HeroActor, _assistants: Array[HeroActor], _ability: String, team: int) -> void:
	if is_instance_valid(victim) and victim.team == team:
		deaths.append({"position":victim.global_position,"time":last_time})
		if deaths.size() > 16: deaths.pop_front()

static func cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x/CELL),floori(point.z/CELL))

## Rebuilt at the director's 2.5 Hz cadence from shared (radio) knowledge only.
func rebuild_danger(now: float) -> void:
	danger.clear()
	var span: int = ceili(DANGER_REACH/CELL)
	for id: int in reports:
		var report: Dictionary = reports[id]
		var age: float = now-float(report.seen)
		if age > 3.0: continue
		var at: Vector3 = report.position
		var facing: Vector3 = Vector3(report.get("facing",Vector3.ZERO))*Vector3(1,0,1)
		if not facing.is_zero_approx(): facing = facing.normalized()
		var origin: Vector2i = cell(at)
		var freshness: float = 1.0-age/3.0
		for dx: int in range(-span,span+1):
			for dz: int in range(-span,span+1):
				var key := Vector2i(origin.x+dx,origin.y+dz)
				var middle := Vector3((key.x+.5)*CELL,at.y,(key.y+.5)*CELL)
				var offset: Vector3 = middle-at
				var distance: float = offset.length()
				if distance > DANGER_REACH: continue
				var aim_bonus: float = .5*maxf(0,facing.dot(offset/maxf(distance,.01))) if not facing.is_zero_approx() else .25
				danger[key] = minf(3.0,float(danger.get(key,0.0))+(1.0-distance/DANGER_REACH)*(1.0+aim_bonus)*freshness)
	for death: Dictionary in deaths:
		var age: float = now-float(death.time)
		if age > 15.0 or age < 0: continue
		var origin: Vector2i = cell(death.position)
		for dx: int in range(-1,2):
			for dz: int in range(-1,2):
				var key := Vector2i(origin.x+dx,origin.y+dz)
				danger[key] = minf(3.0,float(danger.get(key,0.0))+.6*(1.0-age/15.0))

func danger_at(point: Vector3) -> float:
	return float(danger.get(cell(point),0.0))

## Last-reported enemy positions, newest first; used for attention and flank checks.
func recent_threats(now: float, within: float = 6.0) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var entries: Array = reports.values()
	entries.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.seen) > float(y.seen))
	for report: Dictionary in entries:
		if now-float(report.seen) <= within: result.append(report.position)
	return result

func _on_event(entry: Dictionary) -> void:
	if str(entry.get("event","")) != "cast" or str(entry.get("ability","")) != "ultimate": return
	for ref: WeakRef in roster:
		var ally: HeroActor = ref.get_ref() as HeroActor
		if is_instance_valid(ally) and ally.team == team and ally.actor_id == str(entry.get("actor","")):
			ally_ults[ally.get_instance_id()] = {"time":last_time,"position":ally.global_position}

static func dps_for(hero: String) -> float:
	if not dps_cache.has(hero):
		var tuning: HeroTuning = HeroRoster.tuning_for(hero) if hero in HeroRoster.IDS else HeroTuning.new()
		dps_cache[hero] = tuning.rifle_damage/maxf(.1,tuning.shot_interval)
	return float(dps_cache[hero])

func living(own: bool) -> Array[HeroActor]:
	var result: Array[HeroActor] = []
	for ref: WeakRef in roster:
		var other: HeroActor = ref.get_ref() as HeroActor
		if is_instance_valid(other) and other.alive and (other.team == team) == own: result.append(other)
	return result

## Chance-like 0..1 estimate of winning a fight around center: Lanchester-style
## (total health x total damage) from teammates plus shared enemy sightings.
## Enemies alive but unseen count partially: they may be lurking nearby.
func fight_odds(center: Vector3, radius: float, now: float) -> float:
	var ally_hp: float = 0.0
	var ally_dps: float = 0.0
	for ally: HeroActor in living(true):
		if ally.global_position.distance_to(center) > radius: continue
		ally_hp += ally.health+ally.shields+ally.overhealth.value()
		ally_dps += dps_for(ally.tuning.hero_id)
	var enemy_hp: float = 0.0
	var enemy_dps: float = 0.0
	var reported: int = 0
	for id: int in reports:
		var entry: Dictionary = reports[id]
		if now-float(entry.seen) > 4.0: continue
		var other: HeroActor = entry.actor.get_ref() as HeroActor
		if not is_instance_valid(other) or not other.alive: continue
		reported += 1
		if Vector3(entry.position).distance_to(center) > radius: continue
		enemy_hp += float(entry.health)+float(entry.shields)+float(entry.get("overhealth",0.0))
		enemy_dps += dps_for(str(entry.hero))
	var lurking: int = maxi(0,living(false).size()-reported)
	enemy_hp += lurking*.3*250.0
	enemy_dps += lurking*.3*100.0
	var ours: float = ally_hp*ally_dps
	var theirs: float = enemy_hp*enemy_dps
	if ours+theirs <= 0: return .5
	return ours/(ours+theirs)

func update_strategy(now: float) -> void:
	if context.is_empty() or team < 0: return
	var objective: Vector3 = context.get("position",Vector3.ZERO)
	var radius: float = float(context.get("radius",7.0))
	var allies: Array[HeroActor] = living(true)
	var enemies: Array[HeroActor] = living(false)
	odds = fight_odds(objective,radius+22.0,now)
	update_gather(objective,allies)
	var desperate: bool = bool(context.get("desperate",false))
	var secured: bool = bool(context.get("secured",false))
	var gathered: int = 0
	for ally: HeroActor in allies:
		if ally.global_position.distance_to(objective) < radius+10 or (gather_point != Vector3.INF and ally.global_position.distance_to(gather_point) < 10): gathered += 1
	var needed: int = maxi(2,ceili(allies.size()*.65))
	var next: String = order
	if desperate: next = "push"
	elif allies.size()+2 <= enemies.size(): next = "fall_back" if order in ["push","cleanup","hold"] else "group_up"
	elif order in ["group_up","fall_back"]:
		if gathered >= needed or allies.size() > enemies.size() or odds > .6: next = "push"
	elif secured: next = "hold"
	elif odds > .72 and allies.size() > enemies.size(): next = "cleanup"
	elif odds < .26: next = "fall_back"
	else: next = "push"
	if next == "fall_back" and order == "fall_back" and gathered >= needed: next = "group_up"
	if next != order and (now-order_since >= ORDER_HOLD_SECONDS or desperate):
		order_log.append({"time":snappedf(now,.1),"from":order,"to":next,"odds":snappedf(odds,.01),"allies":allies.size(),"enemies":enemies.size()})
		if order_log.size() > 32: order_log.pop_front()
		order = next
		order_since = now
	pick_focus(now)
	pick_flankers(now,allies)

## A sheltered rally point between the team's spawn side and the objective.
func update_gather(objective: Vector3, allies: Array[HeroActor]) -> void:
	if allies.is_empty(): return
	var home := Vector3.ZERO
	for ally: HeroActor in allies: home += ally.spawn_position
	home /= allies.size()
	var away: Vector3 = (home-objective)*Vector3(1,0,1)
	if away.length() < 1: return
	var point: Vector3 = objective+away.normalized()*minf(22.0,away.length()*.5)
	var map: RID = allies[0].get_world_3d().navigation_map
	gather_point = NavigationServer3D.map_get_closest_point(map,point) if NavigationServer3D.map_get_iteration_id(map) > 0 else point

## Shared focus target: low health, isolated, supports and channelers first.
func pick_focus(now: float) -> void:
	var best: float = -INF
	var chosen: int = 0
	for id: int in reports:
		var entry: Dictionary = reports[id]
		if now-float(entry.seen) > 2.0: continue
		var value: float = (1.0-float(entry.health)/maxf(1,float(entry.maximum)))*1.2
		if str(entry.get("role","")) == "support": value += .35
		if bool(entry.get("channeling",false)): value += .4
		var company: int = 0
		for other: int in reports:
			if other != id and now-float(reports[other].seen) < 2.0 and Vector3(reports[other].position).distance_to(entry.position) < 10: company += 1
		value -= company*.12
		if id == focus_id: value += .15
		if value > best:
			best = value
			chosen = id
	focus_id = chosen

## Flankers are chosen by mobility and health, not by slot, and keep the job a while.
func pick_flankers(now: float, allies: Array[HeroActor]) -> void:
	var wanted: int = 0 if order in ["group_up","fall_back"] else (2 if allies.size() >= 5 and order in ["push","cleanup"] else 1)
	for id: int in flankers.keys():
		var ally := instance_from_id(id) as HeroActor
		if not is_instance_valid(ally) or not ally.alive or ally.health < ally.effective_max_health()*.4 or flankers.size() > wanted:
			flankers.erase(id)
	if flankers.size() >= wanted: return
	var scored: Array = []
	for ally: HeroActor in allies:
		var id: int = ally.get_instance_id()
		if flankers.has(id) or not members.has(id): continue
		if ally.health < ally.effective_max_health()*.7: continue
		var profile: BotHeroProfile = BotHeroProfile.for_hero(ally.tuning.hero_id)
		var role: String = HeroRoster.role_for(ally.tuning.hero_id)
		var value: float = profile.mobility*.6+profile.aggression*.4
		if role == "support": value -= .6
		elif role == "tank": value -= .4
		if ally.controller != null and ally.controller.get("brain") != null: value += float(ally.controller.brain.personality.get("flank",0.0))
		scored.append([value,id])
	scored.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	for entry: Array in scored:
		if flankers.size() >= wanted: break
		flankers[int(entry[1])] = now

## Ultimate economy: hold ults when the fight is already won, follow a teammate's ult.
func ult_gate(actor: HeroActor, now: float) -> float:
	for id: int in ally_ults:
		if id == actor.get_instance_id(): continue
		var cast: Dictionary = ally_ults[id]
		if now-float(cast.time) < 2.5 and Vector3(cast.position).distance_to(actor.global_position) < 22: return 1.15
	if order == "cleanup" and odds > .8: return .7
	if order in ["group_up","fall_back"]: return .8
	return 1.0

func assignment(actor: HeroActor) -> String:
	return str(assignments.get(actor.get_instance_id(),"contest"))

func reserved(point: Vector3, owner: int) -> bool:
	for id: int in reservations:
		if id != owner and point.distance_squared_to(reservations[id].position) < 2.5*2.5: return true
	return false

func reserve(actor: HeroActor, point: Vector3, now: float) -> void:
	reservations[actor.get_instance_id()] = {"position":point,"expires":now+.8}

func pressure_on(target_id: int, except: int) -> int:
	var count: int = 0
	for id: int in members:
		var ally: HeroActor = members[id].get_ref() as HeroActor
		if id == except or not is_instance_valid(ally) or not ally.alive: continue
		if ally.controller != null and ally.controller.get("brain") != null and ally.controller.brain.target_id == target_id: count += 1
	return count

func release(actor: HeroActor) -> void:
	var id: int = actor.get_instance_id()
	members.erase(id)
	assignments.erase(id)
	reservations.erase(id)

func clear() -> void:
	order = "push"
	order_since = -99.0
	focus_id = 0
	flankers.clear()
	ally_ults.clear()
	gather_point = Vector3.INF
	danger.clear()
	deaths.clear()
	reports.clear()
	members.clear()
	assignments.clear()
	reservations.clear()
	next_update = -1
