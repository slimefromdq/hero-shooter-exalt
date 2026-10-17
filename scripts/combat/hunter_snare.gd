class_name HunterSnare
extends CharacterBody3D

var source: HeroActor
var flying: bool = false
var armed: bool = false
var age: float = 0.0
var arm_age: float = 0.0
var health: float = 25.0
var cast_id: int = 0
var received: Dictionary = {}
var visual: Node3D
var indicator: MeshInstance3D

func _ready() -> void:
	add_to_group("owned_attacks")
	add_to_group("transient")
	add_to_group("traps")
	cast_id = source.resolver.new_cast()
	health = (source.tuning as SlayerTuning).trap_health
	# Shootable by combat traces, while character capsules can walk over it.
	collision_layer = 16
	collision_mask = 1
	add_collision_exception_with(source)
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = .18
	collider.shape = shape
	add_child(collider)
	visual = Node3D.new()
	add_child(visual)
	SlayerVisuals.trap(visual)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.25
	ring.outer_radius = 1.4
	indicator = Geometry.mesh(self,ring,Vector3(0,.03,0),Geometry.material(Color("e291b4"),.6))
	indicator.scale = Vector3.ONE * .3

static func placement_clear(owner_actor: HeroActor, at: Vector3, exclude: Array[RID] = []) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = .24
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,at + Vector3.UP * .14)
	query.collision_mask = 19
	query.exclude = exclude
	return owner_actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func align_surface(normal: Vector3) -> void:
	var right: Vector3 = Vector3.RIGHT.slide(normal).normalized()
	if right.is_zero_approx(): right = Vector3.FORWARD.slide(normal).normalized()
	basis = Basis(right,normal,right.cross(normal)).orthonormalized()

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	if not is_instance_valid(source) or not source.alive:
		queue_free()
		return
	var t := source.tuning as SlayerTuning
	age += delta
	if age >= t.trap_lifetime or global_position.y < -8:
		queue_free()
		return
	if flying:
		velocity.y -= 15.0 * delta
		var collision: KinematicCollision3D = move_and_collide(velocity * delta)
		if collision != null:
			if collision.get_normal().y >= .7 and placement_clear(source,global_position,[get_rid()]):
				flying = false
				velocity = Vector3.ZERO
				collision_mask = 1
				align_surface(collision.get_normal())
			else:
				velocity = velocity.bounce(collision.get_normal()) * .4
		visual.rotation.x += delta * 8.0
		indicator.visible = false
		return
	# Placed traps settle if their supporting platform is removed.
	velocity = Vector3.DOWN * .7
	move_and_collide(velocity * delta)
	arm_age += delta
	armed = arm_age >= t.trap_arm_time
	indicator.visible = true
	indicator.scale = Vector3.ONE * (.42 if not armed else t.trap_radius / 1.4)
	for target: HeroActor in get_tree().get_nodes_in_group("actors"):
		if not armed or not target.alive or target.team == source.team: continue
		var offset: Vector3 = target.global_position - global_position
		if Vector2(offset.x,offset.z).length() <= t.trap_radius and absf(offset.y) < 1.15 and source.resolver.visible(global_position + Vector3.UP * .25,target,[get_rid()]):
			trigger(target)
			break

func trigger(target: HeroActor) -> void:
	var t := source.tuning as SlayerTuning
	var result: String = source.resolver.damage(source,target,t.trap_damage,"snare",cast_id,false,false,global_position)
	if result != "hit":
		return
	if target.state not in ["captured", "throw_pair"]:
		target.statuses.apply("root",source,t.trap_root)
	CombatEffect.pulse(get_parent(),target.global_position + Vector3.UP * .25,Color("ed79b2"),t.trap_radius)
	source.presentation.sound.play_slayer("snare_hit")
	source.resolver.record("trigger",source,"snare_root","target=" + target.actor_id)
	queue_free()

func receive_damage(attacker: HeroActor, amount: float, id: int) -> void:
	if not is_instance_valid(source) or attacker.team == source.team or received.has(id) or is_queued_for_deletion(): return
	if attacker.resolver.protected_room(attacker): return
	received[id] = true
	health -= amount
	if health <= 0:
		CombatEffect.pulse(get_parent(),global_position,Color("f8bf8d"),.45)
		attacker.resolver.record("destroy",attacker,"snare","owner=" + source.actor_id)
		queue_free()
