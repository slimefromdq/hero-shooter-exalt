class_name CombatResolver
extends Node

signal event_logged(entry: Dictionary)
signal cast_started(source: HeroActor, id: int)
signal confirmed_hit(source: HeroActor, target: HeroActor, amount: float, head: bool, executed: bool)
signal confirmed_heal(source: HeroActor, target: HeroActor, amount: float)
signal confirmed_block(attacker: HeroActor, defender: HeroActor)
signal elimination(killer: HeroActor, victim: HeroActor, assistants: Array[HeroActor], ability: String)
const ASSIST_WINDOW: float = 8.0
var combat_time: float = 0.0
var contributions: Dictionary = {}
var damage_serial: int = 0
var events: Array[Dictionary] = []
var cast_serial: int = 0
var resolved: Dictionary = {}
var cast_powers: Dictionary = {}
var ultimate_casts: Dictionary = {}

func _ready() -> void:
	add_to_group("combat_resolver")

func _physics_process(delta: float) -> void:
	combat_time += delta

func track_damage(source: HeroActor, target: HeroActor, amount: float, tag: String) -> void:
	if amount <= 0.0: return
	var key: int = target.get_instance_id()
	if not contributions.has(key): contributions[key] = {}
	damage_serial += 1
	contributions[key][source.get_instance_id()] = {"actor": source, "time": combat_time, "ability": tag, "order": damage_serial}

func resolve_death(victim: HeroActor) -> void:
	var hits: Dictionary = contributions.get(victim.get_instance_id(), {})
	var killer: HeroActor = null
	var latest: float = -INF
	var ability: String = "world"
	var assistants: Array[HeroActor] = []
	for hit: Dictionary in hits.values():
		var source: HeroActor = hit.actor as HeroActor
		if not is_instance_valid(source) or source.team == victim.team or combat_time - float(hit.time) > ASSIST_WINDOW: continue
		assistants.append(source)
		if float(hit.order) > latest:
			latest = float(hit.order)
			killer = source
			ability = str(hit.ability)
	assistants.erase(killer)
	contributions.erase(victim.get_instance_id())
	elimination.emit(killer, victim, assistants, ability)

func new_cast(source: HeroActor = null) -> int:
	cast_serial += 1
	cast_started.emit(source,cast_serial)
	cast_powers.erase(cast_serial - 16384)
	ultimate_casts.erase(cast_serial - 16384)
	cast_powers[cast_serial] = source.benefits.damage_multiplier() if is_instance_valid(source) and source.benefits != null else 1.0
	if is_instance_valid(source) and is_instance_valid(source.kit) and source.kit.ultimate_active(): ultimate_casts[cast_serial] = true
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
	var session: Node = get_tree().get_first_node_in_group("city_match")
	# A live position query prevents one-frame lingering protection at thresholds.
	return session.is_protected(actor) if session != null else actor.spawn_protected

func attack_locked(actor: HeroActor) -> bool:
	var session: Node = get_tree().get_first_node_in_group("museum_match")
	if session != null: return session.spawn_attack_locked(actor)
	return protected_room(actor)

func spawn_door_blocks(from: Vector3, toward: Vector3) -> bool:
	for door: MuseumSpawnDoor in get_tree().get_nodes_in_group("museum_spawn_doors"):
		if door.blocks_attack(from,toward): return true
	return false

func damage(source: HeroActor, target: HeroActor, base: float, tag: String, cast_id: int,
		head: bool = false, execute: bool = false, incoming_from: Vector3 = Vector3.INF) -> String:
	if not is_instance_valid(source) or not is_instance_valid(target) or not target.alive:
		return "invalid"
	if source.team == target.team or target.invulnerable or target.state == "wisp_phase":
		return "immune"
	# Query positions at the authority boundary, including attacks already in flight.
	if attack_locked(source) or protected_room(target):
		return "immune"
	var origin: Vector3 = source.body_point(1) if incoming_from == Vector3.INF else incoming_from
	if spawn_door_blocks(origin,target.body_point(1)): return "immune"
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
	var executed: bool = execute and target.overhealth.value() <= 0.0 and target.shields <= 0.0 and target.health / target.tuning.max_health <= source.tuning.execute_threshold
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
	# Guard/mitigation first, then temporary overhealth -> personal shields -> HP.
	var temporary: float = target.overhealth.absorb(amount)
	var absorbed: float = minf(target.shields, maxf(0,amount-temporary))
	target.shields -= absorbed
	var hp_damage: float = minf(target.health, maxf(0.0, amount - temporary - absorbed))
	target.health = maxf(0.0, target.health - hp_damage)
	if not source.kit.ultimate_active() and not ultimate_casts.has(cast_id): source.kit.ultimate_charge = minf(100.0, source.kit.ultimate_charge + minf(base,hp_damage + absorbed + temporary) * 0.09)
	track_damage(source, target, hp_damage + absorbed + temporary, tag)
	target.on_damage(hp_damage + absorbed + temporary, head)
	if source.tuning is SlayerTuning and hp_damage + absorbed + temporary > 0.0:
		target.statuses.mark(source,(source.tuning as SlayerTuning).mark_duration)
	record("execution" if executed else "damage", source, tag,
		"target=%s cast=%d base=%.1f applied=%.1f head=%s overhealth=%.1f shield=%.1f hp=%.1f" % [target.actor_id, cast_id, base, hp_damage + absorbed + temporary, head, temporary, absorbed, hp_damage])
	confirmed_hit.emit(source, target, hp_damage + absorbed + temporary, head, executed)
	return "execution" if executed else "hit"

