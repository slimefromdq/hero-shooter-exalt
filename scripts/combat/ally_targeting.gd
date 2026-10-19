class_name AllyTargeting
extends RefCounted
## Stateless acquisition only. Cast permissions, self fallback and channel retention
## belong to the kit; in particular this does not constrain ongoing drone healing.

static func sight(source: HeroActor, target: HeroActor) -> bool:
	if not is_instance_valid(source) or not is_instance_valid(target): return false
	if not target.alive or target == source or target.team != source.team: return false
	if source.resolver.protected_room(target): return false
	# Teammates do not occlude support targeting; world and hostile barriers do.
	return source.resolver.attack_ray(source,source.body_point(1.4),target.body_point(1.2),[],1).is_empty()

static func aimed(source: HeroActor, maximum: float, angle: float = 12.0) -> HeroActor:
	if not is_instance_valid(source): return null
	var best: HeroActor = null
	var score: float = cos(deg_to_rad(angle))
	var origin: Vector3 = source.intent.aim_origin
	if origin == Vector3.ZERO: origin = source.body_point(1.4)
	for other: HeroActor in source.get_tree().get_nodes_in_group("actors"):
		if source.global_position.distance_to(other.global_position) > maximum or not sight(source,other): continue
		var dot: float = (other.body_point(1.2)-origin).normalized().dot(source.aim_direction)
		if dot > score:
			score = dot
			best = other
	return best
