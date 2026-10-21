class_name HeroMotor
extends Node

var actor: HeroActor
var mode: String = "ground"
var timer: float = 0.0
# Remaining time until the next sequential charge returns.
var dash_cd: float = 0.0
var dash_charges: int = 2
var dash_slide_locked: bool = false
var slide_source: String = ""
var mantle_slide_left: float = 0.0
var mantle_slide_buffered: bool = false
var mantle_slide_direction: Vector3 = Vector3.FORWARD
var hover_cd: float = 0.0
var dash_direction: Vector3 = Vector3.FORWARD
var dash_current_speed: float = 0.0
var dash_vertical_speed: float = 0.0
var coyote: float = 0.0
var jump_buffer: float = 0.0
var dash_slide: bool = false
var dash_airborne: bool = false
var slide_press_age: float = 99.0
var slide_rearmed: bool = true
var slide_velocity: Vector3 = Vector3.ZERO
var slide_feedback: DashSlideFeedback
var traversal: TraversalMotion
var external_velocity: Vector3 = Vector3.ZERO
var crouched: bool = false
var body_collision: CollisionShape3D
var standing_capsule: CapsuleShape3D
var standing_clearance_capsule: CapsuleShape3D
var voluntary_airborne: bool = false
var pad_speed_limit: float = 0.0
var pad_flight_left: float = 0.0
var pad_takeoff_left: float = 0.0

func launch_from_pad(launch_velocity: Vector3, flight_time: float) -> bool:
	if not actor.alive or actor.statuses.effects.has("root"): return false
	if actor.state not in ["ready","guard","marshal_shield","huddle_regroup","samson_cross"]: return false
	if traversal.active or mode in ["hover","hover_ascent"]: return false
	if actor.kit is WispKit and (actor.kit as WispKit).leap_active: return false
	mode = "air"
	timer = 0
	slide_velocity = Vector3.ZERO
	mantle_slide_left = 0
	mantle_slide_buffered = false
	dash_slide = false
	jump_buffer = 0
	coyote = 0
	voluntary_airborne = true
	set_crouched(false)
	actor.velocity = launch_velocity
	pad_speed_limit = maxf(actor.tuning.speed_limit,maxf(launch_velocity.length(),(launch_velocity+Vector3.DOWN*actor.tuning.gravity*flight_time).length())+.5)
	pad_flight_left = flight_time+1
	pad_takeoff_left = .1
	visual("jump",launch_velocity)
	return true

func clear_pad_flight() -> void:
	pad_speed_limit = 0
	pad_flight_left = 0
	pad_takeoff_left = 0

func movement_speed_limit() -> float:
	return maxf(actor.tuning.speed_limit,pad_speed_limit)


func _ready() -> void:
	body_collision = actor.get_node("BodyCollision") as CollisionShape3D
	standing_capsule = body_collision.shape.duplicate() as CapsuleShape3D
	standing_clearance_capsule = standing_capsule.duplicate() as CapsuleShape3D
	# CharacterBody's resting contact can sit a few millimeters into a floor.
	# Exclude only the bottom 2 cm from the clearance probe, preserving the
	# standing head height so floor contact cannot masquerade as a low ceiling.
	standing_clearance_capsule.height -= .02
	slide_feedback = DashSlideFeedback.new()
	slide_feedback.actor = actor
	traversal = TraversalMotion.new()
	traversal.actor = actor

func tick(delta: float, input: CombatIntent) -> void:
	if pad_flight_left > 0:
		pad_flight_left -= delta
		pad_takeoff_left = maxf(0,pad_takeoff_left-delta)
		if pad_flight_left<=0 or not actor.alive or (pad_takeoff_left<=0 and grounded() and actor.velocity.y<=0) or actor.statuses.effects.has("root") or mode in ["hover","hover_ascent","mantle"] or actor.state not in ["ready","guard","marshal_shield","huddle_regroup","samson_cross"]:
			clear_pad_flight()
		elif actor.kit is WispKit and (actor.kit as WispKit).leap_active:
			clear_pad_flight()
	var supported_before: bool = grounded()
	var incoming_y: float = actor.velocity.y
	tick_motion(delta,input)
	if not supported_before and grounded() and incoming_y < -3 and mode != "slide":
		visual("landing",actor.velocity,actor.get_floor_normal(),clampf(-incoming_y/10,.35,1.4))
	# Root, melee and mobility branches must not silently swallow a hit impulse.
	# Move separately so knockback cannot turn into stored player momentum.
	if actor.state in ["captured", "throw_pair", "boot_attached", "boot_captured"]:
		external_velocity = Vector3.ZERO
	elif not external_velocity.is_zero_approx():
		var motion: Vector3 = external_velocity * delta
		for index: int in 3:
			var collision: KinematicCollision3D = actor.move_and_collide(motion)
			if collision == null: break
			motion = collision.get_remainder().slide(collision.get_normal())
			if motion.is_zero_approx(): break
		external_velocity = external_velocity.move_toward(Vector3.ZERO,delta * actor.tuning.braking)

