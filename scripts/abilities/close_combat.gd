class_name CloseCombat
extends Node

var actor: HeroActor
var guard_meter: float = 100.0
var guard_cd: float = 0.0
var stagger_scale: float = 1.0
var grace: float = 0.0
var last_throw_time: float = -100.0
var cast_id: int = 0
var pair: HeroActor
var pair_owner: bool = false
var pair_damage_done: bool = false
var throw_target: HeroActor
var sequence: ThrowSequence
var pair_progress: float = 0.0
var melee_age: float = 0.0
var melee_direction: Vector3 = Vector3.FORWARD
var melee_airborne: bool = false
var melee_fall_speed: float = 0.0
var lunge_blocked: bool = false
var melee_lunge_enabled: bool = true
var guard_age: float = 0
var parry_left: float = 0
var notice: String = ""
var notice_left: float = 0
var melee_wall_hit: bool = false
var throw_age: float = 0
var throw_direction: Vector3 = Vector3.FORWARD

func tick(delta: float, input: CombatIntent) -> void:
	var t: HeroTuning = actor.tuning
	guard_cd = maxf(0.0, guard_cd - delta)
	grace = maxf(0.0, grace - delta)
	parry_left = maxf(0,parry_left-delta)
	notice_left = maxf(0,notice_left-delta)
	var action: bool = input.melee or input.throw_action or input.primary or input.primary_held or input.secondary_pressed or input.reload or input.dash or input.jump or input.hover or input.deflect or input.bomb or input.ultimate
	if action or actor.state not in ["ready","guard"]: parry_left = 0
	if actor.state == "guard" and action:
		actor.state = "ready"
		guard_cd = t.guard_cooldown
		guard_age = 0
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
		guard_age += delta
		guard_meter = maxf(0.0, guard_meter - t.guard_drain * delta)
		if not input.guard or guard_meter <= 0.0:
			if not input.guard and guard_meter > 0 and guard_age >= .05 and not action:
				parry_left = .12
				actor.presentation.combat_feedback("parry_release")
			actor.state = "ready"
			guard_cd = t.guard_cooldown
	elif input.guard and guard_meter > 10.0 and guard_cd <= 0.0 and actor.permits("guard"):
		actor.state = "guard"
		guard_age = 0
		parry_left = 0
		actor.resolver.record("cast", actor, "guard")
	if input.melee and actor.permits("melee"):
		actor.motor.end_hover()
		actor.motor.transition("ground" if actor.is_on_floor() else "air")
		actor.state = "melee_windup"
		actor.state_time = t.melee_windup
		melee_direction = input.aim.normalized()
		if melee_direction.length_squared() < 0.1:
			melee_direction = -actor.global_basis.z
		melee_age = 0.0
		lunge_blocked = false
		melee_wall_hit = false
		melee_lunge_enabled = not input.stationary_melee
		melee_airborne = not actor.motor.grounded() and melee_lunge_enabled
		melee_fall_speed = 0
		cast_id = actor.resolver.new_cast(actor)
		actor.resolver.record("cast", actor, "melee")
		actor.presentation.combat_feedback("melee_windup")
	if actor.state.begins_with("melee_"):
		# The lunge begins after its delay, even while damage windup continues.
		if melee_age < t.melee_lunge_delay and not input.aim.is_zero_approx():
			melee_direction = input.aim.normalized()
			actor.aim_direction = melee_direction
		melee_age += delta
		if melee_age-delta < t.melee_lunge_delay and melee_age >= t.melee_lunge_delay:
			actor.movement_confirmed.emit("melee",actor.body_point(1.1),melee_direction,Vector3.UP,1)
	match actor.state:
		"melee_windup":
			if actor.state_time <= 0.0:
				actor.state = "melee_active"
				actor.state_time = t.melee_active
				actor.presentation.combat_feedback("melee_swing")
		"melee_active":
			if not melee_wall_hit:
				var wall: Dictionary = actor.resolver.ray(actor.body_point(1.1),actor.body_point(1.1)+melee_direction*t.melee_range,[actor.get_rid()],1)
				if not wall.is_empty():
					melee_wall_hit = true
					actor.presentation.combat_feedback("wall_clang",wall.position)
			for structure: CombatStructure in actor.get_tree().get_nodes_in_group("structures"):
				var point: Vector3 = structure.nearest_point(actor.body_point(1))
				var offset: Vector3 = point-actor.body_point(1)
				if offset.length() <= t.melee_range and offset.normalized().dot(melee_direction) > .35:
					var hit: Dictionary = actor.resolver.ray(actor.body_point(1),point,[actor.get_rid()],1)
					if hit.is_empty() or hit.get("collider") == structure: structure.receive_damage(actor,t.melee_damage,cast_id)
			for target: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
				if valid_melee_target(target):
					var counter: bool = target.state == "throw_startup"
					var result: String = actor.resolver.damage(actor, target, t.melee_damage, "melee", cast_id)
					if result == "hit":
						actor.resolver.knockback(actor,target,(melee_direction*Vector3(1,0,1)).normalized()*3,"melee")
						actor.presentation.combat_feedback("melee_hit",target.body_point(1.1))
						if counter:
							target.close.interrupt_startup()
							notice = "COUNTER HIT"
							notice_left = .65
							actor.presentation.combat_feedback("counter_hit",target.body_point(1.1))
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
			if not is_instance_valid(pair) or not pair.alive or sequence == null:
				release_pair()
			else:
				pair_progress = clampf(1.0 - actor.state_time / t.throw_duration, 0.0, 1.0)
				pair.close.pair_progress = pair_progress
				if not sequence.advance(pair_progress):
					actor.resolver.record("interrupt", actor, "throw", "path obstructed")
					release_pair()
					return
				if not pair_damage_done and pair_progress >= sequence.impact:
					pair_damage_done = true
					actor.presentation.slam_impact(sequence.landing)
					pair.presentation.combat_feedback("throw_landing",sequence.landing)
					actor.resolver.damage(actor, pair, t.throw_damage, "throw", cast_id)
				if actor.state == "throw_pair" and actor.state_time <= 0.0:
					release_pair()

