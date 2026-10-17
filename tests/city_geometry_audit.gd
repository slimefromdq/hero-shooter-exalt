extends SceneTree
## Compare rendered structural surfaces with physics, independent of their solid flags.
var missing: Array[Dictionary] = []
var checked: int = 0
var winding_checked: int = 0
var winding_errors: int = 0

func _initialize() -> void:
	call_deferred("run")

func probe(world: World3D, at: Vector3, normal: Vector3, caption: String, size: Vector3) -> void:
	if absf(at.x) > 71.5 or absf(at.z) > 65.5: return
	var point_query := PhysicsPointQueryParameters3D.new()
	point_query.position = at + normal * .04
	point_query.collision_mask = 1
	if not world.direct_space_state.intersect_point(point_query).is_empty():
		return # An embedded face is not exposed to play.
	var ray := PhysicsRayQueryParameters3D.create(at + normal * .22, at - normal * .32, 1)
	var hit: Dictionary = world.direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and (hit.position - at).dot(normal) > .02:
		return # Occluded by the outer shell of an intersecting solid.
	checked += 1
	if hit.is_empty() or hit.position.distance_to(at) > .13:
		missing.append({"mesh": caption, "surface": str(at), "normal": str(normal), "size": str(size), "gap": hit.position.distance_to(at) if not hit.is_empty() else -1})

func inspect_batch(node: Node, world: World3D) -> void:
	if node is MultiMeshInstance3D:
		var batch: MultiMeshInstance3D = node
		var kind: String = str(batch.name).get_slice("_", 0)
		if kind == "box" or kind == "cylinder":
			var transforms: Array = batch.get_meta("authored_transforms", [])
			for instance_transform: Transform3D in transforms:
				var transform: Transform3D = batch.global_transform * instance_transform
				var size := Vector3(transform.basis.x.length(), transform.basis.y.length(), transform.basis.z.length())
				for side: float in [-1.0, 1.0]:
					if size.y >= .12 and size.x >= 1 and size.z >= 1:
						probe(world, transform * Vector3(0, side*.5, 0), transform.basis.y.normalized()*side, str(batch.name), size)
					if kind == "box":
						if size.y >= 1.5 and size.z >= 1.5:
							probe(world, transform * Vector3(side*.5,0,0), transform.basis.x.normalized()*side, str(batch.name), size)
						if size.y >= 1.5 and size.x >= 1.5:
							probe(world, transform * Vector3(0,0,side*.5), transform.basis.z.normalized()*side, str(batch.name), size)
	elif node is MeshInstance3D and node.has_meta("material_key"):
		var mesh_node: MeshInstance3D = node
		var faces: PackedVector3Array = mesh_node.mesh.get_faces()
		var arrays: Array = mesh_node.mesh.surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index: int in range(0, faces.size(), 3):
			var geometric: Vector3 = (faces[index+1]-faces[index]).cross(faces[index+2]-faces[index])
			if geometric.length_squared() < .000001: continue
			winding_checked += 1
			if geometric.normalized().dot(normals[index]) > -.99: winding_errors += 1
		for index: int in range(0, faces.size(), 3):
			var a: Vector3 = mesh_node.global_transform * faces[index]
			var b: Vector3 = mesh_node.global_transform * faces[index+1]
			var c: Vector3 = mesh_node.global_transform * faces[index+2]
			var cross: Vector3 = (b-a).cross(c-a)
			if cross.length() > .4:
				var at: Vector3 = (a+b+c)/3
				var normal: Vector3 = -cross.normalized()
				if mesh_node.has_meta("stair_shell"):
					var low: Vector3 = mesh_node.get_meta("low")
					var high: Vector3 = mesh_node.get_meta("high")
					var along := Vector3(high.x-low.x, 0, high.z-low.z)
					var fraction: float = Vector3(at.x-low.x, 0, at.z-low.z).dot(along) / along.length_squared()
					var slope_height: float = lerpf(low.y, high.y, fraction)
					# Treads and risers share a smooth movement hull within half a
					# riser. Measure their vertical support, not a horizontal ray
					# whose error grows with the tread depth on shallow stairs.
					if normal.y > -.1 and absf(at.y-slope_height) <= .13:
						normal = Vector3.UP
				probe(world, at, normal, "closed_" + str(node.get_meta("material_key")), Vector3.ZERO)
	for child: Node in node.get_children(): inspect_batch(child, world)

func run() -> void:
	var arena: Node3D = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.match_controller.freeze_ai = true
	arena.player.controller.active = false
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
	inspect_batch(arena.builder, arena.get_world_3d())
	print("STRUCTURAL SURFACE AUDIT checked=", checked, " missing=", missing.size(), " winding=", winding_checked, " winding_errors=", winding_errors)
	for entry: Dictionary in missing: print(JSON.stringify(entry))
	var file := FileAccess.open("res://artifacts/city-geometry-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checked": checked, "missing": missing, "winding_checked": winding_checked, "winding_errors": winding_errors}, "\t"))
	# Let an outstanding asynchronous bake finish before freeing its source geometry.
	var started: int = Time.get_ticks_msec()
	while not arena.match_controller.navigation_ready and Time.get_ticks_msec() - started < 30000:
		await process_frame
	arena.queue_free()
	await process_frame
	quit(0 if missing.is_empty() and winding_errors == 0 else 1)
