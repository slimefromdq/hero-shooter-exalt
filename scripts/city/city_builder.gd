class_name MeridianCityBuilder
extends Node3D
## Meridian Gardens: authored combat routes wrapped in a batched, inhabited city.

signal navigation_baked

var definition: CityMapDefinition
var navigation_region: NavigationRegion3D
var debug_view: bool = false
var architecture: MeridianArchitecture
var orrery: Node3D
var trains: Array[Node3D] = []
var debug_root: Node3D
var environment: Environment
var _elapsed: float = 0.0

func _ready() -> void:
	name = "MeridianGardensEnvironment"
	architecture = MeridianArchitecture.new(self)
	_build_environment()
	_build_ground_and_subway()
	_build_conservatory()
	_build_gardens()
	_build_districts()
	_build_spawns()
	_build_high_routes()
	_build_viaduct()
	_build_skyline()
	_build_street_details()
	architecture.bake_static_illumination([Vector3(-18, -2, -12), Vector3(18, -2, 12), Vector3(-12, -2, -18), Vector3(12, -2, 18), Vector3(0, -2, -30), Vector3(0, -2, 30)])
	architecture.flush()
	_build_navigation()
	_build_debug()

func _process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(orrery):
		orrery.rotation.y += delta * 0.075
		orrery.get_node("ObliqueOrbit").rotation.z = sin(_elapsed * 0.12) * 0.12 + 0.52
	for i in trains.size():
		var train := trains[i]
		train.position.x = fposmod(_elapsed * (8.0 if i == 0 else -6.5) + i * 93.0 + 130.0, 260.0) - 130.0

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "StormBlueAfternoon"
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("102133")
	sky_material.sky_horizon_color = Color("425e79")
	sky_material.ground_bottom_color = Color("1d2632")
	sky_material.ground_horizon_color = Color("6d7f88")
	sky_material.sky_curve = 0.20
	sky_material.sun_angle_max = 4.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("abc6df")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.glow_enabled = true
	environment.glow_intensity = 0.65
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 1.4
	environment.ssao_enabled = true
	environment.ssao_radius = 1.3
	environment.ssao_intensity = 1.4
	environment.ssr_enabled = true
	environment.ssr_max_steps = 32
	environment.fog_enabled = true
	environment.fog_light_color = Color("526b87")
	environment.fog_light_energy = 0.7
	environment.fog_density = 0.0018
	environment.fog_sky_affect = 0.30
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.0
	environment.volumetric_fog_length = 95.0
	environment.volumetric_fog_albedo = Color("718fa6")
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "AfternoonCloudbreak"
	sun.rotation_degrees = Vector3(-33, -38, 0)
	sun.light_color = Color("ffe0ba")
	sun.light_energy = 0.68
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 145.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.6
	add_child(sun)
	# Four main realtime lamps supplement the baked kit; the sun owns combat shadows.
	for point: Vector3 in [Vector3(-12, 5, 8), Vector3(12, 5, -8), Vector3(-34, 5, 0), Vector3(34, 5, 0)]:
		var light := OmniLight3D.new()
		light.position = point
		light.light_color = Color("ffd0a1")
		light.light_energy = 1.4
		light.omni_range = 14.0
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		add_child(light)
	for point: Vector3 in [Vector3(-40, 0.5, -8), Vector3(34, 0.5, 14), Vector3(-33, 0.5, 32)]:
		var mist := FogVolume.new()
		mist.name = "GardenMist"
		mist.position = point
		mist.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		mist.size = Vector3(17, 2.4, 11)
		var fog := FogMaterial.new()
		fog.albedo = Color("7896aa")
		fog.density = 0.035
		fog.edge_fade = 0.65
		fog.height_falloff = 1.2
		mist.material = fog
		add_child(mist)

func _build_ground_and_subway() -> void:
	# Real holes, not a second floor hidden underneath an unbroken ground slab.
	var x_edges: Array[float] = [-72.0, -21.0, -15.0, -3.0, 3.0, 15.0, 21.0, 72.0]
	var z_edges: Array[float] = [-66.0, -58.0, -38.0, -18.0, 18.0, 38.0, 58.0, 66.0]
	for xi in x_edges.size() - 1:
		for zi in z_edges.size() - 1:
			var x := (x_edges[xi] + x_edges[xi + 1]) * 0.5
			var z := (z_edges[zi] + z_edges[zi + 1]) * 0.5
			var corner_hole := absf(x) > 15.0 and absf(x) < 21.0 and absf(z) > 18.0 and absf(z) < 38.0
			var spawn_hole := absf(x) < 3.0 and absf(z) > 38.0 and absf(z) < 58.0
			if corner_hole or spawn_hole:
				continue
			architecture.box(Vector3(x_edges[xi + 1] - x_edges[xi], 0.7, z_edges[zi + 1] - z_edges[zi]), Vector3(x, -0.35, z), "asphalt", true)
	# Wide park paving and axial streets. Thin dressings never introduce trip edges.
	for xa: Vector2 in [Vector2(-22, -21), Vector2(-21, -15), Vector2(-15, 15), Vector2(15, 21), Vector2(21, 22)]:
		for za: Vector2 in [Vector2(-21, -18), Vector2(-18, 18), Vector2(18, 21)]:
			if absf(xa.x + xa.y) > 30 and absf(xa.x + xa.y) < 43 and absf(za.x + za.y) > 36:
				continue
			architecture.box(Vector3(xa.y - xa.x, 0.035, za.y - za.x), Vector3((xa.x + xa.y) * 0.5, 0.02, (za.x + za.y) * 0.5), "paving_light")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			architecture.box(Vector3(14, 0.035, 16), Vector3(sx * 8.0, 0.025, sz * 43.0), "paving")
			_ramp(Vector3(sx * 18, -5, sz * 18), Vector3(sx * 18, 0, sz * 38), 5.6, "ivory", true)
			_subway_stair_portal(Vector3(sx * 18, 0, sz * 38), sz)
	for sign: float in [-1.0, 1.0]:
		_ramp(Vector3(0, -5, sign * 38), Vector3(0, 0, sign * 58), 5.6, "paving_light", true)
		_subway_corridor(Vector3(0, -5, sign * 28), Vector3(0, -5, sign * 18), 5.9)
		_subway_corridor(Vector3(0, -5, sign * 38), Vector3(0, -5, sign * 28), 5.9)
		_subway_corridor(Vector3(-18, -5, sign * 18), Vector3(18, -5, sign * 18), 6.0, true)
		_subway_corridor(Vector3(sign * 18, -5, -18), Vector3(sign * 18, -5, 18), 6.0)
		# Recesses place the medical pickup behind a short wall, off the throughline.
		architecture.box(Vector3(3.8, 0.25, 3.8), Vector3(0, -5.125, sign * 18), "paving", true)
		architecture.box(Vector3(2.6, 2.6, 0.35), Vector3(-2.5 * sign, -3.7, sign * 21.0), "blue", true)
		architecture.label("LOWER MERIDIAN   /   " + ("CROWN" if sign < 0 else "LANTERN"), Vector3(0, -1.8, sign * 22), 30, Color("b8d3e3"), PI if sign < 0 else 0.0)
		architecture.label("LOWER MERIDIAN   /   " + ("CROWN" if sign < 0 else "LANTERN"), Vector3(0, -1.8, sign * 22 - sign * 0.06), 30, Color("b8d3e3"), PI if sign > 0 else 0.0)
	# Guard perimeter: the city continues visually beyond the actual combat district.
	for sign: float in [-1.0, 1.0]:
		architecture.box(Vector3(0.7, 5.0, 132), Vector3(sign * 72, 2.2, 0), "stone_dark", true)
		architecture.box(Vector3(144, 5.0, 0.7), Vector3(0, 2.2, sign * 66), "stone_dark", true)

