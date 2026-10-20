class_name RedThread
extends Node3D
## One source-owned, cleanseable leash. Never pulls or roots its recipient.
var source: HeroActor
var target: HeroActor
var remaining: float = 5.0
var obstruction: float = 0.0
var source_life: int
var target_life: int
var retired: bool = false
var visual: MeshInstance3D

func _ready() -> void:
	add_to_group("red_threads")
	add_to_group("owned_attacks")
	add_to_group("transient")
	source_life = source.life_serial
	target_life = target.life_serial
	visual = MeshInstance3D.new()
	visual.material_override = Geometry.material(Color("ff234a"),2)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)

func valid() -> bool:
	return not retired and is_instance_valid(source) and is_instance_valid(target) and source.alive and target.alive and source.life_serial == source_life and target.life_serial == target_life and target.state != "wisp_phase" and not source.resolver.protected_room(source) and not source.resolver.protected_room(target)

func _physics_process(delta: float) -> void:
	if not valid():
		retire()
		return
	var t := source.tuning as StitchTuning
	remaining -= delta
	var blocked: bool = not source.resolver.visible(source.body_point(1),target,[source.get_rid()]) or source.resolver.spawn_door_blocks(source.body_point(1),target.body_point(1)) or not source.resolver.barrier_ray(source,source.body_point(1),target.body_point(1)).is_empty()
	obstruction = obstruction+delta if blocked else 0.0
	if remaining <= 0 or source.global_position.distance_to(target.global_position) > t.thread_break_range or obstruction >= t.thread_obstruction:
		retire()
		return
	var line := ImmediateMesh.new()
	line.surface_begin(Mesh.PRIMITIVE_LINES)
	line.surface_add_vertex(to_local(source.body_point(1)))
	line.surface_add_vertex(to_local(target.body_point(1)))
	line.surface_end()
	visual.mesh = line

func retire() -> void:
	if retired: return
	retired = true
	visible = false
	set_physics_process(false)
	queue_free()

static func clear_actor(actor: HeroActor, incoming_only: bool = false) -> void:
	for thread: RedThread in actor.get_tree().get_nodes_in_group("red_threads"):
		if thread.target == actor or (not incoming_only and thread.source == actor): thread.retire()

static func constrain(actor: HeroActor, motion: Vector3) -> Vector3:
	# Preserve falling/gravity. Walking and external forces never call this API.
	var fall: Vector3 = Vector3(0,minf(0,motion.y),0)
	var result: Vector3 = motion-fall
	for thread: RedThread in actor.get_tree().get_nodes_in_group("red_threads"):
		if thread.target != actor or not thread.valid(): continue
		var offset: Vector3 = actor.global_position-thread.source.global_position
		var radius: float = maxf((thread.source.tuning as StitchTuning).thread_leash,offset.length())
		if (offset+result).length_squared() <= radius*radius+.00001: continue
		var length_sq: float = result.length_squared()
		if length_sq < .0000001: continue
		var dot: float = offset.dot(result)
		var discriminant: float = maxf(0,dot*dot-length_sq*(offset.length_squared()-radius*radius))
		var fraction: float = clampf((-dot+sqrt(discriminant))/length_sq,0,1)
		result *= fraction
	return result+fall
