class_name CombatResolver
extends Node

signal event_logged(entry: Dictionary)
signal confirmed_hit(source: HeroActor, target: HeroActor, amount: float, head: bool, executed: bool)
signal confirmed_heal(source: HeroActor, target: HeroActor, amount: float)
signal confirmed_block(attacker: HeroActor, defender: HeroActor)
var events: Array[Dictionary] = []
var cast_serial: int = 0
var resolved: Dictionary = {}
var cast_powers: Dictionary = {}

func _ready() -> void:
	add_to_group("combat_resolver")

func new_cast(source: HeroActor = null) -> int:
	cast_serial += 1
	cast_powers.erase(cast_serial - 16384)
	cast_powers[cast_serial] = source.benefits.damage_multiplier() if is_instance_valid(source) and source.benefits != null else 1.0
	return cast_serial

func cast_multiplier(id: int, _source: HeroActor) -> float:
	return float(cast_powers.get(id,1.0))

func record(kind: String, actor: HeroActor, ability: String, details: String = "") -> void:
	var entry: Dictionary = {"tick": Engine.get_physics_frames(), "event": kind,
		"actor": actor.actor_id if is_instance_valid(actor) else "world",
		"ability": ability, "details": details}
	events.append(entry)
	if events.size() > 200:
		events.pop_front()
	event_logged.emit(entry)

func is_front(target: HeroActor, source_position: Vector3) -> bool:
	var toward: Vector3 = source_position - target.global_position
	toward.y = 0.0
	var facing := Vector3(target.aim_direction.x, 0.0, target.aim_direction.z).normalized()
	return facing.dot(toward.normalized()) > 0.35

func protected_room(actor: HeroActor) -> bool:
	var city: Node = get_tree().get_first_node_in_group("city_match")
	return actor.spawn_protected or (city != null and city.is_protected(actor))

func damage(source: HeroActor, target: HeroActor, base: float, tag: String, cast_id: int,
		head: bool = false, execute: bool = false, incoming_from: Vector3 = Vector3.INF) -> String:
	if not is_instance_valid(source) or not is_instance_valid(target) or not target.alive:
		return "invalid"
	if source.team == target.team or target.invulnerable:
		return "immune"
	# Query positions at the authority boundary, including attacks already in flight.
	if protected_room(source) or protected_room(target):
		return "immune"
	var key: String = "%d:%d" % [cast_id, target.get_instance_id()]
	if resolved.has(key):
		return "duplicate"
	var source_position: Vector3 = source.global_position if incoming_from == Vector3.INF else incoming_from
	var frontal: bool = is_front(target, source_position)
	if target.state == "deflect" and frontal and tag in ["rifle", "ultimate", "projectile", "shotgun", "knife", "axe", "cannon", "sidearm"]:
		record("deflect", target, tag)
		return "deflect"
	resolved[key] = true
	if resolved.size() > 4096:
		resolved.clear()
	if target.state == "guard" and frontal and tag in ["melee", "boot", "march"]:
		target.close.guard_meter = maxf(0.0, target.close.guard_meter - target.tuning.guard_cost)
		source.close.stagger()
		record("block", target, tag)
		if target.close.guard_meter <= 0.0:
			target.close.stagger()
		confirmed_block.emit(source, target)
		return "blocked"
	var amount: float = base * (1.0 if tag == "bleed" else cast_multiplier(cast_id,source))
	var executed: bool = execute and target.shields <= 0.0 and target.health / target.tuning.max_health <= source.tuning.execute_threshold
	if executed:
		amount = target.health
	if target.state in ["captured", "throw_pair"] and tag != "throw":
		amount *= target.tuning.throw_outside_multiplier
		# Execution is still subject to the paired sequence's ordinary mitigation.
		executed = false
	if target.state == "guard" and frontal and tag in ["rifle", "projectile", "shotgun", "knife", "axe", "cannon", "sidearm"]:
		amount *= 1.0 - target.tuning.bullet_guard_reduction
	amount *= 1.0 - target.benefits.reduction()
	if executed and amount < target.health: executed = false
	var absorbed: float = minf(target.shields, amount)
	target.shields -= absorbed
	var hp_damage: float = minf(target.health, maxf(0.0, amount - absorbed))
	target.health = maxf(0.0, target.health - hp_damage)
	source.kit.ultimate_charge = minf(100.0, source.kit.ultimate_charge + minf(base,hp_damage + absorbed) * 0.09)
	target.on_damage(hp_damage + absorbed, head)
	if source.tuning is SlayerTuning and hp_damage + absorbed > 0.0:
		target.statuses.mark(source,(source.tuning as SlayerTuning).mark_duration)
	record("execution" if executed else "damage", source, tag,
		"target=%s cast=%d base=%.1f applied=%.1f head=%s" % [target.actor_id, cast_id, base, hp_damage + absorbed, head])
	confirmed_hit.emit(source, target, hp_damage + absorbed, head, executed)
	return "execution" if executed else "hit"

