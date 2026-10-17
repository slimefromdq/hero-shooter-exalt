class_name CombatResolver
extends Node

signal event_logged(entry: Dictionary)
signal confirmed_hit(source: HeroActor, target: HeroActor, amount: float, head: bool, executed: bool)
signal confirmed_block(attacker: HeroActor, defender: HeroActor)
var events: Array[Dictionary] = []
var cast_serial: int = 0
var resolved: Dictionary = {}

func _ready() -> void:
	add_to_group("combat_resolver")

func new_cast() -> int:
	cast_serial += 1
	return cast_serial

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

func damage(source: HeroActor, target: HeroActor, base: float, tag: String, cast_id: int,
		head: bool = false, execute: bool = false, incoming_from: Vector3 = Vector3.INF) -> String:
	if not is_instance_valid(source) or not is_instance_valid(target) or not target.alive:
		return "invalid"
	if source.team == target.team or target.invulnerable:
		return "immune"
	var key: String = "%d:%d" % [cast_id, target.get_instance_id()]
	if resolved.has(key):
		return "duplicate"
	var source_position: Vector3 = source.global_position if incoming_from == Vector3.INF else incoming_from
	var frontal: bool = is_front(target, source_position)
	if target.state == "deflect" and frontal and tag in ["rifle", "ultimate", "projectile"]:
		record("deflect", target, tag)
		return "deflect"
	resolved[key] = true
	if resolved.size() > 4096:
		resolved.clear()
	if target.state == "guard" and frontal and tag == "melee":
		target.close.guard_meter = maxf(0.0, target.close.guard_meter - target.tuning.guard_cost)
		source.close.stagger()
		record("block", target, tag)
		if target.close.guard_meter <= 0.0:
			target.close.stagger()
		confirmed_block.emit(source, target)
		return "blocked"
	var amount: float = base
	var executed: bool = execute and target.shields <= 0.0 and target.health / target.tuning.max_health <= source.tuning.execute_threshold
	if executed:
		amount = target.health
	if target.state in ["captured", "throw_pair"] and tag != "throw":
		amount *= target.tuning.throw_outside_multiplier
		# Execution is still subject to the paired sequence's ordinary mitigation.
		executed = false
	if target.state == "guard" and frontal and tag in ["rifle", "projectile"]:
		amount *= 1.0 - target.tuning.bullet_guard_reduction
	var absorbed: float = minf(target.shields, amount)
	target.shields -= absorbed
	var hp_damage: float = minf(target.health, maxf(0.0, amount - absorbed))
	target.health = maxf(0.0, target.health - hp_damage)
	source.kit.ultimate_charge = minf(100.0, source.kit.ultimate_charge + (hp_damage + absorbed) * 0.09)
	target.on_damage(hp_damage + absorbed, head)
	record("execution" if executed else "damage", source, tag,
		"target=%s cast=%d base=%.1f applied=%.1f head=%s" % [target.actor_id, cast_id, base, hp_damage + absorbed, head])
	confirmed_hit.emit(source, target, hp_damage + absorbed, head, executed)
	return "execution" if executed else "hit"

func ray(from: Vector3, to: Vector3, exclude: Array[RID] = [], mask: int = 3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
	return get_viewport().world_3d.direct_space_state.intersect_ray(query)

func visible(from: Vector3, target: HeroActor, exclude: Array[RID] = []) -> bool:
	var hit: Dictionary = ray(from, target.global_position + Vector3.UP, exclude)
	return hit.is_empty() or hit.get("collider") == target

func clear_round() -> void:
	resolved.clear()
