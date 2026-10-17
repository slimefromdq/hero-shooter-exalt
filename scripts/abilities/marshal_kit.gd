class_name MarshalKit
extends CareKit

var barrier: MarshalBarrier
var barrier_hp: float = 1200.0
var lowered_age: float = 0.0
var break_remaining: float = 0.0
var march_direction: Vector3
var march_left: float = 0.0
var breach_direction: Vector3
var breach_origin: Vector3
var breach_index: int = 0
var breach_age: float = -1.0
var breach_cast: int = 0
var verdict_direction: Vector3
var verdict_warning: CombatEffect
var verdict_age: float = 0.0
var verdict_launched: bool = false
var verdict_diving: bool = false
var verdict_forward_left: float = 0.0

func data() -> MarshalTuning:
	return actor.tuning as MarshalTuning

func _ready() -> void:
	barrier = MarshalBarrier.new()
	barrier.source = actor
	add_child(barrier)
	refill()

func lower_barrier() -> void:
	if actor.state == "marshal_shield":
		actor.state = "ready"
		lowered_age = 0

func tick(delta: float, input: CombatIntent) -> void:
	tick_common(delta)
	var t := data()
	var was_broken: bool = break_remaining > 0
	break_remaining = maxf(0,break_remaining - delta)
	if actor.state != "marshal_shield":
		lowered_age += delta
		if not was_broken and lowered_age >= t.barrier_delay: barrier_hp = minf(t.barrier_health,barrier_hp + t.barrier_regen * delta)
	else:
		lowered_age = 0
		if not input.secondary_held: lower_barrier()
	if actor.infinite_resources:
		barrier_hp = t.barrier_health
		break_remaining = 0
	if breach_age >= 0:
		breach_age += delta
		while breach_index < t.breach_count and breach_age >= t.breach_warning + breach_index * t.breach_interval:
			breach_step()
		if breach_index >= t.breach_count: breach_age = -1
	if actor.state == "marshal_recovery" and actor.state_time <= 0: actor.state = "ready"
	if input.deflect and deflect_cd <= 0 and (actor.permits("deflect") or actor.state == "marshal_shield"):
		actor.benefits.grant("resolve",actor,t.resolve_duration,t.resolve_reduction)
		deflect_cd = t.resolve_cooldown
		actor.resolver.record("cast",actor,"iron_resolve")
	if actor.state == "marshal_shield" and (input.hover or input.bomb or input.ultimate or input.melee or input.throw_action or input.guard): lower_barrier()
	if input.hover and mobility_cd <= 0 and actor.permits("march"):
		actor.motor.interrupt_mobility()
		actor.state = "marshal_march"
		march_direction = Vector3(actor.aim_direction.x,0,actor.aim_direction.z).normalized()
		march_left = t.march_range
		cast_id = actor.resolver.new_cast(actor)
		mobility_cd = t.march_cooldown
		actor.resolver.record("cast",actor,"forward_march")
	elif input.bomb and bomb_cd <= 0 and actor.permits("bomb"):
		breach_origin = safe_muzzle()
		breach_direction = actor.aim_direction
		breach_index = 0
		breach_age = 0
		breach_cast = actor.resolver.new_cast(actor)
		bomb_cd = t.breach_cooldown
		CombatEffect.streak(actor.get_parent(),breach_origin,breach_origin + breach_direction * t.breach_spacing * t.breach_count,.08,t.breach_warning)
		actor.resolver.record("cast",actor,"breach_line")
	elif input.ultimate and ultimate_charge >= 100 and actor.permits("ultimate"):
		ultimate_charge = 0
		actor.motor.interrupt_mobility()
		verdict_forward_left = t.verdict_forward_range
		verdict_age = 0
		verdict_launched = false
		verdict_diving = false
		actor.state = "marshal_verdict"
		actor.state_time = t.verdict_windup
		verdict_direction = Vector3(actor.aim_direction.x,0,actor.aim_direction.z).normalized()
		cast_id = actor.resolver.new_cast(actor)
		verdict_warning = CombatEffect.cone_warning(actor.get_parent(),actor.global_position,verdict_direction,t.verdict_range,t.verdict_timeout)
		actor.resolver.record("cast",actor,"marshals_verdict")
	elif input.secondary_held and actor.permits("barrier") and barrier_hp > 0 and break_remaining <= 0:
		actor.state = "marshal_shield"
	elif input.primary_held or input.primary:
		weapon(t.cannon_damage,t.cannon_spread,t.cannon_pellets)
	if input.reload: reload_weapon()
	if input.projectile_fire: fire_projectile(input.aim)

func move_override(delta: float) -> bool:
	if actor.state == "marshal_verdict": return move_verdict(delta)
	if actor.state != "marshal_march": return false
	if actor.statuses.movement_disabled():
		actor.state = "ready"
		return false
	var distance: float = minf(march_left,data().march_range / data().march_duration * delta)
	actor.velocity.x = march_direction.x * distance / maxf(delta,.00001)
	actor.velocity.z = march_direction.z * distance / maxf(delta,.00001)
	actor.velocity.y -= actor.tuning.gravity * delta
	actor.move_and_slide()
	march_left -= distance
	for index: int in actor.get_slide_collision_count():
		var hit: KinematicCollision3D = actor.get_slide_collision(index)
		if hit.get_normal().y >= cos(actor.floor_max_angle): continue
		var target := hit.get_collider() as HeroActor
		if target != null:
			var result: String = actor.resolver.damage(actor,target,data().march_damage,"march",cast_id)
			if result == "hit": actor.resolver.knockback(actor,target,Vector3.UP * data().march_up + march_direction * data().march_forward,"march")
		march_left = 0
		break
	if march_left <= .001:
		if actor.state == "marshal_march": actor.state = "ready"
		actor.velocity.x = 0
		actor.velocity.z = 0
	return true