func _ramp(low: Vector3, high: Vector3, width: float, material_key: String, steps: bool = false, hollow: bool = false) -> void:
	var run := Vector3(high.x - low.x, 0, high.z - low.z)
	var sideways := Vector3(-run.z, 0, run.x).normalized() * width * 0.5
	var bottom := minf(low.y, high.y) - 0.45
	var points := PackedVector3Array([low - sideways, low + sideways, high - sideways, high + sideways,
		Vector3(low.x, bottom, low.z) - sideways, Vector3(low.x, bottom, low.z) + sideways,
		Vector3(high.x, bottom, high.z) - sideways, Vector3(high.x, bottom, high.z) + sideways])
	if hollow:
		for index in 4:
			points[index + 4] = points[index] - Vector3.UP * 0.35
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var collider := CollisionShape3D.new()
	collider.shape = shape
	architecture.collision_body.add_child(collider)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([points[0], points[2], points[1], points[1], points[2], points[3]])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = architecture.materials[material_key]
	add_child(visual)
	if steps:
		var count := int(ceil(absf(high.y - low.y) / 0.23))
		for i in count:
			var at := low.lerp(high, (float(i) + 0.5) / count)
			# Thin riser stripes suggest stairs over a smooth collision slope.
			var rot := -atan2(run.z, run.x)
			architecture.box(Vector3(width, 0.045, 0.11), at + Vector3(0, 0.025, 0), "trim", false, Vector3(0, rot + PI * 0.5, 0))
	architecture.railing(low - sideways, high - sideways, 1.1, true)
	architecture.railing(low + sideways, high + sideways, 1.1, true)

func _subway_corridor(a: Vector3, b: Vector3, width: float, branch_gap: bool = false) -> void:
	var along := b - a
	var side := Vector3(-along.z, 0, along.x).normalized()
	var angle := -atan2(along.z, along.x)
	architecture.box(Vector3(along.length() + width, 0.35, width), (a + b) * 0.5 - Vector3.UP * 0.175, "paving", true, Vector3(0, angle, 0))
	# Ceiling remains clear at all intersections and is the underside of the street.
	for sign: float in [-1.0, 1.0]:
		var center := (a + b) * 0.5 + side * sign * (width * 0.5 - 0.35)
		# Open corners and branch junctions intentionally have no continuous walls.
		if branch_gap:
			for offset: float in [-8.5, 8.5]:
				architecture.box(Vector3(10.0, 3.0, 0.3), center + Vector3(offset, 1.5, 0), "blue", true, Vector3(0, angle, 0))
				architecture.box(Vector3(10.0, 0.25, 0.33), center + Vector3(offset, 0.7, 0), "trim", false, Vector3(0, angle, 0))
		else:
			architecture.box(Vector3(maxf(0.4, along.length() - 8.0), 3.0, 0.3), center + Vector3.UP * 1.5, "blue", true, Vector3(0, angle, 0))
			architecture.box(Vector3(maxf(0.4, along.length() - 8.0), 0.25, 0.33), center + Vector3.UP * 0.7, "trim", false, Vector3(0, angle, 0))
	var segments := maxi(2, int(along.length() / 8))
	for i in segments + 1:
		var at := a.lerp(b, float(i) / segments)
		architecture.arch(at + Vector3.UP * 2.6, width, 1.4, 0.30, "iron", angle + PI * 0.5, 0.12)
		architecture.box(Vector3(0.4, 0.08, 1.8), at + Vector3.UP * 3.9, "lamp")
		if i % 2 == 0:
			var light := OmniLight3D.new()
			light.position = at + Vector3.UP * 2.8
			light.omni_range = 9
			light.light_energy = 0.8
			light.light_color = Color("d5bfaa")
			add_child(light)