func lunge_displacement(delta: float) -> Vector3:
	if lunge_blocked or not melee_lunge_enabled:
		return Vector3.ZERO
	var t: HeroTuning = actor.tuning
	var end: float = t.melee_lunge_delay + maxf(0.01, t.melee_lunge_duration)
	# A stronger exponent exceeds the shared speed cap and silently clips the
	# integrated distance. Keep peak speed below 26 m/s at the default tuning.
	var current: float = pow(smoothstep(t.melee_lunge_delay, end, melee_age),1.15)
	var previous: float = pow(smoothstep(t.melee_lunge_delay, end, maxf(0.0, melee_age - delta)),1.15)
	return melee_motion_direction() * (current - previous) * t.melee_lunge_distance

func melee_motion_direction() -> Vector3:
	if melee_airborne: return melee_direction
	var flat: Vector3 = melee_direction * Vector3(1,0,1)
	return flat.normalized() if not flat.is_zero_approx() else -actor.global_basis.z

func melee_progress() -> float:
	var t: HeroTuning = actor.tuning
	return clampf(melee_age / (t.melee_windup + t.melee_active + t.melee_recovery), 0, 1)

func valid_melee_target(target: HeroActor) -> bool:
	if target == actor or not target.alive or target.team == actor.team or target.state == "wisp_phase": return false
	if actor.resolver.attack_locked(actor) or actor.resolver.protected_room(target): return false
	var offset: Vector3 = target.body_point(1)-actor.body_point(1)
	return offset.length() <= actor.tuning.melee_range and offset.normalized().dot(melee_direction) >= .35 and actor.resolver.visible(actor.body_point(1),target,[actor.get_rid()])

func valid_target(target: HeroActor, reach: float, facing: float) -> bool:
	if target == actor or not target.alive or target.team == actor.team or target.state == "wisp_phase":
		return false
	if actor.resolver.attack_locked(actor) or actor.resolver.protected_room(target):
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
	throw_age = 0
	throw_direction = (actor.aim_direction*Vector3(1,0,1)).normalized()
	cast_id = actor.resolver.new_cast(actor)
	throw_target = select_throw_target()
	actor.resolver.record("cast", actor, "throw")

func resolve_throw() -> void:
	var target: HeroActor = throw_target
	throw_target = null
	if not throw_eligible(target): target = select_throw_target()
	if not is_instance_valid(target) or not valid_target(target, actor.tuning.throw_range, 0.65) or target.state in ["captured", "throw_pair"] or target.close.grace > 0.0:
		actor.state = "throw_whiff"
		actor.state_time = actor.tuning.throw_recovery
		return
	var now: float = float(Engine.get_physics_frames()) / Engine.physics_ticks_per_second
	var simultaneous: bool = target.state == "throw_startup" and target.close.throw_target == actor
	if simultaneous or now - target.close.last_throw_time <= actor.tuning.counter_window:
		counter_break(target)
		return
	var path := ThrowSequence.new()
	if not path.configure(actor, target):
		actor.state = "throw_whiff"
		actor.state_time = actor.tuning.throw_recovery
		return
	var shield_broken: bool = target.state == "guard"
	target.close.cancel()
	target.kit.cancel()
	target.motor.end_hover()
	actor.motor.end_hover()
	actor.motor.transition("ground" if actor.is_on_floor() else "air")
	target.motor.transition("ground" if target.is_on_floor() else "air")
	sequence = path
	actor.aim_direction = path.forward
	target.aim_direction = -path.forward
	actor.rotation.y = atan2(-path.forward.x, -path.forward.z)
	target.rotation.y = atan2(path.forward.x, path.forward.z)
	actor.state = "throw_pair"
	target.state = "captured"
	actor.state_time = actor.tuning.throw_duration
	pair = target
	target.close.pair = actor
	pair_owner = true
	target.close.pair_owner = false
	pair_damage_done = false
	pair_progress = 0.0
	target.close.pair_progress = 0.0
	actor.velocity = Vector3.ZERO
	target.velocity = Vector3.ZERO
	actor.resolver.record("capture", actor, "throw", "target=" + target.actor_id)
	actor.presentation.combat_feedback("throw_lift")
	target.presentation.combat_feedback("throw_caught")
	if shield_broken: target.presentation.combat_feedback("shield_break")