func move_verdict(delta: float) -> bool:
	var t := data()
	verdict_age += delta
	actor.velocity.x = 0
	actor.velocity.z = 0
	if not verdict_launched and verdict_age >= t.verdict_takeoff_delay:
		verdict_launched = true
		actor.velocity.y = t.verdict_jump_speed
		actor.motor.transition("air")
	if verdict_launched and (verdict_age >= t.verdict_takeoff_delay + t.verdict_air_time or actor.is_on_ceiling()):
		verdict_diving = true
	# Move only while airborne, along the direction committed at activation.
	var advance: float = 0.0
	if verdict_launched and not (verdict_diving and actor.is_on_floor()):
		advance = minf(verdict_forward_left,t.verdict_forward_speed * delta)
	actor.velocity.x = verdict_direction.x * advance / maxf(delta,.00001)
	actor.velocity.z = verdict_direction.z * advance / maxf(delta,.00001)
	actor.velocity.y = -t.verdict_slam_speed if verdict_diving else actor.velocity.y - actor.tuning.gravity * delta
	var descending: bool = actor.velocity.y < 0
	var before: Vector3 = actor.global_position
	actor.move_and_slide()
	verdict_forward_left = maxf(0,verdict_forward_left - maxf(0,(actor.global_position - before).dot(verdict_direction)))
	for index: int in actor.get_slide_collision_count():
		if actor.get_slide_collision(index).get_normal().dot(verdict_direction) < -.1:
			verdict_forward_left = 0
	if is_instance_valid(verdict_warning):
		var ground: Dictionary = actor.resolver.ray(actor.global_position + Vector3.UP * .1,actor.global_position + Vector3.DOWN * 40,[],1)
		if not ground.is_empty(): verdict_warning.global_position = ground.position + Vector3.UP * .06
	if verdict_launched and descending and actor.is_on_floor() and verdict_age >= t.verdict_windup:
		if is_instance_valid(verdict_warning): verdict_warning.queue_free()
		verdict_warning = null
		verdict()
		MarshalImpact.spawn(actor.get_parent(),actor.global_position)
		actor.velocity.x = 0
		actor.velocity.z = 0
		actor.state = "marshal_recovery"
		actor.state_time = t.verdict_recovery
		actor.resolver.record("impact",actor,"marshals_verdict")
	elif verdict_age >= t.verdict_timeout:
		cancel()
		actor.resolver.record("interrupt",actor,"marshals_verdict","no landing")
	return true

func verdict_progress() -> float:
	if not verdict_launched: return .2 * clampf(verdict_age / maxf(.01,data().verdict_takeoff_delay),0,1)
	return .9 if verdict_diving else lerpf(.2,.8,clampf((verdict_age - data().verdict_takeoff_delay) / maxf(.01,data().verdict_air_time),0,1))

func movement_scale() -> float:
	return data().shield_speed if actor.state == "marshal_shield" else 1.0

func breach_step() -> void:
	var t := data()
	var previous: Vector3 = breach_origin + breach_direction * breach_index * t.breach_spacing
	var endpoint: Vector3 = previous + breach_direction * t.breach_spacing
	var hit: Dictionary = actor.resolver.attack_ray(actor,previous,endpoint,[actor.get_rid()],1)
	breach_index += 1
	if not hit.is_empty():
		endpoint = hit.position + hit.normal * .03
		breach_index = t.breach_count
	CombatEffect.pulse(actor.get_parent(),endpoint,Color("ffb95e"),t.breach_radius)
	actor.presentation.sound.play_tone(65,.15,.2)
	actor.resolver.splash(actor,endpoint,t.breach_radius,t.breach_damage,"breach",breach_cast)
	# A preceding blast can break a barrier before the lane's next segment reaches it.
	# Retire this barrage when a hostile barrier absorbs any of its blasts.
	for shield: CombatBarrier in actor.get_tree().get_nodes_in_group("barriers"):
		if shield.source.team != actor.team and shield.received.has(breach_cast): breach_index = t.breach_count

func verdict() -> void:
	for target: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		var offset: Vector3 = target.global_position - actor.global_position
		var flat: Vector3 = offset * Vector3(1,0,1)
		if not target.alive or target.team == actor.team or flat.length() > data().verdict_range or absf(offset.y) > 1.5: continue
		if not target.motor.grounded() or flat.normalized().dot(verdict_direction) < cos(PI / 4): continue
		if not actor.resolver.ray(actor.global_position + Vector3.UP,target.global_position + Vector3.UP,[actor.get_rid()],1).is_empty(): continue
		if actor.resolver.damage(actor,target,data().verdict_damage,"verdict",cast_id) == "hit" and target.alive and target.state not in ["captured","throw_pair"]: target.close.stagger()
	actor.presentation.impact_sound.play_marshal_slam()

func cancel(clear_owned: bool = false) -> void:
	if is_instance_valid(verdict_warning): verdict_warning.queue_free()
	verdict_warning = null
	verdict_launched = false
	verdict_diving = false
	verdict_age = 0
	verdict_forward_left = 0
	if actor.state.begins_with("marshal_"): actor.state = "ready"
	if clear_owned: breach_age = -1
	super.cancel(clear_owned)

func refill() -> void:
	super.refill()
	barrier_hp = data().barrier_health
	break_remaining = 0
	lowered_age = 0
	breach_age = -1
	if is_instance_valid(barrier): barrier.received.clear()
