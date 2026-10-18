class_name StructureAvoidance
extends RefCounted
## Short physical detours complement the unchanged baked city mesh.

static func clear(a: HeroActor, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = a.motor.body_collision.shape
	query.transform = Transform3D(Basis.IDENTITY,from+Vector3.UP*a.motor.body_collision.position.y)
	query.motion = to-from
	query.collision_mask = 1
	var result: PackedFloat32Array = a.get_world_3d().direct_space_state.cast_motion(query)
	return result[0] >= .999

static func supported(a: HeroActor, point: Vector3) -> Vector3:
	var ground: Dictionary = a.resolver.ray(point+Vector3.UP*1.8,point-Vector3.UP*2.5,[],1)
	if ground.is_empty() or ground.normal.y < .85: return Vector3.INF
	return ground.position+Vector3.UP*.03

static func steer(a: HeroActor, move: Vector3, goal: Vector3) -> Vector3:
	if move.is_zero_approx(): return move
	if a.get_tree().get_nodes_in_group("structures").is_empty():
		a.set_meta("structure_route",[])
		return move
	var route: Array = a.get_meta("structure_route",[])
	var probe: Vector3 = a.global_position+move.normalized()*3
	if clear(a,a.global_position,probe):
		if route.is_empty() or clear(a,a.global_position,goal):
			a.set_meta("structure_route",[])
			return move
	if not route.is_empty():
		if a.global_position.distance_to(route[0]) < .65: route.pop_front()
		if not route.is_empty():
			a.set_meta("structure_route",route)
			return ((route[0]-a.global_position)*Vector3(1,0,1)).normalized()
	var hit: Dictionary = a.resolver.ray(a.body_point(.8),probe+Vector3.UP*.8,[a.get_rid()],1)
	var panel := hit.get("collider") as CombatStructure
	if panel == null: return move
	var wall := panel.get_parent() as DynamoWall
	if wall == null: return move
	var t := wall.source.tuning as DynamoTuning
	var yaw: float = panel.rotation.y
	var center: Vector3 = panel.global_position-Vector3.UP*t.wall_height/2
	var positions: Array[Vector3] = DynamoWall.positions(Vector3.ZERO,yaw,t)
	# Recover the wall center from the surviving section's original index.
	var index: int = wall.sections.find(panel)
	center -= positions[index]-Vector3.UP*t.wall_height/2
	var local: Vector3 = (a.global_position-center).rotated(Vector3.UP,-yaw)
	var side: float = 1.0 if local.z >= 0 else -1.0
	var candidates: Array[float] = [-t.wall_width/2-.8,t.wall_width/2+.8]
	for slot: int in wall.sections.size():
		if not is_instance_valid(wall.sections[slot]) or wall.sections[slot].health <= 0:
			candidates.append((slot-(t.wall_sections-1)/2.0)*t.wall_width/t.wall_sections)
	var best: Array[Vector3] = []
	var cost: float = INF
	for x: float in candidates:
		var near: Vector3 = supported(a,center+Vector3(x,0,side*(t.wall_depth/2+.8)).rotated(Vector3.UP,yaw))
		var far: Vector3 = supported(a,center+Vector3(x,0,-side*(t.wall_depth/2+.8)).rotated(Vector3.UP,yaw))
		if near == Vector3.INF or far == Vector3.INF or not clear(a,a.global_position,near) or not clear(a,near,far): continue
		var value: float = a.global_position.distance_to(near)+near.distance_to(far)+far.distance_to(goal)
		if value < cost:
			cost = value
			best = [near,far]
	if not best.is_empty():
		a.set_meta("structure_route",best)
		return ((best[0]-a.global_position)*Vector3(1,0,1)).normalized()
	return move
