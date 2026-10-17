extends "res://tests/city_traversal_test.gd"
## Both collision and visible paving must leave the full stair opening clear.

func run() -> void:
	arena = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	session = arena.match_controller
	session.freeze_ai = true
	session.player.controller.active = false
	while not session.navigation_ready: await step(1)
	var openings: Array[Rect2] = []
	for side: float in [-1.0,1.0]:
		openings.append(Rect2(-3,38 if side > 0 else -58,6,20))
		openings.append(Rect2(-3,10 if side > 0 else -24,6,14))
		for wing: float in [-1.0,1.0]:
			openings.append(Rect2(15 if wing > 0 else -21,18 if side > 0 else -38,6,20))
	var overhangs: Array[String] = []
	var inspected: int = 0
	for node: Node in arena.builder.get_children():
		if not node is MultiMeshInstance3D or not str(node.name).begins_with("box_"): continue
		var key: String = str(node.name)
		for transform: Transform3D in node.get_meta("authored_transforms", []):
			var size := Vector3(transform.basis.x.length(),transform.basis.y.length(),transform.basis.z.length())
			# Horizontal street surfacing/paint; exclude stairs, vertical walls,
			# curb edges and structural slabs below the finished ground surface.
			if size.y > .1 or absf(transform.origin.y) > .08: continue
			if absf(transform.basis.y.normalized().dot(Vector3.UP)) < .99: continue
			inspected += 1
			var footprint := Rect2(transform.origin.x-size.x*.5,transform.origin.z-size.z*.5,size.x,size.z)
			for opening: Rect2 in openings:
				if footprint.intersects(opening) and footprint.intersection(opening).get_area() > .002:
					overhangs.append(key+" "+str(transform.origin))
	check(inspected > 0,"visible ground surfaces were inspected")
	check(overhangs.is_empty(),"all visible paving and paint stop at stair openings: "+str(overhangs))
	for side: float in [-1.0,1.0]:
		for z: float in [40,44,48,52,56]:
			for x: float in [-2,0,2]:
				var at := Vector3(x,1,side*z)
				var query := PhysicsRayQueryParameters3D.create(at,at-Vector3.UP*7,1)
				var hit: Dictionary = arena.get_world_3d().direct_space_state.intersect_ray(query)
				var expected: float = -5+(z-38)*.25
				check(not hit.is_empty() and absf(hit.position.y-expected)<.13,"spawn stair full-width surface %s" % str(Vector2(x,side*z)))
	print("RESULT: ",checks," checks, ",failures.size()," failures")
	var file := FileAccess.open("res://artifacts/city-stair-openings.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	arena.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
