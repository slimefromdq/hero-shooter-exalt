class_name TempleBuilder
extends Node3D
## Broad collision-authored terraces and separate screened circulation over real voids.
var definition: TempleMapDefinition
var architecture: MeridianArchitecture
var navigation_region: NavigationRegion3D
var spawn_gates: Array[MuseumSpawnDoor] = []
var routes: Array[Dictionary] = []
var audit: Array[Dictionary] = []
var point_labels: Array[Label3D] = []
var bake_started: int = 0
var bake_milliseconds: int = 0
var floor_triangles: Array[Vector3] = []

func _ready() -> void:
	architecture = MeridianArchitecture.new(self)
	architecture.collision_body.remove_from_group("meridian_navigation_geometry")
	architecture.collision_body.add_to_group("temple_navigation_geometry")
	for entry: Array in [["stone","b5b4a1"],["dark_stone","5c7374"],["timber","493e43"],["tile","294c54"],["moss","5e8261"],["blossom","ecacc4"],["blossom_light","f6d7de"],["gold","cfb67c"],["water","8fcbd2"]]:
		architecture.mat(entry[0],Color(entry[1]))
	_environment()
	for index: int in 5: _court(index)
	routes = definition.connections()
	# Additional exits and screened cross-connections are real, walkable geometry.
	var branches: Array[Dictionary] = [
		{"sector":0,"kind":"lower_exit","width":16.0,"points":[Vector3(76,-8,130),Vector3(52,8,100),Vector3(52,8,90)]},
		{"sector":0,"kind":"upper_exit","width":16.0,"points":[Vector3(-20,20,48),Vector3(-20,20,80),Vector3(124,26,80),Vector3(124,8,128),Vector3(52,8,90)]},
		{"sector":1,"kind":"lower_exit","width":16.0,"points":[Vector3(148,-4,24),Vector3(96,8,24),Vector3(64,16,24),Vector3(64,16,-24),Vector3(28,16,0)]},
		{"sector":1,"kind":"upper_exit","width":16.0,"points":[Vector3(-72,32,8),Vector3(-96,24,-64),Vector3(-96,24,0),Vector3(-64,24,0),Vector3(-28,16,0)]},
		{"sector":1,"kind":"crossover","width":16.0,"points":[Vector3(92,8,90),Vector3(112,8,90),Vector3(112,8,46),Vector3(84,8,46),Vector3(84,8,62)]},
		{"sector":1,"kind":"crossover","width":16.0,"points":[Vector3(-8,20,56),Vector3(-20,20,48)]}
	]
	for sign_value: float in [1,-1]:
		for entry: Dictionary in branches:
			var copy: Dictionary = entry.duplicate(true)
			copy.points = []
			for at: Vector3 in entry.points: copy.points.append(TempleMapDefinition.mirror(at,sign_value))
			if sign_value < 0: copy.sector = 3-entry.sector
			routes.append(copy)
	for entry: Dictionary in routes:
		var apron: float = 10
		if entry.kind == "main" and entry.sector in [1,2]: apron = 18
		if entry.kind == "upper" and entry.sector in [0,3]: apron = 14
		entry.points = _sample(entry.points,apron)
	for entry: Dictionary in routes: _route(entry)
	_spawn_aprons()
	_finish_floors()
	for entry: Dictionary in routes:
		var path: Array[Vector3] = []
		for at: Vector3 in entry.points: path.append(at)
		_corridor_edges(path,entry.width,entry.kind != "main",entry.kind.begins_with("lower"))
	_spawns()
	_recovery_shelves()
	_scenery()
	architecture.flush()
	_navigation()

func _environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color("6e9aa8")
	material.sky_horizon_color = Color("edcfca")
	material.ground_bottom_color = Color("344f60")
	material.ground_horizon_color = Color("c3c6c3")
	sky.sky_material = material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d4e3e3")
	environment.ambient_light_energy = .65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("bdced2")
	environment.fog_density = .00035
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34,-35,0)
	sun.light_color = Color("ffe0c5")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220
	add_child(sun)

