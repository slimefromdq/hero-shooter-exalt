class_name MarshalBarrier
extends CombatBarrier
var panel_material: StandardMaterial3D
var edges: Array[MeshInstance3D] = []
var segments: Array[MeshInstance3D] = []
var cracks: Array[MeshInstance3D] = []
var fragments: Node3D
var appearance: float = 0
var break_flash: float = 0
var break_frame: Transform3D
## Analytic rectangle: attacks query it explicitly, so friendly shots and actors pass freely.
func _ready() -> void:
	add_to_group("barriers")
	visual = Node3D.new()
	add_child(visual)
	var t := source.tuning as MarshalTuning
	var color := Color("67cce3") if source.team == 0 else Color("f49d82")
	panel_material = Geometry.material(color,.6)
	panel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	panel_material.albedo_color.a = .1
	var mesh := BoxMesh.new()
	mesh.size = Vector3(t.barrier_width,t.barrier_height,.025)
	Geometry.mesh(visual,mesh,Vector3.ZERO,panel_material)
	for side: float in [-1.0,1.0]:
		for horizontal: bool in [false,true]:
			var shape := BoxMesh.new()
			shape.size = Vector3(t.barrier_width,.04,.03) if horizontal else Vector3(.04,t.barrier_height,.03)
			var at := Vector3(0,side*t.barrier_height/2,0) if horizontal else Vector3(side*t.barrier_width/2,0,0)
			edges.append(Geometry.mesh(visual,shape,at,Geometry.material(Color("d6b36d"),.7)))
	for index: int in 10:
		var shape := BoxMesh.new()
		shape.size = Vector3(t.barrier_width/10-.07,.07,.035)
		segments.append(Geometry.mesh(visual,shape,Vector3((index-4.5)*t.barrier_width/10,t.barrier_height/2-.15,.025),Geometry.material(color,1)))
	for index: int in 8:
		var shape := BoxMesh.new()
		shape.size = Vector3(.7,.025,.02)
		var crack: MeshInstance3D = Geometry.mesh(visual,shape,Vector3((index%4-1.5)*1.4,(index/4.0-.5)*.7,.035),Geometry.material(Color("f6dbb0"),1.5))
		crack.rotation.z = .7 if index%2 == 0 else -.5
		crack.visible = false
		cracks.append(crack)
	fragments = Node3D.new()
	add_child(fragments)
	for index: int in 8:
		var shape := BoxMesh.new()
		shape.size = Vector3(.045,.35,.025)
		var shard: MeshInstance3D = Geometry.mesh(fragments,shape,Vector3((index%4-1.5)*1.3,(index/4.0-.5)*1.3,0),Geometry.material(color,1.5))
		shard.rotation.z = index*.9
	fragments.visible = false
func active() -> bool:
	return is_instance_valid(source) and source.alive and source.kit is MarshalKit and source.state == "marshal_shield" and source.kit.barrier_hp > 0 and not source.resolver.attack_locked(source)

func frame() -> Transform3D:
	var forward: Vector3 = source.aim_direction.normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	if right.is_zero_approx(): right = source.global_basis.x
	var up: Vector3 = right.cross(forward).normalized()
	var center: Vector3 = source.global_position + Vector3.UP * (source.tuning as MarshalTuning).barrier_height * .5 + forward * (source.tuning as MarshalTuning).barrier_offset
	return Transform3D(Basis(right,up,-forward),center)

func dimensions() -> Vector2:
	var t := source.tuning as MarshalTuning
	return Vector2(t.barrier_width,t.barrier_height)

func receive_damage(attacker: HeroActor, amount: float, id: int) -> void:
	if not active() or attacker.team == source.team or received.has(id) or attacker.resolver.attack_locked(attacker): return
	received[id] = true
	if received.size() > 4096: received.clear()
	var kit := source.kit as MarshalKit
	kit.barrier_hp = maxf(0,kit.barrier_hp - amount * attacker.resolver.cast_multiplier(id,attacker))
	flash = .16
	if is_instance_valid(source.presentation.marshal_combat): source.presentation.marshal_combat.barrier_hit(kit.barrier_hp <= 0)
	source.resolver.record("barrier_hit",attacker,"barrier","remaining=%.1f" % kit.barrier_hp)
	if kit.barrier_hp <= 0:
		kit.break_remaining = (source.tuning as MarshalTuning).barrier_break
		kit.lower_barrier()
		appearance = 0
		break_flash = .28
		break_frame = frame()

func _process(delta: float) -> void:
	if not is_instance_valid(source) or not source.alive or not source.kit is MarshalKit:
		clear_feedback()
		return
	var enabled: bool = active()
	appearance = move_toward(appearance,1.0 if enabled else 0.0,delta*12)
	break_flash = maxf(0,break_flash-delta)
	visible = appearance > 0 or break_flash > 0
	if not visible: return
	global_transform = break_frame if break_flash > 0 and not enabled else frame()
	visual.visible = appearance > 0
	fragments.visible = break_flash > 0
	fragments.scale = Vector3.ONE*(1+(1-break_flash/.28)*.25)
	flash = maxf(0,flash-delta)
	var ratio: float = clampf((source.kit as MarshalKit).barrier_hp/(source.tuning as MarshalTuning).barrier_health,0,1)
	var healthy := Color("67cce3") if source.team == 0 else Color("f49d82")
	var tint: Color = Color("ef816e").lerp(healthy,clampf(ratio*2,0,1))
	panel_material.albedo_color = Color(tint,appearance*(.045+.07*ratio+flash*.5))
	panel_material.emission = tint
	for edge: MeshInstance3D in edges:
		var mat := edge.material_override as StandardMaterial3D
		mat.albedo_color = tint.lerp(Color("d6b36d"),ratio*.65)
		mat.emission = mat.albedo_color
	for index: int in segments.size():
		var lit: bool = index < int(ceil(ratio*10))
		var mat := segments[index].material_override as StandardMaterial3D
		mat.albedo_color = tint if lit else Color("171e28")
		mat.emission = tint
		mat.emission_energy_multiplier = 1.0 if lit else 0.0
	for index: int in cracks.size(): cracks[index].visible = index < int((1-ratio)*8) or (flash > .09 and index < 2)

func clear_feedback() -> void:
	appearance = 0
	break_flash = 0
	flash = 0
	visible = false
	if is_instance_valid(fragments): fragments.visible = false
