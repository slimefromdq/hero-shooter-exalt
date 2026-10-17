class_name CombatProjectile
extends Node3D

var source: HeroActor
var direction: Vector3 = Vector3.FORWARD
var speed: float = 17.0
var damage_amount: float = 24.0
var cast_id: int = 0
var lifetime: float = 5.0
var reflections: int = 0
var reflected_events: Dictionary = {}

func _ready() -> void:
	add_to_group("owned_attacks")
	add_to_group("transient")
	var ball := SphereMesh.new()
	ball.radius = 0.1
	ball.height = 0.2
	Geometry.mesh(self, ball, Vector3.ZERO, Geometry.material(Color("ff765e"), 1.5))

func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0 or not is_instance_valid(source) or not source.alive:
		queue_free()
		return
	var next: Vector3 = global_position + direction * speed * delta
	var hit: Dictionary = source.resolver.attack_ray(source, global_position, next, [source.get_rid()])
	if hit.is_empty():
		global_position = next
		return
	var target: HeroActor = hit.get("collider") as HeroActor
	if target != null:
		var result: String = source.resolver.damage(source, target, damage_amount, "projectile", cast_id, false, false, global_position)
		if result == "deflect":
			var event_key: String = "%d:%d" % [target.get_instance_id(), target.kit.cast_id]
			if reflections < 2 and not reflected_events.has(event_key):
				reflected_events[event_key] = true
				reflections += 1
				source = target
				direction = target.aim_direction
				cast_id = target.resolver.new_cast(target)
				global_position = hit["position"] + direction * 0.25
				return
	CombatEffect.pulse(get_parent(), hit["position"], Color("ffae81"), 0.28)
	if hit.get("collider") is MarshalBarrier:
		hit.collider.receive_damage(source,damage_amount,cast_id)
	if hit.get("collider") is HunterSnare:
		(hit.collider as HunterSnare).receive_damage(source,damage_amount,cast_id)
	queue_free()
