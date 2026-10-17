class_name MarshalBarrier
extends Node3D
## Analytic rectangle: attacks query it explicitly, so friendly shots and actors pass freely.
var source: HeroActor
var received: Dictionary = {}
var visual: Node3D
var flash: float = 0.0

func _ready() -> void:
	add_to_group("barriers")
	visual = Node3D.new()
	add_child(visual)
	var t := source.tuning as MarshalTuning
	var color := Color("67cce3") if source.team == 0 else Color("f49d82")
	var mat := Geometry.material(color,0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.14
	var mesh := BoxMesh.new()
	mesh.size = Vector3(t.barrier_width,t.barrier_height,.025)
	Geometry.mesh(visual,mesh,Vector3.ZERO,mat)
	for side: float in [-1.0,1.0]:
		Geometry.box(visual,Vector3(.05,t.barrier_height,.04),Vector3(side * t.barrier_width / 2,0,0),color.lightened(.3),false)
		Geometry.box(visual,Vector3(t.barrier_width,.05,.04),Vector3(0,side * t.barrier_height / 2,0),color.lightened(.3),false)
	for x: int in 7:
		Geometry.box(visual,Vector3(.015,t.barrier_height,.015),Vector3(x - 3,0,0),color.darkened(.25),false)

func active() -> bool:
	return is_instance_valid(source) and source.alive and source.kit is MarshalKit and source.state == "marshal_shield" and source.kit.barrier_hp > 0 and not source.resolver.protected_room(source)

func frame() -> Transform3D:
	var forward: Vector3 = source.aim_direction.normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	if right.is_zero_approx(): right = source.global_basis.x
	var up: Vector3 = right.cross(forward).normalized()
	var center: Vector3 = source.global_position + Vector3.UP * (source.tuning as MarshalTuning).barrier_height * .5 + forward * (source.tuning as MarshalTuning).barrier_offset
	return Transform3D(Basis(right,up,-forward),center)

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
	var t := source.tuning as MarshalTuning
	if absf(at.x) > t.barrier_width * .5 or absf(at.y) > t.barrier_height * .5: return {}
	return {"position":from.lerp(to,fraction),"normal":frame().basis.z * (1.0 if a.z > 0 else -1.0),"collider":self}

func receive_damage(attacker: HeroActor, amount: float, id: int) -> void:
	if not active() or attacker.team == source.team or received.has(id) or attacker.resolver.protected_room(attacker): return
	received[id] = true
	if received.size() > 4096: received.clear()
	var kit := source.kit as MarshalKit
	kit.barrier_hp = maxf(0,kit.barrier_hp - amount * attacker.resolver.cast_multiplier(id,attacker))
	flash = .16
	source.resolver.record("barrier_hit",attacker,"barrier","remaining=%.1f" % kit.barrier_hp)
	if kit.barrier_hp <= 0:
		kit.break_remaining = (source.tuning as MarshalTuning).barrier_break
		kit.lower_barrier()
		CombatEffect.pulse(source.get_parent(),frame().origin,Color("9deeff"),2.0)

func _process(delta: float) -> void:
	visible = active()
	if not visible: return
	global_transform = frame()
	flash = maxf(0,flash - delta)
	var panel := visual.get_child(0) as MeshInstance3D
	(panel.material_override as StandardMaterial3D).albedo_color.a = .14 + flash