func throw_eligible(target: HeroActor) -> bool:
	return is_instance_valid(target) and target.state not in ["captured","throw_pair","boot_attached","boot_captured"] and target.close.grace <= 0 and not target.damage_immune() and valid_target(target,actor.tuning.throw_range,.65)

func select_throw_target() -> HeroActor:
	var result: HeroActor = null
	var nearest: float = INF
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if not throw_eligible(other): continue
		var distance: float = actor.global_position.distance_squared_to(other.global_position)
		if distance < nearest:
			nearest = distance
			result = other
	return result

func throw_displacement(delta: float) -> Vector3:
	var before: float = throw_age
	throw_age = minf(actor.tuning.throw_startup,throw_age+delta)
	return throw_direction*actor.tuning.throw_approach*(smoothstep(0,actor.tuning.throw_startup,throw_age)-smoothstep(0,actor.tuning.throw_startup,before))

func counter_break(target: HeroActor) -> void:
	actor.state = "counterthrow"
	target.state = "counterthrow"
	actor.state_time = 0.22
	target.state_time = 0.22
	var away: Vector3 = ((actor.global_position-target.global_position)*Vector3(1,0,1)).normalized()*3
	actor.velocity.x = 0
	actor.velocity.z = 0
	target.velocity.x = 0
	target.velocity.z = 0
	actor.motor.external_velocity += away
	target.motor.external_velocity -= away
	grace = actor.tuning.throw_grace
	target.close.grace = target.tuning.throw_grace
	target.close.throw_target = null
	actor.resolver.record("counterthrow", target, "throw")
	actor.presentation.combat_feedback("throw_clash")
	target.presentation.combat_feedback("throw_clash")

func interrupt_startup() -> void:
	throw_target = null
	actor.state = "throw_whiff"
	actor.state_time = actor.tuning.throw_recovery
	actor.resolver.record("interrupt", actor, "throw")

func stagger(source: HeroActor = null) -> void:
	var duration: float = actor.tuning.stagger_duration
	stagger_scale = 1.0
	if is_instance_valid(source) and source.team != actor.team:
		if actor.damage_immune() or actor.resolver.protected_room(actor): return
		duration = actor.statuses.hard_duration("stagger",duration)
		stagger_scale = actor.statuses.last_disable_scale
		if duration <= 0: return
	if actor.boot_pair != null: actor.boot_pair.release(false)
	cancel()
	actor.kit.cancel()
	actor.motor.end_hover()
	actor.state = "stagger"
	actor.state_time = duration
	actor.velocity.x = 0.0
	actor.velocity.z = 0.0
	actor.resolver.record("status", actor, "stagger")

func release_pair() -> void:
	var other: HeroActor = pair
	var completed: bool = pair_owner and pair_damage_done and actor.state_time <= 0
	if sequence != null:
		sequence.separate_on_release()
		sequence.cleanup()
		sequence = null
	pair = null
	pair_owner = false
	grace = actor.tuning.throw_grace
	if actor.alive and actor.state in ["captured", "throw_pair"]:
		actor.state = "throw_release"
		actor.state_time = 0.0
	if is_instance_valid(other):
		other.close.pair = null
		other.close.pair_owner = false
		if other.close.sequence != null:
			other.close.sequence.separate_on_release()
			other.close.sequence.cleanup()
			other.close.sequence = null
		other.close.grace = other.tuning.throw_grace
		other.close.pair_progress = 0.0
		if other.alive and other.state in ["captured", "throw_pair"]:
			other.state = "throw_release"
			other.state_time = 0.0
			if completed:
				other.state_time = other.statuses.hard_duration("stun",actor.tuning.throw_release_stun)
				other.close.stagger_scale = other.statuses.last_disable_scale
	pair_progress = 0.0

func cancel() -> void:
	parry_left = 0
	guard_age = 0
	throw_age = 0
	notice_left = 0
	if is_instance_valid(pair):
		release_pair()
	throw_target = null
	lunge_blocked = true
	melee_age = 0.0
	if actor.state == "guard":
		guard_cd = actor.tuning.guard_cooldown
	if actor.alive:
		actor.state = "ready"

func refill() -> void:
	parry_left = 0
	guard_age = 0
	notice_left = 0
	guard_meter = 100.0
	guard_cd = 0.0
	grace = 0.0
	last_throw_time = -100.0
