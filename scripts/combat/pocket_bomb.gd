class_name PocketBomb
extends CharacterBody3D

var source: HeroActor
var cast_id: int = 0
var fuse: float = 1.1
var body: MeshInstance3D

func _ready() -> void:
	add_to_group("owned_attacks")
	add_to_group("transient")
	collision_layer = 0
	collision_mask = 1
	fuse = source.tuning.bomb_fuse
	var sphere := SphereShape3D.new()
	sphere.radius = 0.13
	var collider := CollisionShape3D.new()
	collider.shape = sphere
	add_child(collider)
	var visual := SphereMesh.new()
	visual.radius = 0.14
	visual.height = 0.28
	body = Geometry.mesh(self, visual, Vector3.ZERO, Geometry.material(Color("f4aa6a"), 0.8))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or not source.alive:
		queue_free()
		return
	fuse -= delta
	body.scale = Vector3.ONE * (1.0 + sin(fuse * 35.0) * 0.18)
	velocity.y -= 15.0 * delta
	var collision: KinematicCollision3D = move_and_collide(velocity * delta)
	if collision != null:
		velocity = velocity.bounce(collision.get_normal()) * 0.58
	if fuse <= 0.0:
		explode()

func explode() -> void:
	var t: HeroTuning = source.tuning
	for target: HeroActor in get_tree().get_nodes_in_group("actors"):
		if target == source or not target.alive or target.team == source.team:
			continue
		var distance: float = global_position.distance_to(target.global_position + Vector3.UP * 0.9)
		if distance <= t.bomb_radius and source.resolver.visible(global_position + Vector3.UP * 0.05, target):
			source.resolver.damage(source, target, t.bomb_damage * (1.0 - distance / t.bomb_radius), "bomb", cast_id)
	CombatEffect.pulse(get_parent(), global_position, Color("ffd18d"), t.bomb_radius)
	source.presentation.sound.play_tone(60.0, 0.28, 0.3)
	source.resolver.record("detonate", source, "bomb", "cast=%d" % cast_id)
	queue_free()