func _subway_stair_portal(at: Vector3, sign_z: float) -> void:
	for sign_x: float in [-1.0, 1.0]:
		architecture.box(Vector3(0.45, 2.6, 0.7), at + Vector3(sign_x * 3.1, 1.3, 0), "ivory", true)
	architecture.box(Vector3(6.7, 0.60, 0.8), at + Vector3.UP * 2.85, "slate")
	architecture.label("M  /  LOWER MERIDIAN", at + Vector3(0, 2.85, sign_z * 0.46), 25, Color("e5c397"), 0.0 if sign_z > 0 else PI)

func _build_conservatory() -> void:
	# Brass floor inlay identifies the actual 20 x 18 capture rectangle.
	for sign: float in [-1.0, 1.0]:
		architecture.box(Vector3(20, 0.035, 0.11), Vector3(0, 0.055, sign * 9), "brass")
		architecture.box(Vector3(0.11, 0.035, 18), Vector3(sign * 10, 0.055, 0), "brass")
	architecture.piece("ring", Vector3(8, 0.15, 8), Vector3(0, 0.065, 0), "brass")
	# Solid central plinth blocks diagonal shooting through the park.
	architecture.cylinder(3.1, 2.35, Vector3(0, 1.175, 0), "stone_dark", true)
	architecture.cylinder(3.25, 0.2, Vector3(0, 2.4, 0), "brass")
	architecture.cylinder(2.3, 0.4, Vector3(0, 2.7, 0), "ivory")
	architecture.cylinder(2.0, 0.12, Vector3(0, 2.97, 0), "cyan")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var corner := Vector3(sx * 13.5, 0, sz * 11.5)
			architecture.box(Vector3(1.3, 6.8, 1.3), corner + Vector3.UP * 3.4, "ivory", true)
			architecture.box(Vector3(1.75, 0.35, 1.75), corner + Vector3.UP * 6.6, "trim")
			architecture.box(Vector3(1.65, 0.35, 1.65), corner + Vector3.UP * 0.2, "stone_dark")
			architecture.lamp(corner + Vector3(sx * 1.3, 0, sz * 1.3), 4.5)
			architecture.planter(Vector3(sx * 8.0, 0, sz * 11.9), Vector3(6, 1.6, 2.4))
			architecture.planter(Vector3(sx * 12.0, 0, sz * 5.8), Vector3(2.2, 1.9, 5.0))
	# Four huge glazed portals keep entrances legible from each approach.
	for sign: float in [-1.0, 1.0]:
		architecture.arch(Vector3(0, 6.4, sign * 11.5), 27, 5.0, 0.55, "brass", 0.0, 0.25)
		architecture.arch(Vector3(sign * 13.5, 6.4, 0), 23, 5.0, 0.55, "brass", PI * 0.5, 0.25)
		architecture.box(Vector3(27.8, 0.4, 0.7), Vector3(0, 6.65, sign * 11.5), "ivory")
		architecture.box(Vector3(0.7, 0.4, 23), Vector3(sign * 13.5, 6.65, 0), "ivory")
		architecture.label("MERIDIAN   CONSERVATORY", Vector3(0, 7.25, sign * 11.85), 45, Color("e8d3a6"), PI if sign < 0 else 0.0)
	# A floating barrel lantern roof: opaque narrow wings frame actors against sky.
	for z: float in [-11.5, -6, 0, 6, 11.5]:
		architecture.arch(Vector3(0, 6.8, z), 27, 5.0, 0.12, "iron", 0.0, 0.12)
	for sign: float in [-1.0, 1.0]:
		architecture.box(Vector3(4.7, 0.2, 23), Vector3(sign * 10.6, 8.2, 0), "glass", false, Vector3(0, 0, sign * 0.45))
		architecture.box(Vector3(0.15, 0.18, 23), Vector3(sign * 7.8, 10.5, 0), "brass")
	architecture.box(Vector3(0.18, 0.2, 24), Vector3(0, 11.8, 0), "brass")
	orrery = Node3D.new()
	orrery.name = "CelestialOrrery"
	orrery.position = Vector3(0, 6.0, 0)
	add_child(orrery)
	var core := MeshInstance3D.new()
	core.mesh = architecture.meshes["sphere"]
	core.scale = Vector3.ONE * 2.0
	core.material_override = architecture.materials["cyan"]
	orrery.add_child(core)
	for index in 3:
		var ring := MeshInstance3D.new()
		ring.name = "ObliqueOrbit" if index == 0 else "Orbit%d" % index
		ring.mesh = architecture.meshes["ring"]
		ring.scale = Vector3.ONE * (3.1 + index * 0.75)
		ring.rotation_degrees = Vector3(index * 48.0 + 22, index * 52.0, 30)
		ring.material_override = architecture.materials["brass"]
		orrery.add_child(ring)
		var moon := MeshInstance3D.new()
		moon.mesh = architecture.meshes["sphere"]
		moon.position = Vector3(cos(index * 2.1) * 3.6, sin(index * 2.1) * 1.8, sin(index * 2.1) * 3.6)
		moon.scale = Vector3.ONE * (0.55 + index * 0.15)
		moon.material_override = architecture.materials["violet"] if index != 1 else architecture.materials["lamp"]
		orrery.add_child(moon)
	# Fountains sit outside the capture bounds and provide substantial flank cover.
	for x: float in [-18.0, 18.0]:
		architecture.cylinder(2.45, 0.8, Vector3(x, 0.4, 0), "ivory", true)
		architecture.cylinder(2.2, 0.06, Vector3(x, 0.83, 0), "water")
		architecture.cylinder(0.45, 2.7, Vector3(x, 1.7, 0), "brass")
		architecture.cylinder(1.2, 0.18, Vector3(x, 2.7, 0), "trim")
		architecture.piece("sphere", Vector3(0.48, 0.48, 0.48), Vector3(x, 3.1, 0), "cyan")

