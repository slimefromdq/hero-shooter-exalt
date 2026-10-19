class_name MagneticPull
extends Node
var source: HeroActor
var target: HeroActor
var target_life: int
var direction: Vector3
var remaining: float
var duration: float
var speed: float

func _ready() -> void:
	add_to_group("owned_attacks")
	add_to_group("transient")
	target_life = target.life_serial

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	if not is_instance_valid(source) or not source.alive or not is_instance_valid(target) or not target.alive or target.life_serial != target_life:
		queue_free()
		return
	if source.resolver.attack_locked(source) or source.resolver.protected_room(target) or target.invulnerable or target.state in ["wisp_phase","captured","throw_pair","boot_attached","boot_captured"]:
		queue_free()
		return
	var distance: float = minf(remaining,speed*minf(delta,duration))
	var hit: KinematicCollision3D = target.move_and_collide(direction*distance)
	remaining -= distance
	duration -= delta
	if hit != null or remaining <= .001 or duration <= .00001: queue_free()