func solid(at: Vector3, size: Vector3, key: String = "stone", rotation: Vector3 = Vector3.ZERO) -> void:
	architecture.box(size,at,key,true,rotation)

func _court(index: int) -> void:
	var at: Vector3 = definition.POINTS[index]
	solid(at-Vector3.UP*.8,Vector3(72,1.6,64))
	# Substantial isolated mesas support courts; connecting spans cross actual void.
	for x: float in [-30,30]:
		for z: float in [-26,26]: architecture.cylinder(2,40,at+Vector3(x,-21,z),"dark_stone",true)
	_rock_foundation(at,index)
	for x: float in [-20,20]: architecture.line(at+Vector3(x,.04,-18),at+Vector3(x,.04,18),.18,"gold")
	for z: float in [-18,18]: architecture.line(at+Vector3(-20,.04,z),at+Vector3(20,.04,z),.18,"gold")
	var pavilion_offsets: Array[Vector3] = [Vector3(-24,0,24),Vector3(24,0,-24)]
	if index in [1,3]: pavilion_offsets = [Vector3(-24,0,-24),Vector3(24,0,-24)]
	if index == 2: pavilion_offsets = [Vector3(-24,0,24),Vector3(24,0,-24)]
	if index >= 3:
		for item: int in pavilion_offsets.size(): pavilion_offsets[item] = TempleMapDefinition.mirror(pavilion_offsets[item],-1)
	for offset: Vector3 in pavilion_offsets:
		# Large masses occlude exits; both sides have at least 16 m of open court.
		_pavilion(at+offset,Vector2(9,12),8)
	var cover_offsets: Array[Vector3] = [Vector3(-9,0,7),Vector3(9,0,-7)]
	if index == 2: cover_offsets = [Vector3(-9,0,0),Vector3(9,0,0)]
	for offset: Vector3 in cover_offsets:
		var depth: float = 12 if index == 2 else 3
		solid(at+offset+Vector3.UP*1.3,Vector3(5,2.6,depth),"dark_stone")
		architecture.piece("box",Vector3(5.2,.16,depth+.2),at+offset+Vector3.UP*2.68,"moss")
	var cherry_offsets: Array[Vector3] = [Vector3(-36,0,24),Vector3(36,0,-24)]
	if index == 1: cherry_offsets = [Vector3(-24,0,-36),Vector3(24,0,-36)]
	if index == 3: cherry_offsets = [Vector3(24,0,36),Vector3(-24,0,36)]
	for offset: Vector3 in cherry_offsets:
		solid(at+offset-Vector3.UP*.4,Vector3(12,.8,12),"stone")
		_cherry(at+offset,index)
	var label: Label3D = architecture.label(definition.TITLES[index],at+Vector3(0,6,0),70,Color("ffe3b0"))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	point_labels.append(label)
	# A temple portal frames each point, above clear movement rather than on it.
	_portal(at+Vector3(0,0,25),28)
	_portal(at+Vector3(0,0,-25),28)
	audit.append({"element":"court","point":index,"center":at,"size":Vector2(72,64),"sightline":"offset solid pavilions split flank exits","movement":"broad loop around two low cover groups","cover":"solid pavilions and stone plinths"})

func _pavilion(at: Vector3, footprint: Vector2, height: float) -> void:
	solid(at+Vector3.UP*height/2,Vector3(footprint.x,height,footprint.y),"timber")
	_roof(at+Vector3.UP*height,footprint+Vector2(3,3))
	for y: float in [1,height-1]:
		architecture.piece("box",Vector3(footprint.x+.1,.2,footprint.y+.1),at+Vector3.UP*y,"gold")
	audit.append({"element":"pavilion","center":at,"sightline":"solid mass splits court sightlines","movement":"outer positions leave the objective and its approaches open","cover":"full-height stone and timber, with traversable roof"})