func _build_gardens() -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			architecture.planter(Vector3(sx * 8.5, 0, sz * 18.1), Vector3(6.0, 0.75, 2.3))
			architecture.tree(Vector3(sx * 18.3, 0, sz * 11), 0.85, sx < 0)
			architecture.planter(Vector3(sx * 28.0, 0, sz * 11), Vector3(3.2, 1.35, 5.0))
			architecture.tree(Vector3(sx * 30.0, 0, sz * 17), 1.0, sx < 0)
			architecture.lamp(Vector3(sx * 25.5, 0, sz * 7.5), 4.8)
			architecture.lamp(Vector3(sx * 8.5, 0, sz * 23), 4.8)
	# West garden pavilion, one of the two shared 400 HP destinations.
	architecture.box(Vector3(14, 0.035, 13), Vector3(-34, 0.04, 0), "paving_light")
	for x: float in [-39.0, -29.0]:
		for z: float in [-5.0, 5.0]:
			architecture.cylinder(0.35, 4.5, Vector3(x, 2.25, z), "ivory", true)
			architecture.cylinder(0.55, 0.22, Vector3(x, 4.45, z), "trim")
	architecture.arch(Vector3(-34, 4.5, -5), 10, 2.2, 0.5, "trim")
	architecture.arch(Vector3(-34, 4.5, 5), 10, 2.2, 0.5, "trim")
	architecture.box(Vector3(11.0, 0.4, 11.0), Vector3(-34, 5.3, 0), "slate")
	architecture.box(Vector3(5.0, 2.3, 0.75), Vector3(-34, 1.15, -4.5), "ivory", true)
	architecture.label("GARDEN WALK", Vector3(-34, 4.3, 5.4), 32)
	architecture.planter(Vector3(-42, 0, 8), Vector3(4, 0.8, 6))
	architecture.planter(Vector3(-42, 0, -8), Vector3(4, 0.8, 6))
	for sign: float in [-1.0, 1.0]:
		# Two-metre terraces can be climbed, or reached on ordinary short ramps.
		architecture.box(Vector3(8, 2.0, 7), Vector3(-45, 1, sign * 21), "ivory", true)
		_ramp(Vector3(-45, 0, sign * 33), Vector3(-45, 2, sign * 24.5), 5.0, "paving_light", true)
		architecture.planter(Vector3(-47.5, 2, sign * 21), Vector3(1.6, 0.65, 5.5))
		architecture.lamp(Vector3(-44, 2, sign * 20), 3.5)
		architecture.tree(Vector3(-50, 0, sign * 10), 1.3, true)

func _build_districts() -> void:
	# The four approach interiors shelter small packs without closing the route.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var base := Vector3(sx * 27, 0, sz * 28)
			_arcade(base, sx, sz)
			_apartment(Vector3(sx * 57, 0, sz * 42), Vector3(15, 19 + (1 if sx > 0 else 0) * 5, 16), "rose" if sx > 0 else "blue", 3, true)
			_apartment(Vector3(sx * 56, 0, sz * 15), Vector3(11, 15, 14), "brick" if sx > 0 else "ivory", 3, true)
			_apartment(Vector3(sx * 34, 0, sz * 48), Vector3(13, 16, 8), "rose" if sz > 0 else "blue", 3, true)
	# East shops face a full through arcade. The pack has an opaque streetward back.
	for z: float in [-10.0, 10.0]:
		architecture.box(Vector3(10, 3.9, 1.0), Vector3(38, 1.95, z), "rose", true)
		architecture.box(Vector3(10, 0.3, 2.2), Vector3(38, 4.0, z), "trim")
		architecture.window(Vector3(37, 2.0, z + (0.6 if z < 0 else -0.6)), 3.8, 2.4, PI if z > 0 else 0.0)
	architecture.box(Vector3(0.8, 3.0, 4.5), Vector3(38.2, 1.5, 0), "ivory", true)
	architecture.box(Vector3(14, 0.4, 18), Vector3(36, 4.4, 0), "slate")
	for z: float in [-7.0, 0.0, 7.0]:
		architecture.cylinder(0.32, 4.3, Vector3(30, 2.15, z), "ivory", true)
		architecture.arch(Vector3(30, 3.4, z), 6, 1.2, 0.4, "trim", PI * 0.5, 0.3)
	architecture.label("LANTERN MARKET", Vector3(29.7, 4.2, 0), 30, Color("e4b988"), -PI * 0.5)
	# Two accessible store interiors, useful passages rather than closed facades.
	for sign: float in [-1.0, 1.0]:
		architecture.box(Vector3(6.0, 0.12, 7.0), Vector3(43, 0.06, sign * 9), "paving_light")
		architecture.box(Vector3(0.6, 3.5, 7.0), Vector3(46, 1.75, sign * 9), "rose", true)
		architecture.box(Vector3(6.0, 0.4, 7.0), Vector3(43, 3.7, sign * 9), "slate")
		architecture.box(Vector3(1.0, 1.1, 3.4), Vector3(44, 0.55, sign * 9), "brick", true)
		architecture.box(Vector3(1.1, 0.08, 3.5), Vector3(44, 1.14, sign * 9), "brass")
		architecture.label("ASTRA CAFÉ" if sign > 0 else "MOON & QUILL", Vector3(43, 2.7, sign * 12.6), 25, Color("efd0a0"), 0.0 if sign > 0 else PI)
		for z in 3:
			architecture.box(Vector3(0.5, 0.12, 0.2), Vector3(45.55, 1.7 + z * 0.38, sign * 9), "brass")
	_build_wizard_study()

