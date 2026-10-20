class_name SamsonCourt
extends CombatStructure
## One physical, damageable court; cosmetic roaches never own gameplay effects.
var owner_life: int
var remaining: float = 8.0
var witnesses: Dictionary = {}
var procession: Node3D

static func ground_clear(owner_actor: HeroActor, at: Vector3, yaw: float, footprint: Vector3) -> bool:
	var t := owner_actor.tuning as SamsonTuning
	var bounds := AABB(at-Vector3(footprint.x/2,0,footprint.z/2),Vector3(footprint.x,t.court_size.y,footprint.z))
	# Conservative yaw-expanded bounds for protected rooms and moving objectives.
	var extents := Vector3(absf(cos(yaw))*footprint.x+absf(sin(yaw))*footprint.z,t.court_size.y,absf(sin(yaw))*footprint.x+absf(cos(yaw))*footprint.z)
	bounds = AABB(at-Vector3(extents.x/2,0,extents.z/2),extents)
	var session: Node = owner_actor.get_tree().get_first_node_in_group("city_match")
	if session != null:
		for team: int in 2:
			if session.definition.spawn_bounds(team).intersects(bounds): return false
		if session.has_method("track_intersects") and session.track_intersects(bounds): return false
	for x: float in [-.48,0,.48]:
		for z: float in [-.48,0,.48]:
			var foot: Vector3 = at+Vector3(x*footprint.x,0,z*footprint.z).rotated(Vector3.UP,yaw)
			var hit: Dictionary = owner_actor.resolver.ray(foot+Vector3.UP*t.support_probe,foot-Vector3.UP*t.support_probe,[],1)
			if hit.is_empty() or hit.normal.y < t.support_normal or absf(hit.position.y-at.y) > t.support_height_tolerance: return false
	return true

static func placement_clear(owner_actor: HeroActor, at: Vector3, yaw: float) -> bool:
	var t := owner_actor.tuning as SamsonTuning
	if not ground_clear(owner_actor,at,yaw,t.court_size): return false
	var shape := BoxShape3D.new()
	shape.size = t.court_size-Vector3(.04,.08,.04)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(Vector3.UP,yaw),at+Vector3.UP*(t.court_size.y/2+.03))
	query.collision_mask = 3
	return owner_actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _ready() -> void:
	var t := source.tuning as SamsonTuning
	owner_life = source.life_serial
	health = t.court_health
	maximum = health
	size = t.court_size
	remaining = t.court_duration
	position.y += size.y/2
	super._ready()
	add_to_group("owned_attacks")
	add_to_group("transient")
	add_to_group("protection_fields")
	stone.material_override = Geometry.material(Color("3c6055"),.2)
	Geometry.box(self,Vector3(4.3,.14,1.3),Vector3(0,size.y/2-.08,0),Color("d7be79"),false)
	Geometry.text3d(self,"ROACH COURT\nWITNESS PROTECTION",Vector3(0,.25,-.53),30,Color("ffe3a1"))
	var ring := TorusMesh.new()
	ring.inner_radius = t.court_radius-.06
	ring.outer_radius = t.court_radius
	Geometry.mesh(self,ring,Vector3(0,-size.y/2+.04,0),Geometry.material(Color("38dfff") if source.team == 0 else Color("ff4f65"),.7))
	procession = Node3D.new()
	add_child(procession)
	for i: int in 18:
		var angle: float = i*TAU/18
		SamsonVisuals.roach(procession,Vector3(cos(angle)*2.8,-size.y/2+.12,sin(angle)*1.3),.22,Color("7ee8c6"))
	update_witnesses()

func active() -> bool:
	return not is_queued_for_deletion() and health > 0 and remaining > 0 and is_instance_valid(source) and source.alive and source.life_serial == owner_life and not source.resolver.attack_locked(source)

func qualifies(target: HeroActor) -> bool:
	if not active() or not target.alive or target.team != source.team or source.resolver.protected_room(target): return false
	var t := source.tuning as SamsonTuning
	var ground: Vector3 = global_position-Vector3.UP*size.y/2
	var offset: Vector3 = target.global_position-ground
	if Vector2(offset.x,offset.z).length() > t.court_radius or absf(offset.y) > t.court_height: return false
	return not source.resolver.spawn_door_blocks(global_position,target.body_point(1)) and source.resolver.attack_ray(source,global_position,target.body_point(1),[get_rid()],1).is_empty()

func reduction() -> float:
	return (source.tuning as SamsonTuning).court_reduction

func update_witnesses() -> void:
	var t := source.tuning as SamsonTuning
	for target: HeroActor in get_tree().get_nodes_in_group("actors"):
		if witnesses.has(target.get_instance_id()) or not qualifies(target): continue
		witnesses[target.get_instance_id()] = true
		target.overhealth.grant(source,t.court_shield,t.court_shield_duration,"witness_protection","court")
		source.resolver.record("protect",source,"witness_protection","target="+target.actor_id)

func _physics_process(delta: float) -> void:
	remaining = maxf(0,remaining-delta)
	if not active():
		retire()
		return
	update_witnesses()

func _process(delta: float) -> void:
	if not active(): return
	super._process(delta)
	if is_instance_valid(procession): procession.rotation.y += delta*.45
	plate.text = "COURT %d / %.1fs" % [ceili(health),remaining]

func retire() -> void:
	health = 0
	remaining = 0
	set_physics_process(false)
	visible = false
	queue_free()