func tick_motion(delta: float, input: CombatIntent) -> void:
	var t: HeroTuning = actor.tuning
	slide_feedback.tick(delta,input)
	var was_floor: bool = grounded() and pad_takeoff_left <= 0
	if was_floor and actor.velocity.y <= 0: voluntary_airborne = false
	update_posture(actor.concealed() or was_floor and input.slide and mode not in ["dash","dash_windup","mantle"] and actor.state not in ["captured","throw_pair","boot_attached","boot_captured","stagger","counterthrow","throw_release"])
	slide_press_age += delta
	if input.slide_pressed: slide_press_age = 0.0
	if not input.slide and mode not in ["dash","dash_windup"]: slide_rearmed = true
	if dash_slide_locked and mode not in ["dash","dash_windup"] and Vector2(actor.velocity.x,actor.velocity.z).length() <= t.ground_speed + .05:
		dash_slide_locked = false
	mantle_slide_left = maxf(0,mantle_slide_left-delta)
	if input.slide_pressed and traversal.active and traversal.duration-traversal.elapsed <= t.mantle_slide_buffer:
		mantle_slide_buffered = true
	traversal.tick(delta,was_floor)
	tick_dash_recharge(delta)
	hover_cd = maxf(0.0, hover_cd - delta)
	if actor.infinite_resources:
		refill_dashes()
		hover_cd = 0.0
	if traversal.active:
		# Keep a short press buffer through the finish without turning the held
		# auto-mantle input into an automatic jump on every rooftop.
		jump_buffer = .12 if input.jump else maxf(0,jump_buffer - delta)
		traversal.carry_running_input(delta,input.move)
		if traversal.advance(delta):
			finish_mantle(delta)
		return
	if mantle_slide_left > 0 and input.slide_pressed and input.slide and not input.jump and was_floor and actor.state == "ready":
		start_mantle_slide()
	if actor.state in ["captured", "throw_pair", "boot_attached", "boot_captured"]:
		actor.velocity = Vector3.ZERO
		return
	if actor.kit.move_override(delta):
		return
	if actor.statuses.effects.has("root"):
		actor.velocity = Vector3(0,actor.velocity.y - t.gravity * delta,0)
		actor.move_and_slide()
		return
	if actor.state == "throw_startup":
		var charge: Vector3 = actor.close.throw_displacement(delta)
		actor.velocity = Vector3(charge.x/delta,actor.velocity.y-t.gravity*delta,charge.z/delta)
		actor.move_ability_slide(delta)
		return
	if actor.state in ["melee_windup", "melee_active"] or (actor.state == "melee_recovery" and actor.close.melee_age - delta < t.melee_lunge_delay + t.melee_lunge_duration):
		var lunge: Vector3 = actor.close.lunge_displacement(delta)
		actor.velocity.x = lunge.x / delta
		actor.velocity.z = lunge.z / delta
		if actor.close.melee_airborne:
			var falling_delta: float = maxf(0,actor.close.melee_age-t.melee_air_suspend)-maxf(0,actor.close.melee_age-delta-t.melee_air_suspend)
			actor.close.melee_fall_speed -= t.gravity * falling_delta
			actor.velocity.y = actor.close.melee_fall_speed + lunge.y / delta
		else:
			actor.velocity.y -= t.gravity * delta
		actor.velocity = actor.velocity.limit_length(movement_speed_limit())
		actor.move_ability_slide(delta)
		for index: int in actor.get_slide_collision_count():
			var normal: Vector3 = actor.get_slide_collision(index).get_normal()
			if normal.dot(actor.close.melee_motion_direction()) < -0.25:
				actor.close.lunge_blocked = true
		if actor.close.melee_age >= t.melee_lunge_delay + t.melee_lunge_duration:
			if actor.close.melee_airborne: actor.velocity.y = actor.close.melee_fall_speed
			actor.velocity.x = 0
			actor.velocity.z = 0
		return
	coyote = 0.1 if was_floor else maxf(0.0, coyote - delta)
	jump_buffer = 0.12 if input.jump else maxf(0.0, jump_buffer - delta)
	var can_move: bool = not actor.statuses.stunned() and actor.state not in ["stagger", "counterthrow", "throw_release"]
	var wish: Vector3 = input.move if can_move else Vector3.ZERO
	if input.dash and can_dash():
		end_hover()
		dash_airborne = not was_floor
		dash_slide_locked = true
		mantle_slide_left = 0
		slide_rearmed = false
		slide_press_age = 99.0
		slide_feedback.begin(input)
		transition("dash_windup", t.dash_buildup)
		dash_charges -= 1
		if dash_cd <= 0: dash_cd = t.dash_cooldown
		actor.resolver.record("cast", actor, "dash")
	if input.hover and hover_cd <= 0.0 and actor.permits("hover"):
		if mode in ["hover", "hover_ascent"]:
			end_hover()
		else:
			transition("hover_ascent", t.hover_ascent_time)
			voluntary_airborne = true
			actor.velocity.y = t.hover_ascent
			actor.resolver.record("cast", actor, "hover")
	if mode == "dash_windup":
		timer -= delta
		actor.velocity.y -= t.gravity * delta
		if timer <= 0.0:
			dash_direction = requested_dash_direction(input)
			if not dash_airborne:
				dash_direction = Vector3(dash_direction.x,0,dash_direction.z).normalized()
				if dash_direction.is_zero_approx(): dash_direction = -actor.global_basis.z
			dash_current_speed = minf(t.speed_limit,maxf(t.dash_speed,Vector2(actor.velocity.x,actor.velocity.z).length()))
			dash_vertical_speed = dash_direction.y * dash_current_speed
			transition("dash", t.dash_duration)
	elif mode == "dash":
		timer -= delta
		actor.velocity = dash_direction * dash_current_speed
		if dash_airborne and dash_direction.y >= 0:
			dash_vertical_speed -= t.gravity * delta
			actor.velocity.y = dash_vertical_speed
		dash_current_speed = maxf(t.ground_speed, dash_current_speed - t.dash_decay * delta)
	elif mode == "slide":
		if not was_floor:
			transition("air")
		else:
			var normal: Vector3 = actor.get_floor_normal()
			var tangent: Vector3 = slide_velocity.slide(normal)
			tangent += (Vector3.DOWN * t.gravity).slide(normal) * delta
			var friction: float = t.slide_friction if slide_source in ["air_dash","ground_dash"] else t.momentum_slide_friction
			tangent = tangent.move_toward(Vector3.ZERO, friction * delta)
			# Steering bends existing momentum along the floor without adding
			# speed. Opposing input cannot instantly reverse a committed slide.
			var steer: Vector3 = wish.slide(normal)
			if not tangent.is_zero_approx() and not steer.is_zero_approx():
				var turn: float = normal.dot(tangent.normalized().cross(steer.normalized()))
				tangent = tangent.rotated(normal,turn*deg_to_rad(t.slide_steer_degrees)*delta*minf(1,steer.length()))
			slide_velocity = tangent.limit_length(t.speed_limit)
			# Keep reliable floor contact at small resting separations; this is
			# support pressure, not stored slide momentum.
			actor.velocity = slide_velocity + Vector3.DOWN * maxf(.5,t.gravity*delta)
			if (tangent.length() < 2.0 and rad_to_deg(actor.get_floor_angle()) < t.slide_slope) or not input.slide:
				transition("ground")
	else:
		# Test incoming momentum before crouch braking. Slide takes priority,
		# including downhill entry, but cannot bypass the dash landing gate.
		var enter_slide: bool = not actor.concealed() and input.slide and slide_rearmed and not dash_slide_locked and was_floor and can_move and actor.state == "ready" and (Vector2(actor.velocity.x,actor.velocity.z).length() >= t.slide_entry_speed or rad_to_deg(actor.get_floor_angle()) >= t.slide_slope)
		var scale: float = 1.0
		if crouched and not enter_slide: scale = (actor.tuning as StitchTuning).conceal_speed if actor.concealed() else t.crouch_speed_scale
		if actor.concealed() and (actor.kit as StitchKit).collapse_left > 0: scale = 0
		if input.aim_held and actor.tuning.hero_id in ["nimbus","slayer"]:
			scale = minf(scale,0.6)
		if actor.state == "guard":
			scale = 0.15
		elif actor.state not in ["ready", "slayer_knife", "slayer_trap", "marshal_shield", "huddle_regroup", "wisp_phase", "samson_cross"]:
			scale = minf(scale, 0.35)
		var current := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
		var movement_scale: float = scale * actor.statuses.movement_scale() * actor.kit.movement_scale()
		var target_speed: float = t.ground_speed * movement_scale * actor.benefits.speed_multiplier()
		current = steer_horizontal(current,wish,target_speed,was_floor,not can_move or movement_scale < .999,delta)
		actor.velocity.x = current.x
		actor.velocity.z = current.z
		if mode == "hover_ascent":
			timer -= delta
			actor.velocity.y = t.hover_ascent
			if timer <= 0.0 or actor.is_on_ceiling():
				transition("hover", t.hover_duration)
		elif mode == "hover":
			timer -= delta
			actor.velocity.y = move_toward(actor.velocity.y, -t.hover_descent, t.gravity * delta)
			if timer <= 0.0 or (was_floor and actor.velocity.y <= 0.0):
				end_hover()
		else:
			actor.velocity.y -= t.gravity * delta
			mode = "ground" if was_floor else "air"
		if enter_slide:
			slide_source = "momentum"
			transition("slide")
		elif crouched and was_floor:
			mode = "crouch"
	var can_traverse: bool = can_move and actor.permits("jump") and mode not in ["dash", "dash_windup"]
	var mantle_request: bool = jump_buffer > 0.0 or (input.jump_held and (wish * Vector3(1,0,1)).length_squared() >= .1)
	if mantle_request and can_traverse:
		if traversal.try_mantle(wish):
			clear_pad_flight()
			jump_buffer = 0
			coyote = 0
			if traversal.advance(delta):
				finish_mantle(delta)
			return
	# Holding Space keeps ledge detection alive, but jumps and wall kicks still
	# require a fresh press (or its short buffer), avoiding automatic kick loops.
	if jump_buffer > 0.0 and can_traverse:
		if not was_floor and coyote <= 0 and traversal.try_wall_jump(wish):
			clear_pad_flight()
			jump_buffer = 0
		elif coyote > 0 and mode not in ["hover", "hover_ascent"]:
			voluntary_airborne = true
			actor.velocity.y = t.jump_impulse
			jump_buffer = 0.0
			coyote = 0.0
			transition("air")
			visual("jump",actor.velocity)
		elif not was_floor and input.jump and actor.kit is RelayKit and (actor.kit as RelayKit).spirit_jump(input):
			clear_pad_flight()
			jump_buffer = 0
	actor.velocity = actor.velocity.limit_length(movement_speed_limit())
	var before: Vector3 = actor.velocity
	actor.floor_stop_on_slope = mode != "slide"
	if mode in ["dash","dash_windup","slide","hover","hover_ascent"] or voluntary_airborne:
		actor.move_ability_slide(delta)
	else: actor.move_and_slide()
	if mode == "slide":
		for index: int in actor.get_slide_collision_count():
			var normal: Vector3 = actor.get_slide_collision(index).get_normal()
			if absf(normal.y) < 0.7:
				slide_velocity = slide_velocity.slide(normal)
	if mode == "dash":
		for index: int in actor.get_slide_collision_count():
			var normal: Vector3 = actor.get_slide_collision(index).get_normal()
			if normal.dot(Vector3.UP) >= cos(actor.floor_max_angle) and before.dot(normal) < -0.5:
				# Project once. No new impulse, no charge/cooldown reset.
				actor.velocity = before.slide(normal)
				if not dash_airborne: continue
				slide_feedback.resolve("",input,slide_press_age,actor.velocity.length())
				if dash_airborne and input.slide and slide_press_age <= t.dash_slide_window + .000001 and actor.velocity.length() >= t.slide_entry_speed:
					slide_source = "air_dash"
					transition("slide")
					dash_slide = true
					dash_slide_locked = false
					slide_rearmed = true
				else:
					transition("ground")
				break
			elif absf(normal.y) < 0.7 or normal.y < -0.7:
				slide_feedback.resolve("ceiling" if normal.y < -.7 else "wall",input,slide_press_age,0)
				actor.velocity = before.slide(normal)
				transition("air")
				break
			elif dash_airborne and normal.dot(Vector3.UP) >= cos(actor.floor_max_angle):
				slide_feedback.resolve("not_downward",input,slide_press_age,0)
		if mode == "dash" and timer <= 0:
			finish_dash(input,can_move)
	if mode == "hover_ascent" and actor.is_on_ceiling():
		transition("hover", t.hover_duration)
	if mode == "ground" and crouched: mode = "crouch"

