class_name TempleBuilder
extends Node3D
## Shared floor cells eliminate duplicate coplanar route/court faces.
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
var stair_triangles: Array[Vector3] = []
var underside_triangles: Array[Vector3] = []
var floor_cells: Dictionary = {}
var floor_conflicts: Array[String] = []
var pads: Array[TempleJumpPad] = []
var pad_specs: Array[Dictionary] = []
var walk_routes: Array[Dictionary] = []
var furnished_bounds: Array[AABB] = []
const CELL: float = 2.0

func _ready() -> void:
	architecture = MeridianArchitecture.new(self)
	architecture.collision_body.remove_from_group("meridian_navigation_geometry")
	architecture.collision_body.add_to_group("temple_navigation_geometry")
	for entry: Array in [["stone","b5b4a1"],["dark_stone","5c7374"],["timber","493e43"],["tile","294c54"],["moss","5e8261"],["blossom","ecacc4"],["blossom_light","f6d7de"],["gold","cfb67c"],["water","8fcbd2"]]:
		architecture.mat(entry[0],Color(entry[1]))
	_environment()
	routes = definition.connections()
	pad_specs = definition.jump_pads()
	for i: int in 5: _plate(definition.POINTS[i],Vector2(72,64),"court_%d" % i)
	for entry: Dictionary in routes: _build_route(entry)
	for entry: Dictionary in definition.spawn_routes(): _build_route(entry)
	for team: int in 2:
		for stage: int in 3: _plate(definition.room_center(team,stage),Vector2(28,16),"spawn")
	for bay: Dictionary in definition.rest_bays(): _plate(bay.center,bay.size,"garden_bay")
	for gallery: Dictionary in definition.galleries(): _gallery(gallery)
	for entry: Dictionary in pad_specs:
		_plate(entry.destination,Vector2(8,8),entry.id+"_landing")
	_finish_floors()
	for index: int in 5: _court(index)
	_furnish_routes()
	_spawns()
	_scenery()
	_build_pads()
	architecture.flush()
	_navigation()

func solid(at: Vector3, size: Vector3, key: String = "stone", rotation: Vector3 = Vector3.ZERO) -> void:
	architecture.box(size,at,key,true,rotation)
	furnished_bounds.append(AABB(at-size/2,size))

func _cell(x: int, z: int, heights: Vector4, source: String) -> void:
	var key := Vector2i(x,z)
	if not floor_cells.has(key): floor_cells[key] = []
	for existing: Dictionary in floor_cells[key]:
		var difference: Vector4 = existing.heights-heights
		if difference.abs().length() < .02: return
		var minimum: float = minf(minf(absf(difference.x),absf(difference.y)),minf(absf(difference.z),absf(difference.w)))
		if minimum < 4.8 and source.ends_with("_veranda"): return # The authored ramp owns this doorway cutout.
		if minimum < 4.8:
			floor_conflicts.append("%s / %s at %s" % [existing.source,source,key])
	floor_cells[key].append({"heights":heights,"source":source})

func _plate(at: Vector3, size: Vector2, source: String) -> void:
	for x: int in range(roundi((at.x-size.x/2)/CELL),roundi((at.x+size.x/2)/CELL)):
		for z: int in range(roundi((at.z-size.y/2)/CELL),roundi((at.z+size.y/2)/CELL)):
			_cell(x,z,Vector4.ONE*at.y,source)

func authored_floor(at: Vector3) -> Vector3:
	var key := Vector2i(floori(at.x/CELL),floori(at.z/CELL))
	var nearest: float = INF
	var result: Vector3 = at
	for entry: Dictionary in floor_cells.get(key,[]):
		var h: Vector4 = entry.heights
		var u: float = (at.x-key.x*CELL)/CELL
		var v: float = (at.z-key.y*CELL)/CELL
		var height: float = lerpf(lerpf(h.x,h.y,u),lerpf(h.w,h.z,u),v)
		if absf(height-at.y)<nearest:
			nearest = absf(height-at.y)
			result.y = height
	return result

func ramp_height(a: Vector3, b: Vector3, at: Vector3, width: float) -> float:
	if a.y>b.y: return ramp_height(b,a,at,width) # Identical landings in both travel directions.
	var distance: float = Vector2(b.x-a.x,b.z-a.z).length()
	var along: float = Vector2(at.x-a.x,at.z-a.z).dot(Vector2(b.x-a.x,b.z-a.z).normalized())
	var flights: int = maxi(1,ceili(absf(b.y-a.y)/4))
	var apron: float = width/2
	var total_run: float = distance-2*apron-(flights-1)*2
	var regular_run: float = floorf(total_run/flights/2)*2
	var progress: float = clampf(along-apron,0,distance-2*apron)
	var climbed: float = 0
	for flight: int in flights:
		var run: float = regular_run if flight<flights-1 else total_run-regular_run*(flights-1)
		climbed += clampf(progress,0,run)/run
		progress -= run+2
	return lerpf(a.y,b.y,climbed/flights)

