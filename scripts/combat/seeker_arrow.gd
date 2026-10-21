class_name SeekerArrow
extends CombatProjectile
## Uses the shared resolver and projectile lifetime/ownership convention, with swept curved flight.
var kit: RelayKit
var source_life: int
var piercing: bool = false
var volley: SeekerVolley
var orbit_index: int = -1
var flight_origin: Vector3
var axis: Vector3
var right: Vector3
var up: Vector3
var age: float = 0.0
var hit_targets: Array[RID] = []
var homing_lost: bool = false
var initialized: bool = false

func _ready() -> void:
	add_to_group("owned_attacks")
	add_to_group("transient")
	source_life = source.life_serial
	cast_id = source.resolver.new_cast(source)
	lifetime = 3.0
	color = Color("ffe8a0") if orbit_index < 0 else Color("8ceee2")
	Geometry.box(self,Vector3(.035,.035,.65),Vector3.ZERO,color,false)
	var tip := PrismMesh.new()
	tip.size = Vector3(.14,.12,.2)
	Geometry.mesh(self,tip,Vector3(0,0,-.38),Geometry.material(color,1.5))
	for side: int in [-1,1]:
		Geometry.box(self,Vector3(.12,.015,.18),Vector3(side*.06,0,.23),color,false).rotation.z = side*.45

func initialize(at: Vector3) -> void:
	flight_origin = at
	axis = direction.normalized()
	right = axis.cross(Vector3.UP).normalized()
	if right.is_zero_approx(): right = Vector3.RIGHT
	up = right.cross(axis).normalized()
	global_position = at
	orient(axis)
	initialized = true
	# Offset formation must not materialize on the far side of nearby cover.
	if orbit_index >= 0: sweep(orbit_point(0)-at)

func orbit_point(time: float) -> Vector3:
	var angle: float = orbit_index*TAU/4+time*TAU*2
	var radius: float = .3+.1*sin(time*TAU*1.3)
	return flight_origin+axis*(speed*time-.6)+(right*cos(angle)+up*sin(angle))*radius

func orient(forward: Vector3) -> void:
	if forward.is_zero_approx(): return
	look_at(global_position+forward,Vector3.RIGHT if absf(forward.normalized().y) > .99 else Vector3.UP)

func _physics_process(delta: float) -> void:
	if not initialized or is_queued_for_deletion(): return
	if not is_instance_valid(source) or not source.alive or source.life_serial != source_life:
		queue_free()
		return
	var remaining: float = delta
	while remaining > .000001 and not is_queued_for_deletion():
		var dt: float = minf(remaining,1.0/240.0)
		lifetime -= dt
		if lifetime <= 0 or traveled >= max_distance:
			queue_free()
			return
		age += dt
		var next: Vector3
		var target: HeroActor = volley.patient() if volley != null and volley.locked else null
		if orbit_index >= 0 and is_instance_valid(target) and not homing_lost:
			direction = (target.body_point(1.2)-global_position).normalized()
			next = global_position+direction*speed*dt
		elif orbit_index >= 0 and volley != null and not volley.locked:
			next = orbit_point(age)
		else:
			if volley != null and volley.locked: homing_lost = true
			next = global_position+direction*speed*dt
		var motion: Vector3 = (next-global_position).limit_length(max_distance-traveled)
		if motion.length_squared() > .0000001:
			direction = motion.normalized()
			orient(direction)
			if not sweep(motion): return
		remaining -= dt
	trail_clock += delta
	if trail_clock >= .025:
		trail_clock = 0
		CombatEffect.line(get_parent(),global_position-direction*.5,global_position,color,.06)

func sweep(motion: Vector3) -> bool:
	var endpoint: Vector3 = global_position+motion
	var exceptions: Array[RID] = [source.get_rid()]
	exceptions.append_array(hit_targets)
	for other: HeroActor in source.get_tree().get_nodes_in_group("actors"):
		if other.team == source.team: exceptions.append(other.get_rid())
	# Every continuation adds a collider exclusion, so there is no arbitrary pierce cap.
	while global_position.distance_to(endpoint) > .00001:
		var hit := source.resolver.attack_ray(source,global_position,endpoint,exceptions)
		if hit.is_empty():
			traveled += global_position.distance_to(endpoint)
			global_position = endpoint
			return true
		var at: Vector3 = hit.position
		traveled += global_position.distance_to(at)
		var target := hit.get("collider") as HeroActor
		if is_instance_valid(target):
			var head: bool = at.y-target.global_position.y >= target.headshot_height()
			var result := source.resolver.damage(source,target,damage_amount*(source.tuning.head_multiplier if head else 1.0),"projectile",cast_id,head,false,global_position,at)
			if result == "deflect":
				if reflections >= 2:
					queue_free()
					return false
				reflections += 1
				source = target
				source_life = source.life_serial
				kit = null
				volley = null
				orbit_index = -1
				piercing = false
				hit_targets.clear()
				cast_id = source.resolver.new_cast(source)
				direction = source.aim_direction
				global_position = at+direction*.05
				return true
			if result == "hit":
				if volley != null and orbit_index < 0: volley.acquire(target)
				if is_instance_valid(kit) and source.kit == kit: kit.arrow_hit(target)
			hit_targets.append(target.get_rid())
			exceptions.append(target.get_rid())
			if piercing:
				global_position = at
				continue
		else:
			source.resolver.hit_object(hit.get("collider"),source,damage_amount,cast_id)
		CombatEffect.pulse(get_parent(),at,color,.18)
		queue_free()
		return false
	return true