func knockback(source: HeroActor, target: HeroActor, impulse: Vector3, tag: String) -> void:
	if not target.alive or target.invulnerable or source.team == target.team or protected_room(source) or protected_room(target): return
	if target.state in ["captured", "throw_pair"]: return
	if target.motor.traversal.active: target.motor.traversal.abort()
	if impulse.y > 0:
		# Upward launches use normal gravity, not the horizontal shove's braking.
		# Interrupt a competing mobility override without adding a control lock.
		target.motor.interrupt_mobility()
		if target.state in ["doctor_call","marshal_march"]: target.kit.cancel()
		target.velocity.y = maxf(target.velocity.y,impulse.y)
		impulse.y = 0
	target.motor.external_velocity += impulse
	record("displacement",source,tag,"target=%s speed=%.1f" % [target.actor_id,impulse.length()])

func ray(from: Vector3, to: Vector3, exclude: Array[RID] = [], mask: int = 19) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	return get_viewport().world_3d.direct_space_state.intersect_ray(query)

func visible(from: Vector3, target: HeroActor, exclude: Array[RID] = []) -> bool:
	var hit: Dictionary = ray(from, target.global_position + Vector3.UP, exclude)
	return hit.is_empty() or hit.get("collider") == target

func clear_round() -> void:
	resolved.clear()
	cast_powers.clear()


func heal(source: HeroActor, target: HeroActor, amount: float, tag: String) -> float:
	if not is_instance_valid(source) or not is_instance_valid(target) or not source.alive or not target.alive or source.team != target.team or amount <= 0: return 0.0
	if protected_room(source) or protected_room(target): return 0.0
	var restored: float = minf(amount,maxf(0,target.effective_max_health() - target.health))
	if restored <= 0: return 0.0
	target.health += restored
	source.kit.ultimate_charge = minf(100,source.kit.ultimate_charge + restored * .06)
	confirmed_heal.emit(source,target,restored)
	# Beam ticks would otherwise crowd out useful combat history every frame.
	if tag not in ["attending_care","aftercare","ward"]: record("heal",source,tag,"target=%s applied=%.1f" % [target.actor_id,restored])
	return restored

func barrier_ray(source: HeroActor, from: Vector3, to: Vector3) -> Dictionary:
	var result: Dictionary = {}
	var distance: float = INF
	for barrier: MarshalBarrier in get_tree().get_nodes_in_group("barriers"):
		if not is_instance_valid(barrier.source) or barrier.source.team == source.team: continue
		var hit: Dictionary = barrier.intersection(from,to)
		if not hit.is_empty() and from.distance_squared_to(hit.position) < distance:
			result = hit
			distance = from.distance_squared_to(hit.position)
	return result

func attack_ray(source: HeroActor, from: Vector3, to: Vector3, exclude: Array[RID] = [], mask: int = 19) -> Dictionary:
	var hit: Dictionary = ray(from,to,exclude,mask)
	var end: Vector3 = hit.get("position",to)
	var shield: Dictionary = barrier_ray(source,from,end)
	return shield if not shield.is_empty() else hit

func splash(source: HeroActor, origin: Vector3, radius: float, amount: float, tag: String, id: int, falloff: bool = false) -> void:
	# Snapshot cover before changing any durability: a breaking shield still stops this blast.
	var victims: Array[HeroActor] = []
	for target: HeroActor in get_tree().get_nodes_in_group("actors"):
		if not target.alive or target.team == source.team: continue
		var to: Vector3 = target.global_position + Vector3.UP * .9
		if origin.distance_to(to) <= radius and attack_ray(source,origin,to,[],1).is_empty(): victims.append(target)
	# Damage nearby barriers once even when nobody stands behind them.
	for barrier: MarshalBarrier in get_tree().get_nodes_in_group("barriers"):
		if not barrier.active() or barrier.source.team == source.team: continue
		var local: Vector3 = barrier.frame().affine_inverse() * origin
		var t := barrier.source.tuning as MarshalTuning
		var nearest: Vector3 = barrier.frame() * Vector3(clampf(local.x,-t.barrier_width/2,t.barrier_width/2),clampf(local.y,-t.barrier_height/2,t.barrier_height/2),0)
		if origin.distance_to(nearest) <= radius and ray(origin,nearest,[],1).is_empty(): barrier.receive_damage(source,amount,id)
	for target: HeroActor in victims:
		var distance: float = origin.distance_to(target.global_position + Vector3.UP * .9)
		damage(source,target,amount * (maxf(0,1-distance/radius) if falloff else 1.0),tag,id,false,false,origin)