func _roof(at: Vector3, footprint: Vector2) -> void:
	# Colliding shallow slopes permit roof traversal; eave trim is cosmetic only.
	for sign_value: float in [-1,1]:
		var size := Vector3(footprint.x/2+.7,.4,footprint.y)
		solid(at+Vector3(sign_value*footprint.x/4,1.2,0),size,"tile",Vector3(0,0,-sign_value*.17))
	architecture.piece("box",Vector3(.5,.6,footprint.y+1),at+Vector3(0,2.4,0),"gold")
	# Tile ribs and stepped eaves are visual details outside the collision surface.
	for z: float in range(-int(footprint.y/2),int(footprint.y/2)+1,2):
		for side: float in [-1,1]:
			architecture.piece("box",Vector3(footprint.x/2+.8,.08,.09),at+Vector3(side*footprint.x/4,1.43,z),"dark_stone",Vector3(0,0,-side*.17))
	audit.append({"element":"roof","center":at,"sightline":"ridge and eaves define an exposed perch","movement":"shallow colliding slopes; tile ribs have no snagging collision","cover":"solid roof blocks shots from below"})

func _rock_foundation(at: Vector3, seed_value: int) -> void:
	var vertices := PackedVector3Array()
	for level: int in 2:
		for index: int in 8:
			var angle: float = index*TAU/8
			var radius: float = (1 if level == 0 else .52)*(1+sin(index*2.4+seed_value)*.08)
			vertices.append(Vector3(cos(angle)*31*radius,-2 if level == 0 else -35,sin(angle)*27*radius))
	vertices.append(Vector3(4,-64,3))
	var faces := PackedInt32Array()
	for index: int in 8:
		var next: int = (index+1)%8
		faces.append_array(PackedInt32Array([index,next,index+8,next,next+8,index+8,index+8,next+8,16]))
	architecture.polyhedron(vertices,faces,at,"dark_stone",true)
	# A visible waterfall spills down the rock face, beyond the traversal floor.
	var waterfall := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(4,45)
	waterfall.mesh = mesh
	waterfall.position = at+Vector3(25,-25,18)
	waterfall.rotation.y = .7
	var water := ShaderMaterial.new()
	water.shader = preload("res://shaders/temple_water.gdshader")
	waterfall.material_override = water
	waterfall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(waterfall)
	audit.append({"element":"rock_foundation","center":at,"sightline":"cliff silhouette makes the playable terrace edge legible","movement":"foundation stays below the court; bridges cross open voids","cover":"solid rock below, cosmetic waterfall outside circulation"})

func _portal(at: Vector3, width: float, yaw: float = 0) -> void:
	var basis := Basis(Vector3.UP,yaw)
	for x: float in [-width/2-1,width/2+1]:
		if not routes.is_empty() and _crossing_at(at+basis*Vector3(x,0,0),true): return
	for x: float in [-width/2-1,width/2+1]: solid(at+basis*Vector3(x,5,0),Vector3(1.4,10,1.4),"timber",Vector3(0,yaw,0))
	solid(at+Vector3.UP*9.5,Vector3(width+6,1,1.6),"timber",Vector3(0,yaw,0))
	architecture.piece("box",Vector3(width+8,.5,2.5),at+Vector3.UP*10.3,"tile",Vector3(0,yaw,0))
	architecture.piece("sphere",Vector3(2,2.5,2),at+Vector3.UP*7,"gold")
	audit.append({"element":"portal","center":at,"sightline":"frames an entrance without screening its center","movement":"posts sit outside route clearance; ten-meter overhead opening","cover":"posts provide limited edge cover"})

