class_name MarshalCannonball
extends CharacterBody3D
## Physical sphere sweeps; damage and defenses stay on CombatResolver.
var source: HeroActor
var source_life: int
var cast_id: int
var damage_amount: float
var gravity: float
var radius: float
var range_left: float
var reflections: int = 0
var trail_age: float = 0

func _ready() -> void:
	add_to_group("owned_attacks")
	add_to_group("transient")
	add_to_group("marshal_cannonballs")
	collision_layer = 0
	collision_mask = 19
	add_collision_exception_with(source)
	source_life = source.life_serial
	var t := source.tuning as MarshalTuning
	damage_amount = t.cannon_damage
	gravity = t.cannon_gravity
	radius = t.cannon_radius
	range_left = t.cannon_range
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius*2
	var metal := Geometry.material(Color("343b46"),.15)
	metal.metallic = .85
	metal.roughness = .3
	Geometry.mesh(self,ball,Vector3.ZERO,metal)
	var ring := TorusMesh.new()
	ring.inner_radius = radius*.85
	ring.outer_radius = radius*1.04
	Geometry.mesh(self,ring,Vector3.ZERO,Geometry.material(Color("e7b868"),1.3))

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	if not is_instance_valid(source) or not source.alive or source.life_serial != source_life:
		queue_free()
		return
	var remaining: float = delta
	while remaining > .000001:
		var dt: float = minf(remaining,1.0/120)
		var acceleration: Vector3 = Vector3.DOWN*gravity
		var motion: Vector3 = velocity*dt+acceleration*(.5*dt*dt)
		motion = motion.limit_length(range_left)
		velocity += acceleration*dt
		range_left -= motion.length()
		if not sweep(motion): return
		if range_left <= .001:
			queue_free()
			return
		remaining -= dt
	trail_age += delta
	if trail_age >= .045:
		trail_age = 0
		CombatEffect.streak(get_parent(),global_position-velocity.normalized()*.6,global_position,.045,.12)

func barrier_contact(motion: Vector3) -> Dictionary:
	var result: Dictionary = {}
	var nearest: float = INF
	var right: Vector3 = velocity.normalized().cross(Vector3.UP).normalized()*radius
	# Sample the sphere silhouette against the shared analytic shield surfaces.
	for offset: Vector3 in [Vector3.ZERO,right,-right,Vector3.UP*radius,Vector3.DOWN*radius]:
		var hit: Dictionary = source.resolver.barrier_ray(source,global_position+offset,global_position+motion+offset)
		if hit.is_empty(): continue
		var distance: float = global_position.distance_to(hit.position-offset)
		if distance < nearest:
			nearest = distance
			result = hit
			result["center_distance"] = distance
	return result

func sweep(motion: Vector3) -> bool:
	for iteration: int in 16:
		var previous: Vector3 = global_position
		var barrier_hit: Dictionary = barrier_contact(motion)
		var probe: KinematicCollision3D = move_and_collide(motion,true)
		if not barrier_hit.is_empty() and (probe == null or float(barrier_hit.center_distance) <= probe.get_travel().length()):
			barrier_hit.collider.receive_damage(source,damage_amount,cast_id)
			impact(barrier_hit.position)
			return false
		var hit: KinematicCollision3D = move_and_collide(motion)
		if hit == null: return true
		var target := hit.get_collider() as HeroActor
		if target != null:
			if target.team == source.team:
				add_collision_exception_with(target)
				motion = hit.get_remainder()
				continue
			var result: String = source.resolver.damage(source,target,damage_amount,"cannon",cast_id,false,false,previous)
			if result == "deflect" and reflections < 2:
				reflections += 1
				for ignored: PhysicsBody3D in get_collision_exceptions(): remove_collision_exception_with(ignored)
				source = target
				source_life = target.life_serial
				add_collision_exception_with(target)
				cast_id = source.resolver.new_cast(source)
				velocity = target.aim_direction.normalized()*velocity.length()
				# Stay at the swept contact; never teleport through nearby world geometry.
				return false
		elif hit.get_collider() is HunterSnare or hit.get_collider() is CombatStructure:
			var amount: float = damage_amount
			# Structures apply their own cast multiplier; traps accept resolved damage.
			if hit.get_collider() is HunterSnare: amount *= source.resolver.cast_multiplier(cast_id,source)
			source.resolver.hit_object(hit.get_collider(),source,amount,cast_id)
		impact(hit.get_position())
		return false
	queue_free()
	return false

func impact(at: Vector3) -> void:
	CombatEffect.pulse(get_parent(),at,Color("edb76a"),.65)
	if is_instance_valid(source.presentation): source.presentation.impact_sound.play_tone(48,.2,.3)
	queue_free()
