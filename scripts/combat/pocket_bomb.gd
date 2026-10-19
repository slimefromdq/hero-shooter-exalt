class_name PocketBomb
extends CharacterBody3D

var source: HeroActor
var cast_id: int = 0
var fuse: float = 1.1
var body: MeshInstance3D
var airborne: bool = true
var detonated: bool = false

func _ready() -> void:
	add_to_group("owned_attacks")
	add_to_group("transient")
	add_to_group("pocket_bombs")
	collision_layer = 32
	collision_mask = 1
	fuse = source.tuning.bomb_fuse
	var sphere := SphereShape3D.new()
	sphere.radius = 0.13
	var collider := CollisionShape3D.new()
	collider.shape = sphere
	add_child(collider)
	var visual := SphereMesh.new()
	visual.radius = 0.19
	visual.height = 0.38
	body = Geometry.mesh(self, visual, Vector3.ZERO, Geometry.material(Color("f4aa6a"), 0.8))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or not source.alive:
		queue_free()
		return
	fuse -= delta
	body.scale = Vector3.ONE * (1.0 + sin(fuse * 35.0) * 0.18)
	velocity.y -= 15.0 * delta
	var shield_hit: Dictionary = source.resolver.attack_ray(source,global_position,global_position + velocity * delta,[get_rid()],1)
	if shield_hit.get("collider") is CombatBarrier:
		airborne = false
		global_position = shield_hit.position + shield_hit.normal * .15
		velocity = velocity.bounce(shield_hit.normal) * .58
	var collision: KinematicCollision3D = move_and_collide(velocity * delta)
	if collision != null:
		airborne = false
		velocity = velocity.bounce(collision.get_normal()) * 0.58
	if fuse <= 0.0:
		explode()

func explode(shot_triggered: bool = false) -> void:
	if detonated or is_queued_for_deletion(): return
	detonated = true
	collision_layer = 0
	var t: HeroTuning = source.tuning
	for trap: HunterSnare in get_tree().get_nodes_in_group("traps"):
		var distance: float = global_position.distance_to(trap.global_position)
		var hit: Dictionary = source.resolver.ray(global_position,trap.global_position,[get_rid()])
		if distance < t.bomb_radius and (hit.is_empty() or hit.get("collider") == trap):
			trap.receive_damage(source,t.bomb_damage * (1.0 - distance / t.bomb_radius),cast_id)
	source.resolver.splash(source,global_position,t.bomb_radius,t.bomb_damage,"bomb",cast_id,true)
	CombatEffect.pulse(get_parent(), global_position, Color("ffd18d"), t.bomb_radius)
	source.presentation.sound.play_tone(60.0, 0.28, 0.3)
	source.resolver.record("detonate", source, "bomb", "cast=%d trigger=%s" % [cast_id,"shot" if shot_triggered else "fuse"])
	queue_free()

func receive_shot(shooter: HeroActor) -> void:
	if shooter == source and airborne and not source.resolver.attack_locked(source): explode(true)
