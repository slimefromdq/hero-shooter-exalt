class_name MarshalKit
extends CareKit

var barrier: MarshalBarrier
var barrier_hp: float = 1200.0
var lowered_age: float = 0.0
var break_remaining: float = 0.0
var march_direction: Vector3
var march_left: float = 0.0
var march_age: float = 0.0
var march_speed: float = 0.0
var march_turn_used: float = 0.0
var march_hits: Dictionary = {}
var march_effect_age: float = 0.0
var verdict_steer: Vector3 = Vector3.ZERO
var verdict_steer_left: float = 0
var breach_direction: Vector3
var breach_origin: Vector3
var breach_index: int = 0
var breach_age: float = -1.0
var breach_cast: int = 0
var orbital_points: Array[Dictionary] = []
var orbital_effects: Array[MarshalOrbitalEffect] = []
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
		while breach_index < orbital_points.size() and breach_age >= float(orbital_points[breach_index].delay):
			breach_step()
		if breach_index >= orbital_points.size(): breach_age = -1
	if actor.state == "marshal_recovery" and actor.state_time <= 0: actor.state = "ready"
	if input.deflect and actor.statuses.permits("deflect") and deflect_cd <= 0 and rally_allowed(): rally()
	if actor.state == "marshal_shield" and (input.hover or input.bomb or input.ultimate or input.melee or input.throw_action or input.guard): lower_barrier()
	if input.hover and mobility_cd <= 0 and actor.permits("march"):
		actor.motor.interrupt_mobility()
		actor.state = "marshal_march"
		march_direction = Vector3(actor.aim_direction.x,0,actor.aim_direction.z).normalized()
		march_left = t.march_range
		march_age = 0
		march_speed = 0
		march_turn_used = 0
		march_hits.clear()
		march_effect_age = 0
		actor.presentation.sound.play_tone(55,.18,.3)
		if actor.controller is PlayerController: (actor.controller as PlayerController).add_recoil(.035)
		cast_id = actor.resolver.new_cast(actor)
		mobility_cd = t.march_cooldown
		actor.resolver.record("cast",actor,"forward_march")
	elif input.bomb and bomb_cd <= 0 and actor.permits("bomb"):
		clear_orbital()
		breach_origin = actor.global_position
		breach_direction = actor.aim_direction
		breach_index = 0
		breach_age = 0
		breach_cast = actor.resolver.new_cast(actor)
		bomb_cd = t.breach_cooldown
		orbital_points = MarshalOrbitalTargeting.plan(actor,breach_origin,breach_direction)
		for entry: Dictionary in orbital_points:
			orbital_effects.append(actor.presentation.marshal_combat.orbital_marker(entry,t.breach_radius))
		actor.resolver.record("cast",actor,"orbital_barrage")
	elif input.ultimate and ultimate_charge >= 100 and actor.permits("ultimate"):
		ultimate_charge = 0
		actor.motor.interrupt_mobility()
		verdict_forward_left = t.verdict_forward_range
		verdict_steer_left = t.verdict_steer_range
		verdict_steer = Vector3.ZERO
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
		fire(false)
	if input.reload: reload_weapon()
	if input.projectile_fire: fire_projectile(input.aim)

