class_name HeroMotor
extends Node

var actor: HeroActor
var mode: String = "ground"
var timer: float = 0.0
var dash_cd: float = 0.0
var hover_cd: float = 0.0
var dash_direction: Vector3 = Vector3.FORWARD
var dash_current_speed: float = 0.0
var coyote: float = 0.0
var jump_buffer: float = 0.0
var dash_slide: bool = false
var dash_airborne: bool = false
var slide_press_age: float = 99.0
var slide_rearmed: bool = true
var slide_velocity: Vector3 = Vector3.ZERO
var traversal: TraversalMotion
var external_velocity: Vector3 = Vector3.ZERO
var crouched: bool = false
var body_collision: CollisionShape3D
var standing_capsule: CapsuleShape3D

func _ready() -> void:
	body_collision = actor.get_node("BodyCollision") as CollisionShape3D
	standing_capsule = body_collision.shape.duplicate() as CapsuleShape3D
	traversal = TraversalMotion.new()
	traversal.actor = actor

func tick(delta: float, input: CombatIntent) -> void:
	tick_motion(delta,input)
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
	var was_floor: bool = grounded()
	update_posture(was_floor and input.slide and mode not in ["dash","dash_windup","mantle"] and actor.state not in ["captured","throw_pair","boot_attached","boot_captured","stagger","counterthrow","throw_release"])
	slide_press_age += delta
	if input.slide_pressed: slide_press_age = 0.0
	if not input.slide and mode not in ["dash","dash_windup"]: slide_rearmed = true
	traversal.tick(delta,was_floor)
	dash_cd = maxf(0.0, dash_cd - delta)
	hover_cd = maxf(0.0, hover_cd - delta)
	if actor.infinite_resources:
		dash_cd = 0.0
		hover_cd = 0.0
	if traversal.active:
		# Keep a short press buffer through the finish without turning the held
		# auto-mantle input into an automatic jump on every rooftop.
		jump_buffer = .12 if input.jump else maxf(0,jump_buffer - delta)
		traversal.carry_running_input(delta,input.move)
		if traversal.advance(delta):
			finish_mantle(delta)
		return
	if actor.state in ["captured", "throw_pair", "boot_attached", "boot_captured"]:
		actor.velocity = Vector3.ZERO
		return
	if actor.kit.move_override(delta):
		return
	if actor.statuses.effects.has("root"):
		actor.velocity = Vector3(0,actor.velocity.y - t.gravity * delta,0)
		actor.move_and_slide()
		return
	if actor.state in ["melee_windup", "melee_active"] or (actor.state == "melee_recovery" and actor.close.melee_age - delta < t.melee_lunge_delay + t.melee_lunge_duration):
		var lunge: Vector3 = actor.close.lunge_displacement(delta)
		actor.velocity.x = lunge.x / delta
		actor.velocity.z = lunge.z / delta
		actor.velocity.y -= t.gravity * delta
		actor.velocity = actor.velocity.limit_length(t.speed_limit)
		actor.move_and_slide()
		for index: int in actor.get_slide_collision_count():
			var normal: Vector3 = actor.get_slide_collision(index).get_normal()
			if normal.dot(actor.close.melee_direction) < -0.25 and normal.y < cos(actor.floor_max_angle):
				actor.close.lunge_blocked = true
		if actor.close.melee_age >= t.melee_lunge_delay + t.melee_lunge_duration:
			actor.velocity.x = 0
			actor.velocity.z = 0
		return
	coyote = 0.1 if was_floor else maxf(0.0, coyote - delta)
	jump_buffer = 0.12 if input.jump else maxf(0.0, jump_buffer - delta)
	var can_move: bool = actor.state not in ["stagger", "counterthrow", "throw_release"]
	var wish: Vector3 = input.move if can_move else Vector3.ZERO
	if input.dash and dash_cd <= 0.0 and actor.permits("dash"):
		end_hover()
		dash_airborne = not was_floor
		slide_rearmed = false
		slide_press_age = 99.0
		transition("dash_windup", t.dash_buildup)
		dash_cd = t.dash_cooldown
		actor.resolver.record("cast", actor, "dash")
	if input.hover and hover_cd <= 0.0 and actor.permits("hover"):
		if mode in ["hover", "hover_ascent"]:
			end_hover()
		else:
			transition("hover_ascent", t.hover_ascent_time)
			actor.velocity.y = t.hover_ascent
			actor.resolver.record("cast", actor, "hover")
	if mode == "dash_windup":
		timer -= delta
		actor.velocity.x = move_toward(actor.velocity.x, 0.0, delta * 8.0)
		actor.velocity.z = move_toward(actor.velocity.z, 0.0, delta * 8.0)
		actor.velocity.y -= t.gravity * delta
		if timer <= 0.0:
			dash_direction = actor.aim_direction
			if not dash_airborne:
				dash_direction = Vector3(dash_direction.x,0,dash_direction.z).normalized()
				if dash_direction.is_zero_approx(): dash_direction = -actor.global_basis.z
			dash_current_speed = t.dash_speed
			transition("dash", t.dash_duration)
	elif mode == "dash":
		timer -= delta
		actor.velocity = dash_direction * dash_current_speed
		dash_current_speed = maxf(t.ground_speed, dash_current_speed - t.dash_decay * delta)
		if timer <= 0.0:
			transition("air")
	elif mode == "slide":
		if not was_floor:
			transition("air")
		else:
			var normal: Vector3 = actor.get_floor_normal()
			var tangent: Vector3 = slide_velocity.slide(normal)
			tangent += (Vector3.DOWN * t.gravity).slide(normal) * delta
			tangent = tangent.move_toward(Vector3.ZERO, t.slide_friction * delta)
			slide_velocity = tangent.limit_length(t.speed_limit)
			actor.velocity = slide_velocity + Vector3.DOWN * 0.1
			if (tangent.length() < 2.0 and rad_to_deg(actor.get_floor_angle()) < t.slide_slope) or not input.slide:
				transition("ground")
	else:
		# Test incoming momentum before crouch braking. Slide takes priority,
		# including downhill entry, but cannot bypass the dash landing gate.
		var enter_slide: bool = input.slide and slide_rearmed and was_floor and can_move and actor.state == "ready" and (Vector2(actor.velocity.x,actor.velocity.z).length() >= t.slide_entry_speed or rad_to_deg(actor.get_floor_angle()) >= t.slide_slope)
		var scale: float = 1.0
		if crouched and not enter_slide: scale = t.crouch_speed_scale
		if input.aim_held and actor.tuning.hero_id in ["nimbus","slayer"]:
			scale = minf(scale,0.6)
		if actor.state == "guard":
			scale = 0.15
		elif actor.state not in ["ready", "slayer_knife", "slayer_trap", "marshal_shield", "huddle_regroup", "wisp_phase"]:
			scale = minf(scale, 0.35)
		var current := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
		var acceleration: float = t.acceleration if was_floor else t.air_steering
		if wish.length_squared() < 0.01 and was_floor:
			acceleration = t.braking
		current = current.move_toward(wish * t.ground_speed * scale * actor.statuses.movement_scale() * actor.kit.movement_scale() * actor.benefits.speed_multiplier(), acceleration * delta)
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
			transition("slide")
		elif crouched and was_floor:
			mode = "crouch"
	var can_traverse: bool = can_move and actor.permits("jump") and mode not in ["dash", "dash_windup"]
	var mantle_request: bool = jump_buffer > 0.0 or (input.jump_held and (wish * Vector3(1,0,1)).length_squared() >= .1)
	if mantle_request and can_traverse:
		if traversal.try_mantle(wish):
			jump_buffer = 0
			coyote = 0
			if traversal.advance(delta):
				finish_mantle(delta)
			return
	# Holding Space keeps ledge detection alive, but jumps and wall kicks still
	# require a fresh press (or its short buffer), avoiding automatic kick loops.
	if jump_buffer > 0.0 and can_traverse:
		if not was_floor and coyote <= 0 and traversal.try_wall_jump(wish):
			jump_buffer = 0
		elif coyote > 0 and mode not in ["hover", "hover_ascent"]:
			actor.velocity.y = t.jump_impulse
			jump_buffer = 0.0
			coyote = 0.0
			transition("air")
	actor.velocity = actor.velocity.limit_length(t.speed_limit)
	var before: Vector3 = actor.velocity
	actor.floor_stop_on_slope = mode != "slide"
	actor.move_and_slide()
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
				if dash_airborne and input.slide and slide_press_age <= t.dash_slide_window + .000001 and actor.velocity.length() >= t.slide_entry_speed:
					transition("slide")
					dash_slide = true
					slide_rearmed = true
				else:
					transition("ground")
				break
			elif absf(normal.y) < 0.7 or normal.y < -0.7:
				actor.velocity = before.slide(normal)
				transition("air")
				break
	if mode == "hover_ascent" and actor.is_on_ceiling():
		transition("hover", t.hover_duration)
	if mode == "ground" and crouched: mode = "crouch"

