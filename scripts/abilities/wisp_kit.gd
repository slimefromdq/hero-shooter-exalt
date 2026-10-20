class_name WispKit
extends ExpansionKit

var shells: int = 0
var steps: int = 3
var recharge: float = 0.0
var step_left: float = 0.0
var step_direction: Vector3
var step_immunity_left: float = 0.0
var secondary_cd: float = 0.0
var phase_recovery_left: float = 0.0
var glide_left: float = 0.0
var leap_active: bool = false
var leap_airborne: bool = false
var diving: bool = false
var heist: WispCallingCard
var phase_pressed: bool = false
var leap_pressed: bool = false

func data() -> WispTuning:
	return actor.tuning as WispTuning

func _ready() -> void:
	reset_life()

func ultimate_active() -> bool:
	# Only the release is an ultimate cast; ordinary follow-up shots can charge.
	return actor.state == "wisp_heist_start"

func ability_immune() -> bool:
	return actor.state == "wisp_phase" or (actor.state == "wisp_step" and step_immunity_left > .000001)

func clear_leap() -> void:
	leap_active = false
	leap_airborne = false
	diving = false
	glide_left = 0

func end_phase() -> void:
	actor.state = "ready"
	actor.state_time = 0
	phase_recovery_left = data().phase_recovery
	WispEffects.flourish(actor,actor.body_point(1),1.0)
	actor.presentation.sound.play_tone(880,.16,.16)
	actor.resolver.record("cast",actor,"vanishing_return")

func tick(delta: float, input: CombatIntent) -> void:
	tick_common(delta)
	var t := data()
	var phase_request: bool = input.deflect and not phase_pressed
	var leap_request: bool = input.bomb and not leap_pressed
	phase_pressed = input.deflect
	leap_pressed = input.bomb
	secondary_cd = maxf(0,secondary_cd-delta)
	step_immunity_left = maxf(0,step_immunity_left-delta)
	phase_recovery_left = maxf(0,phase_recovery_left-delta)
	if steps < t.step_charges:
		recharge -= delta
		while recharge <= .000001 and steps < t.step_charges:
			steps += 1
			if steps < t.step_charges: recharge += t.step_recharge
			else: recharge = 0
	mobility_cd = recharge if steps == 0 else 0.0
	if actor.infinite_resources:
		steps = t.step_charges
		shells = t.shell_limit
		recharge = 0
	if leap_active:
		if actor.state != "ready" or actor.motor.mode in ["dash","dash_windup","mantle","slide"] or actor.statuses.movement_disabled():
			clear_leap()
		elif not actor.motor.grounded(): leap_airborne = true
		elif leap_airborne and actor.velocity.y <= 0: clear_leap()
	if glide_left > 0 and actor.velocity.y <= 0: glide_left = maxf(0,glide_left-delta)
	if actor.state in ["wisp_step","wisp_heist_start"] and actor.statuses.movement_disabled(): cancel()
	if actor.state == "wisp_phase":
		if actor.state_time <= .000001 or phase_request: end_phase()
		return
	if actor.state == "wisp_heist_start":
		if actor.state_time <= .000001:
			heist = WispCallingCard.new()
			heist.source = actor
			heist.direction = shot_direction(t.heist_range)
			heist.cast_id = actor.resolver.new_cast(actor)
			actor.get_parent().add_child(heist)
			heist.global_position = safe_muzzle()
			ultimate_charge = 0
			actor.state = "ready"
			feedback(440)
		return
	if phase_recovery_left > .000001: return
	if input.hover and steps > 0 and can_act("step"):
		clear_leap()
		actor.motor.interrupt_mobility()
		step_direction = actor.aim_direction.normalized()
		if actor.motor.grounded() and step_direction.y < 0: step_direction = (step_direction*Vector3(1,0,1)).normalized()
		step_left = t.step_distance
		step_immunity_left = t.step_immunity
		if steps == t.step_charges: recharge = t.step_recharge
		steps -= 1
		actor.state = "wisp_step"
		WispEffects.afterimage(actor)
		actor.resolver.record("cast",actor,"ghoststep")
	if phase_request and deflect_cd <= 0 and can_act("phase"):
		clear_leap()
		actor.motor.interrupt_mobility()
		actor.velocity = Vector3.ZERO
		actor.state = "wisp_phase"
		actor.state_time = t.phase_duration
		deflect_cd = t.phase_cooldown
		WispEffects.flourish(actor,actor.body_point(1),1.2)
		feedback(330)
		actor.resolver.record("cast",actor,"between_worlds")
	if leap_request and can_act("lift"):
		if leap_active and (leap_airborne or not actor.motor.grounded()):
			diving = true
			glide_left = 0
			actor.velocity.y = -t.dive_speed
		elif bomb_cd <= 0:
			actor.motor.interrupt_mobility()
			var forward := (actor.aim_direction*Vector3(1,0,1)).normalized()
			if forward.is_zero_approx(): forward = -actor.global_basis.z
			actor.velocity = forward*t.leap_forward_speed+Vector3.UP*t.lift_speed
			actor.motor.transition("air")
			leap_active = true
			leap_airborne = not actor.motor.grounded()
			diving = false
			glide_left = t.glide_duration
			bomb_cd = t.lift_cooldown
			WispEffects.flourish(actor,actor.body_point(.5),1.0)
			actor.resolver.record("cast",actor,"majestic_leap")
	if input.ultimate and ultimate_charge >= 100 and can_act("ultimate"):
		clear_leap()
		actor.motor.interrupt_mobility()
		actor.state = "wisp_heist_start"
		actor.state_time = t.heist_preparation
		actor.resolver.record("cast",actor,"grand_heist")
		WispEffects.flourish(actor,actor.body_point(1),.7)
	if input.secondary_pressed: soulbreaker()
	elif input.primary or input.primary_held: fire()
	if input.reload: start_reload()

