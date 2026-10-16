class_name CloseCombat
extends Node

var actor: HeroActor
var guard_meter: float = 100.0
var guard_cd: float = 0.0
var grace: float = 0.0
var last_throw_time: float = -100.0
var cast_id: int = 0
var pair: HeroActor
var pair_owner: bool = false
var pair_damage_done: bool = false
var throw_target: HeroActor

func tick(delta: float, input: CombatIntent) -> void:
	var t: HeroTuning = actor.tuning
	guard_cd = maxf(0.0, guard_cd - delta)
	grace = maxf(0.0, grace - delta)
	if actor.infinite_resources:
		guard_cd = 0.0
	if actor.state != "guard":
		guard_meter = minf(100.0, guard_meter + t.guard_regen * delta)
	if input.throw_action and actor.permits("counter"):
		last_throw_time = float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
		if incoming_throw() != null:
			actor.resolver.record("counter_input", actor, "throw")
		else:
			start_throw()
	if actor.state == "guard":
		guard_meter = maxf(0.0, guard_meter - t.guard_drain * delta)
		if not input.guard or guard_meter <= 0.0:
			actor.state = "ready"
			guard_cd = t.guard_cooldown
	elif input.guard and guard_meter > 10.0 and guard_cd <= 0.0 and actor.permits("guard"):
		actor.state = "guard"
		actor.resolver.record("cast", actor, "guard")
	if input.melee and actor.permits("melee"):
		actor.state = "melee_windup"
		actor.state_time = t.melee_windup
		cast_id = actor.resolver.new_cast()
		actor.resolver.record("cast", actor, "melee")
	match actor.state:
		"melee_windup":
			if actor.state_time <= 0.0:
				actor.state = "melee_active"
				actor.state_time = t.melee_active
		"melee_active":
			for target: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
				if valid_target(target, t.melee_range, 0.35):
					actor.resolver.damage(actor, target, t.melee_damage, "melee", cast_id)
					if actor.state == "stagger":
						break
			if actor.state == "melee_active" and actor.state_time <= 0.0:
				actor.state = "melee_recovery"
				actor.state_time = t.melee_recovery
		"melee_recovery", "throw_whiff":
			if actor.state_time <= 0.0:
				actor.state = "ready"
		"throw_startup":
			if actor.state_time <= 0.0:
				resolve_throw()
		"throw_pair":
			if not is_instance_valid(pair) or not pair.alive:
				release_pair()
			elif not pair_damage_done and actor.state_time <= t.throw_duration * 0.35:
				pair_damage_done = true
				actor.resolver.damage(actor, pair, t.throw_damage, "throw", cast_id)
			if actor.state_time <= 0.0:
				release_pair()

func valid_target(target: HeroActor, reach: float, facing: float) -> bool:
	if target == actor or not target.alive or target.team == actor.team:
		return false
	var offset: Vector3 = target.global_position - actor.global_position
	if offset.length() > reach or absf(offset.y) > 1.5:
		return false
	var flat := Vector3(offset.x, 0.0, offset.z).normalized()
	var forward := Vector3(actor.aim_direction.x, 0.0, actor.aim_direction.z).normalized()
	return flat.dot(forward) >= facing and actor.resolver.visible(actor.global_position + Vector3.UP, target, [actor.get_rid()])

func incoming_throw() -> HeroActor:
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if other != actor and other.state == "throw_startup" and other.close.throw_target == actor:
			return other
	return null

func start_throw() -> void:
	if not actor.permits("throw") or grace > 0.0:
		return
	last_throw_time = float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
	actor.state = "throw_startup"
	actor.state_time = actor.tuning.throw_startup
	cast_id = actor.resolver.new_cast()
	throw_target = null
	var nearest: float = actor.tuning.throw_range
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if valid_target(other, nearest, 0.65) and other.close.grace <= 0.0:
			throw_target = other
			nearest = actor.global_position.distance_to(other.global_position)
	actor.resolver.record("cast", actor, "throw")

func resolve_throw() -> void:
	var target: HeroActor = throw_target
	throw_target = null
	if not is_instance_valid(target) or not valid_target(target, actor.tuning.throw_range, 0.65) or target.state in ["captured", "throw_pair"] or target.close.grace > 0.0:
		actor.state = "throw_whiff"
		actor.state_time = actor.tuning.throw_recovery
		return
	var now: float = float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
	var simultaneous: bool = target.state == "throw_startup" and target.close.throw_target == actor
	if simultaneous or now - target.close.last_throw_time <= actor.tuning.counter_window:
		counter_break(target)
		return
	# Test a full capsule path to the paired position before granting mitigation.
	var offset: Vector3 = target.global_position - actor.global_position
	offset.y = 0.0
	var desired: Vector3 = actor.global_position + offset.normalized() * 1.05
	if target.test_move(target.global_transform, desired - target.global_position):
		actor.state = "throw_whiff"
		actor.state_time = actor.tuning.throw_recovery
		return
	target.close.cancel()
	target.kit.cancel()
	target.motor.end_hover()
	actor.motor.end_hover()
	target.global_position = desired
	actor.state = "throw_pair"
	target.state = "captured"
	actor.state_time = actor.tuning.throw_duration
	pair = target
	target.close.pair = actor
	pair_owner = true
	target.close.pair_owner = false
	pair_damage_done = false
	actor.velocity = Vector3.ZERO
	target.velocity = Vector3.ZERO
	actor.resolver.record("capture", actor, "throw", "target=" + target.actor_id)

func counter_break(target: HeroActor) -> void:
	actor.state = "counterthrow"
	target.state = "counterthrow"
	actor.state_time = 0.22
	target.state_time = 0.22
	actor.velocity = (actor.global_position - target.global_position).normalized() * 3.0
	target.velocity = -actor.velocity
	grace = actor.tuning.throw_grace
	target.close.grace = target.tuning.throw_grace
	target.close.throw_target = null
	actor.resolver.record("counterthrow", target, "throw")

func interrupt_startup() -> void:
	throw_target = null
	actor.state = "throw_whiff"
	actor.state_time = actor.tuning.throw_recovery
	actor.resolver.record("interrupt", actor, "throw")

func stagger() -> void:
	cancel()
	actor.kit.cancel()
	actor.motor.end_hover()
	actor.state = "stagger"
	actor.state_time = actor.tuning.stagger_duration
	actor.resolver.record("status", actor, "stagger")

func release_pair() -> void:
	var other: HeroActor = pair
	pair = null
	pair_owner = false
	grace = actor.tuning.throw_grace
	if actor.alive and actor.state in ["captured", "throw_pair"]:
		actor.state = "throw_release"
		actor.state_time = 0.0
	if is_instance_valid(other):
		other.close.pair = null
		other.close.pair_owner = false
		other.close.grace = other.tuning.throw_grace
		if other.alive and other.state in ["captured", "throw_pair"]:
			other.state = "throw_release"
			other.state_time = 0.0
	# Both capsules stay at their last validated, non-overlapping positions.

func cancel() -> void:
	if is_instance_valid(pair):
		release_pair()
	throw_target = null
	if actor.state == "guard":
		guard_cd = actor.tuning.guard_cooldown
	if actor.alive:
		actor.state = "ready"

func refill() -> void:
	guard_meter = 100.0
	guard_cd = 0.0
	grace = 0.0
	last_throw_time = -100.0
