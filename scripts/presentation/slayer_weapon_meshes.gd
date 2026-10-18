class_name SlayerWeaponMeshes
extends RefCounted
## Three cached surfaces per weapon; one draw node shared by held/thrown variants.
static var knife_mesh: ArrayMesh
static var axe_mesh: ArrayMesh

static func material(colour: Color, metal: float) -> StandardMaterial3D:
	var result := Geometry.material(colour)
	result.metallic = metal
	result.roughness = .32
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	return result

static func triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)

static func box(tool: SurfaceTool, centre: Vector3, size: Vector3) -> void:
	var points: Array[Vector3] = []
	for z: float in [-.5,.5]:
		for y: float in [-.5,.5]:
			for x: float in [-.5,.5]: points.append(centre + size * Vector3(x,y,z))
	for face: Array in [[0,2,3,1],[4,5,7,6],[0,1,5,4],[2,6,7,3],[0,4,6,2],[1,3,7,5]]:
		triangle(tool,points[face[0]],points[face[1]],points[face[2]])
		triangle(tool,points[face[0]],points[face[2]],points[face[3]])

static func surface(mesh: ArrayMesh, tool: SurfaceTool, colour: Color, metal: float) -> void:
	tool.generate_normals()
	tool.set_material(material(colour,metal))
	tool.commit(mesh)

static func build_knife() -> ArrayMesh:
	if knife_mesh != null: return knife_mesh
	knife_mesh = ArrayMesh.new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Point is local -Z. Faceted ridge joins the five-point tapered outline.
	var outline: Array[Vector3] = [Vector3(0,0,-.43),Vector3(.062,0,-.22),Vector3(.037,0,-.035),Vector3(-.037,0,-.035),Vector3(-.062,0,-.22)]
	for index: int in outline.size():
		var next: int = (index + 1) % outline.size()
		triangle(tool,outline[index],outline[next],Vector3(0,.022,-.19))
		triangle(tool,outline[next],outline[index],Vector3(0,-.016,-.19))
	surface(knife_mesh,tool,Color("bccbdc"),.60)
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	box(tool,Vector3(0,0,.065),Vector3(.046,.045,.18))
	for index: int in 5: box(tool,Vector3(0,0,-.005 + index * .032),Vector3(.052,.049,.012))
	surface(knife_mesh,tool,Color("272432"),.2)
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	box(tool,Vector3(0,0,-.028),Vector3(.12,.035,.025))
	box(tool,Vector3(0,0,.16),Vector3(.06,.05,.025))
	triangle(tool,Vector3(0,.023,-.42),Vector3(.01,.025,-.19),Vector3(0,.023,-.05))
	surface(knife_mesh,tool,Color("edfaff"),.60)
	return knife_mesh

static func build_axe() -> ArrayMesh:
	if axe_mesh != null: return axe_mesh
	axe_mesh = ArrayMesh.new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	box(tool,Vector3(0,.15,0),Vector3(.085,1.8,.09))
	# Blade plane XY, thickness Z. Projectiles must rotate about this Z normal.
	for side: float in [-1.0,1.0]:
		var outline: Array[Vector3] = [Vector3(side*.12,.99,0),Vector3(side*.77,1.2,0),Vector3(side*.88,.91,0),Vector3(side*.77,.50,0),Vector3(side*.12,.62,0)]
		for index: int in outline.size():
			var next: int = (index + 1) % outline.size()
			triangle(tool,outline[index],outline[next],Vector3(side*.40,.85,.11))
			triangle(tool,outline[next],outline[index],Vector3(side*.40,.85,-.11))
	surface(axe_mesh,tool,Color("494657"),.85)
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0,1.0]:
		for depth: float in [-.08,.08]:
			triangle(tool,Vector3(side*.77,1.2,depth),Vector3(side*.88,.91,depth),Vector3(side*.65,.91,depth))
			triangle(tool,Vector3(side*.88,.91,depth),Vector3(side*.77,.50,depth),Vector3(side*.65,.91,depth))
	box(tool,Vector3(0,.85,0),Vector3(.20,.30,.26))
	for y: float in [-.72,-.14,.32]: box(tool,Vector3(0,y,0),Vector3(.12,.055,.13))
	surface(axe_mesh,tool,Color("e1e4f0"),.60)
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	box(tool,Vector3(0,-.44,0),Vector3(.115,.52,.12))
	for index: int in 7: box(tool,Vector3(0,-.67+index*.07,0),Vector3(.13,.023,.135))
	box(tool,Vector3(0,.85,-.145),Vector3(.09,.15,.035))
	surface(axe_mesh,tool,Color("823654"),.4)
	return axe_mesh
