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
	danger.clear()
	deaths.clear()
	reports.clear()
	members.clear()
	assignments.clear()
	reservations.clear()
	next_update = -1