func _cherry(at: Vector3, seed_value: int) -> void:
	architecture.cylinder(.65,7,at+Vector3.UP*3.5,"timber",true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 721+seed_value
	for index: int in 14:
		var offset := Vector3(rng.randf_range(-4,4),rng.randf_range(7,10),rng.randf_range(-4,4))
		architecture.line(at+Vector3.UP*4,at+offset,.25,"timber")
		architecture.piece("sphere",Vector3(5,2.8,4.5),at+offset,"blossom" if index%3 else "blossom_light")
	audit.append({"element":"cherry","center":at,"sightline":"canopy remains overhead, never the sole concealment","movement":"trunk is outside the primary circulation; branches are cosmetic","cover":"solid trunk offers only narrow incidental cover"})

func _route(entry: Dictionary) -> void:
	var points: Array = entry.points
	var width: float = entry.width
	var main: bool = entry.kind == "main"
	var sampled: Array[Vector3] = []
	for at: Vector3 in points: sampled.append(at)
	# An extra meter of paving under either wall supports diagonal landings.
	entry["face_begin"] = floor_triangles.size()/3
	_ribbon(sampled,width+2,"stone" if main else "dark_stone")
	entry["face_end"] = floor_triangles.size()/3
	# Broad turn chambers preserve turning radius; end chambers are open reveals.
	for index: int in points.size():
		var at: Vector3 = points[index]
		# The continuous ribbon and flat aprons supply the turning chambers.
		if main and index == points.size()/2:
			# Bridge cover is recessed outside the 28 m clear deck.
			var tangent: Vector3 = (points[index+1]-at)*Vector3(1,0,1)
			var side: Vector3 = tangent.normalized().cross(Vector3.UP)
			for sign_value: float in [-1,1]:
				var cover: Vector3 = at+side*sign_value*(width/2+3)
				if _crossing_at(cover,true): continue
				solid(cover-Vector3.UP*.4,Vector3(8,.8,12),"stone")
				solid(cover+Vector3.UP*1.8,Vector3(3,3.6,5),"dark_stone")
			_portal(at,width,atan2(tangent.x,tangent.z))
	audit.append({"element":entry.kind,"sector":entry.sector,"width":width,"points":points,"sightline":"solid sidewalls and bends screen transit; open endpoint reveals","movement":"continuous ramps, generous turning chambers, bidirectional retreat","cover":"sidewall shoulders; bridge bays outside clear deck"})

func _ribbon(points: Array[Vector3], width: float, key: String) -> void:
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for index: int in points.size():
		var incoming: Vector3 = points[index]-points[maxi(0,index-1)]
		var outgoing: Vector3 = points[mini(points.size()-1,index+1)]-points[index]
		incoming.y = 0
		outgoing.y = 0
		if incoming.is_zero_approx(): incoming = outgoing
		if outgoing.is_zero_approx(): outgoing = incoming
		var normal: Vector3 = incoming.normalized().cross(Vector3.UP)
		var bisector: Vector3 = (normal+outgoing.normalized().cross(Vector3.UP)).normalized()
		var half: float = width/2
		if absf(points[index].x) >= 147.9: half = maxf(half,12)
		if absf(points[index].z) >= 129.9: half = maxf(half,14)
		var miter: Vector3 = bisector*half/maxf(.65,bisector.dot(normal))
		left.append(points[index]-miter)
		right.append(points[index]+miter)
	for index: int in range(1,points.size()):
		for vertex: Vector3 in [left[index],right[index-1],left[index-1],left[index],right[index],right[index-1]]:
			floor_triangles.append(vertex)

func _inside_court(at: Vector3, margin: float = 0) -> bool:
	for center: Vector3 in definition.POINTS:
		if absf(at.x-center.x) < 36+margin and absf(at.z-center.z) < 32+margin: return true
	return false

func _corridor_edges(points: Array[Vector3], width: float, screened: bool, roofed: bool) -> void:
	for index: int in range(1,points.size()):
		var a: Vector3 = points[index-1]
		var b: Vector3 = points[index]
		var center: Vector3 = (a+b)/2
		# Court arrivals reveal attackers. Never drag transit walls through courts.
		if _inside_court(center,2): continue
		var flat: Vector3 = (b-a)*Vector3(1,0,1)
		var side: Vector3 = flat.normalized().cross(Vector3.UP)
		var rotation: Vector3 = (Basis(Vector3.UP,atan2(flat.x,flat.z))*Basis(Vector3.RIGHT,-atan2(b.y-a.y,flat.length()))).get_euler()
		var half: float = width/2
		if absf(center.x) > 147: half = maxf(half,12)
		if absf(center.z) > 129: half = maxf(half,14)
		for sign_value: float in [-1,1]:
			if screened:
				var foot: Vector3 = center+side*sign_value*(half+.6)
				if not _crossing_at(foot,true): solid(foot+Vector3.UP*3.5,Vector3(1.2,7,a.distance_to(b)+.2),"timber" if roofed else "dark_stone",rotation)
			elif index%5 == 0:
				var foot: Vector3 = center+side*sign_value*(half+.5)
				if not _crossing_at(foot): solid(foot+Vector3.UP*.55,Vector3(1,1.1,3),"dark_stone",rotation)
		if roofed and not _crossing_at(center+Vector3.UP*8,false,half+2): solid(center+Vector3.UP*8,Vector3(half*2+2,.5,a.distance_to(b)+.2),"timber",rotation)

func _crossing_at(at: Vector3, wall: bool = false, margin: float = .2) -> bool:
	for entry: Dictionary in routes:
		var points: Array = entry.points
		for index: int in range(1,points.size()):
			var a: Vector3 = points[index-1]
			var b: Vector3 = points[index]
			if absf(at.x-a.x) > entry.width+4 or absf(at.z-a.z) > entry.width+4: continue
			var flat := Vector2(b.x-a.x,b.z-a.z)
			var fraction: float = clampf(Vector2(at.x-a.x,at.z-a.z).dot(flat)/maxf(.001,flat.length_squared()),0,1)
			var nearest: Vector3 = a.lerp(b,fraction)
			var difference: float = nearest.y-at.y
			var intersects_height: bool = difference > -2.3 and difference < 9 if wall else absf(difference) < 3.5
			if Vector2(at.x-nearest.x,at.z-nearest.z).length() < entry.width/2+margin and intersects_height: return true
	return false

func _span(a: Vector3, b: Vector3, width: float, key: String, screened: bool, roofed: bool, draw_floor: bool = true) -> void:
	var flat: Vector3 = (b-a)*Vector3(1,0,1)
	var length: float = flat.length()
	if length < .1: return
	var yaw: float = atan2(flat.x,flat.z)
	var pitch: float = -atan2(b.y-a.y,length)
	var basis := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)
	var rotation: Vector3 = basis.get_euler()
	if draw_floor: solid((a+b)/2-Vector3.UP*.25,Vector3(width,.5,a.distance_to(b)+.5),key,rotation)
	var side: Vector3 = flat.normalized().cross(Vector3.UP)
	if screened:
		var height: float = 7 if roofed else 5
		# Shorten walls at turns to leave broad chambers and cross-connections open.
		for sign_value: float in [-1,1]:
			var center: Vector3 = (a+b)/2+side*sign_value*(width/2+.6)+Vector3.UP*height/2
			solid(center,Vector3(1.2,height,maxf(1,a.distance_to(b)-16)),"timber" if roofed else "dark_stone",rotation)
		if roofed: solid((a+b)/2+Vector3.UP*8,Vector3(width+2,.6,a.distance_to(b)),"timber",rotation)

