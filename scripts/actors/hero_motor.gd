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
var slide_velocity: Vector3 = Vector3.ZERO

func tick(delta: float, input: CombatIntent) -> void:
	var t: HeroTuning = actor.tuning
	dash_cd = maxf(0.0, dash_cd - delta)
	hover_cd = maxf(0.0, hover_cd - delta)
	if actor.infinite_resources:
		dash_cd = 0.0
		hover_cd = 0.0
	if actor.state in ["captured", "throw_pair"]:
		actor.velocity = Vector3.ZERO
		return
	if actor.state in ["melee_windup", "melee_active"]:
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
		return
	var was_floor: bool = actor.is_on_floor()
	coyote = 0.1 if was_floor else maxf(0.0, coyote - delta)
	jump_buffer = 0.12 if input.jump else maxf(0.0, jump_buffer - delta)
	var can_move: bool = actor.state not in ["stagger", "counterthrow", "throw_release"]
	var wish: Vector3 = input.move if can_move else Vector3.ZERO
	if input.dash and dash_cd <= 0.0 and actor.permits("dash"):
		end_hover()
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
			if dash_slide and input.slide:
				dash_slide = false
			if (tangent.length() < 2.0 and rad_to_deg(actor.get_floor_angle()) < t.slide_slope) or (not input.slide and not dash_slide):
				transition("ground")
	else:
		var scale: float = 1.0
		if input.aim_held:
			scale = 0.6
		if actor.state == "guard":
			scale = 0.15
		elif actor.state == "reload":
			scale = minf(scale, t.reload_move_multiplier)
		elif actor.state != "ready":
			scale = minf(scale, 0.35)
		var current := Vector3(actor.velocity.x, 0.0, actor.velocity.z)
		var acceleration: float = t.acceleration if was_floor else t.air_steering
		if wish.length_squared() < 0.01 and was_floor:
			acceleration = t.braking
		current = current.move_toward(wish * t.ground_speed * scale, acceleration * delta)
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
		if input.slide and was_floor and can_move and actor.state == "ready":
			var slope: float = rad_to_deg(actor.get_floor_angle())
			if current.length() >= t.slide_entry_speed or slope >= t.slide_slope:
				transition("slide")
	if jump_buffer > 0.0 and coyote > 0.0 and can_move and actor.permits("jump") and mode not in ["dash", "dash_windup", "hover", "hover_ascent"]:
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
				transition("slide")
				dash_slide = true
				break
			elif absf(normal.y) < 0.7 or normal.y < -0.7:
				actor.velocity = before.slide(normal)
				transition("air")
				break
	if mode == "hover_ascent" and actor.is_on_ceiling():
		transition("hover", t.hover_duration)

func transition(next: String, duration: float = 0.0) -> void:
	if mode != next and is_instance_valid(actor.resolver):
		actor.resolver.record("movement", actor, next)
	mode = next
	if next == "slide":
		slide_velocity = actor.velocity
	if next != "slide":
		dash_slide = false
	timer = duration

func end_hover() -> void:
	if mode in ["hover", "hover_ascent"]:
		hover_cd = actor.tuning.hover_cooldown
		transition("air")

func cancel() -> void:
	mode = "ground"
	timer = 0.0
	dash_cd = 0.0
	hover_cd = 0.0
	coyote = 0.0
	jump_buffer = 0.0
	dash_slide = false
	slide_velocity = Vector3.ZERO
