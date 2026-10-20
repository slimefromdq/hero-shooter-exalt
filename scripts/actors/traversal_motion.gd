class_name TraversalMotion
extends RefCounted

# Shared movement authority. Ledges use environment probes, but the complete
# standing capsule is swept against the world AND other actors along the path.
var actor: HeroActor
var active: bool = false
var origin: Vector3
var raised: Vector3
var landing: Vector3
var elapsed: float = 0.0
var duration: float = 0.32
var progress: float = 0.0
var approach_direction: Vector3 = Vector3.FORWARD
var carried_velocity: Vector3 = Vector3.ZERO
var last_wall_normal: Vector3 = Vector3.ZERO
var wall_cooldown: float = 0.0
var wall_pose: float = 0.0

func tick(delta: float, grounded: bool) -> void:
	wall_cooldown = maxf(0, wall_cooldown - delta)
	wall_pose = maxf(0, wall_pose - delta)
	if grounded and not active:
		last_wall_normal = Vector3.ZERO
	if active and (actor.state != "mantle" or actor.motor.mode != "mantle"):
		abort()

func try_mantle(wish: Vector3) -> bool:
	var forward: Vector3 = (wish * Vector3(1,0,1)).normalized()
	if forward.is_zero_approx(): forward = (actor.aim_direction * Vector3(1,0,1)).normalized()
	if forward.is_zero_approx(): return false
	var side: Vector3 = forward.cross(Vector3.UP)
	var probes: Array[Vector3] = [Vector3.ZERO,side*actor.tuning.mantle_probe_offset,-side*actor.tuning.mantle_probe_offset]
	probes.sort_custom(func(a: Vector3,b: Vector3) -> bool:
		var from_a: Vector3 = actor.global_position+Vector3.UP*.5+a
		var from_b: Vector3 = actor.global_position+Vector3.UP*.5+b
		var hit_a: Dictionary = actor.resolver.ray(from_a,from_a+forward*actor.tuning.mantle_reach,[],1)
		var hit_b: Dictionary = actor.resolver.ray(from_b,from_b+forward*actor.tuning.mantle_reach,[],1)
		var distance_a: float = from_a.distance_squared_to(hit_a.position) if not hit_a.is_empty() else INF
		var distance_b: float = from_b.distance_squared_to(hit_b.position) if not hit_b.is_empty() else INF
		return distance_a < distance_b)
	for offset: Vector3 in probes:
		if try_mantle_probe(wish,offset): return true
	return false