func _sample(points: Array, apron: float = 10) -> Array[Vector3]:
	var sampled: Array[Vector3] = []
	for index: int in range(1,points.size()):
		var steps: int = maxi(1,ceili(Vector3(points[index-1]).distance_to(points[index])/3))
		var a: Vector3 = points[index-1]
		var b: Vector3 = points[index]
		var length: float = Vector2(b.x-a.x,b.z-a.z).length()
		var stations: Array[float] = []
		for step: int in steps: stations.append(float(step)/steps)
		if length > apron*2:
			stations.append(apron/length)
			stations.append(1-apron/length)
		stations.sort()
		var previous: float = -1
		for t: float in stations:
			if t-previous < .00001: continue
			previous = t
			var at: Vector3 = a.lerp(b,t)
			# Shared junctions have a full-width flat apron before each incline.
			var rise_t: float = clampf((t*length-apron)/maxf(.1,length-apron*2),0,1)
			at.y = lerpf(a.y,b.y,rise_t)
			sampled.append(definition.surface_position(at))
	sampled.append(definition.surface_position(points[-1]))
	return sampled

func _finish_floors() -> void:
	# Every route is a continuous, mitered ribbon. Keep the authored elevations:
	# separate storeys must never be collapsed into a shared height field.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array(floor_triangles)
	for vertex: Vector3 in faces: surface.add_vertex(vertex)
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	var paving := ShaderMaterial.new()
	paving.shader = preload("res://shaders/temple_paving.gdshader")
	instance.material_override = paving
	add_child(instance)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	architecture.collision_body.add_child(collision)

