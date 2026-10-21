class_name TempleBotController
extends CityBotController
var goal: int = -1
var route_key: String = ""
var assignment: String = "attack"
var route_visits: Dictionary = {}

func load_route() -> void:
	route.clear()
	entered_hill = true
	destination = actor.global_position
	goal = -1
	route_key = ""

func invalidate_route() -> void:
	goal = -1
	route_key = ""
	think_timer = 0
	if brain != null: brain.movement.position_timer = -1

func decide() -> void:
	super.decide()
	if seeking_health or elapsed < detour_until: return
	var session := match_controller as TempleMatch
	var d: TempleMapDefinition = session.temple_definition()
	var next_goal: int = session.goal_index(actor.team)
	if next_goal != goal:
		goal = next_goal
		route.clear()
		route_index = 0
		route_key = ""
	var nearest: int = 0
	var distance: float = INF
	for index: int in 5:
		var candidate: float = actor.global_position.distance_squared_to(d.POINTS[index])
		if candidate < distance:
			distance = candidate
			nearest = index
	if route.is_empty() and nearest != goal:
		var sector: int = nearest if nearest < goal else nearest-1
		var kind: String = "upper" if slot == 4 else ("lower" if slot == 5 else "main")
		if session.objective.overtime: kind = "main"
		route_key = "%d_%s_%d" % [sector,kind,goal]
		for entry: Dictionary in session.arena.builder.routes:
			if entry.sector != sector or entry.kind != kind: continue
			for at: Vector3 in entry.points: route.append(at)
			if nearest > goal: route.reverse()
			# Join the route at its nearest waypoint, avoiding long backtracking.
			var best: float = INF
			for index: int in route.size():
				var length: float = actor.global_position.distance_squared_to(route[index])
				if length < best:
					best = length
					route_index = index
			route_visits[kind] = int(route_visits.get(kind,0))+1
			break
	if not route.is_empty():
		entered_hill = false
		assignment = "flank_"+route_key if slot >= 4 else "attack"
		if actor.global_position.distance_to(route[route_index]) < 3:
			route_index += 1
			if route_index >= route.size():
				route.clear()
				entered_hill = true
				return
		destination = route[route_index]
	else:
		entered_hill = true
		assignment = "defend" if session.objective.owners[goal] == actor.team else "contest"
		var offset := Vector3((slot%3-1)*8,.1,(slot/3*2-1)*7)
		destination = d.POINTS[goal]+offset
	destination = NavigationServer3D.map_get_closest_point(navagent.get_navigation_map(),destination)