func move_override(delta: float) -> bool:
	if actor.state == "marshal_verdict": return move_verdict(delta)
	if actor.state != "marshal_march": return false
	if actor.statuses.movement_disabled():
		finish_march(false)
		return false
	# Bound integration steps for stable acceleration, steering and curved sweeps.
	var left: float = delta
	while left > .00001 and actor.state == "marshal_march":
		var dt: float = minf(left,1.0/120)
		left -= dt
		march_age += dt
		if march_age >= data().march_timeout:
			finish_march(false)
			break
		if march_age < data().march_startup: continue
		var wish: Vector3 = actor.intent.move * Vector3(1,0,1)
		if wish.length_squared() > .01:
			var turn: float = march_direction.signed_angle_to(wish.normalized(),Vector3.UP)
			var budget: float = maxf(0,deg_to_rad(data().march_steering_degrees)-march_turn_used)
			turn = clampf(turn,-minf(budget,deg_to_rad(data().march_turn_rate)*dt),minf(budget,deg_to_rad(data().march_turn_rate)*dt))
			march_direction = march_direction.rotated(Vector3.UP,turn)
			march_turn_used += absf(turn)
		var previous_speed: float = march_speed
		march_speed = move_toward(march_speed,data().march_speed,data().march_acceleration*dt)
		var distance: float = minf(march_left,(previous_speed+march_speed)*.5*dt)
		var before: Vector3 = actor.global_position
		# Actors are combat targets, not physical roadblocks during this motion.
		# CharacterBody sweeps the full capsule against world geometry continuously.
		var mask: int = actor.collision_mask
		actor.collision_mask = 1
		actor.velocity = march_direction*distance/dt + Vector3.UP*(minf(0,actor.velocity.y)-actor.tuning.gravity*dt)
		var motion: Vector3 = actor.velocity*dt
		var blocked: bool = false
		for iteration: int in 3:
			var hit: KinematicCollision3D = actor.move_and_collide(motion)
			if hit == null: break
			if hit.get_normal().y < cos(actor.floor_max_angle):
				blocked = true
				break
			actor.velocity.y = 0
			motion = hit.get_remainder().slide(hit.get_normal())
			if motion.length_squared() < .0000001: break
		actor.collision_mask = mask
		march_left -= (actor.global_position-before).length()
		march_contacts(before,actor.global_position)
		if actor.state != "marshal_march": break
		if blocked: finish_march(true)
		if march_left <= .001 and actor.state == "marshal_march": finish_march(false)
		march_effect_age += dt
		if march_effect_age > .09:
			march_effect_age = 0
			CombatEffect.streak(actor.get_parent(),actor.body_point(.8)-march_direction*.7,actor.body_point(.8),.035,.16)
			if not actor.resolver.ray(actor.global_position+Vector3.UP*.1,actor.global_position+Vector3.DOWN*.2,[],1).is_empty(): CombatEffect.pulse(actor.get_parent(),actor.global_position,Color("bba889"),.4)
	return true

func finish_march(collision: bool) -> void:
	if actor.state == "marshal_march": actor.state = "ready"
	actor.velocity.x = 0
	actor.velocity.z = 0
	march_left = 0
	if collision:
		actor.presentation.impact_sound.play_marshal_slam()
		if actor.controller is PlayerController: (actor.controller as PlayerController).add_recoil(.07)

