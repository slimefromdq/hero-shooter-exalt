class_name DynamoWall
extends Node3D
var source: HeroActor
var remaining: float = 8.0
var sections: Array[CombatStructure] = []

static func positions(at: Vector3, yaw: float, t: DynamoTuning) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for index: int in t.wall_sections:
		result.append(at+Vector3((index-(t.wall_sections-1)/2.0)*t.wall_width/t.wall_sections,t.wall_height/2,0).rotated(Vector3.UP,yaw))
	return result

static func placement_clear(actor: HeroActor, at: Vector3, yaw: float) -> bool:
	var t := actor.tuning as DynamoTuning
	var city: Node = actor.get_tree().get_first_node_in_group("city_match")
	var shape := BoxShape3D.new()
	shape.size = Vector3(t.wall_width/t.wall_sections-.04,t.wall_height-.12,t.wall_depth-.04)
	var room_extents := Vector3(absf(cos(yaw))*shape.size.x+absf(sin(yaw))*shape.size.z,shape.size.y,absf(sin(yaw))*shape.size.x+absf(cos(yaw))*shape.size.z)
	for center: Vector3 in positions(at,yaw,t):
		if city != null:
			for team: int in 2:
				if city.definition.spawn_bounds(team).intersects(AABB(center-room_extents/2,room_extents)): return false
		for x: float in [-.45,.45]:
			for z: float in [-.4,.4]:
				var foot: Vector3 = center-Vector3.UP*t.wall_height/2+Vector3(x*t.wall_width/t.wall_sections,0,z*t.wall_depth).rotated(Vector3.UP,yaw)
				var ground: Dictionary = actor.resolver.ray(foot+Vector3.UP*.3,foot-Vector3.UP*.35,[],1)
				if ground.is_empty() or ground.normal.y < .94 or absf(ground.position.y-at.y) > .25: return false
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis(Vector3.UP,yaw),center+Vector3.UP*.04)
		query.collision_mask = 3
		if not actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	return true

func build(at: Vector3, yaw: float) -> void:
	var t := source.tuning as DynamoTuning
	remaining = t.wall_duration
	for center: Vector3 in positions(at,yaw,t):
		var section := CombatStructure.new()
		section.source = source
		section.health = t.wall_health
		section.maximum = t.wall_health
		section.size = Vector3(t.wall_width/t.wall_sections,t.wall_height,t.wall_depth)
		add_child(section)
		section.global_position = center
		section.rotation.y = yaw
		sections.append(section)

func _ready() -> void:
	add_to_group("owned_attacks")
	add_to_group("transient")

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	remaining -= delta
	var intact: int = 0
	for section: CombatStructure in sections:
		if is_instance_valid(section) and section.health > 0: intact += 1
	if remaining <= 0 or intact == 0 or not is_instance_valid(source) or not source.alive: queue_free()
