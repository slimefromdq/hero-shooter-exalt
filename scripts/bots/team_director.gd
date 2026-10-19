class_name TeamDirector
extends Node
## Shared radio information only; the director never searches live opponents.
var reports: Dictionary = {}
var members: Dictionary = {}
var assignments: Dictionary = {}
var reservations: Dictionary = {}
var next_update: float = -1.0
var last_time: float = -1.0

static func obtain(parent: Node, team: int) -> TeamDirector:
	var node_name: String = "BotTeamDirector%d" % team
	var director: TeamDirector = parent.get_node_or_null(node_name) as TeamDirector
	if director == null:
		director = TeamDirector.new()
		director.name = node_name
		parent.add_child(director)
	return director

func report(actor: HeroActor, observations: Dictionary, visible: Array[int], now: float) -> void:
	if now < last_time: clear()
	last_time = now
	members[actor.get_instance_id()] = weakref(actor)
	for id: int in visible:
		if observations.has(id): reports[id] = observations[id].duplicate()
	for id: int in reports.keys():
		if now-float(reports[id].seen) > BotPerception.MEMORY_SECONDS: reports.erase(id)
	for id: int in reservations.keys():
		if now > float(reservations[id].expires): reservations.erase(id)
	if now < next_update: return
	next_update = now+.4
	assignments.clear()
	var flankers: int = 0
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
		elif role == "support": intention = "support"
		elif ally.tuning.hero_id in ["marshal","dynamo"] and anchors < 1:
			intention = "hold"
			anchors += 1
		elif role == "dps" and flankers < 1:
			intention = "flank"
			flankers += 1
		else: intention = "pressure"
		assignments[id] = intention

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
	reports.clear()
	members.clear()
	assignments.clear()
	reservations.clear()
	next_update = -1