func fire(_ultimate: bool = false) -> void:
	if not can_act("primary") or shot_cd > 0 or secondary_cd > 0: return
	if ammo <= 0:
		start_reload()
		return
	consume_ammo()
	shot_cd = primary_interval()+cadence_debt
	var hit: Dictionary = hitscan(shot_direction(data().pistol_range),data().pistol_range,actor.tuning.rifle_damage,"rifle")
	var target: HeroActor = hit.get("collider") as HeroActor
	if target != null and target.alive and hit.get("result","") == "hit": target.statuses.add_soul(actor,data().mark_limit,data().mark_duration)
	feedback(660 if ammo%2 == 0 else 740)
	actor.resolver.record("cast",actor,"pistols")

func estimated_burst(distance: float, marks: int) -> float:
	# Bots assume an aimed impact, never a speculative hit at the blast fringe.
	if distance > data().burst_range: return 0
	return data().burst_damage+mini(marks,data().mark_limit)*data().mark_damage

func explosive_burst(direction: Vector3) -> Dictionary:
	var t := data()
	var from: Vector3 = safe_muzzle()
	var hit: Dictionary = actor.resolver.attack_ray(actor,from,from+direction*t.burst_range,[actor.get_rid()])
	var at: Vector3 = hit.get("position",from+direction*t.burst_range)
	if not hit.is_empty(): at += Vector3(hit.normal)*.04
	var id: int = actor.resolver.new_cast(actor)
	var result: Dictionary = WispBlast.resolve(actor,at,t.burst_radius,t.burst_full_radius,t.burst_damage,t.burst_minimum,id,"rogue_burst")
	CombatEffect.line(actor.get_parent(),from,at,Color("c174ff"),.055)
	CombatEffect.pulse(actor.get_parent(),at,Color("aa4cde"),t.burst_radius)
	WispEffects.flourish(actor,at,1.3)
	if int(result.hits) > 0: actor.presentation.impact_sound.play_tone(1040,.11,.15)
	return result

func soulbreaker() -> void:
	if shells <= 0 or secondary_cd > 0 or not can_act("secondary"): return
	shells -= 1
	secondary_cd = data().burst_recovery
	shot_cd = maxf(shot_cd,secondary_cd)
	explosive_burst(shot_direction(data().burst_range))
	feedback(160)
	# Keep the existing event/resource identity for telemetry and saved drills.
	actor.resolver.record("cast",actor,"soulbreaker")

func move_override(delta: float) -> bool:
	if actor.state == "wisp_step":
		var distance: float = minf(step_left,data().step_speed*delta)
		var start: Vector3 = actor.global_position
		var hit: KinematicCollision3D = actor.move_ability_collide(step_direction*distance)
		if hit != null and hit.get_normal().dot(step_direction) >= -.02:
			var remainder: Vector3 = hit.get_remainder().slide(hit.get_normal())
			hit = actor.move_ability_collide(remainder) if remainder.length() > .0001 else null
		step_left -= distance
		CombatEffect.line(actor.get_parent(),start+Vector3.UP,actor.body_point(1),Color("a35cff"),.09)
		actor.velocity = step_direction*data().step_speed
		if hit != null or actor.mobility_limited or step_left <= .00001:
			if hit == null and not actor.mobility_limited: shells = mini(data().shell_limit,shells+1)
			elif hit != null: actor.velocity = actor.velocity.slide(hit.get_normal())
			actor.state = "ready"
			actor.velocity = actor.velocity.limit_length(data().step_exit_speed)
			step_immunity_left = 0
		return true
	if actor.state == "wisp_phase":
		actor.velocity = (actor.intent.move*Vector3(1,0,1)).limit_length(1)*data().phase_speed*actor.statuses.movement_scale()
		actor.move_ability_slide(delta)
		return true
	if actor.state == "ready" and leap_active:
		if actor.intent.dash and actor.motor.can_dash():
			clear_leap()
			return false
		if actor.motor.grounded() and leap_airborne:
			clear_leap()
			return false
		if diving or (glide_left > 0 and actor.velocity.y <= 0 and actor.intent.jump_held):
			var wish: Vector3 = (actor.intent.move*Vector3(1,0,1)).limit_length(1)*actor.tuning.ground_speed
			actor.velocity.x = move_toward(actor.velocity.x,wish.x,actor.tuning.air_steering*delta)
			actor.velocity.z = move_toward(actor.velocity.z,wish.z,actor.tuning.air_steering*delta)
			if diving:
				var horizontal := Vector2(actor.velocity.x,actor.velocity.z).limit_length(actor.tuning.ground_speed)
				actor.velocity.x = horizontal.x
				actor.velocity.z = horizontal.y
			actor.velocity.y = -data().dive_speed if diving else -data().glide_descent
			actor.move_ability_slide(delta)
			if actor.motor.grounded(): clear_leap()
			return true
	return false

func cancel(clear_owned: bool = false) -> void:
	if actor.state == "wisp_phase" and not clear_owned: end_phase()
	elif actor.state.begins_with("wisp_"): actor.state = "ready"
	step_left = 0
	step_immunity_left = 0
	clear_leap()
	if clear_owned: phase_recovery_left = 0
	super.cancel(clear_owned)

func refill() -> void:
	super.refill()
	steps = data().step_charges
	recharge = 0
	shells = data().shell_limit
	secondary_cd = 0

func reset_life() -> void:
	refill()
	phase_pressed = false
	leap_pressed = false
	step_immunity_left = 0
	phase_recovery_left = 0
	clear_leap()
	shells = 0
