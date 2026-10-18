extends SceneTree
## Loads the separate review asset only. Does not replace any live actor visuals.
var checks: int = 0
var failures: Array[String] = []
var lower := Vector3(INF,INF,INF)
var upper := Vector3(-INF,-INF,-INF)
var meshes: int = 0
var surfaces: int = 0
var triangles: int = 0
var face: MeshInstance3D
var skin_tint_imported: bool = false
const FACE_KEYS := ["Blink","BrowRaise","BrowLower","Smile","Frown","MouthOpen","Relaxed","Focused","Smirk"]

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	if ok: print("PASS  ",caption)
	else:
		failures.append(caption)
		push_error(caption)

func inspect(node: Node) -> void:
	check(not node is CollisionObject3D,"review asset has no gameplay collision: " + str(node.name))
	if node is MeshInstance3D:
		meshes += 1
		var visual := node as MeshInstance3D
		check(visual.mesh != null,"imported mesh exists: " + str(node.name))
		if visual.mesh != null:
			if visual.mesh.get_blend_shape_count() > 0:
				check(face == null,"facial morphs belong to one isolated mesh")
				face = visual
				check(visual.mesh.get_blend_shape_count() == FACE_KEYS.size(),"nine facial morph targets survive Godot import")
				for key: String in FACE_KEYS:
					var blend_index: int = visual.find_blend_shape_by_name(key)
					check(blend_index >= 0,"named facial morph imported: " + key)
					if blend_index >= 0:
						visual.set_blend_shape_value(blend_index,1.0)
						check(is_equal_approx(visual.get_blend_shape_value(blend_index),1.0),"morph can be driven in Godot: " + key)
						visual.set_blend_shape_value(blend_index,0.0)
			var box: AABB = visual.mesh.get_aabb()
			for index: int in 8:
				var point: Vector3 = visual.global_transform * box.get_endpoint(index)
				lower = lower.min(point)
				upper = upper.max(point)
			for index: int in visual.mesh.get_surface_count():
				surfaces += 1
				var material: Material = visual.get_active_material(index)
				check(material is StandardMaterial3D,"PBR material survives glTF import")
				if material is StandardMaterial3D and material.resource_name == "FaceSkin":
					skin_tint_imported = material.vertex_color_use_as_albedo
				var arrays: Array = visual.mesh.surface_get_arrays(index)
				if visual.mesh.get_blend_shape_count() > 0:
					var tangent_data: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
					check(tangent_data.size() == (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()*4,"facial tangent data survives import")
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += indices.size()/3 if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3
	for child: Node in node.get_children(): inspect(child)

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var packed: PackedScene = load("res://assets/characters/slayer/slayer.glb")
	check(packed != null,"GLB loads as a Godot PackedScene")
	if packed == null:
		quit(1)
		return
	var model: Node3D = packed.instantiate()
	stage.add_child(model)
	inspect(model)
	check(meshes == 21,"twenty preserved groups plus isolated morph face imported")
	check(face != null,"expressive face mesh exists")
	check(skin_tint_imported,"skin warmth and socket shadows survive as vertex colour albedo")
	check(absf(lower.y) < .005,"feet and model ground origin are at zero")
	check(absf(upper.y-lower.y-1.8607) < .005,"shorter neck lowers the visual crown without rescaling the body")
	check(triangles > 70000 and triangles < 95000,"geometry stays within the detailed-face review triangle budget")
	var forward := model.find_child("Slayer_Forward",true,false) as Node3D
	check(forward != null and forward.global_position.z < -.25,"Blender +Y converts to Godot -Z facing")
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.25
	camera.position = Vector3(2.1,1.5,-4.5)
	camera.look_at(Vector3(0,.98,0))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("1b2330")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c1ccdf")
	environment.environment.ambient_light_energy = .65
	stage.add_child(environment)
	for at: Vector3 in [Vector3(2.5,4,-3),Vector3(-3,2,-1),Vector3(1,3,3)]:
		var light := OmniLight3D.new()
		stage.add_child(light)
		light.position = at
		light.omni_range = 9
		light.light_energy = 2
	if DisplayServer.get_name() != "headless":
		for index: int in 8: await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://assets/characters/slayer/previews/godot-import.png") == OK,"rendered imported asset preview saved")
		camera.position = Vector3(-.34,1.75,-2.1)
		camera.look_at(Vector3(0,1.72,-.015))
		camera.size = .43
		var neutral_pixels := PackedByteArray()
		for expression: String in ["neutral","Smile","BrowLower","Blink","MouthOpen","Relaxed","Focused","Smirk"]:
			if face != null:
				for key: String in FACE_KEYS:
					face.set_blend_shape_value(face.find_blend_shape_by_name(key),1.0 if key == expression else 0.0)
			for index: int in 4: await process_frame
			await RenderingServer.frame_post_draw
			var pixels: PackedByteArray = root.get_texture().get_image().get_data()
			if expression == "neutral": neutral_pixels = pixels
			else: check(pixels != neutral_pixels,"facial morph changes actual rendered pixels: " + expression)
			check(root.get_texture().get_image().save_png("res://assets/characters/slayer/previews/godot-face-" + expression.to_lower() + ".png") == OK,"rendered Godot face expression: " + expression)
		if face != null:
			for key: String in FACE_KEYS: face.set_blend_shape_value(face.find_blend_shape_by_name(key),0.0)
	var file := FileAccess.open("res://assets/characters/slayer/godot-validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failures":failures,"meshes":meshes,"surfaces":surfaces,"triangles":triangles,"facial_shape_keys":FACE_KEYS,"bounds_min":str(lower),"bounds_max":str(upper),"height":upper.y-lower.y,"live_actor_replaced":false},"\t"))
	print("RESULT: %d checks, %d failures" % [checks,failures.size()])
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
