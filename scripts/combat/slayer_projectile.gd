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

func _ready() -> void:
	add_to_group("owned_attacks")
	add_to_group("transient")
	collision_layer = 0
	collision_mask = 19
	add_collision_exception_with(source)
	cast_id = source.resolver.new_cast(source)
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = (source.tuning as SlayerTuning).knife_radius if kind == "knife" else (source.tuning as SlayerTuning).axe_radius
	collider.shape = shape
	add_child(collider)
	visual = Node3D.new()
	add_child(visual)
	SlayerVisuals.knife(visual) if kind == "knife" else SlayerVisuals.axe(visual)
	if kind == "axe": visual.scale = Vector3.ONE * .9
	else:
		var glint := SphereMesh.new()
		glint.radius = .065
		glint.height = .13
		var mat: StandardMaterial3D = Geometry.material(Color("c2f6ff"),1.8)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		Geometry.mesh(visual,glint,Vector3(0,0,-.25),mat)
	rotation.y = atan2(-direction.x,-direction.z)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or not source.alive or is_queued_for_deletion():
		queue_free()
		return
	var t := source.tuning as SlayerTuning
	var speed: float = t.knife_speed if kind == "knife" else t.axe_speed
	var maximum: float = t.knife_range if kind == "knife" else t.axe_range
	var distance: float = minf(speed * delta, maximum - travelled)
	if distance <= .001:
		queue_free()
		return
	var previous: Vector3 = global_position
	# Resolve remainder after piercing; exceptions guarantee once per actor per axe.
	var motion: Vector3 = direction * distance
	for iteration: int in 16:
		var barrier_hit: Dictionary = source.resolver.barrier_ray(source,global_position,global_position + motion)
		if not barrier_hit.is_empty():
			var probe: KinematicCollision3D = move_and_collide(motion,true)
			if probe == null or global_position.distance_to(barrier_hit.position) <= probe.get_travel().length():
				barrier_hit.collider.receive_damage(source,t.knife_damage if kind == "knife" else t.axe_damage,cast_id)
				queue_free()
				return
		var hit: KinematicCollision3D = move_and_collide(motion)
		if hit == null: break
		if kind == "knife": CombatEffect.streak(get_parent(),previous,global_position,t.knife_trail_width,t.knife_trail_time)
		var target := hit.get_collider() as HeroActor
		if target != null:
			var id: int = target.get_instance_id()
			if not hit_targets.has(id):
				hit_targets[id] = true
				var tag: String = "knife" if kind == "knife" else "axe"
				var result: String = source.resolver.damage(source,target,t.knife_damage if kind == "knife" else t.axe_damage,tag,cast_id,false,false,previous)
				if result == "deflect":
					# Knives and the axe are blocked by Nimbus's frontal deflect.
					CombatEffect.pulse(get_parent(),hit.get_position(),Color("8de9e2"),.7)
					queue_free()
					return
				if result == "hit" and target.alive:
					if kind == "knife":
						target.statuses.apply("bleed",source,t.bleed_duration,t.bleed_dps)
					elif target.shields <= 0.0 and target.state not in ["captured", "throw_pair"]:
						target.statuses.apply("max_health",source,t.axe_debuff_duration,t.axe_max_reduction)
				CombatEffect.pulse(get_parent(),hit.get_position(),Color("ff627f") if kind == "knife" else Color("c294ff"),.4 if kind == "knife" else 1.2)
				if result == "hit": source.presentation.sound.play_slayer("knife_hit" if kind == "knife" else "axe_hit")
			if kind == "knife":
				queue_free()
				return
			add_collision_exception_with(target)
			motion = hit.get_remainder()
		elif hit.get_collider() is HunterSnare:
			(hit.get_collider() as HunterSnare).receive_damage(source,t.knife_damage if kind == "knife" else t.axe_damage,cast_id)
			queue_free()
			return
		else:
			CombatEffect.pulse(get_parent(),hit.get_position(),Color("e6c49b"),.2 if kind == "knife" else .8)
			queue_free()
			return
	travelled += distance
	if kind == "axe":
		visual.rotation.x += delta * 20.0
		CombatEffect.line(get_parent(),previous,global_position,Color("b585eb"),.12)
	else:
		CombatEffect.streak(get_parent(),previous,global_position,t.knife_trail_width,t.knife_trail_time)
		look_at(global_position + direction)