func floor_position(at: Vector3) -> Vector3:
	var closest: float = INF
	var result: Vector3 = at
	for index: int in range(0,floor_triangles.size(),3):
		var a: Vector3 = floor_triangles[index]
		var b: Vector3 = floor_triangles[index+1]
		var c: Vector3 = floor_triangles[index+2]
		var ab := Vector2(b.x-a.x,b.z-a.z)
		var ac := Vector2(c.x-a.x,c.z-a.z)
		var determinant: float = ab.cross(ac)
		if absf(determinant) < .0001: continue
		var offset := Vector2(at.x-a.x,at.z-a.z)
		var u: float = offset.cross(ac)/determinant
		var v: float = ab.cross(offset)/determinant
		if u < -.001 or v < -.001 or u+v > 1.001: continue
		var height: float = a.y+u*(b.y-a.y)+v*(c.y-a.y)
		if absf(height-at.y) < closest:
			closest = absf(height-at.y)
			result.y = height
	return result

func _recovery_shelves() -> void:
	for sign_value: float in [1,-1]:
		for authored: Vector3 in [Vector3(2,-12,104),Vector3(54,0,24)]:
			var at: Vector3 = TempleMapDefinition.mirror(authored,sign_value)
			solid(at-Vector3.UP*.4,Vector3(14,.8,12),"moss")
			var height: float = 11 if authored.y < 0 else 7
			for side: float in [-1,1]:
				solid(at+Vector3(side*6.5,height/2,0),Vector3(1,height,10),"dark_stone")
			audit.append({"element":"recovery_shelf","center":at,"sightline":"exposed lower landing under bridge","movement":"alternating wall kicks and a mantle lip return to bridge","cover":"solid retaining walls"})

func _spawns() -> void:
	for team: int in 2:
		var sign_value: float = 1 if team == 0 else -1
		for stage: int in 3:
			var center: Vector3 = definition.room_center(team,stage)
			solid(center-Vector3.UP*.4,Vector3(26,.8,16))
			solid(center+Vector3(0,3,sign_value*8),Vector3(26,6,1),"timber")
			for x: float in [-13,13]: solid(center+Vector3(x,3,0),Vector3(1,6,16),"timber")
			solid(center+Vector3(0,3,-sign_value*8),Vector3(2,6,1),"timber")
			_roof(center+Vector3.UP*6,Vector2(28,18))
			audit.append({"element":"spawn","team":team,"stage":stage,"center":center,"sightline":"solid walls and team shutters screen the room","movement":"two wide exits join a continuous apron","cover":"active room heals and protects its team"})
			for x: float in [-6.5,6.5]:
				var door := MuseumSpawnDoor.new()
				door.team = team
				door.stage = stage
				door.width = 11
				door.position = center+Vector3(x,0,-sign_value*8)
				add_child(door)
				spawn_gates.append(door)

func _spawn_aprons() -> void:
	for team: int in 2:
		var sign_value: float = 1 if team == 0 else -1
		for stage: int in 3:
			var center: Vector3 = definition.room_center(team,stage)
			var end: Vector3 = [definition.POINTS[0]+Vector3(-28,0,8),definition.POINTS[1]+Vector3(28,0,-8),definition.POINTS[2]+Vector3(0,0,28)][stage]
			end = TempleMapDefinition.mirror(end,sign_value)
			var exit: Vector3 = center+Vector3(0,0,-sign_value*12)
			_ribbon([center,exit,end],26,"stone")

