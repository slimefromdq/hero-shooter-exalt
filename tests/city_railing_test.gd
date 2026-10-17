extends SceneTree
## Railing barriers must follow vertical posts on slopes, including their endpoints.

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var fixture := Node3D.new()
	root.add_child(fixture)
	var kit := MeridianArchitecture.new(fixture)
	var cases: Array[Dictionary] = []
	var vectors: Array[Vector3] = [Vector3(0,6.5,16), Vector3(0,-6.5,16), Vector3(10,4.2,0), Vector3(-10,4.2,0), Vector3(8,3,8), Vector3(0,0,8), Vector3(8,0,0)]
	for i: int in vectors.size():
		var a := Vector3(i*24, 10, 0)
		var b: Vector3 = a + vectors[i]
		var height: float = .45 if i == 6 else 1.1
		kit.railing(a,b,height)
		cases.append({"a":a,"b":b,"height":height})
	kit.flush()
	await physics_frame
	await process_frame
	await physics_frame
	var checks: int = 0
	var failures: Array[String] = []
	for i: int in cases.size():
		var a: Vector3 = cases[i].a
		var b: Vector3 = cases[i].b
		var height: float = cases[i].height
		var along := Vector3(b.x-a.x,0,b.z-a.z).normalized()
		var side := along.cross(Vector3.UP)
		var follows_posts: bool = true
		for fraction: float in [.02,.5,.98]:
			for elevation: float in [.08,.5,.92]:
				var at: Vector3 = a.lerp(b,fraction)+Vector3.UP*height*elevation
				var query := PhysicsRayQueryParameters3D.create(at+side*.3,at-side*.3,1)
				if fixture.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): follows_posts = false
		var endpoints_clear: bool = true
		for end: int in 2:
			for elevation: float in [.1,.9]:
				var at: Vector3 = (a-along*.08 if end == 0 else b+along*.08)+Vector3.UP*height*elevation
				var query := PhysicsRayQueryParameters3D.create(at+side*.3,at-side*.3,1)
				if not fixture.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): endpoints_clear = false
		for result: Dictionary in [{"ok":follows_posts,"name":"barrier follows posts"},{"ok":endpoints_clear,"name":"barrier ends at landing"}]:
			checks += 1
			var caption: String = "Railing %d %s" % [i,result.name]
			print("PASS  " if result.ok else "FAIL  ",caption)
			if not result.ok: failures.append(caption)
	print("RESULT: ",checks," checks, ",failures.size()," failures")
	var file := FileAccess.open("res://artifacts/city-railing.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	fixture.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