func knockback(source: HeroActor, target: HeroActor, impulse: Vector3, tag: String) -> void:
	if not target.alive or target.invulnerable or target.state == "wisp_phase" or source.team == target.team or attack_locked(source) or protected_room(target): return
	if spawn_door_blocks(source.body_point(1),target.body_point(1)): return
	if target.boot_pair != null: target.boot_pair.release(false)
	if target.state in ["captured", "throw_pair"]: return
	if target.motor.traversal.active: target.motor.traversal.abort()
	if impulse.y > 0:
		# Upward launches use normal gravity, not the horizontal shove's braking.
		# Interrupt a competing mobility override without adding a control lock.
		target.motor.interrupt_mobility()
		target.motor.voluntary_airborne = false
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
	for actor: HeroActor in get_tree().get_nodes_in_group("actors"):
		if actor.overhealth != null: actor.overhealth.clear()
	contributions.clear()
	combat_time = 0.0

	cast_powers.clear()
	ultimate_casts.clear()


func heal(source: HeroActor, target: HeroActor, amount: float, tag: String, award_charge: bool = true) -> float:
	if not is_instance_valid(source) or not is_instance_valid(target) or not source.alive or not target.alive or source.team != target.team or amount <= 0: return 0.0
	if attack_locked(source) or protected_room(target): return 0.0
	var restored: float = minf(amount,maxf(0,target.effective_max_health() - target.health))
	if restored <= 0: return 0.0
	target.health += restored
	if award_charge and not source.kit.ultimate_active(): source.kit.ultimate_charge = minf(100,source.kit.ultimate_charge + restored * .06)
	confirmed_heal.emit(source,target,restored)
	# Beam ticks would otherwise crowd out useful combat history every frame.
	if tag not in ["attending_care","aftercare","ward","regroup","drone","circuit"]: record("heal",source,tag,"target=%s applied=%.1f" % [target.actor_id,restored])
	return restored

func barrier_ray(source: HeroActor, from: Vector3, to: Vector3) -> Dictionary:
	var result: Dictionary = {}
	var distance: float = INF
	for barrier: CombatBarrier in get_tree().get_nodes_in_group("barriers"):
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

func weapon_ray(source: HeroActor, from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var ignored: Array[RID] = exclude.duplicate()
	for bomb: Node in get_tree().get_nodes_in_group("pocket_bombs"):
		if bomb.source != source or not bomb.airborne: ignored.append(bomb.get_rid())
	var hit: Dictionary = ray(from,to,ignored,51)
	var shield: Dictionary = barrier_ray(source,from,hit.get("position",to))
	return shield if not shield.is_empty() else hit

func splash(source: HeroActor, origin: Vector3, radius: float, amount: float, tag: String, id: int, falloff: bool = false, impact_damage: Dictionary = {}) -> void:
	# Snapshot cover before changing any durability: a breaking shield still stops this blast.
	var victims: Array[HeroActor] = []
	for target: HeroActor in get_tree().get_nodes_in_group("actors"):
		if not target.alive or target.team == source.team: continue
		var to: Vector3 = target.global_position + Vector3.UP * .9
		if origin.distance_to(to) <= radius and attack_ray(source,origin,to,[],1).is_empty(): victims.append(target)
	var structures: Array[CombatStructure] = []
	for structure: CombatStructure in get_tree().get_nodes_in_group("structures"):
		var at: Vector3 = structure.nearest_point(origin)
		var hit: Dictionary = ray(origin,at,[],1)
		if origin.distance_to(at) <= radius and (hit.is_empty() or hit.get("collider") == structure): structures.append(structure)
	# Damage nearby barriers once even when nobody stands behind them.
	for barrier: CombatBarrier in get_tree().get_nodes_in_group("barriers"):
		if not barrier.active() or barrier.source.team == source.team: continue
		var nearest: Vector3 = barrier.nearest_point(origin)
		if origin.distance_to(nearest) <= radius and ray(origin,nearest,[],1).is_empty(): barrier.receive_damage(source,float(impact_damage.get(barrier,amount)),id)
	for target: HeroActor in victims:
		var distance: float = origin.distance_to(target.global_position + Vector3.UP * .9)
		damage(source,target,amount * (maxf(0,1-distance/radius) if falloff else 1.0),tag,id,false,false,origin)
	# Explosive projectiles can retain stronger direct object hits without breaking
	# cover before the blast's protected victims have been snapshotted.
	for structure: CombatStructure in structures: structure.receive_damage(source,float(impact_damage.get(structure,amount)),id)

func hit_object(collider: Object, source: HeroActor, amount: float, id: int) -> void:
	if is_instance_valid(collider) and collider.has_method("receive_damage"):
		collider.receive_damage(source,amount,id)