func posture_lowering() -> float:
	return standing_capsule.height - (body_collision.shape as CapsuleShape3D).height

func try_stand() -> bool:
	if not crouched: return true
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_clearance_capsule
	query.transform = actor.global_transform
	query.transform.origin += Vector3.UP * (standing_capsule.height * .5 + .01)
	query.collision_mask = actor.collision_mask
	query.exclude = [actor.get_rid()]
	query.margin = 0.0
	if not actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	set_crouched(false)
	return true

func update_posture(requested: bool) -> void:
	if requested:
		set_crouched(true)
	else:
		try_stand()

func set_crouched(value: bool) -> void:
	crouched = value
	var capsule := body_collision.shape as CapsuleShape3D
	capsule.height = clampf(actor.tuning.crouch_height,capsule.radius * 2,standing_capsule.height) if value else standing_capsule.height
	body_collision.position.y = capsule.height * .5
	if not value and mode == "crouch": mode = "ground" if grounded() else "air"

func finish_mantle(delta: float) -> void:
	# The checked landing supplies ground permission immediately. Resolve a
	# buffered slide BEFORE moving so a wall kick cannot carry us off the lip.
	mantle_slide_direction = traversal.approach_direction
	mantle_slide_left = actor.tuning.mantle_slide_window
	dash_slide_locked = false
	coyote = .1
	var exit_slide: bool = jump_buffer <= 0 and mantle_slide_buffered and actor.intent.slide
	if exit_slide: start_mantle_slide()
	actor.velocity.y = -actor.tuning.gravity * delta
	if jump_buffer > 0:
		actor.velocity.y = actor.tuning.jump_impulse
		jump_buffer = 0
		coyote = 0
		mantle_slide_left = 0
		visual("jump",actor.velocity)
	actor.velocity = actor.velocity.limit_length(actor.tuning.speed_limit)
	actor.move_ability_slide(delta)
	# Mantles end slightly above the validated roof. Airborne approaches have
	# no cached floor contact, so settle onto that roof in the handoff tick.
	if coyote > 0: actor.apply_floor_snap()
	transition("slide" if exit_slide and grounded() else ("ground" if actor.is_on_floor() else "air"))
	mantle_slide_buffered = false