func posture_lowering() -> float:
	return standing_capsule.height - (body_collision.shape as CapsuleShape3D).height

func try_stand() -> bool:
	if not crouched: return true
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_capsule
	query.transform = actor.global_transform
	query.transform.origin += Vector3.UP * (standing_capsule.height * .5)
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

func finish_mantle(delta: float) -> void:
	# The checked landing supplies ground permission immediately. Continue the
	# carried motion in this same tick, or launch a buffered jump off the top.
	coyote = .1
	actor.velocity.y = -actor.tuning.gravity * delta
	if jump_buffer > 0:
		actor.velocity.y = actor.tuning.jump_impulse
		jump_buffer = 0
		coyote = 0
	actor.velocity = actor.velocity.limit_length(actor.tuning.speed_limit)
	actor.move_and_slide()
	transition("ground" if actor.is_on_floor() else "air")

func grounded() -> bool:
	if not actor.is_on_floor():
		return false
	# move_and_collide and training teleports do not refresh is_on_floor.
	# Confirm actual nearby support before rearming jumps or coyote time.
	var collision := KinematicCollision3D.new()
	return actor.test_move(actor.global_transform,Vector3.DOWN * .06,collision) and collision.get_normal().y >= cos(actor.floor_max_angle)

func transition(next: String, duration: float = 0.0) -> void:
	if mode != next and is_instance_valid(actor.resolver):
		actor.resolver.record("movement", actor, next)
	mode = next
	if next == "slide":
		slide_velocity = actor.velocity
		set_crouched(true)
	if next != "slide":
		dash_slide = false
	timer = duration

func end_hover() -> void:
	if mode in ["hover", "hover_ascent"]:
		hover_cd = actor.tuning.hover_cooldown
		transition("air")

func cancel() -> void:
	set_crouched(false)
	external_velocity = Vector3.ZERO
	if traversal != null:
		traversal.reset()
	mode = "ground"
	timer = 0.0
	dash_cd = 0.0
	hover_cd = 0.0
	coyote = 0.0
	jump_buffer = 0.0
	dash_slide = false
	dash_airborne = false
	slide_press_age = 99.0
	slide_rearmed = true
	slide_velocity = Vector3.ZERO

func interrupt_mobility() -> void:
	if traversal != null and traversal.active: traversal.abort()
	end_hover()
	transition("ground" if actor.is_on_floor() else "air")
	if actor.state.begins_with("slayer_boot") or actor.state in ["huddle_scatter","huddle_wave","huddle_wave_start","wisp_step","wisp_ballet","wisp_ballet_start"]:
		actor.kit.cancel()
	actor.velocity.x = 0.0
	actor.velocity.z = 0.0
	# A root/slow interrupts voluntary mobility, not an enemy's existing push.
