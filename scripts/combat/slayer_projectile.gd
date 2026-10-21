class_name SlayerProjectile
extends CharacterBody3D
## Kinematic shape sweeps include world and actors, including at low physics rates.
var source: HeroActor
var kind: String = "knife"
var direction: Vector3 = Vector3.FORWARD
var cast_id: int
var travelled: float = 0.0
var visual: Node3D
var hit_targets: Dictionary = {}
var spin_frame: Node3D
var trail: SlayerRibbon
var edge_trail: SlayerRibbon
var source_life: int

func _ready() -> void:
	add_to_group("owned_attacks")
	add_to_group("transient")
	collision_layer = 0
	collision_mask = 19
	add_collision_exception_with(source)
	cast_id = source.resolver.classify(source.resolver.new_cast(source),CombatResolver.ImpactKind.ULTIMATE if kind == "axe" else CombatResolver.ImpactKind.ABILITY)
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = (source.tuning as SlayerTuning).knife_radius if kind == "knife" else (source.tuning as SlayerTuning).axe_radius
	collider.shape = shape
	add_child(collider)
	visual = Node3D.new()
	add_child(visual)
	SlayerVisuals.knife(visual) if kind == "knife" else SlayerVisuals.axe(visual)
	if kind == "axe":
		visual.scale = Vector3.ONE * 1.215 # 1.35 times the previous .9 visual scale; collider is unchanged.
		spin_frame = Node3D.new()
		add_child(spin_frame)
		spin_frame.rotation.y = PI / 2 # mesh X -> travel -Z; mesh Z -> travel right.
		visual.reparent(spin_frame, false)
		visual.rotation.z = -PI / 4
	else:
		velocity = direction.normalized() * (source.tuning as SlayerTuning).knife_speed
	orient_travel(direction)
	source_life = source.life_serial
	trail = SlayerRibbon.new()
	add_child(trail)
	if kind == "knife": trail.add_to_group("knife_trails")
	trail.width = .045 if kind == "axe" else (source.tuning as SlayerTuning).knife_trail_width * .5
	trail.lifetime = .26 if kind == "axe" else (source.tuning as SlayerTuning).knife_trail_time
	trail.material.albedo_color = Color("b47dff") if kind == "axe" else Color("d8f8ff")
	if kind == "axe":
		edge_trail = SlayerRibbon.new()
		add_child(edge_trail)
		edge_trail.width = .022
		edge_trail.material.albedo_color = Color("ff88af")

func orient_travel(forward: Vector3) -> void:
	if forward.is_zero_approx(): return
	look_at(global_position + forward, Vector3.RIGHT if absf(forward.normalized().dot(Vector3.UP)) > .99 else Vector3.UP)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or not source.alive or source.life_serial != source_life or is_queued_for_deletion():
		queue_free()
		return
	var t := source.tuning as SlayerTuning
	if kind == "knife":
		# Exact constant-acceleration integration with short swept chords. The same
		# velocity and path drive both visible point orientation and the actual sphere.
		var remaining: float = delta
		while remaining > .000001:
			var dt: float = minf(remaining, 1.0 / 240.0)
			var acceleration := Vector3.DOWN * t.knife_gravity
			var motion: Vector3 = velocity * dt + acceleration * (.5 * dt * dt)
			var budget: float = t.knife_range - travelled
			if budget <= .001:
				queue_free()
				return
			if motion.length() > budget:
				dt *= budget / motion.length()
				motion = (velocity * dt + acceleration * (.5 * dt * dt)).limit_length(budget)
			velocity += acceleration * dt
			if not sweep_motion(motion): return
			orient_travel(velocity)
			direction = velocity.normalized()
			trail.sample(global_position)
			remaining -= dt
	else:
		var distance: float = minf(t.axe_speed * delta, t.axe_range - travelled)
		if distance <= .001:
			queue_free()
			return
		if not sweep_motion(direction * distance): return
		visual.rotation.z -= delta * t.axe_spin_rate
		trail.sample(global_position)
		edge_trail.sample(visual.to_global(Vector3(.77,.9,0)))

func impact(at: Vector3, normal: Vector3, category: String) -> void:
	if is_instance_valid(source.presentation.slayer_abilities):
		source.presentation.slayer_abilities.projectile_impact(kind, at, normal, category)

func sweep_motion(requested: Vector3) -> bool:
	var t := source.tuning as SlayerTuning
	var previous: Vector3 = global_position
	var motion: Vector3 = requested
	# Resolve remainder after piercing; exceptions guarantee once per actor per axe.
	for iteration: int in 16:
		var barrier_hit: Dictionary = source.resolver.barrier_ray(source,global_position,global_position + motion)
		if not barrier_hit.is_empty():
			var probe: KinematicCollision3D = move_and_collide(motion,true)
			if probe == null or global_position.distance_to(barrier_hit.position) <= probe.get_travel().length():
				barrier_hit.collider.receive_damage(source,t.knife_damage if kind == "knife" else t.axe_damage,cast_id)
				impact(barrier_hit.position,barrier_hit.get("normal",-direction),"barrier")
				queue_free()
				return false
		var hit: KinematicCollision3D = move_and_collide(motion)
		if hit == null: break
		var target := hit.get_collider() as HeroActor
		if target != null:
			var id: int = target.get_instance_id()
			if not hit_targets.has(id):
				hit_targets[id] = true
				var tag: String = "knife" if kind == "knife" else "axe"
				var had_shields: bool = target.shields > 0.0
				var result: String = source.resolver.damage(source,target,t.knife_damage if kind == "knife" else t.axe_damage,tag,cast_id,false,false,previous)
				if result == "deflect":
					# Knives and the axe are blocked by Nimbus's frontal deflect.
					impact(hit.get_position(),hit.get_normal(),"deflect")
					queue_free()
					return false
				if result == "hit" and target.alive:
					if kind == "knife":
						target.statuses.apply("bleed",source,t.bleed_duration,t.bleed_dps)
						source.presentation.slayer_abilities.burst(hit.get_position(),hit.get_normal(),Color("bc385b"),.38)
					elif target.shields <= 0.0 and target.state not in ["captured", "throw_pair"]:
						target.statuses.apply("max_health",source,t.axe_debuff_duration,t.axe_max_reduction)
						source.presentation.slayer_abilities.wound(target)
				if result == "hit": impact(hit.get_position(),hit.get_normal(),"shield" if had_shields else "flesh")
			if kind == "knife":
				queue_free()
				return false
			add_collision_exception_with(target)
			motion = hit.get_remainder()
		elif hit.get_collider() is HunterSnare or hit.get_collider() is CombatStructure:
			source.resolver.hit_object(hit.get_collider(),source,t.knife_damage if kind == "knife" else t.axe_damage,cast_id)
			impact(hit.get_position(),hit.get_normal(),"barrier")
			queue_free()
			return false
		else:
			impact(hit.get_position(),hit.get_normal(),"world")
			queue_free()
			return false
	travelled += previous.distance_to(global_position)
	return true