func start_mantle_slide() -> void:
	var speed: float = maxf(actor.tuning.mantle_slide_speed,actor.velocity.dot(mantle_slide_direction))
	actor.velocity = (mantle_slide_direction * speed).limit_length(actor.tuning.speed_limit)
	mantle_slide_left = 0
	mantle_slide_buffered = false
	dash_slide_locked = false
	slide_source = "mantle"
	transition("slide")

func can_dash() -> bool:
	return dash_charges > 0 and mode not in ["dash","dash_windup"] and actor.permits("dash")

func refill_dashes() -> void:
	dash_charges = actor.tuning.dash_capacity
	dash_cd = 0

func tick_dash_recharge(delta: float) -> void:
	if dash_charges >= actor.tuning.dash_capacity:
		dash_cd = 0
		return
	dash_cd -= delta
	while dash_cd <= 0 and dash_charges < actor.tuning.dash_capacity:
		dash_charges += 1
		if dash_charges < actor.tuning.dash_capacity: dash_cd += actor.tuning.dash_cooldown
	if dash_charges >= actor.tuning.dash_capacity: dash_cd = 0

func requested_dash_direction(input: CombatIntent) -> Vector3:
	var aim: Vector3 = input.aim.normalized()
	var forward: Vector3 = (aim * Vector3(1,0,1)).normalized()
	if forward.is_zero_approx(): forward = -actor.global_basis.z
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	var direction: Vector3 = aim
	if not input.move.is_zero_approx():
		direction = (aim if dash_airborne else forward) * input.move.dot(forward) + right * input.move.dot(right)
	if not dash_airborne: direction.y = 0
	direction = direction.normalized() if not direction.is_zero_approx() else forward
	if dash_airborne and direction.y > sin(deg_to_rad(actor.tuning.dash_up_angle)):
		var flat: Vector3 = (direction * Vector3(1,0,1)).normalized()
		if flat.is_zero_approx(): flat = forward
		var angle: float = deg_to_rad(actor.tuning.dash_up_angle)
		direction = flat * cos(angle) + Vector3.UP * sin(angle)
	return direction

