class_name WispBlast
extends RefCounted
## Rogue's secondary and Heist share one cover snapshot and one hit per victim.
static func multiplier(distance: float, full_radius: float, radius: float, minimum: float) -> float:
	return lerpf(1.0,minimum,clampf((distance-full_radius)/maxf(.001,radius-full_radius),0,1))

static func resolve(source: HeroActor, origin: Vector3, radius: float, full_radius: float, base: float, minimum: float, cast_id: int, tag: String) -> Dictionary:
	var result: Dictionary = {"hits":0,"cast_id":cast_id,"origin":origin}
	if not is_instance_valid(source) or not source.alive or source.resolver.attack_locked(source): return result
	var t := source.tuning as WispTuning
	var victims: Array[Dictionary] = []
	var objects: Array[Dictionary] = []
	# Snapshot every line of sight before destroying cover or changing victims.
	for target: HeroActor in source.get_tree().get_nodes_in_group("actors"):
		if not target.alive or target.team == source.team or target.damage_immune() or source.resolver.protected_room(target): continue
		var at: Vector3 = target.body_point(.9)
		var distance: float = origin.distance_to(at)
		if distance <= radius and source.resolver.attack_ray(source,origin,at,[],1).is_empty():
			victims.append({"actor":target,"damage":(base+target.statuses.soul_count(source)*t.mark_damage)*multiplier(distance,full_radius,radius,minimum)})
	for barrier: CombatBarrier in source.get_tree().get_nodes_in_group("barriers"):
		if not barrier.active() or barrier.source.team == source.team: continue
		var at: Vector3 = barrier.nearest_point(origin)
		var hit: Dictionary = source.resolver.attack_ray(source,origin,at,[],1)
		if origin.distance_to(at) <= radius and (hit.is_empty() or hit.get("collider") == barrier):
			objects.append({"object":barrier,"damage":base*multiplier(origin.distance_to(at),full_radius,radius,minimum)})
	for structure: CombatStructure in source.get_tree().get_nodes_in_group("structures"):
		var at: Vector3 = structure.nearest_point(origin)
		var hit: Dictionary = source.resolver.attack_ray(source,origin,at,[],1)
		if origin.distance_to(at) <= radius and (hit.is_empty() or hit.get("collider") == structure):
			objects.append({"object":structure,"damage":base*multiplier(origin.distance_to(at),full_radius,radius,minimum)})
	for victim: Dictionary in victims:
		var target: HeroActor = victim.actor
		var hit: String = source.resolver.damage(source,target,victim.damage,tag,cast_id,false,false,origin)
		if hit == "hit":
			target.statuses.take_souls(source)
			result.hits += 1
	for object: Dictionary in objects: source.resolver.hit_object(object.object,source,object.damage,cast_id)
	return result
