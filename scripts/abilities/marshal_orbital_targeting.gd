class_name MarshalOrbitalTargeting
extends RefCounted
## A committed lane projected onto walkable terrain, never an airborne explosion ray.
static func ground(actor: HeroActor, candidate: Vector3) -> Dictionary:
	var t := actor.tuning as MarshalTuning
	var hit: Dictionary = actor.resolver.ray(candidate+Vector3.UP*t.orbital_probe_rise,candidate+Vector3.DOWN*t.orbital_probe_drop,[],1)
	if hit.is_empty() or hit.normal.y < cos(actor.floor_max_angle): return {}
	return hit

static func open_sky(actor: HeroActor, at: Vector3, normal: Vector3) -> bool:
	var t := actor.tuning as MarshalTuning
	if not actor.resolver.ray(at+normal*.08,at+Vector3.UP*t.orbital_sky_height,[],1).is_empty(): return false
	# Sweep the rendered column's width too, so a roof edge cannot clip its sides.
	var sphere := SphereShape3D.new()
	sphere.radius = t.orbital_column_clearance
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1
	query.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*(sphere.radius/maxf(.1,normal.y)+.08))
	query.motion = Vector3.UP*t.orbital_sky_height
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	return space.intersect_shape(query,1).is_empty() and space.cast_motion(query)[0] >= .999
static func plan(actor: HeroActor, origin: Vector3, aim: Vector3) -> Array[Dictionary]:
	var t := actor.tuning as MarshalTuning
	var result: Array[Dictionary] = []
	var flat: Vector3 = (aim*Vector3(1,0,1)).normalized()
	if flat.is_zero_approx(): flat = -actor.global_basis.z
	var previous: Vector3 = origin
	for index: int in t.breach_count:
		var distance: float = (index+1)*t.breach_spacing
		var candidate: Vector3 = origin+flat*distance
		candidate.y = previous.y
		var surface: Dictionary = ground(actor,candidate)
		if surface.is_empty(): break
		var at: Vector3 = surface.position
		var lane: Dictionary = actor.resolver.attack_ray(actor,previous+Vector3.UP*.9,at+Vector3.UP*.9,[actor.get_rid()],1)
		var stop: bool = not lane.is_empty()
		if stop:
			surface = ground(actor,lane.position-flat*(t.orbital_column_clearance+.08))
			if surface.is_empty(): break
			at = surface.position
		var valid: bool = open_sky(actor,at,surface.normal)
		result.append({"position":at,"normal":surface.normal,"valid":valid,"stop":stop,"delay":t.breach_warning+index*t.breach_interval})
		previous = at
		if stop: break
	return result

static func revalidate(actor: HeroActor, entry: Dictionary) -> bool:
	if not bool(entry.valid): return false
	# A roof, floor or lift added/moved after the marker must not receive a hidden strike.
	var hit: Dictionary = actor.resolver.ray(entry.position+Vector3.UP*.3,entry.position+Vector3.DOWN*.35,[],1)
	if hit.is_empty() or hit.position.distance_to(entry.position) > .25 or hit.normal.y < cos(actor.floor_max_angle): return false
	if not open_sky(actor,hit.position,hit.normal): return false
	entry.position = hit.position
	entry.normal = hit.normal
	return true

static func can_strike(actor: HeroActor, aim: Vector3, target: Vector3) -> bool:
	for entry: Dictionary in plan(actor,actor.global_position,aim):
		if bool(entry.valid) and Vector3(entry.position+Vector3.UP*.12).distance_to(target) <= (actor.tuning as MarshalTuning).breach_radius: return true
	return false
