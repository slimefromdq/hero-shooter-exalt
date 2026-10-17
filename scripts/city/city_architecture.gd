class_name MeridianArchitecture
extends RefCounted
## Reusable city kit. Thousands of architectural details share a few MultiMeshes.

var owner_node: Node3D
var collision_body: StaticBody3D
var materials: Dictionary = {}
var batches: Dictionary = {}
var meshes: Dictionary = {}
var collision_shapes: Dictionary = {}
var lamp_positions: Array[Vector3] = []
var custom_surfaces: Array[MeshInstance3D] = []

func _init(parent: Node3D) -> void:
	owner_node = parent
	collision_body = StaticBody3D.new()
	collision_body.name = "CityCollision"
	collision_body.add_to_group("meridian_navigation_geometry")
	parent.add_child(collision_body)
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3.ONE
	meshes["box"] = box_mesh
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = 0.5
	cylinder_mesh.bottom_radius = 0.5
	cylinder_mesh.height = 1.0
	cylinder_mesh.radial_segments = 12
	meshes["cylinder"] = cylinder_mesh
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = 0.5
	cone_mesh.height = 1.0
	cone_mesh.radial_segments = 12
	meshes["cone"] = cone_mesh
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 12
	ball.rings = 6
	meshes["sphere"] = ball
	var ring := TorusMesh.new()
	ring.inner_radius = 0.92
	ring.outer_radius = 1.0
	ring.rings = 48
	ring.ring_segments = 6
	meshes["ring"] = ring
	_palette()

func _palette() -> void:
	mat("ivory", Color("929ca5"), 0.0, 0.81)
	mat("cream", Color("bac0bd"), 0.0, 0.70)
	mat("trim", Color("d1d0bb"), 0.0, 0.72)
	mat("stone_dark", Color("343f50"), 0.0, 0.88)
	mat("slate", Color("263547"), 0.0, 0.55)
	mat("brick", Color("6b6669"), 0.0, 0.89)
	mat("rose", Color("8c777b"), 0.0, 0.84)
	mat("blue", Color("4e6879"), 0.0, 0.78)
	mat("brass", Color("a08e63"), 0.0, 0.32, 0.68)
	mat("iron", Color("25343c"), 0.0, 0.44, 0.5)
	mat("asphalt", Color("29343f"), 0.0, 0.53)
	mat("paving", Color("596774"), 0.0, 0.66)
	mat("paving_light", Color("74838a"), 0.0, 0.67)
	mat("soil", Color("37333d"), 0.0, 1.0)
	mat("grass", Color("3f5559"), 0.0, 1.0)
	mat("leaf", Color("30484b"), 0.0, 1.0)
	mat("leaf_light", Color("52686b"), 0.0, 1.0)
	mat("trunk", Color("554c50"), 0.0, 0.95)
	mat("flower", Color("b9819e"), 0.25, 0.9)
	mat("flower_blue", Color("7c9cae"), 0.35, 0.9)
	mat("window", Color("c99555"), 1.05, 0.35)
	mat("window_dim", Color("886f58"), 0.6, 0.38)
	mat("glass", Color("334d63"), 0.06, 0.16, 0.35)
	var roof_glass: StandardMaterial3D = mat("roof_glass", Color("69879a"), .03, .2, .1)
	roof_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	roof_glass.albedo_color.a = .38
	roof_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat("cyan", Color("79c7e5"), 1.6, 0.32)
	mat("violet", Color("b09bdf"), 1.3, 0.35)
	mat("lamp", Color("ffd5a0"), 2.6, 0.4)
	mat("warm_wash", Color("9b8a75"), 0.13, 0.82)
	mat("water", Color("375e77"), 0.2, 0.12, 0.3)
	mat("white", Color("d6dedc"), 0.0, 0.55)
	mat("sign", Color("1b303c"), 0.0, 0.8)

