class_name MuseumSpawnDoor
extends Node3D
## A physical shutter plus a persistent team-only threshold. Never moves actors.
var width: float = 6.0
var team: int = 0
var stage: int = 0
var active: bool = false
var locked: bool = true
var retired: bool = false
var openness: float = 0.0
var empty_time: float = 0.0
var shutter: StaticBody3D
var threshold: StaticBody3D
var panel: MeshInstance3D
var sign_label: Label3D

func body(size: Vector3, layer: int) -> StaticBody3D:
	var result := StaticBody3D.new()
	result.collision_layer = layer
	result.collision_mask = 0
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.position.y = 2.5
	result.add_child(collision)
	add_child(result)
	return result

func _ready() -> void:
	add_to_group("museum_spawn_doors")
	threshold = body(Vector3(width,5,.25),4 if team == 0 else 8)
	shutter = body(Vector3(width,5,.3),1)
	panel = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width,5,.3)
	panel.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("427d8e") if team == 0 else Color("a5645a")
	material.metallic = .55
	material.roughness = .4
	panel.material_override = material
	add_child(panel)
	sign_label = Label3D.new()
	sign_label.font_size = 30
	sign_label.pixel_size = .012
	sign_label.position = Vector3(0,5.4,.25)
	sign_label.no_depth_test = false
	add_child(sign_label)
	apply_state()

func configure(enabled: bool, preparation_lock: bool, is_retired: bool = false) -> void:
	active = enabled
	locked = preparation_lock or not enabled
	retired = is_retired
	if locked and not retired: openness = 0.0
	if retired: openness = 1.0
	empty_time = 0.0
	if is_instance_valid(shutter): apply_state()

func friendly_nearby() -> bool:
	for actor: HeroActor in get_tree().get_nodes_in_group("actors"):
		if not actor.alive or actor.team != team: continue
		var local: Vector3 = to_local(actor.global_position)
		# Distance to the wide doorway rectangle, from either side, in meters.
		var dx: float = maxf(0,absf(local.x)-width/2)
		if Vector2(dx,local.z).length() <= 3 and local.y >= -.3 and local.y <= 4.5: return true
	return false

func _physics_process(delta: float) -> void:
	var previous_openness: float = openness
	if retired:
		openness = 1.0
	elif locked:
		openness = 0.0
	else:
		var nearby: bool = friendly_nearby()
		var previous_empty: float = empty_time
		empty_time = 0.0 if nearby else empty_time+delta
		if nearby: openness = minf(1,openness+delta/.25)
		elif empty_time >= .75: openness = maxf(0,openness-(maxf(0,empty_time-.75)-maxf(0,previous_empty-.75))/.25)
	if not is_equal_approx(openness,previous_openness): apply_state()

func apply_state() -> void:
	threshold.collision_layer = 0 if retired else (4 if team == 0 else 8)
	# Collision follows the visible shutter; team exclusion stays at the threshold.
	shutter.position.y = openness*5.2
	shutter.force_update_transform()
	shutter.collision_layer = 0 if openness >= .999 else 1
	panel.position = Vector3(0,2.5+openness*5.2,0)
	sign_label.text = "PUBLIC ACCESS" if retired else ("LOCKED / PREPARATION" if locked and active else ("TEAM SPAWN / IMMUNITY" if active else "INACTIVE SPAWN"))

func blocks_attack(from: Vector3, toward: Vector3) -> bool:
	return openness < .999 and AABB(Vector3(-width/2,openness*5.2,-.2),Vector3(width,5,.4)).intersects_segment(to_local(from),to_local(toward)) != null