func _scenery() -> void:
	# Scenery is deliberately outside the navigation source and never disguises voids.
	for sign_value: float in [1,-1]:
		for at: Vector3 in [Vector3(-128,-35,112),Vector3(120,-40,108),Vector3(156,-40,0),Vector3(-80,-38,28)]:
			var center: Vector3 = TempleMapDefinition.mirror(at,sign_value)
			architecture.piece("cone",Vector3(30,65,30),center,"dark_stone")
			architecture.piece("box",Vector3(3,45,1),center+Vector3(5,-8,8),"water")
		for index: int in 9:
			var at := Vector3(sign_value*(180+index%3*35),-20+index%4*12,sign_value*(index*48-190))
			architecture.piece("cone",Vector3(100,130+index%3*30,100),at,"dark_stone")
			architecture.piece("cone",Vector3(34,42,34),at+Vector3.UP*(58+index%3*15),"stone")
		# Optional wall-kick / mantle chain, away from the ordinary main route.
		var origin: Vector3 = TempleMapDefinition.mirror(Vector3(-100,0,96),sign_value)
		solid(origin+Vector3(0,-.4,4*sign_value),Vector3(20,.8,24),"stone")
		_span(TempleMapDefinition.mirror(Vector3(-80,0,96),sign_value),origin,16,"stone",false,false)
		for index: int in 4:
			var at: Vector3 = origin+Vector3(sign_value*(index%2*5-2.5),0,sign_value*index*4)
			solid(at+Vector3.UP*(.8+index),Vector3(3,1.6+index*2,3),"moss")
			audit.append({"element":"mantle_shortcut","center":at,"sightline":"exposed between solid stepping plinths","movement":"2 m rise within mantle reach; ordinary bypass alongside","cover":"low stone blocks"})

func update_gates(stages: Array[int], preparation: bool) -> void:
	for door: MuseumSpawnDoor in spawn_gates:
		door.configure(door.stage == stages[door.team],preparation)

func _navigation() -> void:
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "TempleNavigation"
	var nav := NavigationMesh.new()
	nav.cell_size = .4
	nav.cell_height = .25
	nav.agent_radius = .8
	nav.agent_height = 2
	nav.agent_max_climb = .5
	nav.agent_max_slope = 49
	nav.region_min_size = 1
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav.geometry_source_group_name = &"temple_navigation_geometry"
	nav.filter_baking_aabb = AABB(Vector3(-162,-40,-146),Vector3(324,88,292))
	navigation_region.navigation_mesh = nav
	add_child(navigation_region)
	navigation_region.bake_finished.connect(func() -> void: bake_milliseconds = Time.get_ticks_msec()-bake_started)
	call_deferred("_bake")

func _bake() -> void:
	await get_tree().physics_frame
	bake_started = Time.get_ticks_msec()
	var nav: NavigationMesh = navigation_region.navigation_mesh
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav,source,self)
	# Explicit volumes keep paths out of solid temple masses when overlapping
	# terrace surfaces share a voxel. Inflate by capsule clearance after carving.
	for child: Node in architecture.collision_body.get_children():
		var collision := child as CollisionShape3D
		var vertices := PackedVector3Array()
		var bottom: float = INF
		var top: float = -INF
		if collision.shape is BoxShape3D:
			var size: Vector3 = collision.shape.size
			if size.y < 1.8: continue
			for corner: Vector3 in [Vector3(-size.x/2-.7,0,-size.z/2-.7),Vector3(size.x/2+.7,0,-size.z/2-.7),Vector3(size.x/2+.7,0,size.z/2+.7),Vector3(-size.x/2-.7,0,size.z/2+.7)]:
				var at: Vector3 = collision.transform*corner
				vertices.append(at)
				bottom = minf(bottom,at.y-size.y/2)
				top = maxf(top,at.y+size.y/2)
		elif collision.shape is CylinderShape3D:
			var cylinder: CylinderShape3D = collision.shape
			if cylinder.height < 1.8: continue
			bottom = collision.position.y-cylinder.height/2
			top = bottom+cylinder.height
			for index: int in 12: vertices.append(collision.position+Vector3(cos(index*TAU/12),0,sin(index*TAU/12))*(cylinder.radius+.7))
		if not vertices.is_empty(): source.add_projected_obstruction(vertices,bottom-.1,top-bottom+.1,true)
	NavigationServer3D.bake_from_source_geometry_data_async(nav,source,func() -> void:
		if not is_instance_valid(navigation_region): return
		navigation_region.navigation_mesh = null
		navigation_region.navigation_mesh = nav
		bake_milliseconds = Time.get_ticks_msec()-bake_started)