func try_mantle_probe(wish: Vector3, offset: Vector3) -> bool:
	var forward: Vector3 = wish * Vector3(1,0,1)
	if forward.length_squared() < .1:
		forward = actor.aim_direction * Vector3(1,0,1)
	if forward.length_squared() < .1:
		return false
	forward = forward.normalized()
	var t: HeroTuning = actor.tuning
	var from: Vector3 = actor.global_position + Vector3.UP * .5 + offset
	var wall: Dictionary = actor.resolver.ray(from, from + forward * t.mantle_reach, [], 1)
	if wall.is_empty() or absf((wall.normal as Vector3).y) > .2:
		return false
	var normal: Vector3 = wall.normal
	if forward.dot(-normal) < t.mantle_approach_dot:
		return false
	# Probe beyond the lip far enough for the whole capsule to stand on top.
	var over: Vector3 = wall.position - normal * .55
	var top: Dictionary = actor.resolver.ray(Vector3(over.x,actor.global_position.y + t.mantle_height + .1,over.z), Vector3(over.x,actor.global_position.y + .25,over.z), [], 1)
	if top.is_empty() or (top.normal as Vector3).y < cos(actor.floor_max_angle):
		return false
	var height: float = (top.position as Vector3).y - actor.global_position.y
	if height < .3 or height > t.mantle_height:
		return false
	origin = actor.global_position
	landing = top.position + Vector3.UP * .045
	raised = Vector3(origin.x,landing.y + .06,origin.z)
	# A standing landing needs headroom and support under both feet, not just
	# a single ray grazing a thin wall or the edge of another tower.
	if not supported(landing):
		return false
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.shape = actor.motor.standing_capsule
	shape.transform = actor.global_transform
	shape.transform.origin = landing + Vector3.UP * .95
	shape.collision_mask = actor.collision_mask
	shape.exclude = [actor.get_rid()]
	shape.margin = .01
	if not actor.get_world_3d().direct_space_state.intersect_shape(shape,1).is_empty():
		return false
	var was_crouched: bool = actor.motor.crouched
	if not actor.motor.try_stand(): return false
	var transform: Transform3D = actor.global_transform
	for index: int in range(1,25):
		var point: Vector3 = sample(float(index) / 24.0)
		if actor.test_move(transform,point - transform.origin):
			actor.motor.set_crouched(was_crouched)
			return false
		transform.origin = point
	actor.motor.end_hover()
	actor.motor.transition("mantle")
	actor.state = "mantle"
	actor.aim_direction = forward
	actor.rotation.y = atan2(-forward.x,-forward.z)
	approach_direction = (-normal * Vector3(1,0,1)).normalized()
	actor.motor.mantle_slide_buffered = false
	actor.motor.mantle_slide_left = 0
	carried_velocity = (actor.velocity * Vector3(1,0,1)).limit_length(t.speed_limit)
	actor.velocity = Vector3.ZERO
	active = true
	elapsed = 0
	progress = 0
	duration = maxf(.25,t.mantle_duration)
	actor.state_time = duration
	actor.resolver.record("cast",actor,"mantle")
	return true

func supported(at: Vector3) -> bool:
	for offset: Vector3 in [Vector3.ZERO,Vector3(.28,0,0),Vector3(-.28,0,0),Vector3(0,0,.28),Vector3(0,0,-.28)]:
		var hit: Dictionary = actor.resolver.ray(at + offset + Vector3.UP * .12, at + offset + Vector3.DOWN * .16, [], 1)
		if hit.is_empty() or (hit.normal as Vector3).y < cos(actor.floor_max_angle):
			return false
	return true

func sample(p: float) -> Vector3:
	if p < .6:
		return origin.lerp(raised,smoothstep(0,.6,p))
	return raised.lerp(landing,smoothstep(.6,1,p))

func carry_running_input(delta: float, wish: Vector3) -> void:
	var flat: Vector3 = wish * Vector3(1,0,1)
	if flat.length_squared() < .01:
		return
	var speed: float = carried_velocity.length()
	var direction: Vector3 = carried_velocity.normalized() if speed > .01 else actor.aim_direction
	if flat.normalized().dot(direction) < .65:
		return
	# Continuing into the climb can build a slow approach up to running speed;
	# faster incoming motion and its direction remain intact.
	var desired: float = actor.tuning.ground_speed * minf(1,flat.length())
	if speed < desired:
		carried_velocity = direction * move_toward(speed,desired,actor.tuning.acceleration * delta)

func advance(delta: float) -> bool:
	if not supported(landing):
		abort()
		return false
	elapsed += delta
	progress = clampf(elapsed / duration,0,1)
	var desired: Vector3 = sample(progress)
	# At most 0.16 m per substep, even at low frame rates. Every step is swept.
	var distance: float = actor.global_position.distance_to(desired)
	var steps: int = maxi(1,ceili(distance / .16))
	var from: Vector3 = actor.global_position
	for index: int in range(1,steps + 1):
		var next: Vector3 = from.lerp(desired,float(index) / steps)
		if actor.move_ability_collide(next - actor.global_position) != null or actor.mobility_limited:
			abort()
			return false
	actor.velocity = Vector3.ZERO
	if progress >= 1:
		active = false
		actor.state = "ready"
		actor.state_time = 0
		actor.velocity = carried_velocity
		# A wall kick may still point away from the ledge when a tall mantle
		# catches. Completion must carry that speed over the roof, even when
		# crouch was pressed too early to earn the timed mantle-slide boost.
		if actor.velocity.dot(approach_direction) < 0:
			actor.velocity = approach_direction * carried_velocity.length()
		carried_velocity = Vector3.ZERO
		actor.motor.transition("air")
		actor.resolver.record("land",actor,"mantle")
		actor.movement_confirmed.emit("mantle",landing,approach_direction,Vector3.UP,1)
		return true
	return false