func finish_dash(input: CombatIntent, can_move: bool) -> void:
	if not dash_airborne:
		dash_slide_locked = false
		slide_rearmed = true
		if grounded() and can_move and actor.state == "ready" and input.slide and not actor.concealed():
			var tangent: Vector3 = actor.velocity.slide(actor.get_floor_normal())
			if tangent.length() >= actor.tuning.slide_entry_speed:
				actor.velocity = tangent
				slide_source = "ground_dash"
				slide_feedback.success()
				transition("slide")
				dash_slide = true
				return
		slide_feedback.clear()
	else:
		slide_feedback.resolve("not_downward" if grounded() else "expired",input,slide_press_age,0)
	transition("ground" if grounded() else "air")

func steer_horizontal(current: Vector3, wish: Vector3, target_speed: float, on_floor: bool, restricted: bool, delta: float) -> Vector3:
	var t: HeroTuning = actor.tuning
	if restricted:
		return current.move_toward(wish * target_speed,t.braking * delta)
	if wish.length_squared() < .01:
		return current.move_toward(Vector3.ZERO,t.braking * delta) if on_floor else current
	if not on_floor and mode not in ["hover","hover_ascent"]:
		# Source-style projection cap: turning the wish vector opens room for
		# acceleration without pulling existing perpendicular momentum away.
		var direction: Vector3 = wish.normalized()
		var incoming_speed: float = current.length()
		var add: float = minf(target_speed,t.air_wish_cap)*minf(1,wish.length())-current.dot(direction)
		if add > 0: current += direction*minf(add,t.air_acceleration*delta)
		# Keep the responsive turn, but make speed gain gradual and bounded.
		# Earned dash/launch speed remains steerable above this gain ceiling.
		var gain_ceiling: float = maxf(incoming_speed,t.air_strafe_speed_limit)
		var gain_budget: float = maxf(minf(target_speed,t.air_strafe_speed_limit),incoming_speed+maxf(0,t.air_speed_gain_rate)*delta)
		return current.limit_length(minf(movement_speed_limit(),minf(gain_ceiling,gain_budget)))
	var speed: float = current.length()
	var desired: Vector3 = wish.normalized()
	var acceleration: float = t.acceleration if on_floor else t.air_steering
	if not on_floor:
		var strength: float = minf(1,wish.length())
		var step: float = maxf(0,t.air_steering) * strength * delta
		if speed <= .001:
			return current.move_toward(desired * target_speed * strength,step)
		# Opposing input brakes before a later tick can launch backward.
		if current.dot(desired) < 0:
			return current.move_toward(Vector3.ZERO,step)
		# Angular control stays useful at speed without creating strafe boosts.
		var air_angle: float = current.signed_angle_to(desired,Vector3.UP)
		var max_turn: float = deg_to_rad(maxf(0,t.air_turn_degrees)) * strength * delta
		var air_speed: float = maxf(speed,minf(target_speed * strength,speed + step))
		return current.rotated(Vector3.UP,clampf(air_angle,-max_turn,max_turn)).normalized() * air_speed
	if speed > .001 and current.dot(desired) < 0:
		return current.move_toward(Vector3.ZERO,(t.braking if on_floor else acceleration) * delta)
	var desired_speed: float = target_speed * minf(1,wish.length())
	if speed <= desired_speed:
		return current.move_toward(desired * desired_speed,acceleration * delta)
	# Rotate existing momentum rather than adding speed through strafing.
	var angle: float = current.signed_angle_to(desired,Vector3.UP)
	var turn: float = clampf(angle,-acceleration * delta / speed,acceleration * delta / speed)
	var exit_speed: float = maxf(desired_speed,speed-t.ground_overspeed_decay * delta) if on_floor else speed
	return current.rotated(Vector3.UP,turn).normalized() * exit_speed