func _arcade(at: Vector3, sx: float, sz: float) -> void:
	architecture.box(Vector3(10, 0.05, 12), at + Vector3.UP * 0.04, "paving_light")
	# Opaque outer side and open north/south ends make the pack a tactical pocket.
	architecture.box(Vector3(0.7, 4.0, 12), at + Vector3(sx * 5, 2, 0), "ivory" if sx < 0 else "rose", true)
	architecture.box(Vector3(10.7, 0.45, 12.6), at + Vector3.UP * 4.0, "trim")
	architecture.box(Vector3(10.4, 0.35, 12.4), at + Vector3.UP * 4.5, "slate")
	for z: float in [-4.4, 4.4]:
		architecture.cylinder(0.35, 3.7, at + Vector3(-sx * 4.2, 1.85, z), "ivory", true)
		architecture.arch(at + Vector3(0, 3.0, z), 8.8, 1.1, 0.45, "trim", 0.0, 0.35)
		architecture.box(Vector3(1.8, 3.0, 0.45), at + Vector3(sx * 3.7, 1.5, z), "ivory", true)
	architecture.label("BOTANICA" if sx < 0 else "THE LANTERN ROOMS", at + Vector3(0, 3.55, sz * 6.35), 26, Color("edc18b"), PI if sz < 0 else 0.0)
	for z: float in [-3.0, 0.0, 3.0]:
		architecture.window(at + Vector3(sx * 4.6, 2, z), 1.2, 1.6, PI * 0.5 * -sx)
	architecture.planter(at + Vector3(sx * 1.5, 0, -sz * 4.5), Vector3(4, 1.4, 1.2))

func _apartment(at: Vector3, size: Vector3, key: String, floors: int = 4, solid: bool = true) -> void:
	architecture.box(size, at + Vector3.UP * size.y * 0.5, key, solid)
	architecture.box(Vector3(size.x + 0.5, 0.55, size.z + 0.5), at + Vector3.UP * (size.y - 0.4), "trim")
	architecture.box(Vector3(size.x + 0.8, 0.5, size.z + 0.8), at + Vector3.UP * (size.y + 0.15), "slate")
	architecture.box(Vector3(size.x + 0.22, 0.7, size.z + 0.22), at + Vector3.UP * 0.35, "stone_dark")
	# Mansard roof shoulders alternate with the modern flat-roof buildings.
	if key == "ivory" or key == "rose":
		for side: float in [-1.0, 1.0]:
			architecture.box(Vector3(size.x * 0.54, 0.3, size.z + 0.7), at + Vector3(side * size.x * 0.25, size.y + 1.5, 0), "slate", false, Vector3(0, 0, side * -0.38))
		architecture.box(Vector3(0.18, 0.18, size.z + 0.85), at + Vector3.UP * (size.y + 2.5), "brass")
	floors = maxi(floors, int((size.y - 1.5) / 3.25))
	var columns := maxi(2, int(size.x / 3.0))
	for floor_index in floors:
		var y := 2.6 + floor_index * (size.y - 3.7) / floors
		architecture.box(Vector3(size.x + 0.35, 0.13, size.z + 0.35), at + Vector3.UP * (y - 1.3), "trim")
		for column in columns:
			var x := (float(column) + 0.5) * size.x / columns - size.x * 0.5
			for side: float in [-1.0, 1.0]:
				architecture.window(at + Vector3(x, y, side * (size.z * 0.5 + 0.09)), 1.25, 1.7, PI if side < 0 else 0.0, (column + floor_index) % 4 != 1)
				if solid and floor_index % 3 == 1 and column % 2 == 0:
					architecture.box(Vector3(2.1, 0.18, 1.2), at + Vector3(x, y - 1.0, side * (size.z * 0.5 + 0.65)), "trim")
					architecture.railing(at + Vector3(x - 1.0, y - 0.9, side * (size.z * 0.5 + 1.1)), at + Vector3(x + 1.0, y - 0.9, side * (size.z * 0.5 + 1.1)), 0.85, false)
		for side: float in [-1.0, 1.0]:
			for z: float in [-size.z * 0.25, size.z * 0.25]:
				architecture.window(at + Vector3(side * (size.x * 0.5 + 0.09), y, z), 1.25, 1.7, side * PI * 0.5, (floor_index + int(side)) % 3 != 0)
	for side: float in [-1.0, 1.0]:
		architecture.box(Vector3(0.55, size.y, 0.55), at + Vector3(side * (size.x * 0.5 - 0.4), size.y * 0.5, size.z * 0.5 + 0.1), "trim")
		if solid:
			architecture.box(Vector3(size.x * 0.72, 0.2, 1.6), at + Vector3(0, 3.3, side * (size.z * 0.5 + 0.65)), "blue" if key == "rose" else "slate", false, Vector3(side * 0.16, 0, 0))
			for awning_index in 7:
				architecture.box(Vector3(size.x * 0.72 / 14.0, 0.21, 1.6), at + Vector3((awning_index - 3.0) * size.x * 0.72 / 7.0, 3.31, side * (size.z * 0.5 + 0.65)), "trim", false, Vector3(side * 0.16, 0, 0))

func _build_wizard_study() -> void:
	# A low, genuinely accessible study under the scenic wizard spire.
	architecture.box(Vector3(8, 0.4, 11), Vector3(49, 4.0, 28), "ivory", true)
	_ramp(Vector3(49, 0, 12), Vector3(49, 4.2, 22.5), 4.5, "paving_light", true)
	_ramp(Vector3(49, 0, 44), Vector3(49, 4.2, 33.5), 4.5, "paving_light", true)
	architecture.box(Vector3(0.55, 3.3, 11), Vector3(52.7, 5.85, 28), "ivory", true)
	architecture.box(Vector3(8, 0.4, 11.7), Vector3(49, 7.7, 28), "slate")
	for x: float in [45.4, 52.6]:
		for z: float in [23.0, 33.0]:
			architecture.cylinder(0.3, 3.3, Vector3(x, 5.85, z), "ivory", true)
	architecture.box(Vector3(0.8, 2.5, 6), Vector3(51.9, 5.5, 28), "brick", true)
	for shelf in 5:
		architecture.box(Vector3(1.05, 0.09, 5.7), Vector3(51.7, 4.6 + shelf * 0.48, 28), "brass")
		for book in 12:
			architecture.box(Vector3(0.35, 0.32, 0.16), Vector3(51.65, 4.82 + shelf * 0.48, 25.5 + book * 0.44), "blue" if book % 2 == 0 else "rose")
	architecture.cylinder(0.75, 1.1, Vector3(48.5, 4.75, 28), "brass", true)
	architecture.piece("sphere", Vector3(0.65, 0.65, 0.65), Vector3(48.5, 5.7, 28), "violet")
	architecture.railing(Vector3(45, 4.2, 23), Vector3(45, 4.2, 26), 1.1)
	architecture.railing(Vector3(45, 4.2, 30), Vector3(45, 4.2, 33), 1.1)
	architecture.label("THE ASTRONOMER’S STUDY", Vector3(44.7, 7.1, 28), 24, Color("c9b3e6"), -PI * 0.5)
	_wizard_tower(Vector3(57, 0, 28), 26.0, 4.4)