func try_wall_jump(wish: Vector3) -> bool:
	if wall_cooldown > 0:
		return false
	var forward: Vector3 = (actor.aim_direction * Vector3(1,0,1)).normalized()
	var directions: Array[Vector3] = [(wish * Vector3(1,0,1)).normalized(),forward,Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT]
	for diagonal: Vector3 in [Vector3(1,0,1),Vector3(-1,0,1),Vector3(1,0,-1),Vector3(-1,0,-1)]:
		directions.append(diagonal.normalized())
	var nearest: float = INF
	var normal: Vector3 = Vector3.ZERO
	var from: Vector3 = actor.global_position + Vector3.UP
	for direction: Vector3 in directions:
		if direction.is_zero_approx():
			continue
		var hit: Dictionary = actor.resolver.ray(from,from + direction * actor.tuning.wall_jump_reach,[],1)
		if hit.is_empty() or absf((hit.normal as Vector3).y) > .2:
			continue
		var candidate: Vector3 = hit.normal
		if not last_wall_normal.is_zero_approx() and last_wall_normal.dot(candidate) > .5:
			continue
		var distance: float = from.distance_to(hit.position)
		if distance < nearest:
			nearest = distance
			normal = candidate
	if normal.is_zero_approx():
		return false
	normal = (normal * Vector3(1,0,1)).normalized()
	var horizontal: Vector3 = actor.velocity * Vector3(1,0,1)
	var upward: float = minf(actor.tuning.speed_limit,maxf(actor.tuning.wall_jump_up,actor.velocity.y))
	var horizontal_limit: float = sqrt(maxf(0,actor.tuning.speed_limit*actor.tuning.speed_limit-upward*upward))
	var speed: float = minf(horizontal_limit,maxf(actor.tuning.wall_jump_speed,horizontal.length()))
	var outward: float = minf(speed,maxf(actor.tuning.wall_jump_out,speed*maxf(0,forward.dot(normal))))
	var tangent: Vector3 = forward.slide(normal).normalized()
	# Facing into the wall is an up-and-back kick, with no arbitrary
	# tangent inherited from momentum or chosen from the wall's orientation.
	if forward.dot(-normal) >= actor.tuning.wall_jump_head_on_dot or tangent.is_zero_approx():
		outward = speed
		tangent = Vector3.ZERO
	var launch: Vector3 = tangent*sqrt(maxf(0,speed*speed-outward*outward))+normal*outward
	actor.motor.end_hover()
	actor.motor.transition("air")
	actor.velocity = (launch+Vector3.UP*upward).limit_length(actor.tuning.speed_limit)
	actor.motor.voluntary_airborne = true
	last_wall_normal = normal
	wall_cooldown = actor.tuning.wall_jump_cooldown
	wall_pose = .28
	actor.resolver.record("cast",actor,"wall_jump")
	actor.movement_confirmed.emit("wall_jump",actor.body_point(.8)-normal*.36,actor.velocity,normal,1)
	actor.presentation.sound.play_tone(190,.09,.25)
	return true

func abort() -> void:
	actor.motor.mantle_slide_buffered = false
	actor.motor.mantle_slide_left = 0
	active = false
	carried_velocity = Vector3.ZERO
	progress = 0
	elapsed = 0
	if actor.state == "mantle":
		actor.state = "ready"
		actor.state_time = 0
	if actor.motor.mode == "mantle":
		actor.motor.transition("air")
	actor.velocity = Vector3.ZERO

func reset() -> void:
	abort()
	last_wall_normal = Vector3.ZERO
	wall_cooldown = 0
	wall_pose = 0
