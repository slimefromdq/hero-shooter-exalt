class_name ThrowSequence
extends RefCounted

# Physics owns the paired travel. Animation only poses the bodies on this path.
var attacker: HeroActor
var victim: HeroActor
var origin: Vector3
var start: Vector3
var forward: Vector3
var right: Vector3
var landing: Vector3
var lift: float
var impact: float
var exceptions_active: bool = false
var last_progress: float = 0.0

func configure(owner: HeroActor, target: HeroActor) -> bool:
	attacker = owner
	victim = target
	origin = owner.global_position
	start = target.global_position
	forward = (start - origin) * Vector3(1, 0, 1)
	forward = forward.normalized()
	right = forward.cross(Vector3.UP).normalized()
	lift = owner.tuning.throw_lift_height
	impact = clampf(owner.tuning.throw_impact_progress, 0.55, 0.85)
	var candidate: Vector3 = origin + forward * 1.65 + right * 0.8
	var floor_hit: Dictionary = owner.resolver.ray(candidate + Vector3.UP * 0.6, candidate + Vector3.DOWN * 2.0, [], 1)
	if floor_hit.is_empty() or (floor_hit["normal"] as Vector3).dot(Vector3.UP) < cos(owner.floor_max_angle):
		return false
	landing = floor_hit["position"] + Vector3.UP * 0.04
	# Ignore only the two paired capsules. Walls and every other actor still block.
	attacker.add_collision_exception_with(victim)
	victim.add_collision_exception_with(attacker)
	exceptions_active = true
	var from: Transform3D = victim.global_transform
	for index: int in range(1, 33):
		var point: Vector3 = sample(float(index) / 32.0)
		if victim.test_move(from, point - from.origin):
			cleanup()
			return false
		from.origin = point
	return true

func sample(progress: float) -> Vector3:
	var p: float = clampf(progress, 0.0, 1.0)
	var caught: Vector3 = origin + forward * 1.0 + Vector3.UP * 0.08
	var lifted: Vector3 = origin + forward * 0.12 + right * 0.42 + Vector3.UP * lift
	if p < 0.2:
		return start.lerp(caught, smoothstep(0.0, 0.2, p))
	if p < 0.46:
		return caught.lerp(lifted, smoothstep(0.2, 0.46, p))
	if p < impact:
		var t: float = (p - 0.46) / (impact - 0.46)
		return lifted.lerp(landing, t * t)
	return landing

func advance(progress: float) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(victim):
		return false
	var desired: Vector3 = sample(progress)
	var collision: KinematicCollision3D = victim.move_and_collide(desired - victim.global_position)
	if collision == null:
		last_progress = progress
	# A newly introduced obstacle aborts at the last safe swept position.
	return collision == null

func separate_on_release() -> void:
	if not is_instance_valid(attacker) or not is_instance_valid(victim) or not victim.alive:
		return
	if separated():
		return
	# An interrupted lift may be over the attacker's hip. Retrace swept travel
	# before restoring capsule collisions; never leave overlapping live actors.
	for index: int in range(1, 25):
		var point: Vector3 = sample(last_progress * (1.0 - float(index) / 24.0))
		var collision: KinematicCollision3D = victim.move_and_collide(point - victim.global_position)
		if separated():
			return
		if collision != null:
			break
	for direction: Vector3 in [right, -right, forward, -forward]:
		var point: Vector3 = victim.global_position + direction * .85
		var flat: Vector3 = (point - attacker.global_position) * Vector3(1,0,1)
		if flat.length() >= .8 and not victim.test_move(victim.global_transform, point - victim.global_position):
			victim.move_and_collide(point - victim.global_position)
			return

func separated() -> bool:
	var offset: Vector3 = victim.global_position - attacker.global_position
	return absf(offset.y) >= 1.92 or Vector2(offset.x,offset.z).length() >= .8

func cleanup() -> void:
	if exceptions_active and is_instance_valid(attacker) and is_instance_valid(victim):
		attacker.remove_collision_exception_with(victim)
		victim.remove_collision_exception_with(attacker)
	exceptions_active = false