func _wizard_tower(at: Vector3, height: float, radius: float) -> void:
	architecture.cylinder(radius, height, at + Vector3.UP * height * 0.5, "blue", absf(at.x) < 72 and absf(at.z) < 66)
	architecture.cylinder(radius * 1.1, 0.6, at + Vector3.UP * height, "trim")
	architecture.cylinder(radius * 1.08, 0.5, at + Vector3.UP * (height - 5.0), "brass")
	architecture.piece("cone", Vector3(radius * 2.5, height * 0.37, radius * 2.5), at + Vector3.UP * height * 1.185, "slate")
	architecture.piece("sphere", Vector3.ONE * 0.7, at + Vector3.UP * height * 1.38, "violet")
	for index in 8:
		var angle := index * TAU / 8.0
		for y: float in [height * 0.4, height * 0.7, height - 2.0]:
			architecture.window(at + Vector3(sin(angle) * radius, y, cos(angle) * radius), 0.9, 2.5, angle, true)

func _build_spawns() -> void:
	for sign: float in [-1.0, 1.0]:
		var z := sign * 60
		architecture.box(Vector3(9, 0.05, 12), Vector3(-7.5, 0.035, z), "paving_light")
		architecture.box(Vector3(9, 0.05, 12), Vector3(7.5, 0.035, z), "paving_light")
		architecture.box(Vector3(6, 0.05, 8), Vector3(0, 0.035, sign * 62), "paving_light")
		# Two separated front street exits and the central open subway stair.
		architecture.box(Vector3(9.5, 1.9, 0.8), Vector3(0, 3.65, sign * 54), "ivory", true)
		for pier_x: float in [-4.4, 4.4]:
			architecture.box(Vector3(0.7, 2.7, 0.8), Vector3(pier_x, 1.35, sign * 54), "ivory", true)
		for x: float in [-12.0, 12.0]:
			architecture.box(Vector3(0.8, 5.0, 12), Vector3(x, 2.5, z), "ivory", true)
			architecture.box(Vector3(1.8, 5.0, 0.8), Vector3(x * 0.93, 2.5, sign * 54), "ivory", true)
		architecture.box(Vector3(24.6, 0.6, 12.8), Vector3(0, 5.0, z), "slate", true)
		architecture.box(Vector3(24.7, 0.22, 1.0), Vector3(0, 4.5, sign * 53.7), "brass")
		architecture.label("CROWN STATION" if sign < 0 else "LANTERN COURT", Vector3(0, 3.2, sign * 53.5), 39, Color("edcd99"), PI if sign > 0 else 0.0)
		for sx: float in [-1.0, 1.0]:
			architecture.arch(Vector3(sx * 8.0, 2.9, sign * 54), 5.0, 1.4, 0.7, "trim", 0.0, 0.4)
			architecture.lamp(Vector3(sx * 10.8, 0, sign * 51.8), 4.5)
			architecture.planter(Vector3(sx * 9.5, 0, sign * 47), Vector3(3, 2.2, 3))
			_apartment(Vector3(sx * 22, 0, sign * 60), Vector3(12, 14 if sign < 0 else 18, 12), "blue" if sign < 0 else "rose", 3)
			architecture.box(Vector3(3.2, 2.5, 1.2), Vector3(sx * 5.2, 1.25, sign * 39), "ivory", true)
			architecture.box(Vector3(3.4, 0.2, 1.4), Vector3(sx * 5.2, 2.6, sign * 39), "brass")
			architecture.lamp(Vector3(sx * 11, 0, sign * 34), 4.7)

func _build_high_routes() -> void:
	for sx: float in [-1.0, 1.0]:
		# Parallel covered viaduct promenades, with two long approaches apiece.
		architecture.box(Vector3(4.6, 0.45, 42), Vector3(sx * 23, 6.275, 0), "ivory", true)
		for sz: float in [-1.0, 1.0]:
			_ramp(Vector3(sx * 42, 0, sz * 46), Vector3(sx * 42, 6.5, sz * 22.25), 4.5, "ivory", true)
			architecture.box(Vector3(21.5, 0.45, 4.5), Vector3(sx * 33.75, 6.275, sz * 20), "ivory", true)
			architecture.railing(Vector3(sx * 23, 6.5, sz * 22.1), Vector3(sx * 39.5, 6.5, sz * 22.1))
			architecture.railing(Vector3(sx * 25.3, 6.5, sz * 17.9), Vector3(sx * 39.7, 6.5, sz * 17.9))
			architecture.box(Vector3(2.0, 2.2, 1.1), Vector3(sx * 21.8, 7.6, sz * 10), "ivory", true)
			architecture.planter(Vector3(sx * 30, 6.5, sz * 21.5), Vector3(3.0, 0.85, 0.65), true)
			architecture.railing(Vector3(sx * 44.4, 6.5, sz * 17.8), Vector3(sx * 44.4, 6.5, sz * 22.25), 1.1)
			architecture.lamp(Vector3(sx * 40, 6.5, sz * 20), 3.3)
		architecture.railing(Vector3(sx * 25.2, 6.5, -18), Vector3(sx * 25.2, 6.5, 18))
		architecture.railing(Vector3(sx * 20.8, 6.5, -18), Vector3(sx * 20.8, 6.5, -7 if sx > 0 else -3))
		architecture.railing(Vector3(sx * 20.8, 6.5, 7 if sx < 0 else 3), Vector3(sx * 20.8, 6.5, 18))
		# An inner garden stair lets high-ground players rejoin a fight promptly.
		# It also prevents bots taking a 150 m promenade detour to return to the hill.
		_ramp(Vector3(sx * 14, 0, -sx * 21), Vector3(sx * 20.7, 6.5, -sx * 5), 4.2, "ivory", true, true)
		# Opaque central shelter denies a single uninterrupted hill overlook.
		architecture.box(Vector3(0.65, 3.2, 7), Vector3(sx * 20.9, 8.1, 0), "ivory", true)
		architecture.box(Vector3(5.2, 0.3, 42), Vector3(sx * 23, 10.0, 0), "slate")
		for z: float in [-19.0, -12.0, 0.0, 12.0, 19.0]:
			for side: float in [-1.0, 1.0]:
				architecture.cylinder(0.19, 3.5, Vector3(sx * 23 + side * 2.1, 8.25, z), "iron", true)
		for z: float in [-16.0, 0.0, 16.0]:
			architecture.box(Vector3(1.4, 6.3, 1.4), Vector3(sx * 23, 3.15, z), "ivory", true)
		architecture.label("ARCANE PROMENADE", Vector3(sx * 23, 10.7, 0), 29, Color("d3c5df"), sx * PI * 0.5)

