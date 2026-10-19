class_name HuddleScreen
extends CombatBarrier

var recipient: HeroActor
var remaining: float = 2.5
var health: float = 250.0

func _ready() -> void:
	add_to_group("barriers")
	visual = Node3D.new()
	add_child(visual)
	var size: Vector2 = dimensions()
	var mat := Geometry.material(Color("f8d95c"),.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = .12
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x,size.y,.03)
	Geometry.mesh(visual,mesh,Vector3.ZERO,mat)
	for i: int in 20:
		var bug: Node3D = HuddleVisuals.bug(visual,.13)
		bug.position = Vector3((i%5-2)*size.x/4.5,(i/5-1.5)*size.y/3.5,0)
	global_transform = frame()

func dimensions() -> Vector2:
	var t := source.tuning as HuddleTuning
	return Vector2(t.screen_width,t.screen_height)

func active() -> bool:
	return is_instance_valid(source) and source.alive and is_instance_valid(recipient) and recipient.alive and recipient.team == source.team and source.kit is HuddleKit and health > 0 and remaining > 0 and not source.resolver.attack_locked(source) and not source.resolver.protected_room(recipient)

func frame() -> Transform3D:
	if not is_instance_valid(recipient): return global_transform
	var forward: Vector3 = recipient.aim_direction.normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	if right.is_zero_approx(): right = recipient.global_basis.x
	return Transform3D(Basis(right,right.cross(forward),-forward),recipient.global_position + Vector3.UP * dimensions().y/2 + forward * 1.1)

func receive_damage(attacker: HeroActor, amount: float, id: int) -> void:
	if not active() or attacker.team == source.team or received.has(id) or attacker.resolver.attack_locked(attacker): return
	received[id] = true
	health = maxf(0,health - amount * attacker.resolver.cast_multiplier(id,attacker))
	flash = .18
	source.resolver.record("barrier_hit",attacker,"huddle_screen","remaining=%.1f" % health)
	if health <= 0: retire()

func retire() -> void:
	remaining = 0
	visible = false
	queue_free()

func _physics_process(delta: float) -> void:
	remaining -= delta
	if not active():
		retire()
		return
	global_transform = frame()

func _process(delta: float) -> void:
	if not active(): return
	flash = maxf(0,flash-delta)
	var ratio: float = health/(source.tuning as HuddleTuning).screen_health
	for i: int in range(1,visual.get_child_count()):
		var bug: Node3D = visual.get_child(i)
		bug.visible = i <= ceili(ratio*20)
		bug.rotation.z = sin(Time.get_ticks_msec()*.008+i)*.12
	(visual.get_child(0).material_override as StandardMaterial3D).albedo_color.a = .08 + flash