func march_contacts(from: Vector3, to: Vector3) -> void:
	var shield: Dictionary = actor.resolver.barrier_ray(actor,from+Vector3.UP,to+Vector3.UP)
	if not shield.is_empty():
		(shield.collider as CombatBarrier).receive_damage(actor,data().march_damage,cast_id)
		actor.global_position = shield.position-Vector3.UP-march_direction*.05
		finish_march(true)
		return
	var candidates: Array[HeroActor] = []
	for target: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if target.team == actor.team or not target.alive or march_hits.has(target.get_instance_id()): continue
		var at: Vector3 = Geometry3D.get_closest_point_to_segment(target.body_point(.95),from+Vector3.UP*.95,to+Vector3.UP*.95)
		# Capsule interval handles feet, slopes, crouch and elevation changes.
		var body: Vector3 = target.body_point(.95)
		var flat: Vector3 = (body-at)*Vector3(1,0,1)
		if flat.length() > data().march_hit_radius or absf(body.y-at.y) > 1.4: continue
		if not actor.resolver.ray(at,body,[actor.get_rid()],1).is_empty(): continue
		candidates.append(target)
	candidates.sort_custom(func(a: HeroActor,b: HeroActor) -> bool: return from.distance_squared_to(a.global_position)<from.distance_squared_to(b.global_position))
	for target: HeroActor in candidates:
		march_hits[target.get_instance_id()] = true
		var result: String = actor.resolver.damage(actor,target,data().march_damage,"march",cast_id,false,false,from+Vector3.UP)
		if result == "hit":
			if target.alive and target.state not in ["captured","throw_pair"]:
				target.close.stagger()
				target.state_time = data().march_stagger
			actor.resolver.knockback(actor,target,Vector3.UP*data().march_up+march_direction*data().march_forward,"march")
			actor.presentation.impact_sound.play_marshal_slam()
		if actor.state != "marshal_march": return

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
	# Air steering changes horizontal travel while the impact cone stays committed.
	var advance: float = 0.0
	if verdict_launched and not (verdict_diving and actor.is_on_floor()):
		advance = minf(verdict_forward_left,t.verdict_forward_speed * delta)
	var wish: Vector3 = actor.intent.move * Vector3(1,0,1)
	verdict_steer = verdict_steer.move_toward(wish.limit_length(1)*t.verdict_steer_speed,t.verdict_steer_acceleration*delta)
	var horizontal: Vector3 = verdict_direction*advance/maxf(delta,.00001)
	var steering_distance: float = minf(verdict_steer_left,verdict_steer.length()*delta) if verdict_launched else 0.0
	if steering_distance > 0: horizontal += verdict_steer.normalized()*steering_distance/maxf(delta,.00001)
	actor.velocity.x = horizontal.x
	actor.velocity.z = horizontal.z
	actor.velocity.y = -t.verdict_slam_speed if verdict_diving else actor.velocity.y - actor.tuning.gravity * delta
	var descending: bool = actor.velocity.y < 0
	actor.move_and_slide()
	verdict_forward_left = maxf(0,verdict_forward_left-advance)
	verdict_steer_left = maxf(0,verdict_steer_left-steering_distance)
	for index: int in actor.get_slide_collision_count():
		if actor.get_slide_collision(index).get_normal().dot(verdict_direction) < -.1:
			verdict_forward_left = 0
			verdict_steer_left = 0
	if is_instance_valid(verdict_warning):
		var beneath: Dictionary = actor.resolver.ray(actor.global_position+Vector3.UP*.1,actor.global_position+Vector3.DOWN*80,[],1)
		var height: float = actor.global_position.y-float(beneath.get("position",Vector3.ZERO).y)
		var ascent_left: float = maxf(0,t.verdict_air_time-maxf(0,verdict_age-t.verdict_takeoff_delay)) if not verdict_diving else 0.0
		var vertical_speed: float = actor.velocity.y if verdict_launched else t.verdict_jump_speed
		var fall_time: float = maxf(0,height+vertical_speed*ascent_left-.5*actor.tuning.gravity*ascent_left*ascent_left)/t.verdict_slam_speed
		var remaining_air: float = ascent_left+fall_time
		var predicted: Vector3 = actor.global_position+verdict_direction*minf(verdict_forward_left,t.verdict_forward_speed*remaining_air)+verdict_steer.normalized()*minf(verdict_steer_left,verdict_steer.length()*remaining_air)
		var obstruction: Dictionary = actor.resolver.ray(actor.body_point(1),predicted+Vector3.UP,[],1)
		if not obstruction.is_empty(): predicted = obstruction.position-verdict_direction*.4
		var ground: Dictionary = actor.resolver.ray(predicted+Vector3.UP*.1,predicted+Vector3.DOWN*40,[],1)
		verdict_warning.visible = not ground.is_empty() and ground.get("normal",Vector3.ZERO).y >= cos(actor.floor_max_angle)
		if not ground.is_empty(): verdict_warning.global_position = ground.position + Vector3.UP * .06
	var support: Dictionary = actor.resolver.ray(actor.global_position+Vector3.UP*.1,actor.global_position+Vector3.DOWN*.25,[],1)
	if verdict_launched and descending and actor.is_on_floor() and not support.is_empty() and support.normal.y >= cos(actor.floor_max_angle) and verdict_age >= t.verdict_windup:
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
	var index: int = breach_index
	var entry: Dictionary = orbital_points[index]
	breach_index += 1
	var previous: Vector3 = breach_origin if index == 0 else Vector3(orbital_points[index-1].position)
	var lane: Dictionary = actor.resolver.attack_ray(actor,previous+Vector3.UP*.9,entry.position+Vector3.UP*.9,[actor.get_rid()],1)
	if not lane.is_empty():
		if lane.collider is CombatBarrier: lane.collider.receive_damage(actor,t.breach_damage,breach_cast)
		stop_orbital()
		return
	if MarshalOrbitalTargeting.revalidate(actor,entry):
		var overhead: Dictionary = actor.resolver.barrier_ray(actor,entry.position+Vector3.UP*t.orbital_sky_height,entry.position+Vector3.UP*.08)
		if not overhead.is_empty():
			overhead.collider.receive_damage(actor,t.breach_damage,breach_cast)
			if index < orbital_effects.size() and is_instance_valid(orbital_effects[index]): orbital_effects[index].queue_free()
			actor.presentation.marshal_combat.orbital_block(overhead.position)
			stop_orbital()
			return
		if index < orbital_effects.size() and is_instance_valid(orbital_effects[index]):
			orbital_effects[index].global_position = entry.position
			orbital_effects[index].strike()
		actor.presentation.marshal_combat.orbital_impact(entry.position)
		actor.resolver.splash(actor,entry.position+Vector3.UP*.12,t.breach_radius,t.breach_damage,"orbital_barrage",breach_cast)
		actor.resolver.record("impact",actor,"orbital_barrage","index=%d position=%s" % [index,entry.position])
	elif index < orbital_effects.size() and is_instance_valid(orbital_effects[index]):
		orbital_effects[index].queue_free()
	if bool(entry.stop): stop_orbital()
	for shield: CombatBarrier in actor.get_tree().get_nodes_in_group("barriers"):
		if shield.source.team != actor.team and shield.received.has(breach_cast): stop_orbital()