func grounded() -> bool:
	if not actor.is_on_floor() and mode != "slide":
		return false
	# move_and_collide and training teleports do not refresh is_on_floor.
	# Confirm actual nearby support before rearming jumps or coyote time.
	var collision := KinematicCollision3D.new()
	if actor.test_move(actor.global_transform,Vector3.DOWN * .06,collision) and collision.get_normal().y >= cos(actor.floor_max_angle): return true
	# A resting sweep can report a grazing contact instead of its support.
	# Confirm a nearby walkable floor so flat slides do not randomly drop out.
	var support: Dictionary = actor.resolver.ray(actor.global_position+Vector3.UP*.02,actor.global_position+Vector3.DOWN*.06,[actor.get_rid()],1)
	return not support.is_empty() and support.normal.y >= cos(actor.floor_max_angle)

func transition(next: String, duration: float = 0.0) -> void:
	if next in ["dash_windup","dash","mantle","hover","hover_ascent","slide"]: clear_pad_flight()
	if mode != next and is_instance_valid(actor.resolver):
		actor.resolver.record("movement", actor, next)
	var changed: bool = mode != next
	mode = next
	if changed and next == "dash": visual("dash",dash_direction)
	if next == "slide":
		slide_velocity = actor.velocity
		set_crouched(true)
		if changed: visual("dash_slide" if slide_source in ["air_dash","ground_dash"] else ("mantle_slide" if slide_source == "mantle" else "slide"),actor.velocity,actor.get_floor_normal() if actor.is_on_floor() else Vector3.UP)
	if next != "slide":
		dash_slide = false
	timer = duration

