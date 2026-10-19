class_name MuseumBotController
extends CityBotController
var assignment: String = "escort"
var tactical_key: String = ""
var tactical_index: int = 0
var tactical_done: bool = false
var tactical_hold: float = 0.0
var retry_at: float = 0.0

func load_route() -> void:
	route.clear()
	entered_hill = true
	destination = actor.global_position
	tactical_key = ""
	tactical_index = 0
	tactical_done = false
	retry_at = 0.0

func decide() -> void:
	super.decide()
	if seeking_health or elapsed < detour_until: return
	var session := match_controller as MuseumMatch
	var d: MuseumMapDefinition = session.museum_definition()
	var escort: bool = session.phase == "escort"
	var objective_at: Vector3 = session.payload.global_position if escort else d.hill_center
	var sector: int = d.sector(session.payload_distance,escort)
	var urgent: bool = session.overtime or (actor.team == 1 and session.occupancy[0] > 0 and session.occupancy[1] == 0)
	var offsets: Array[Vector3] = [Vector3(-3,0,-2),Vector3(3,0,2),Vector3(-3,0,2),Vector3(3,0,-2)]
	var hold: Vector3 = objective_at+offsets[slot%4]
	assignment = "escort" if actor.team == 0 else "contest"
	if slot >= 4 and not urgent and elapsed >= retry_at:
		var kind: String = "high_ground" if slot == 4 else "flank"
		var entry: Dictionary = d.tactical_route(sector,kind)
		if not entry.is_empty():
			var key: String = str(sector)+kind
			if tactical_key != key:
				tactical_key = key
				tactical_index = 0
				tactical_done = false
				tactical_hold = 0.0
			var points: Array = entry.points
			if not tactical_done:
				assignment = kind
				hold = points[tactical_index]
				if actor.global_position.distance_to(hold) < 1.8:
					# Occupy the actual perch briefly before completing its exit route.
					if kind == "high_ground" and tactical_index == int(entry.get("hold_index",2)) and sees_target and tactical_hold < 4:
						tactical_hold += .2
					else:
						tactical_index += 1
						if tactical_index >= points.size(): tactical_done = true
						else: hold = points[tactical_index]
				if stuck_time >= 1.5:
					tactical_done = true
					retry_at = elapsed+8
					hold = objective_at+offsets[slot%4]
					assignment = "escort" if actor.team == 0 else "contest"
	elif actor.team == 1 and escort and session.occupancy[0] == 0:
		assignment = "forward_hold"
		hold = d.path_position(minf(d.checkpoint_distances()[-1],session.payload_distance+8))+offsets[slot%4]*.5
	if session.phase == "preparation": hold = d.hill_center+Vector3(5,0,(slot%3-1)*3)
	destination = NavigationServer3D.map_get_closest_point(navagent.get_navigation_map(),hold)

func gather_intent(delta: float) -> CombatIntent:
	var intent: CombatIntent = super.gather_intent(delta)
	if actor.kit is RelayKit or actor.kit is HuddleKit: intent.hover = false
	return intent