func _build_route(entry: Dictionary) -> void:
	var authored: Array = entry.points.duplicate()
	var sampled: Array[Vector3] = []
	for i: int in range(1,authored.size()):
		var a: Vector3 = authored[i-1]
		var b: Vector3 = authored[i]
		var half: float = entry.width/2
		var low: Vector3 = a.min(b)
		var high: Vector3 = a.max(b)
		var sloped: bool = not is_equal_approx(a.y,b.y)
		if is_equal_approx(a.x,b.x):
			low.x -= half
			high.x += half
		else:
			low.z -= half
			high.z += half
		_plate(a,Vector2(entry.width,entry.width),entry.id)
		_plate(b,Vector2(entry.width,entry.width),entry.id)
		for x: int in range(roundi(low.x/CELL),roundi(high.x/CELL)):
			for z: int in range(roundi(low.z/CELL),roundi(high.z/CELL)):
				var heights := Vector4.ONE*a.y
				if sloped:
					heights = Vector4(ramp_height(a,b,Vector3(x*CELL,0,z*CELL),entry.width),ramp_height(a,b,Vector3((x+1)*CELL,0,z*CELL),entry.width),ramp_height(a,b,Vector3((x+1)*CELL,0,(z+1)*CELL),entry.width),ramp_height(a,b,Vector3(x*CELL,0,(z+1)*CELL),entry.width))
				_cell(x,z,heights,entry.id)
		var steps: int = maxi(1,ceili(a.distance_to(b)/2))
		for j: int in steps:
			var at: Vector3 = a.lerp(b,float(j)/steps)
			if sloped: at.y = ramp_height(a,b,at,entry.width)
			sampled.append(at)
		audit.append({"element":"stairs" if sloped else "passage","source":entry.id,"from":a,"to":b,"width":entry.width})
	sampled.append(authored[-1])
	entry["authored"] = authored
	entry.points = sampled
	walk_routes.append(entry)

