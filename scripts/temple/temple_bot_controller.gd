class_name TempleBotController
extends CityBotController
var goal: int = -1
var route_key: String = ""
var assignment: String = "attack"
var route_visits: Dictionary = {}

var selected_pad: TempleJumpPad
var pad_phase: String = ""
var pad_timeout: float = 0
var pad_retry: float = 0
var pad_uses: int = 0
var gallery_visits: int = 0
var was_flanker: bool = false
var legacy_pads: bool = true

func gather_intent(delta: float) -> CombatIntent:
	pad_retry = maxf(0,pad_retry-delta)
	if not actor.alive:
		selected_pad = null
		pad_phase = ""
	if is_instance_valid(selected_pad) and active and not frozen and actor.alive and not match_controller.freeze_ai and not match_controller.exploration:
		pad_timeout -= delta
		if actor.motor.pad_flight_left>0 and pad_phase == "approach":
			pad_phase = "flight"
			pad_uses += 1
			pad_timeout = selected_pad.spec.flight_time+2
		if pad_phase == "flight":
			var flight_intent := CombatIntent.new()
			flight_intent.aim = remembered_aim
			flight_intent.aim_origin = actor.body_point(1.45)
			if is_instance_valid(target) and target.alive:
				flight_intent.aim = (target.body_point(1.2)-flight_intent.aim_origin).normalized()
				flight_intent.primary = sees_target
				flight_intent.primary_held = sees_target
			if (actor.motor.pad_flight_left<=0 and actor.motor.grounded()) or pad_timeout<=0:
				selected_pad = null
				pad_phase = ""
				pad_retry = 12
				invalidate_route()
				gallery_visits += 1
			return flight_intent
		if pad_timeout<=0:
			selected_pad = null
			pad_phase = ""
			pad_retry = 15
			invalidate_route()
	var intent: CombatIntent = super.gather_intent(delta)
	if is_instance_valid(selected_pad) and pad_phase == "approach":
		# Prevent combat steering/abilities from carrying a bot past the trigger.
		navagent.target_position = selected_pad.global_position
		var approach := CombatIntent.new()
		approach.aim = intent.aim
		approach.aim_origin = intent.aim_origin
		approach.move = follow_path()
		if actor.global_position.distance_to(selected_pad.global_position)<4:
			approach.move = ((selected_pad.global_position-actor.global_position)*Vector3(1,0,1)).normalized()
		approach.primary = intent.primary
		approach.primary_held = intent.primary_held
		return approach
	return intent

func load_route() -> void:
	selected_pad = null
	pad_phase = ""
	pad_timeout = 0
	pad_retry = 0
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
	if is_instance_valid(selected_pad):
		destination = selected_pad.global_position
		return
	var flanker: bool = brain.team_intention == "flank"
	# Becoming a flanker mid-route re-plans onto a flank route (flankers are assigned
	# by the director after the first decisions, not fixed by slot at spawn).
	if flanker and not was_flanker and route_key.contains("main") and not route.is_empty():
		route.clear()
		route_key = ""
	was_flanker = flanker
	# Authored routes go waypoint to waypoint, so a pad shortcut is chosen here against
	# the goal. Flankers and mobile heroes take any pad heading the right way; everyone
	# else takes one when it lands at least 20 m closer to the goal. Pads are also
	# navigation links (TraversalLinks.register_pads) for long off-route trips.
	if legacy_pads and pad_retry<=0 and actor.motor.grounded() and not seeking_health:
		var goal_at: Vector3 = (match_controller as TempleMatch).temple_definition().POINTS[match_controller.goal_index(actor.team)]
		for candidate: TempleJumpPad in match_controller.arena.builder.pads:
			if actor.global_position.distance_to(candidate.global_position)>32: continue
			if candidate.spec.destination.distance_to(goal_at)>candidate.global_position.distance_to(goal_at)+8: continue
			if not (flanker or brain.hero_profile.mobility >= .6) and candidate.spec.destination.distance_to(goal_at) > actor.global_position.distance_to(goal_at)-20: continue
			selected_pad = candidate
			pad_phase = "approach"
			pad_timeout = 12
			destination = candidate.global_position
			return
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
		var kind: String = "main"
		if flanker:
			# Prefer the route that suits the hero's range, then alternate so both flanks see use.
			var preferred: String = "upper" if brain.hero_profile.maximum_range >= 18 else "lower"
			var other: String = "lower" if preferred == "upper" else "upper"
			kind = other if int(route_visits.get(preferred,0)) > int(route_visits.get(other,0)) else preferred
			# With two flankers, the second takes the opposite flank to the first.
			if is_instance_valid(brain.director) and brain.director.flankers.keys().find(actor.get_instance_id()) == 1: kind = "lower" if kind == "upper" else "upper"
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
		assignment = "flank_"+route_key if not route_key.contains("main") else "attack"
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
		if flanker and brain.hero_profile.maximum_range >= 18 and session.objective.owners[goal] == actor.team:
			destination = d.POINTS[goal]+Vector3(0,8,26 if actor.team==0 else -26)
			assignment = "gallery_defense"
			if actor.global_position.distance_to(destination)<5: gallery_visits += 1
	destination = NavigationServer3D.map_get_closest_point(navagent.get_navigation_map(),destination)
