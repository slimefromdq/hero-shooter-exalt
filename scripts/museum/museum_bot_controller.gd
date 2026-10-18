class_name MuseumBotController
extends CityBotController
var assignment: String = "escort"
var flank_sector: int = -1
var flank_reached: bool = false

func load_route() -> void:
	route.clear()
	entered_hill = true
	destination = Vector3.ZERO
	flank_sector = -1
	flank_reached = false

func decide() -> void:
	super.decide()
	if seeking_health or elapsed < detour_until: return
	var session := match_controller as MuseumMatch
	var definition: MuseumMapDefinition = session.museum_definition()
	var escort: bool = session.phase == "escort"
	var objective_at: Vector3 = session.payload.global_position if escort else Vector3.ZERO
	var sector: int = definition.sector(session.payload_distance,escort)
	# Four slots always pressure the objective; two choose connected side routes.
	var urgent: bool = session.overtime or (actor.team == 1 and session.occupancy[0] > 0 and session.occupancy[1] == 0)
	var offsets: Array = [Vector3(-3,0,-2),Vector3(3,0,2),Vector3(-3,0,2),Vector3(3,0,-2)] if escort else [Vector3(-5,0,-3),Vector3(5,0,3),Vector3(-5,0,3),Vector3(5,0,-3)]
	var hold: Vector3 = objective_at+offsets[slot%4]
	assignment = "escort" if actor.team == 0 else "contest"
	if not urgent and slot == 4:
		assignment = "high_ground"
		hold = definition.high_positions[sector]
	elif not urgent and slot == 5:
		assignment = "flank"
		if flank_sector != sector:
			flank_sector = sector
			flank_reached = false
		hold = definition.flank_positions[sector]
		if actor.global_position.distance_to(hold) < 2.5: flank_reached = true
		if flank_reached:
			hold = objective_at+Vector3(2,0,3)
	elif actor.team == 1 and escort and session.occupancy[0] == 0:
		assignment = "forward_hold"
		hold = definition.path_position(minf(definition.checkpoint_distances()[-1],session.payload_distance+8))+Vector3(0,0,(slot%3-1)*2)
	if session.phase == "preparation": hold = Vector3(5,0,(slot%3-1)*3)
	var map: RID = navagent.get_navigation_map()
	destination = NavigationServer3D.map_get_closest_point(map,hold)

func gather_intent(delta: float) -> CombatIntent:
	var intent: CombatIntent = super.gather_intent(delta)
	# Keep ordinary team tactics on this map's navigable area. Mobility remains
	# available to players; bots don't launch themselves over museum boundaries.
	if actor.kit is RelayKit or actor.kit is HuddleKit: intent.hover = false
	return intent