func _build_viaduct() -> void:
	# The impossible central 48 m arch is the principal city silhouette.
	var pillar_x := [-96.0, -72.0, -48.0, -29.0, 29.0, 48.0, 72.0, 96.0]
	for x: float in pillar_x:
		architecture.box(Vector3(3.6, 13, 5.6), Vector3(x, 6.5, -13), "ivory", absf(x) < 72)
		architecture.box(Vector3(4.5, 0.6, 6.2), Vector3(x, 12.6, -13), "trim")
		architecture.box(Vector3(4.5, 0.65, 6.4), Vector3(x, 0.35, -13), "stone_dark")
		for offset: float in [-1.2, 1.2]:
			architecture.box(Vector3(0.12, 10.5, 0.14), Vector3(x + offset, 6.3, -9.99), "cyan")
	for i in pillar_x.size() - 1:
		var width: float = pillar_x[i + 1] - pillar_x[i]
		var center_x: float = (pillar_x[i + 1] + pillar_x[i]) * 0.5
		architecture.arch(Vector3(center_x, 12.3, -13), width, 8.0, 5.2, "ivory", 0, 1.15)
		architecture.arch(Vector3(center_x, 12.3, -9.9), width - 1.1, 7.45, 0.16, "cyan", 0, 0.10)
		architecture.arch(Vector3(center_x, 12.3, -16.1), width - 1.1, 7.45, 0.16, "cyan", 0, 0.10)
	architecture.box(Vector3(220, 1.0, 7.2), Vector3(0, 21.4, -13), "ivory")
	architecture.box(Vector3(220, 0.20, 7.8), Vector3(0, 22.0, -13), "trim")
	for z: float in [-16.6, -9.4]:
		architecture.box(Vector3(220, 1.0, 0.25), Vector3(0, 22.5, z), "iron")
		architecture.box(Vector3(220, 0.10, 0.12), Vector3(0, 23.0, z), "cyan")
	for z: float in [-14.3, -11.7]:
		architecture.box(Vector3(250, 0.13, 0.14), Vector3(0, 22.18, z), "brass")
	for index in 2:
		var train := Node3D.new()
		train.name = "ScenicTrain%d" % index
		train.position = Vector3(-65 + index * 130, 23.4, -13)
		add_child(train)
		var train_kit := MeridianArchitecture.new(train)
		for car in 3:
			var x := car * 10.6
			train_kit.box(Vector3(10.0, 2.3, 2.6), Vector3(x, 0.0, 0), "cream")
			train_kit.box(Vector3(10.1, 0.45, 2.7), Vector3(x, -0.95, 0), "slate")
			train_kit.box(Vector3(10.1, 0.14, 2.72), Vector3(x, -0.40, 0), "brass")
			for wx in 5:
				for side: float in [-1.0, 1.0]:
					train_kit.box(Vector3(1.25, 1.15, 0.08), Vector3(x - 3.6 + wx * 1.8, 0.1, side * 1.33), "window")
			train_kit.box(Vector3(1.2, 1.4, 2.0), Vector3(x - 4.5, 0.1, 0), "glass")
		train_kit.flush()
		trains.append(train)

func _build_skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 62194
	for ring_index in 2:
		var distance := 95.0 + ring_index * 43.0
		for i in 24:
			var angle := i * TAU / 24.0 + ring_index * 0.12
			var at := Vector3(sin(angle) * distance * 1.1, 0, cos(angle) * distance)
			var size := Vector3(rng.randf_range(10, 18), rng.randf_range(25, 64) + ring_index * 16, rng.randf_range(10, 18))
			_apartment(at, size, "blue" if i % 3 == 0 else ("ivory" if i % 3 == 1 else "brick"), 7 if ring_index == 0 else 9, false)
			if i % 5 == 0:
				architecture.piece("cone", Vector3(size.x * 1.2, 12, size.z * 1.2), at + Vector3.UP * (size.y + 6), "slate")
			if i % 7 == 0:
				_wizard_tower(at + Vector3(12, 0, 0), size.y * 1.15, 4.5)
	# A distant vertical glass landmark gives the east district its modern identity.
	for x: float in [84.0, 96.0]:
		architecture.box(Vector3(10, 82, 18), Vector3(x, 41, -68), "glass")
		for floor_index in 25:
			architecture.box(Vector3(10.3, 0.13, 18.3), Vector3(x, floor_index * 3.2 + 2, -68), "blue")
		for strip in 4:
			architecture.box(Vector3(0.18, 82, 18.3), Vector3(x - 4.5 + strip * 3, 41, -68), "trim")
	architecture.label("M E R I D I A N", Vector3(90, 85, -58.7), 65, Color("adcede"))

