class_name WispKit
extends ExpansionKit
var shells: int = 0
var steps: int = 3
var recharge: float = 0.0
var step_left: float = 0.0
var step_direction: Vector3
var secondary_cd: float = 0.0
var glide_left: float = 0.0
var ballet_left: float = 0.0
var ballet_cd: float = 0.0

func data() -> WispTuning:
	return actor.tuning as WispTuning

func _ready() -> void:
	reset_life()

func ultimate_active() -> bool:
	return ballet_left > 0

func tick(delta: float, input: CombatIntent) -> void:
	tick_common(delta)
	var t := data()
	secondary_cd = maxf(0,secondary_cd-delta)
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
	if glide_left > 0 and actor.velocity.y <= 0: glide_left = maxf(0,glide_left-delta)
	if actor.state in ["wisp_step","wisp_ballet_start","wisp_ballet"] and actor.statuses.movement_disabled(): cancel()
	if actor.state == "wisp_phase":
		if actor.state_time <= 0: actor.state = "ready"
		else: return
	if actor.state == "wisp_ballet_start":
		if actor.state_time <= 0:
			actor.state = "wisp_ballet"
			ballet_left = t.ballet_duration
			ballet_cd = 0
			ultimate_charge = 0
		else: return
	if actor.state == "wisp_ballet":
		var active: float = minf(delta,ballet_left)
		if input.primary_held or input.primary:
			while ballet_cd < active-.000001:
				ballet_volley()
				ballet_cd += t.ballet_interval
			ballet_cd -= active
		else: ballet_cd = maxf(0,ballet_cd-active)
		ballet_left = maxf(0,ballet_left-active)
		if ballet_left <= .000001:
			# Finale remains part of the ultimate, including charge suppression.
			ballet_left = .000001
			launch(shot_direction(t.pistol_range),t.finale_damage,t.ballet_projectile_speed,t.pistol_range,Color("d7a0ff"),t.finale_radius)
			ballet_left = 0
			actor.state = "ready"
			actor.velocity.y = 0
		return
	if input.hover and steps > 0 and can_act("step"):
		actor.motor.interrupt_mobility()
		step_direction = actor.aim_direction.normalized()
		if actor.motor.grounded() and step_direction.y < 0: step_direction = (step_direction*Vector3(1,0,1)).normalized()
		step_left = t.step_distance
		if steps == t.step_charges: recharge = t.step_recharge
		steps -= 1
		actor.state = "wisp_step"
		actor.resolver.record("cast",actor,"ghoststep")
	if input.deflect and deflect_cd <= 0 and can_act("phase"):
		actor.state = "wisp_phase"
		actor.state_time = t.phase_duration
		deflect_cd = t.phase_cooldown
		actor.resolver.record("cast",actor,"between_worlds")
	if input.bomb and bomb_cd <= 0 and can_act("lift"):
		actor.motor.interrupt_mobility()
		actor.velocity.y = t.lift_speed
		actor.motor.transition("air")
		glide_left = t.glide_duration
		bomb_cd = t.lift_cooldown
		CombatEffect.pulse(actor.get_parent(),actor.global_position,Color("b796ff"),1.4)
		actor.resolver.record("cast",actor,"spectral_lift")
	if input.ultimate and ultimate_charge >= 100 and can_act("ultimate"):
		actor.motor.interrupt_mobility()
		actor.state = "wisp_ballet_start"
		actor.state_time = t.ballet_preparation
		actor.velocity.y = 8
		actor.resolver.record("cast",actor,"death_ballet")
		CombatEffect.pulse(actor.get_parent(),actor.body_point(1),Color("d7b1ff"),2)
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

func soulbreaker() -> void:
	if shells <= 0 or secondary_cd > 0 or not can_act("secondary"): return
	var t := data()
	shells -= 1
	secondary_cd = t.shotgun_recovery
	shot_cd = maxf(shot_cd,t.shotgun_recovery)
	var direction: Vector3 = shot_direction(t.shotgun_range)
	var core: Dictionary = hitscan(direction,t.shotgun_range,t.core_damage,"shotgun")
	var target: HeroActor = core.get("collider") as HeroActor
	if target != null and target.alive and core.get("result","") == "hit":
		var count: int = target.statuses.take_souls(actor)
		if count > 0:
			actor.resolver.damage(actor,target,count*t.mark_damage,"soulburst",actor.resolver.new_cast(actor),false,false,safe_muzzle())
			CombatEffect.pulse(actor.get_parent(),target.body_point(1),Color("e1b7ff"),1.0)
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	if right.is_zero_approx(): right = Vector3.RIGHT
	var up: Vector3 = right.cross(direction)
	for i: int in t.pellet_count:
		var angle: float = i*TAU/t.pellet_count
		var pellet: Vector3 = (direction+(right*cos(angle)+up*sin(angle))*tan(deg_to_rad(t.pellet_spread))).normalized()
		hitscan(pellet,t.shotgun_range,t.pellet_damage,"shotgun",false)
	feedback(160)
	actor.resolver.record("cast",actor,"soulbreaker")

func ballet_volley() -> void:
	var direction: Vector3 = shot_direction(data().pistol_range)
	for i: int in 3:
		launch(direction.rotated(Vector3.UP,(i-1)*.018),data().ballet_damage,data().ballet_projectile_speed,data().pistol_range,Color("c99dff"))
	feedback(520)

func move_override(delta: float) -> bool:
	if actor.state == "wisp_step":
		var distance: float = minf(step_left,data().step_speed*delta)
		var start: Vector3 = actor.global_position
		var hit: KinematicCollision3D = actor.move_ability_collide(step_direction*distance)
		if hit != null and hit.get_normal().dot(step_direction) >= -.02:
			var remainder: Vector3 = hit.get_remainder().slide(hit.get_normal())
			hit = actor.move_ability_collide(remainder) if remainder.length() > .0001 else null
		step_left -= distance
		CombatEffect.streak(actor.get_parent(),start+Vector3.UP,actor.body_point(1),.1,.16)
		actor.velocity = step_direction*data().step_speed
		if hit != null or actor.mobility_limited or step_left <= .00001:
			if hit == null and not actor.mobility_limited: shells = mini(data().shell_limit,shells+1)
			elif hit != null: actor.velocity = actor.velocity.slide(hit.get_normal())
			actor.state = "ready"
		return true
	if actor.state in ["wisp_ballet_start","wisp_ballet"]:
		actor.velocity = actor.intent.move*data().ballet_movement+Vector3.UP*(8.0 if actor.state == "wisp_ballet_start" else 0.0)
		actor.move_ability_slide(delta)
		return true
	if actor.state == "ready" and glide_left > 0 and actor.velocity.y <= 0 and actor.intent.jump_held and not actor.motor.grounded():
		actor.velocity.x = move_toward(actor.velocity.x,actor.intent.move.x*actor.tuning.ground_speed,actor.tuning.air_steering*delta)
		actor.velocity.z = move_toward(actor.velocity.z,actor.intent.move.z*actor.tuning.ground_speed,actor.tuning.air_steering*delta)
		actor.velocity.y = -data().glide_descent
		actor.move_ability_slide(delta)
		return true
	return false

func cancel(clear_owned: bool = false) -> void:
	if actor.state.begins_with("wisp_"): actor.state = "ready"
	step_left = 0
	ballet_left = 0
	glide_left = 0
	super.cancel(clear_owned)

func refill() -> void:
	super.refill()
	steps = data().step_charges
	recharge = 0
	shells = data().shell_limit
	secondary_cd = 0

func reset_life() -> void:
	refill()
	shells = 0