func mat(key: String, color: Color, emission: float = 0.0, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	materials[key] = material
	return material

func piece(kind: String, size: Vector3, at: Vector3, material_key: String, rotation: Vector3 = Vector3.ZERO) -> void:
	var key := kind + ":" + material_key
	if not batches.has(key):
		batches[key] = []
	batches[key].append(Transform3D(Basis.from_euler(rotation).scaled_local(size), at))

func box(size: Vector3, at: Vector3, material_key: String, solid: bool = false, rotation: Vector3 = Vector3.ZERO) -> void:
	piece("box", size, at, material_key, rotation)
	# Substantial slabs, roofs, balcony decks and counter tops are always tangible.
	# Thin paint, mouldings and small trim remain detail over the supporting collider.
	if solid or (size.x >= 1.0 and size.z >= 1.0 and size.y >= 0.12):
		collider_box(size, at, rotation)

func cylinder(radius: float, height: float, at: Vector3, material_key: String, solid: bool = false) -> void:
	piece("cylinder", Vector3(radius * 2.0, height, radius * 2.0), at, material_key)
	if solid:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = at
		collision_body.add_child(collider)

func collider_box(size: Vector3, at: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var key := str(size)
	if not collision_shapes.has(key):
		var shape := BoxShape3D.new()
		shape.size = size
		collision_shapes[key] = shape
	var collider := CollisionShape3D.new()
	collider.shape = collision_shapes[key]
	collider.position = at
	collider.rotation = rotation
	collision_body.add_child(collider)

func line(a: Vector3, b: Vector3, thickness: float, material_key: String) -> void:
	var along := b - a
	var orient := Basis.looking_at(along.normalized(), Vector3.UP)
	if absf(along.normalized().dot(Vector3.UP)) > 0.99:
		orient = Basis.looking_at(along.normalized(), Vector3.RIGHT)
	var key := "box:" + material_key
	if not batches.has(key):
		batches[key] = []
	batches[key].append(Transform3D(orient.scaled_local(Vector3(thickness, thickness, along.length())), (a + b) * 0.5))

func arch(center: Vector3, width: float, height: float, depth: float, material_key: String, turn: float = 0.0, thickness: float = 0.55, solid: bool = true) -> void:
	var rot := Basis(Vector3.UP, turn)
	var steps := 18
	for i in steps:
		var a := float(i) * PI / steps
		var b := float(i + 1) * PI / steps
		var first := Vector3(cos(a) * width * 0.5, sin(a) * height, 0)
		var second := Vector3(cos(b) * width * 0.5, sin(b) * height, 0)
		var delta := second - first
		var midpoint := (first + second) * 0.5
		var angle := atan2(delta.y, delta.x)
		if angle > PI * 0.5: angle -= PI
		var size := Vector3(delta.length() + 0.07, thickness, depth)
		var at: Vector3 = center + rot * midpoint
		piece("box", size, at, material_key, Vector3(0, turn, angle))
		if solid: collider_box(size, at, Vector3(0, turn, angle))

func vaulted_roof(center: Vector3, width: float, rise: float, length: float, key: String, segments: int = 24) -> void:
	# Continuous supported barrel roof. Every visible panel has the same physical slab.
	for index: int in segments:
		var a := float(index) * PI / segments
		var b := float(index + 1) * PI / segments
		var first := Vector3(cos(a) * width * .5, sin(a) * rise, 0)
		var second := Vector3(cos(b) * width * .5, sin(b) * rise, 0)
		var along: Vector3 = second - first
		var angle: float = atan2(along.y, along.x)
		if angle > PI * .5: angle -= PI
		box(Vector3(along.length() + .035, .18, length), center + (first + second) * .5, key, true, Vector3(0, 0, angle))

func polygon_prism(outline: PackedVector2Array, depth: float, at: Vector3, key: String, solid: bool = true) -> MeshInstance3D:
	# Closed extrusion for gables and the masonry above railway arches.
	var area: float = 0
	for index: int in outline.size():
		var next: int = (index + 1) % outline.size()
		area += outline[index].cross(outline[next])
	if area < 0: outline.reverse()
	var vertices := PackedVector3Array()
	for side: float in [1.0, -1.0]:
		for point: Vector2 in outline: vertices.append(Vector3(point.x, point.y, side * depth * .5))
	var count: int = outline.size()
	var faces := PackedInt32Array()
	var cap: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	for index: int in range(0, cap.size(), 3):
		faces.append_array(PackedInt32Array([cap[index], cap[index + 1], cap[index + 2], cap[index + 2] + count, cap[index + 1] + count, cap[index] + count]))
	for index: int in count:
		var next: int = (index + 1) % count
		faces.append_array(PackedInt32Array([index, index + count, next, next, index + count, next + count]))
	return polyhedron(vertices, faces, at, key, solid)

func polyhedron(vertices: PackedVector3Array, faces: PackedInt32Array, at: Vector3, key: String, solid: bool = true) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var collision_faces := PackedVector3Array()
	for index: int in range(0, faces.size(), 3):
		var a: Vector3 = vertices[faces[index]]
		var b: Vector3 = vertices[faces[index + 1]]
		var c: Vector3 = vertices[faces[index + 2]]
		var normal: Vector3 = (b - a).cross(c - a).normalized()
		for point: Vector3 in [a, b, c]:
			tool.set_normal(normal)
			tool.add_vertex(point)
			collision_faces.append(point)
	var visual := MeshInstance3D.new()
	visual.mesh = tool.commit()
	visual.position = at
	visual.material_override = materials[key]
	visual.set_meta("material_key", key)
	owner_node.add_child(visual)
	custom_surfaces.append(visual)
	if solid:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(collision_faces)
		shape.backface_collision = true
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = at
		collision_body.add_child(collider)
	return visual

func window(at: Vector3, width: float = 1.15, height: float = 1.65, turn: float = 0.0, lit: bool = true, ornate: bool = true) -> void:
	var basis := Basis(Vector3.UP, turn)
	box(Vector3(width + 0.22, height + 0.22, 0.18), at, "stone_dark", false, Vector3(0, turn, 0))
	box(Vector3(width, height, 0.20), at + basis * Vector3(0, 0, 0.04), "window" if lit else "window_dim", width >= 1.5 and height >= 1.5, Vector3(0, turn, 0))
	box(Vector3(0.075, height, 0.25), at, "iron", false, Vector3(0, turn, 0))
	box(Vector3(width, 0.075, 0.25), at + Vector3(0, height * 0.16, 0), "iron", false, Vector3(0, turn, 0))
	# Interior shades leave a dark recess around the amber panes.
	box(Vector3(width * 0.13, height, 0.27), at + basis * Vector3(-width * 0.43, 0, 0.01), "slate", false, Vector3(0, turn, 0))
	box(Vector3(width * 0.13, height, 0.27), at + basis * Vector3(width * 0.43, 0, 0.01), "slate", false, Vector3(0, turn, 0))
	if ornate:
		box(Vector3(width + 0.45, 0.14, 0.5), at + Vector3(0, -height * 0.5 - 0.15, 0), "trim", false, Vector3(0, turn, 0))
		arch(at + Vector3(0, height * 0.5, 0), width + 0.25, width * 0.35, 0.22, "trim", turn, 0.15, false)

func lamp(at: Vector3, tall: float = 4.2) -> void:
	lamp_positions.append(at + Vector3.UP * tall)
	cylinder(0.12, tall, at + Vector3(0, tall * 0.5, 0), "iron", true)
	cylinder(0.32, 0.22, at + Vector3(0, 0.11, 0), "brass")
	box(Vector3(0.41, 0.58, 0.41), at + Vector3(0, tall, 0), "lamp")
	box(Vector3(0.58, 0.12, 0.58), at + Vector3(0, tall - 0.39, 0), "iron")
	box(Vector3(0.58, 0.12, 0.58), at + Vector3(0, tall + 0.39, 0), "iron")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			box(Vector3(0.045, 0.78, 0.045), at + Vector3(sx * 0.25, tall, sz * 0.25), "iron")
	piece("cone", Vector3(0.85, 0.40, 0.85), at + Vector3(0, tall + 0.55, 0), "slate")
	# A fixed warm stone plinth is the baked component of each lamppost.
	cylinder(0.52, 0.04, at + Vector3(0, 0.025, 0), "warm_wash")

func planter(at: Vector3, size: Vector3, flowers: bool = true, solid: bool = true) -> void:
	box(size, at + Vector3(0, size.y * 0.5, 0), "ivory", solid)
	box(Vector3(size.x + 0.12, 0.12, size.z + 0.12), at + Vector3(0, size.y, 0), "trim")
	box(Vector3(size.x - 0.25, 0.07, size.z - 0.25), at + Vector3(0, size.y + 0.06, 0), "soil")
	var nx := maxi(1, int(size.x / 0.65))
	var nz := maxi(1, int(size.z / 0.65))
	for x in nx:
		for z in nz:
			var point := at + Vector3((float(x) + 0.5) * size.x / nx - size.x * 0.5, size.y + 0.24, (float(z) + 0.5) * size.z / nz - size.z * 0.5)
			piece("sphere", Vector3(0.7, 0.5, 0.7), point, "leaf")
			if flowers and (x + z) % 2 == 0:
				var flower_at := point + Vector3(0.09, 0.35 + (z % 2) * 0.12, 0.05)
				cylinder(0.018, 0.38, flower_at - Vector3.UP * 0.18, "leaf_light")
				for petal in 4:
					var angle := petal * TAU / 4.0
					piece("sphere", Vector3(0.13, 0.09, 0.13), flower_at + Vector3(cos(angle) * 0.065, 0, sin(angle) * 0.065), "flower" if x % 2 == 0 else "flower_blue")
				piece("sphere", Vector3(0.06, 0.06, 0.06), flower_at + Vector3.UP * 0.04, "brass")

func tree(at: Vector3, scale_factor: float = 1.0, pale: bool = false) -> void:
	cylinder(0.24 * scale_factor, 3.7 * scale_factor, at + Vector3(0, 1.85 * scale_factor, 0), "trunk", true)
	for i in 9:
		var angle := i * TAU / 9.0
		var radius := 1.15 + (i % 3) * 0.24
		var branch_end := at + Vector3(cos(angle) * radius, 3.8 + (i % 3) * 0.6, sin(angle) * radius) * scale_factor
		line(at + Vector3(0, 2.5 * scale_factor, 0), branch_end, 0.18 * scale_factor, "trunk")
		piece("sphere", Vector3(2.0 + (i % 2) * 0.25, 2.5, 1.9) * scale_factor, branch_end + Vector3(0, 0.5, 0), "leaf_light" if pale and i % 3 != 0 else "leaf", Vector3(0.1 * i, angle, 0.12 * (i % 3)))

func railing(a: Vector3, b: Vector3, height: float = 1.1, solid: bool = true) -> void:
	line(a + Vector3.UP * height, b + Vector3.UP * height, 0.11, "brass")
	line(a + Vector3.UP * 0.45, b + Vector3.UP * 0.45, 0.065, "iron")
	var count := maxi(1, int(a.distance_to(b) / 1.2))
	for i in count + 1:
		var at := a.lerp(b, float(i) / count)
		box(Vector3(0.08, height, 0.08), at + Vector3.UP * height * 0.5, "iron")
	if solid:
		var delta := b - a
		var tangent := delta.normalized()
		var side := tangent.cross(Vector3.UP).normalized()
		var normal := side.cross(tangent).normalized()
		var shape := BoxShape3D.new()
		shape.size = Vector3(delta.length(), height, 0.12)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.transform = Transform3D(Basis(tangent, normal, side), (a + b) * 0.5 + Vector3.UP * height * 0.5)
		collision_body.add_child(collider)

func label(caption: String, at: Vector3, font_size: int = 54, color: Color = Color("f1d3a3"), turn: float = 0.0) -> Label3D:
	var result := Label3D.new()
	result.text = caption
	result.position = at
	result.rotation.y = turn
	result.font_size = font_size
	result.pixel_size = 0.012
	result.modulate = color
	result.outline_size = 0
	result.no_depth_test = false
	result.double_sided = false
	result.shaded = false
	result.visibility_range_end = 75.0
	owner_node.add_child(result)
	return result

func flush() -> void:
	for key: String in batches:
		var transforms: Array = batches[key]
		var mesh_batch := MultiMesh.new()
		mesh_batch.transform_format = MultiMesh.TRANSFORM_3D
		mesh_batch.mesh = meshes[key.get_slice(":", 0)]
		mesh_batch.instance_count = transforms.size()
		for index in transforms.size():
			mesh_batch.set_instance_transform(index, transforms[index])
		var instance := MultiMeshInstance3D.new()
		instance.name = key.replace(":", "_")
		instance.multimesh = mesh_batch
		# The headless renderer cannot read MultiMesh buffers back. Preserve authored
		# matrices for independent geometry/physics audits only in headless verification.
		if DisplayServer.get_name() == "headless":
			instance.set_meta("authored_transforms", transforms)
		instance.material_override = materials[key.get_slice(":", 1)]
		owner_node.add_child(instance)
	batches.clear()

func bake_static_illumination(extra_lamps: Array[Vector3]) -> void:
	# A small, deterministic three-height irradiance bake for this procedural kit.
	# It is deliberately indirect only: the directional light owns combat shadows.
	var lamp_sources: Array[Vector3] = lamp_positions.duplicate()
	lamp_sources.append_array(extra_lamps)
	var images: Array[Image] = []
	var resolution := 96
	for floor_y: float in [-5.0, 0.0, 6.5]:
		var image := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
		for y in resolution:
			for x in resolution:
				var position := Vector3((x + 0.5) * 144.0 / resolution - 72.0, floor_y + 0.5, (y + 0.5) * 132.0 / resolution - 66.0)
				var irradiance := 0.0
				for lamp_position: Vector3 in lamp_sources:
					# Keep underground lighting on its own level; streets cannot light tunnels.
					if (floor_y < -2.0) != (lamp_position.y < -1.0):
						continue
					var squared_distance := position.distance_squared_to(lamp_position)
					if squared_distance < 169.0:
						irradiance += pow(maxf(0.0, 1.0 - sqrt(squared_distance) / 13.0), 2.0) * 0.85
				image.set_pixel(x, y, Color(minf(irradiance, 1.0), minf(irradiance * 0.63, 1.0), minf(irradiance * 0.30, 1.0)))
		images.append(image)
	var baked_texture := Texture2DArray.new()
	baked_texture.create_from_images(images)
	var shader: Shader = load("res://scripts/city/city_surface.gdshader")
	for key: String in ["ivory", "cream", "trim", "stone_dark", "slate", "brick", "rose", "blue", "asphalt", "paving", "paving_light", "warm_wash"]:
		var original: StandardMaterial3D = materials[key]
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("base_color", original.albedo_color)
		material.set_shader_parameter("surface_roughness", original.roughness)
		material.set_shader_parameter("surface_metallic", original.metallic)
		material.set_shader_parameter("masonry_strength", 0.24 if key in ["ivory", "cream", "stone_dark", "brick", "rose", "blue"] else 0.10)
		material.set_shader_parameter("wet_paving", 0.38 if key in ["asphalt", "paving", "paving_light"] else 0.0)
		material.set_shader_parameter("static_irradiance", baked_texture)
		materials[key] = material
	for visual: MeshInstance3D in custom_surfaces:
		visual.material_override = materials[visual.get_meta("material_key")]