func _build_street_details() -> void:
	for sz: float in [-1.0, 1.0]:
		# 12–18 m rhythm of hard cover prevents spawn-to-objective firing corridors.
		architecture.box(Vector3(4.2, 2.5, 2.0), Vector3(0, 1.25, sz * 29), "ivory", true)
		architecture.box(Vector3(4.5, 0.18, 2.3), Vector3(0, 2.6, sz * 29), "brass")
		architecture.piece("sphere", Vector3(1.4, 1.4, 1.4), Vector3(0, 3.4, sz * 29), "slate")
		for sx: float in [-1.0, 1.0]:
			architecture.box(Vector3(3.8, 2.0, 1.3), Vector3(sx * 10, 1, sz * 23), "ivory", true)
			architecture.box(Vector3(3.8, 0.16, 1.4), Vector3(sx * 10, 2.1, sz * 23), "brass")
			architecture.tree(Vector3(sx * 13, 0, sz * 44), 0.85)
			architecture.lamp(Vector3(sx * 35.5, 0, sz * 38), 4.4)
			# Flush road inlays and crossing marks aid navigation without collision.
			for i in 5:
				architecture.box(Vector3(2, 0.018, 0.38), Vector3(sx * 7.5, 0.05, sz * (42 + i * 0.85)), "trim")
			for z: float in [10.0, 23.0, 40.0]:
				architecture.box(Vector3(0.10, 0.018, 4.5), Vector3(sx * 34, 0.05, sz * z), "brass")
			architecture.box(Vector3(1.7, 1.35, 0.7), Vector3(sx * 37, 0.675, sz * 17), "slate", true)
			architecture.box(Vector3(1.9, 0.14, 0.9), Vector3(sx * 37, 1.4, sz * 17), "trim")
			# Park benches have one simple rounded collision volume, no snagging legs.
			architecture.box(Vector3(3.0, 0.12, 0.85), Vector3(sx * 6.5, 0.65, sz * 15.0), "trunk")
			architecture.box(Vector3(3.0, 0.7, 0.12), Vector3(sx * 6.5, 1.0, sz * 15.4), "trunk")
			architecture.collider_box(Vector3(3.0, 1.3, 1.0), Vector3(sx * 6.5, 0.65, sz * 15.0))
			architecture.box(Vector3(0.15, 0.6, 0.75), Vector3(sx * 6.5 - 1.1, 0.3, sz * 15), "iron")
			architecture.box(Vector3(0.15, 0.6, 0.75), Vector3(sx * 6.5 + 1.1, 0.3, sz * 15), "iron")
	# Canal-like illuminated garden details and plaza paving seams.
	for x: float in [-11.0, -5.5, 5.5, 11.0]:
		architecture.box(Vector3(0.035, 0.018, 36), Vector3(x, 0.045, 0), "stone_dark")
	for z: float in [-18.0, -12.0, -6.0, 6.0, 12.0, 18.0]:
		architecture.box(Vector3(42, 0.018, 0.035), Vector3(0, 0.045, z), "stone_dark")

func _build_navigation() -> void:
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "CityNavigation"
	navigation_region.use_edge_connections = true
	var nav := NavigationMesh.new()
	nav.cell_size = 0.25
	nav.cell_height = 0.25
	nav.agent_height = 2.0
	nav.agent_radius = 0.75
	nav.agent_max_climb = 0.5
	nav.agent_max_slope = 40.0
	nav.region_min_size = 2.0
	nav.region_merge_size = 6.0
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav.geometry_source_group_name = &"meridian_navigation_geometry"
	nav.filter_baking_aabb = AABB(Vector3(-71, -5.4, -65.5), Vector3(142, 15.5, 131))
	nav.filter_walkable_low_height_spans = true
	nav.filter_ledge_spans = true
	nav.filter_low_hanging_obstacles = true
	navigation_region.navigation_mesh = nav
	add_child(navigation_region)
	# Runtime-authored meshes bake once before match time begins; tactical decisions wait.
	navigation_region.bake_finished.connect(_on_navigation_baked)
	call_deferred("_bake_navigation_after_registration")

func _bake_navigation_after_registration() -> void:
	await get_tree().physics_frame
	if is_instance_valid(navigation_region):
		navigation_region.bake_navigation_mesh(true)

func _on_navigation_baked() -> void:
	call_deferred("_synchronize_navigation")

func _synchronize_navigation() -> void:
	if not is_inside_tree():
		return
	NavigationServer3D.map_force_update(get_world_3d().navigation_map)
	navigation_baked.emit()

func _build_debug() -> void:
	debug_root = Node3D.new()
	debug_root.name = "RouteAndResourceOverlay"
	debug_root.visible = debug_view
	add_child(debug_root)
	var kit := MeridianArchitecture.new(debug_root)
	for side: float in [-1.0, 1.0]:
		for x: float in [-8.0, 8.0]:
			for z in range(12, 55, 3):
				kit.box(Vector3(0.16, 0.025, 1.4), Vector3(x, 0.09, side * z), "cyan")
		for x: float in [-34.0, 34.0]:
			for z in range(-42, 43, 3):
				kit.box(Vector3(0.14, 0.025, 1.4), Vector3(x, 0.09, z), "violet")
	kit.label("NORTH  /  CROWN STATION", Vector3(0, 12, -57), 54, Color("9ac7e3"))
	kit.label("SOUTH  /  LANTERN COURT", Vector3(0, 12, 57), 54, Color("e6b9a0"))
	kit.flush()

func set_debug_view(enabled: bool) -> void:
	debug_view = enabled
	if is_instance_valid(debug_root):
		debug_root.visible = enabled