func end_hover() -> void:
	if mode in ["hover", "hover_ascent"]:
		hover_cd = actor.tuning.hover_cooldown
		transition("air")

func cancel() -> void:
	clear_pad_flight()
	if slide_feedback != null: slide_feedback.clear()
	voluntary_airborne = false
	set_crouched(false)
	external_velocity = Vector3.ZERO
	if traversal != null:
		traversal.reset()
	mode = "ground"
	timer = 0.0
	refill_dashes()
	dash_slide_locked = false
	slide_source = ""
	mantle_slide_left = 0
	mantle_slide_buffered = false
	hover_cd = 0.0
	coyote = 0.0
	jump_buffer = 0.0
	dash_slide = false
	dash_airborne = false
	dash_vertical_speed = 0
	dash_current_speed = 0
	slide_press_age = 99.0
	slide_rearmed = true
	slide_velocity = Vector3.ZERO

func interrupt_mobility() -> void:
	clear_pad_flight()
	slide_feedback.clear()
	if is_instance_valid(actor.presentation.movement): actor.presentation.movement.clear()
	mantle_slide_left = 0
	mantle_slide_buffered = false
	if traversal != null and traversal.active: traversal.abort()
	end_hover()
	transition("ground" if actor.is_on_floor() else "air")
	if actor.state.begins_with("stitch_") or actor.state.begins_with("slayer_boot") or actor.state in ["huddle_scatter","huddle_wave","huddle_wave_start","wisp_step","wisp_heist_start"]:
		actor.kit.cancel()
	if actor.kit is WispKit: (actor.kit as WispKit).clear_leap()
	actor.velocity.x = 0.0
	actor.velocity.z = 0.0
	# A root/slow interrupts voluntary mobility, not an enemy's existing push.

func visual(kind: String, direction: Vector3, normal: Vector3 = Vector3.UP, strength: float = 1) -> void:
	var at: Vector3 = actor.body_point(.9) if kind == "dash" else actor.global_position+Vector3.UP*.055
	actor.movement_confirmed.emit(kind,at,direction,normal,strength)