func _finish_floors() -> void:
	for cell: Vector2i in floor_cells:
		for entry: Dictionary in floor_cells[cell]:
			var h: Vector4 = entry.heights
			var a := Vector3(cell.x*CELL,h.x,cell.y*CELL)
			var b := Vector3((cell.x+1)*CELL,h.y,cell.y*CELL)
			var c := Vector3((cell.x+1)*CELL,h.z,(cell.y+1)*CELL)
			var d := Vector3(cell.x*CELL,h.w,(cell.y+1)*CELL)
			floor_triangles.append_array([a,b,c,a,c,d])
	# Closed deck undersides prevent looking through an upper floor from a hall.
	for index: int in range(0,floor_triangles.size(),3):
		for offset: int in [0,2,1]: underside_triangles.append(floor_triangles[index+offset]-Vector3.UP*.35)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex: Vector3 in floor_triangles+underside_triangles: surface.add_vertex(vertex)
	surface.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	var paving := ShaderMaterial.new()
	paving.shader = preload("res://shaders/temple_paving.gdshader")
	instance.material_override = paving
	add_child(instance)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(PackedVector3Array(floor_triangles+underside_triangles+stair_triangles))
	shape.backface_collision = true
	var collision := CollisionShape3D.new()
	collision.shape = shape
	architecture.collision_body.add_child(collision)
	# Closed skirts at exposed deck boundaries; no duplicate internal seams.
	for cell: Vector2i in floor_cells:
		for entry: Dictionary in floor_cells[cell]:
			var h: Vector4 = entry.heights
			var corners: Array[Vector3] = [Vector3(cell.x*CELL,h.x,cell.y*CELL),Vector3((cell.x+1)*CELL,h.y,cell.y*CELL),Vector3((cell.x+1)*CELL,h.z,(cell.y+1)*CELL),Vector3(cell.x*CELL,h.w,(cell.y+1)*CELL)]
			var neighbors: Array[Vector2i] = [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
			for side: int in 4:
				var a: Vector3 = corners[side]
				var b: Vector3 = corners[(side+1)%4]
				var joined: bool = false
				for other: Dictionary in floor_cells.get(cell+neighbors[side],[]):
					var oh: Vector4 = other.heights
					var pair: Vector2 = [Vector2(oh.w,oh.z),Vector2(oh.x,oh.w),Vector2(oh.y,oh.x),Vector2(oh.z,oh.y)][side]
					if absf(pair.x-a.y)<.02 and absf(pair.y-b.y)<.02: joined = true
				if not joined:
					architecture.line(a-Vector3.UP*.22,b-Vector3.UP*.22,.45,"dark_stone")

func _gallery(entry: Dictionary) -> void:
	var at: Vector3 = entry.center
	_plate(at,entry.size,entry.id)
	var outward: float = signf(at.z-definition.POINTS[entry.point].z)
	_plate(at+Vector3(0,-8,outward*6),Vector2(44,8),entry.id+"_veranda")
	for x: float in [-14,14]: solid(at+Vector3(x,-7.4,outward*9.6),Vector3(14,1.2,.6),"dark_stone")
	var hall_path: Array[Vector3] = []
	for z: int in range(-8,9,2): hall_path.append(authored_floor(at+Vector3(0,-8,z)))
	walk_routes.append({"id":entry.id+"_hall","kind":"hall","sector":-1,"width":8.0,"points":hall_path})
	# Two broad stairs leave both ends, with a 2 m landing halfway up.
	for side: float in [-1,1]:
		var low: Vector3 = at+Vector3(side*38,-8,0)
		var path: Array[Vector3] = []
		for j: int in 25:
			var distance: float = j
			var height: float = clampf(distance-1,0,10)*.4+clampf(distance-13,0,10)*.4
			var center: Vector3 = low+Vector3(-side*distance,height,0)
			path.append(center)
		furnished_bounds.append(AABB(low.min(path[-1])-Vector3(0,.3,4),Vector3(24,8.3,8)))
		# Continuous, closed wedge collision; visual closed treads sit below it.
		for j: int in 24:
			var a: Vector3 = path[j]
			var b: Vector3 = path[j+1]
			var top: float = minf(a.y,b.y)
			architecture.piece("box",Vector3(1,maxf(.1,top-low.y+.3),8),(a+b)/2-Vector3.UP*((a.y+b.y)/2-low.y+.3)/2,"stone")
			var vertices := PackedVector3Array([a+Vector3(0,0,-4),a+Vector3(0,0,4),b+Vector3(0,0,-4),b+Vector3(0,0,4),Vector3(a.x,low.y-.3,a.z-4),Vector3(a.x,low.y-.3,a.z+4),Vector3(b.x,low.y-.3,b.z-4),Vector3(b.x,low.y-.3,b.z+4)])
			var faces := PackedInt32Array([0,1,2,1,3,2,4,6,5,5,6,7,0,4,1,1,4,5,2,3,6,3,7,6,0,2,4,2,6,4,1,5,3,3,5,7])
			# Geometry winding follows stair direction.
			if side < 0:
				for f: int in range(0,faces.size(),3):
					var swap: int = faces[f+1]
					faces[f+1] = faces[f+2]
					faces[f+2] = swap
			for face: int in faces: stair_triangles.append(vertices[face])
		walk_routes.append({"id":entry.id+"_stairs_"+str(side),"kind":"gallery","sector":-1,"width":8.0,"points":path})
		audit.append({"element":"stairs","source":entry.id,"from":path[0],"to":path[-1],"width":8.0})
	# Through-hall beneath each gallery: broad openings on both long sides.
	for x: float in [-12,12]:
		for z: float in [-4,4]: solid(at+Vector3(x,-4,z),Vector3(1.2,8,1.2),"timber")
	for x: float in [-13,13]: solid(at+Vector3(x,-4,0),Vector3(1,7.5,8),"timber")
	for x: float in [-9,9]:
		for z: float in [-5,5]: solid(at+Vector3(x,-4,z),Vector3(6,7.5,1),"timber")
	for z: float in [-5,5]:
		solid(at+Vector3(0,-.8,z),Vector3(12,1,1),"timber")
		architecture.line(at+Vector3(-6,-1.4,z),at+Vector3(6,-1.4,z),.16,"gold")
	# Open fighting gallery, with offset cover and short decorative awnings.
	for x: float in [-10,10]:
		solid(at+Vector3(x,.6,4 if at.z>definition.POINTS[entry.point].z else -4),Vector3(5,1.2,1),"dark_stone")
		_roof(at+Vector3(x,5,0),Vector2(6,10))
		for z: float in [-4,4]: solid(at+Vector3(x,2.5,z),Vector3(.5,5,.5),"timber")
	audit.append({"element":"gallery","center":at,"point":entry.point,"movement":"two walkable stair exits and open through-hall","cover":"offset gallery shoulders"})

func _court(index: int) -> void:
	var at: Vector3 = definition.POINTS[index]
	_rock_foundation(at,index)
	for x: float in [-20,20]: architecture.line(at+Vector3(x,.04,-18),at+Vector3(x,.04,18),.15,"gold")
	for z: float in [-18,18]: architecture.line(at+Vector3(-20,.04,z),at+Vector3(20,.04,z),.15,"gold")
	# Four staggered garden/stone islands break open floor into fighting pockets.
	for offset: Vector3 in [Vector3(-12,0,-10),Vector3(12,0,10),Vector3(-28,0,4),Vector3(28,0,-4),Vector3(-24,0,-14),Vector3(24,0,14)]:
		var center: Vector3 = at+offset
		if _reserved(center,4): continue
		solid(center+Vector3.UP*.7,Vector3(6,1.4,4),"dark_stone")
		architecture.piece("box",Vector3(5.6,.15,3.6),center+Vector3.UP*1.45,"moss")
		if absf(offset.x)>20:
			solid(center+Vector3(0,2.4,0),Vector3(1,4.8,4),"timber")
			if not _reserved(center+Vector3.UP*7,2): _cherry(center+Vector3(0,1.4,0),index)
	if index == 2:
		# Skybell landmark suspended clear of both the ground routes and pad arcs.
		architecture.cylinder(2.2,3.6,at+Vector3.UP*15,"gold",true)
		architecture.cylinder(2.6,.4,at+Vector3.UP*13.2,"dark_stone",true)
		for x: float in [-10,10]:
			for z: float in [-26,26]: architecture.line(at+Vector3(x,14,z),at+Vector3(0,18,0),.22,"gold")
		architecture.line(at+Vector3.UP*18,at+Vector3.UP*16.8,.3,"timber")
	var label: Label3D = architecture.label(definition.TITLES[index],at+Vector3(0,12,0),70,Color("ffe3b0"))
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	point_labels.append(label)
	audit.append({"element":"court","point":index,"center":at,"size":Vector2(72,64),"movement":"open center with two through-halls and paired galleries"})

func _reserved(at: Vector3, margin: float) -> bool:
	for pad: Dictionary in pad_specs:
		for target: Vector3 in [pad.position,pad.destination]:
			if absf(target.y-at.y)<5 and Vector2(target.x-at.x,target.z-at.z).length()<margin+5: return true
	for route: Dictionary in walk_routes:
		for point: Vector3 in route.points:
			if absf(point.y-at.y)<4 and Vector2(point.x-at.x,point.z-at.z).length()<margin+route.width/2: return true
	return false

func _furnish_routes() -> void:
	for entry: Dictionary in routes:
		var accumulated: float = 0
		for i: int in range(1,entry.points.size()):
			var a: Vector3 = entry.points[i-1]
			var at: Vector3 = entry.points[i]
			accumulated += a.distance_to(at)
			if accumulated < 16 or absf(a.y-at.y)>.02: continue
			accumulated = 0
			var inside: bool = false
			for court: Vector3 in definition.POINTS:
				if absf(at.x-court.x)<42 and absf(at.z-court.z)<38: inside = true
			if inside: continue
			var near_turn: bool = false
			for turn: Vector3 in entry.authored:
				if at.distance_to(turn)<12: near_turn = true
			if near_turn: continue
			var side: Vector3 = (at-a).normalized().cross(Vector3.UP)
			for sign_value: float in [-1,1]:
				var center: Vector3 = at+side*sign_value*(entry.width/2+2)
				var clear: bool = true
				var forward: Vector3 = (at-a).normalized()
				for across: float in [-.6,.6]:
					for along: float in [-3,3]:
						if _reserved(center+side*across+forward*along,.6): clear = false
				if not clear: continue
				# Small supported rest bays stay outside the clear circulation width.
				var rotation := Vector3(0,atan2((at-a).x,(at-a).z),0)
				solid(center-Vector3.UP*.3,Vector3(4,.6,8),"stone",rotation)
				solid(center+Vector3.UP*1.6,Vector3(1.2,3.2,6),"dark_stone",rotation)
				architecture.piece("box",Vector3(1.4,.12,6.2),center+Vector3.UP*3.26,"moss",rotation)

func _build_pads() -> void:
	for entry: Dictionary in pad_specs:
		var pad := TempleJumpPad.new()
		pad.spec = entry
		pad.position = entry.position
		add_child(pad)
		pads.append(pad)
		var direction: Vector3 = (entry.destination-entry.position)*Vector3(1,0,1)
		direction = direction.normalized()
		architecture.piece("box",Vector3(4,.06,4),entry.position+Vector3.UP*.03,"gold")
		architecture.line(entry.position+Vector3.UP*.1-direction,entry.position+Vector3.UP*.1+direction*1.5,.2,"cyan")
		for side: float in [-1,1]: architecture.line(entry.position+Vector3.UP*.1+direction*1.5,entry.position+Vector3.UP*.1+direction*.5+direction.cross(Vector3.UP)*side*.7,.2,"cyan")
		for x: float in [-4,4]: architecture.line(entry.destination+Vector3(x,.06,-4),entry.destination+Vector3(x,.06,4),.15,"gold")
		for z: float in [-4,4]: architecture.line(entry.destination+Vector3(-4,.06,z),entry.destination+Vector3(4,.06,z),.15,"gold")
		architecture.label("WIND LIFT",entry.position+Vector3.UP*2.8,28,Color("8fe5e7"))

func _scenery() -> void:
	for sign_value: float in [1,-1]:
		for index: int in 9:
			var at := Vector3(sign_value*(190+index%3*35),-20+index%4*12,sign_value*(index*48-190))
			architecture.piece("cone",Vector3(100,130+index%3*30,100),at,"dark_stone")
			architecture.piece("cone",Vector3(34,42,34),at+Vector3.UP*(58+index%3*15),"stone")

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


func _roof(at: Vector3, footprint: Vector2) -> void:
	# Colliding shallow slopes permit roof traversal; eave trim is cosmetic only.
	for sign_value: float in [-1,1]:
		var size := Vector3(footprint.x/2+.7,.4,footprint.y)
		solid(at+Vector3(sign_value*footprint.x/4,1.2,0),size,"tile",Vector3(0,0,-sign_value*.17))
	architecture.piece("box",Vector3(.5,.6,footprint.y+1),at+Vector3(0,1.42+sin(.17)*footprint.x/4,0),"gold")
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


func _cherry(at: Vector3, seed_value: int) -> void:
	architecture.cylinder(.65,7,at+Vector3.UP*3.5,"timber",true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 721+seed_value
	for index: int in 14:
		var offset := Vector3(rng.randf_range(-4,4),rng.randf_range(7,10),rng.randf_range(-4,4))
		architecture.line(at+Vector3.UP*4,at+offset,.25,"timber")
		architecture.piece("sphere",Vector3(5,2.8,4.5),at+offset,"blossom" if index%3 else "blossom_light")
	audit.append({"element":"cherry","center":at,"sightline":"canopy remains overhead, never the sole concealment","movement":"trunk is outside the primary circulation; branches are cosmetic","cover":"solid trunk offers only narrow incidental cover"})


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


func _spawns() -> void:
	for team: int in 2:
		var sign_value: float = 1 if team == 0 else -1
		for stage: int in 3:
			var center: Vector3 = definition.room_center(team,stage)
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
	nav.agent_max_slope = 26
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
	_merge_static_collision()
	NavigationServer3D.bake_from_source_geometry_data_async(nav,source,func() -> void:
		if not is_instance_valid(navigation_region): return
		navigation_region.navigation_mesh = null
		navigation_region.navigation_mesh = nav
		bake_milliseconds = Time.get_ticks_msec()-bake_started)



func _merge_static_collision() -> void:
	# Bake uses original primitives and obstruction metadata. Runtime queries use
	# one BVH for box/triangle geometry instead of hundreds of compound shapes.
	var triangles := PackedVector3Array()
	for node: Node in architecture.collision_body.get_children():
		var child := node as CollisionShape3D
		if child == null: continue
		var faces := PackedVector3Array()
		if child.shape is BoxShape3D:
			var mesh := BoxMesh.new()
			mesh.size = child.shape.size
			faces = mesh.get_faces()
		elif child.shape is ConcavePolygonShape3D:
			faces = child.shape.get_faces()
		else: continue
		for vertex: Vector3 in faces: triangles.append(child.transform*vertex)
		architecture.collision_body.remove_child(child)
		child.queue_free()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(triangles)
	shape.backface_collision = true
	var collider := CollisionShape3D.new()
	collider.shape = shape
	architecture.collision_body.add_child(collider)
