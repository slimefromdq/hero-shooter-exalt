class_name CombatBarrier
extends Node3D
## Shared analytic barrier contract; friends and physical actors pass through.
var source: HeroActor
var received: Dictionary = {}
var visual: Node3D
var flash: float = 0.0

func active() -> bool:
	return false

func dimensions() -> Vector2:
	return Vector2.ZERO

func frame() -> Transform3D:
	return global_transform

func nearest_point(origin: Vector3) -> Vector3:
	var local: Vector3 = frame().affine_inverse() * origin
	var size: Vector2 = dimensions()
	return frame() * Vector3(clampf(local.x,-size.x/2,size.x/2),clampf(local.y,-size.y/2,size.y/2),0)

func intersection(from: Vector3, to: Vector3) -> Dictionary:
	if not active(): return {}
	var inverse: Transform3D = frame().affine_inverse()
	var a: Vector3 = inverse * from
	var b: Vector3 = inverse * to
	var dz: float = b.z - a.z
	if absf(dz) < .000001: return {}
	var fraction: float = -a.z / dz
	if fraction < 0 or fraction > 1: return {}
	var at: Vector3 = a.lerp(b,fraction)
	var size: Vector2 = dimensions()
	if absf(at.x) > size.x/2 or absf(at.y) > size.y/2: return {}
	return {"position":from.lerp(to,fraction),"normal":frame().basis.z * (1.0 if a.z > 0 else -1.0),"collider":self}

func receive_damage(_attacker: HeroActor, _amount: float, _id: int) -> void:
	pass