func stop_orbital() -> void:
	for index: int in range(breach_index,orbital_effects.size()):
		if is_instance_valid(orbital_effects[index]): orbital_effects[index].queue_free()
	breach_index = orbital_points.size()
	breach_age = -1

func clear_orbital() -> void:
	for effect in orbital_effects:
		if is_instance_valid(effect): effect.queue_free()
	orbital_effects.clear()
	orbital_points.clear()
	breach_age = -1
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
	march_left = 0
	march_speed = 0
	march_hits.clear()
	verdict_steer = Vector3.ZERO
	if is_instance_valid(verdict_warning): verdict_warning.queue_free()
	verdict_warning = null
	verdict_launched = false
	verdict_diving = false
	verdict_age = 0
	verdict_forward_left = 0
	verdict_steer_left = 0
	if actor.state.begins_with("marshal_"): actor.state = "ready"
	if clear_owned:
		clear_orbital()
		if is_instance_valid(barrier): barrier.clear_feedback()
	super.cancel(clear_owned)

func refill() -> void:
	super.refill()
	barrier_hp = data().barrier_health
	break_remaining = 0
	lowered_age = 0
	clear_orbital()
	if is_instance_valid(barrier): barrier.received.clear()

func fire(_ultimate: bool = false) -> void:
	if not actor.permits("primary") or shot_cd > 0: return
	if ammo <= 0:
		reload_weapon()
		return
	var t := data()
	var muzzle: Vector3 = safe_muzzle()
	var origin: Vector3 = actor.intent.aim_origin
	if origin == Vector3.ZERO: origin = actor.body_point(1.6)
	var view: Dictionary = actor.resolver.ray(origin,origin+actor.aim_direction*t.cannon_range,[actor.get_rid()])
	var direction: Vector3 = (Vector3(view.get("position",origin+actor.aim_direction*t.cannon_range))-muzzle).normalized()
	var ball := MarshalCannonball.new()
	ball.source = actor
	ball.cast_id = actor.resolver.new_cast(actor)
	ball.velocity = direction*t.cannon_speed
	actor.get_parent().add_child(ball)
	ball.global_position = actor.body_point(1.36)
	ball.sweep(muzzle-ball.global_position)
	consume_ammo()
	shot_cd = primary_interval()
	actor.presentation.fire_flash = .22
	actor.presentation.marshal_combat.fire()
	if actor.controller is PlayerController: (actor.controller as PlayerController).add_recoil(.075)
	actor.resolver.record("cast",actor,"cannon")

func rally_allowed() -> bool:
	if not actor.statuses.permits("deflect"): return false
	return actor.alive and actor.state in ["ready","guard","marshal_shield"] and actor.motor.mode not in ["dash","dash_windup","mantle"] and not actor.resolver.attack_locked(actor)

func rally_recipient(target: HeroActor) -> bool:
	if not target.alive or target.team != actor.team or actor.global_position.distance_to(target.global_position) > data().rally_radius: return false
	if actor.resolver.protected_room(target): return false
	var from: Vector3 = actor.body_point(1.2)
	var to: Vector3 = target.body_point(1.2)
	if actor.resolver.spawn_door_blocks(from,to): return false
	return target == actor or actor.resolver.attack_ray(actor,from,to,[actor.get_rid()],1).is_empty()

func rally() -> void:
	if deflect_cd > 0 or not rally_allowed(): return
	deflect_cd = data().rally_cooldown
	for target: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if rally_recipient(target): target.overhealth.grant(actor,data().rally_self_overhealth if target == actor else data().rally_ally_overhealth,data().rally_duration,"rallying_command")
	actor.presentation.overhealth_visual.command(data().rally_radius)
	actor.resolver.record("cast",actor,"rallying_command")
