class_name MuseumBuilder
extends Node3D
## Original batched architecture; solid silhouettes carry combat readability.
var definition: MuseumMapDefinition
var architecture: MeridianArchitecture
var navigation_region: NavigationRegion3D
var stairs: Array[Dictionary] = []
var shortcuts: Array[Dictionary] = []
var spawn_gates: Array[StaticBody3D] = []
var capture_marker: MeshInstance3D

func _ready() -> void:
	architecture = MeridianArchitecture.new(self)
	architecture.collision_body.remove_from_group("meridian_navigation_geometry")
	architecture.collision_body.add_to_group("museum_navigation_geometry")
	architecture.mat("ivory",Color("eee6d1"))
	architecture.mat("paving",Color("a19f99"))
	architecture.mat("bone",Color("dbc99c"))
	architecture.mat("leaf",Color("457c68"))
	architecture.mat("terracotta",Color("bd8462"))
	_build_environment()
	_build_floors()
	_build_court()
	_build_giants()
	_build_terrace()
	_build_vault()
	_build_spawns()
	_build_track()
	_build_exhibits()
	for child: Node in get_children():
		if child is Label3D:
			# Back-to-back signs stay readable from either direction; enabling a
			# label's back face would mirror its lettering for the other team.
			var reverse: Label3D = child.duplicate()
			reverse.rotation.y += PI
			add_child(reverse)
	architecture.flush()
	_build_navigation()

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("367a9b")
	sky_mat.sky_horizon_color = Color("d9d9be")
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bed5dd")
	environment.ambient_light_energy = .65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58,-25,0)
	sun.light_color = Color("ffe2b4")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 170
	add_child(sun)

func slab(at: Vector3, size: Vector3, key: String = "paving") -> void:
	architecture.box(size,at,key,true)

func wall(a: Vector3, b: Vector3, height: float = 7, key: String = "ivory") -> void:
	var direction: Vector3 = b-a
	slab((a+b)/2+Vector3.UP*height/2,Vector3(.6,height,direction.length()),key)
	# Replace the last collider/batch orientation consistently for non-axis walls.
	var collider := architecture.collision_body.get_child(-1) as CollisionShape3D
	var yaw: float = atan2(direction.x,direction.z)
	collider.rotation.y = yaw
	var batch: Array = architecture.batches["box:"+key]
	batch[-1] = Transform3D(Basis(Vector3.UP,yaw).scaled_local(Vector3(.6,height,direction.length())),(a+b)/2+Vector3.UP*height/2)

func ramp(a: Vector3, b: Vector3, width: float, caption: String = "STAIR") -> void:
	var flat: Vector3 = (b-a)*Vector3(1,0,1)
	var length: float = flat.length()
	var rise: float = b.y-a.y
	var yaw: float = atan2(flat.x,flat.z)
	var angle: float = atan2(rise,length)
	var basis := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,-angle)
	var center: Vector3 = (a+b)/2-Vector3.UP*.16
	var size := Vector3(width,.32,sqrt(length*length+rise*rise))
	architecture.piece("box",size,center,"cream",basis.get_euler())
	architecture.collider_box(size,center,basis.get_euler())
	# Tread stripes visually articulate a broad stair over a continuous safe slope.
	var steps: int = maxi(1,int(absf(rise)/.18))
	for index: int in steps:
		var t: float = (index+.5)/steps
		architecture.piece("box",Vector3(width,.025,.08),a.lerp(b,t)+Vector3.UP*.025,"brass",Vector3(0,yaw,0))
	stairs.append({"a":a,"b":b,"width":width,"label":caption})
	architecture.label(caption,a+Vector3.UP*.25,24,Color("305b65"),yaw)

func deck(at: Vector3, length: float, height: float, key: String = "cream") -> void:
	slab(at+Vector3(0,height-.2,0),Vector3(length,.4,5),key)
	for x: float in [-length/2+1,length/2-1]:
		slab(at+Vector3(x,height/2,0),Vector3(.65,height,.65),"ivory")
	# The front rail is interrupted for shots and mantle entries; rear rail is safe.
	architecture.railing(at+Vector3(-length/2,height,2.4),at+Vector3(length/2,height,2.4),.95)
	for x: float in [-length*.33,length*.33]:
		slab(at+Vector3(x,height+.5,-2.25),Vector3(3.2,1, .4),"ivory")
	ramp(at+Vector3(-length/2-9,0,0),at+Vector3(-length/2,height,0),3.5,"WEST STAIR")
	ramp(at+Vector3(length/2+9,0,0),at+Vector3(length/2,height,0),3.5,"EAST STAIR")

func _build_floors() -> void:
	slab(Vector3(-1,-.4,0),Vector3(130,.8,80))
	slab(Vector3(86,-.4,-13),Vector3(44,.8,54))
	slab(Vector3(86,-1.9,20.5),Vector3(44,.8,13),"grass")
	slab(Vector3(86,-.4,34),Vector3(44,.8,12))
	# A gentle arrival ramp reaches the elevated conservation wing.
	ramp(Vector3(92,0,0),Vector3(108,1.5,0),27,"CONSERVATION RISE")
	slab(Vector3(154,1.1,0),Vector3(92,.8,80))
	ramp(Vector3(99,0,32),Vector3(108,1.5,32),13,"SERVICE RISE")
	ramp(Vector3(99,0,-32),Vector3(108,1.5,-32),13,"SERVICE RISE")
	ramp(Vector3(70,0,14),Vector3(70,-1.5,21),6,"GARDEN STAIR")
	ramp(Vector3(97,0,14),Vector3(97,-1.5,21),6,"GARDEN STAIR")
	ramp(Vector3(76,-1.5,21),Vector3(76,0,28),5,"GARDEN EXIT")
	ramp(Vector3(82,-1.5,21),Vector3(82,0,28),5,"GARDEN EXIT")
	for z: float in [-40,40]: wall(Vector3(-66,0,z),Vector3(200,1.5,z),9,"terracotta")
	wall(Vector3(-66,0,-40),Vector3(-66,0,40),10)
	wall(Vector3(200,1.5,-40),Vector3(200,1.5,40),10)
	# Chunked perimeter gives deliberate side doors, display niches and landmarks.
	for x: float in [-27,16,62,108,160]:
		var y: float = 1.5 if x >= 108 else 0.0
		for side: float in [-1,1]:
			wall(Vector3(x,y,side*8),Vector3(x,y,side*14),8)
			wall(Vector3(x,y,side*23),Vector3(x,y,side*26),8)
		architecture.arch(Vector3(x,y,0),15,10,.8,"ivory",PI/2,.7)
	for z: float in [-26,26]:
		for x: float in [-22,4,30,56,82,108,134,160]:
			var doorway: bool = false
			var rooms: Array[Vector3] = definition.attacker_rooms if z > 0 else definition.defender_rooms
			for room: Vector3 in rooms:
				if absf(room.x-x) < 15: doorway = true
			if doorway: continue
			var y: float = 1.5 if x >= 108 else 0.0
			wall(Vector3(x-8,y,z),Vector3(x+8,y,z),8)

func _build_court() -> void:
	architecture.label("MERIDIAN  /  MUSEUM OF LIVING HISTORY",Vector3(-25,8,0),65,Color("e5bb74"),PI/2)
	architecture.label("A  /  ASTROLABE COURT",Vector3(0,.12,8),32)
	# Oval architectural rhythm with generous breaks for three approaches.
	for index: int in 12:
		if index in [0,6]: continue
		var angle: float = index*TAU/12
		var at := Vector3(cos(angle)*20,0,sin(angle)*23)
		architecture.cylinder(.6,7,at+Vector3.UP*3.5,"ivory",true)
		architecture.arch(at+Vector3.UP*6,8,2.5,1,"cream",angle,.4,false)
	architecture.cylinder(3,1.25,Vector3(1,.625,0),"slate",true)
	architecture.cylinder(.55,5,Vector3(1,3.7,0),"brass",true)
	for tilt: float in [0,.8,-.7]:
		architecture.piece("ring",Vector3(7,.22,7),Vector3(1,4,0),"brass",Vector3(PI/2,tilt,.4))
	architecture.piece("sphere",Vector3(1.4,1.4,1.4),Vector3(1,4,0),"cyan")
	deck(Vector3(-5,0,-17),16,3.6)
	for at: Vector3 in [Vector3(-15,0,15),Vector3(6,0,17)]:
		architecture.planter(at,Vector3(4,1.2,2.5))
		architecture.tree(at+Vector3.UP*1.2,1.1)
	# Short mantle chain into the crescent's side; all drops land on court paving.
	for index: int in 2:
		slab(Vector3(-9+index*2, .6+index*.6,-12-index*1.8),Vector3(2.8,1.2+index*1.2,2.8),"terracotta")
	deck(Vector3(-12,0,9),6,3.6)
	wall(Vector3(-16,0,11.7),Vector3(-16,0,16),4,"terracotta")
	wall(Vector3(-16,0,15),Vector3(-12,0,15),4,"terracotta")
	shortcuts.append({"a":Vector3(-9,0,-12),"b":Vector3(-5,3.6,-17),"kind":"MANTLE"})
	shortcuts.append({"a":Vector3(-16.7,0,13),"b":Vector3(-12,3.6,9),"kind":"WALL KICK"})
	for x: float in [-22,-13]:
		slab(Vector3(x,1.1,19),Vector3(3.5,2.2,2),"ivory")
		architecture.piece("sphere",Vector3(1,2,1),Vector3(x,3,19),"brass")

func _build_giants() -> void:
	architecture.label("01  /  HALL OF GIANTS",Vector3(18,8,0),52,Color("e5bb74"),PI/2)
	# Payload wraps the island; neither mezzanine sees both sides.
	slab(Vector3(34,1.4,0),Vector3(11,2.8,7),"slate")
	slab(Vector3(53,1.3,-15),Vector3(5,2.6,5),"terracotta")
	deck(Vector3(38,0,17),16,4)
	deck(Vector3(48,0,-19),10,4)
	# Separate ledges form a real 4 m clear dash gap.
	slab(Vector3(28,3.8,10),Vector3(6,.4,4),"cream")
	slab(Vector3(38,3.8,10),Vector3(6,.4,4),"cream")
	ramp(Vector3(17,0,10),Vector3(25,4,10),3.5,"EXHIBIT STAIR")
	shortcuts.append({"a":Vector3(31,4,10),"b":Vector3(35,4,10),"kind":"DASH 4 m"})
	wall(Vector3(18,0,21),Vector3(18,0,25),4)
	wall(Vector3(26,0,21),Vector3(30,0,21),4)
	# Suspended skeleton: spine, rib cage, skull, jaw, tail and legs.
	for index: int in 15:
		var x: float = 26+index*1.15
		var y: float = 6.2+sin(index*.2)*.6
		architecture.piece("sphere",Vector3(.6,.6,.6),Vector3(x,y,0),"bone")
		if index > 2 and index < 11:
			for side: float in [-1,1]:
				architecture.line(Vector3(x,y,0),Vector3(x-.3,y-1.4,side*1.7),.18,"bone")
				architecture.line(Vector3(x-.3,y-1.4,side*1.7),Vector3(x+.1,y-2.2,side*1),.15,"bone")
	architecture.piece("sphere",Vector3(3,1.4,1.8),Vector3(25,6.2,0),"bone")
	architecture.line(Vector3(24,5.6,0),Vector3(26,5.3,0),.3,"bone")
	for x: float in [31,38]:
		for side: float in [-1,1]:
			architecture.line(Vector3(x,5.5,side*.5),Vector3(x+1,3.6,side*1.4),.28,"bone")
	for index: int in 6:
		architecture.line(Vector3(42+index,6.2,0),Vector3(43+index,6.0-index*.15,0),.3-index*.035,"bone")
	for x: float in [27,39,48]: architecture.line(Vector3(x,7,0),Vector3(x,12,0),.045,"iron")
	# Vaulted skylight ribs leave clear airspace for flight without hiding routes.
	for x: float in [19,28,37,46,55,61]:
		architecture.arch(Vector3(x,0,0),51,13,.4,"ivory",PI/2,.35,false)
	architecture.piece("box",Vector3(45,.12,34),Vector3(39,13,0),"roof_glass")
	for x: float in [24,47]:
		slab(Vector3(x,1,22),Vector3(3,2,2),"ivory")
		architecture.piece("sphere",Vector3(1,1.6,1),Vector3(x,2.8,22),"bone")

func _build_terrace() -> void:
	architecture.label("02  /  LIVING TERRACE",Vector3(64,7,0),50,Color("e5bb74"),PI/2)
	deck(Vector3(83,0,-17),14,4.5,"grass")
	for at: Vector3 in [Vector3(79,0,-4),Vector3(103,-1.5,24),Vector3(88,-1.5,24)]:
		architecture.planter(at,Vector3(4,1.3,3))
		architecture.tree(at+Vector3.UP*1.3,1.3)
	wall(Vector3(80,0,-6),Vector3(87,0,-6),3.8,"terracotta")
	wall(Vector3(97,0,7),Vector3(103,0,7),3.8,"terracotta")
	for index: int in 3:
		var h: float = 1.5*(index+1)
		slab(Vector3(76+index*2,h/2,-10-index*2),Vector3(2.7,h,2.7),"ivory")
	shortcuts.append({"a":Vector3(76,0,-10),"b":Vector3(80,4.5,-14),"kind":"MANTLE CHAIN"})
	slab(Vector3(80,2.6,20),Vector3(5,.4,4),"cream")
	slab(Vector3(90,2.6,20),Vector3(5,.4,4),"cream")
	ramp(Vector3(72,-1.5,20),Vector3(77.5,2.8,20),3.5,"SCULPTURE STAIR")
	ramp(Vector3(98,-1.5,20),Vector3(92.5,2.8,20),3.5,"SCULPTURE STAIR")
	shortcuts.append({"a":Vector3(82.5,2.8,20),"b":Vector3(87.5,2.8,20),"kind":"DASH 5 m"})
	for x: float in [71,87,101]:
		architecture.cylinder(.8,1.2,Vector3(x,-.9,24),"ivory",true)
		architecture.piece("ring",Vector3(2.3,.3,2.3),Vector3(x,1.1,24),"brass",Vector3(PI/2,.4,0))

func _build_vault() -> void:
	architecture.label("03  /  CONSERVATION VAULT",Vector3(109,8,0),48,Color("e5bb74"),PI/2)
	slab(Vector3(128,3,0),Vector3(10,3,8),"ivory")
	slab(Vector3(147,3,-13),Vector3(7,3,7),"terracotta")
	deck(Vector3(131,1.5,17),16,3.5)
	wall(Vector3(115,1.5,22),Vector3(115,1.5,25),4)
	wall(Vector3(119,1.5,19),Vector3(124,1.5,19),4)
	for index: int in 2:
		var h: float = 1.6*(index+1)
		slab(Vector3(127+index*2,1.5+h/2,11+index*2),Vector3(2.7,h,2.7),"terracotta")
	shortcuts.append({"a":Vector3(127,1.5,11),"b":Vector3(131,5,17),"kind":"PACKING MANTLE"})
	shortcuts.append({"a":Vector3(116,1.5,20),"b":Vector3(124,5,17),"kind":"WALL KICK"})
	for x: float in [116,137,153]:
		slab(Vector3(x,2.6,-21),Vector3(4,2.2,3),"slate")
		architecture.piece("sphere",Vector3(1.3,2,1.3),Vector3(x,4.5,-21),"brass")
	for x: float in [112,124,136,148,159]:
		architecture.arch(Vector3(x,1.5,0),50,11,.5,"ivory",PI/2,.45,false)
	architecture.piece("box",Vector3(52,.12,34),Vector3(134,13,0),"roof_glass")
	architecture.cylinder(4,.12,Vector3(154,1.56,0),"cyan")
	architecture.label("ARTIFACT DOCK  /  FINAL",Vector3(158,6.5,0),42,Color("8beaff"),PI/2)
	# Final defender approach doglegs behind solid storage bays.
	wall(Vector3(174,1.5,-8),Vector3(182,1.5,-8),6)
	wall(Vector3(165,1.5,8),Vector3(178,1.5,8),6)
	# Archive/service separation makes the final defender return a committed
	# rotation. The west exit serves CP1; the east exit reaches the final dock.
	wall(Vector3(108,1.5,-18),Vector3(166,1.5,-18),5,"slate")
	wall(Vector3(166,1.5,-18),Vector3(166,1.5,12),5,"slate")

func _build_spawns() -> void:
	for team: int in 2:
		var rooms: Array[Vector3] = definition.attacker_rooms if team == 0 else definition.defender_rooms
		for index: int in rooms.size():
			var center: Vector3 = rooms[index]
			# Two exits in the front wall, separated by an opaque screening panel.
			wall(center+Vector3(-7,0,-5),center+Vector3(7,0,-5),5,"slate")
			wall(center+Vector3(-7,0,-5),center+Vector3(-7,0,5),5)
			wall(center+Vector3(7,0,-5),center+Vector3(7,0,5),5)
			wall(center+Vector3(-1,0,5),center+Vector3(1,0,5),5)
			slab(center+Vector3(0,5.2,0),Vector3(14,.4,10),"cream")
			for offset: float in [-4,4]:
				var gate := StaticBody3D.new()
				gate.name = "%s%dGate" % ["A" if team == 0 else "D",index]
				gate.set_meta("team",team)
				gate.set_meta("stage",index)
				gate.collision_layer = 4 if team == 0 else 8
				gate.collision_mask = 0
				gate.position = center+Vector3(offset,2.5,5)
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(6,5,.2)
				shape.shape = box
				gate.add_child(shape)
				var mesh := MeshInstance3D.new()
				var gate_mesh := BoxMesh.new()
				gate_mesh.size = box.size
				mesh.mesh = gate_mesh
				var material := StandardMaterial3D.new()
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.albedo_color = Color(.2,.8,.95,.14) if team == 0 else Color(.95,.4,.35,.14)
				material.emission_enabled = true
				material.emission = Color(.1,.4,.6) if team == 0 else Color(.5,.16,.1)
				mesh.material_override = material
				gate.add_child(mesh)
				add_child(gate)
				spawn_gates.append(gate)
			architecture.label("%s%d  /  %s" % ["A" if team == 0 else "D",index,"ATTACK" if team == 0 else "DEFEND"],center+Vector3(0,4.4,5.4),28,Color("8beaff") if team == 0 else Color("ef9f85"))
			# Screens outside both exits prevent shooting straight into arrival rooms.
			var long_screen: bool = team == 0 or index == 0
			wall(center+Vector3(-10 if long_screen else -6,0,9),center+Vector3(3 if long_screen else 0,0,9),3)
			wall(center+Vector3(-3 if long_screen else 3,0,8),center+Vector3(12 if long_screen else 8,0,8),3)

func _build_track() -> void:
	var path: Array[Vector3] = definition.payload_path
	for index: int in range(1,path.size()):
		for side: float in [-1,1]:
			architecture.line(path[index-1]+Vector3(0,.035,side*.85),path[index]+Vector3(0,.035,side*.85),.075,"brass")
	for index: int in 3:
		var point: Vector3 = path[definition.checkpoint_vertices[index]]
		architecture.label("CHECKPOINT %d" % (index+1),point+Vector3(0,.1,4),30,Color("66d6eb"))
	# Capture perimeter is geometry paint, with a nonblocking center landmark.
	for z: float in [-7,7]: architecture.line(Vector3(-9,.035,z),Vector3(9,.035,z),.12,"cyan")
	for x: float in [-9,9]: architecture.line(Vector3(x,.035,-7),Vector3(x,.035,7),.12,"cyan")

func _build_exhibits() -> void:
	var glass: StandardMaterial3D = architecture.mat("case_glass",Color(.55,.8,.83,.12),0,.15)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for index: int in 8:
		var at: Vector3 = [Vector3(-21,0,-22),Vector3(5,0,22),Vector3(30,0,23),Vector3(52,0,22),Vector3(70,0,-22),Vector3(102,0,-22),Vector3(120,1.5,-23),Vector3(151,1.5,22)][index]
		slab(at+Vector3.UP*.65,Vector3(1.6,1.3,1.6),"ivory")
		# Vitrines are visibly delicate; only the opaque stone plinth is cover.
		architecture.piece("box",Vector3(1.7,2,1.7),at+Vector3.UP*2.3,"case_glass")
		architecture.piece("sphere",Vector3(.6,1.2,.6),at+Vector3.UP*1.9,"brass")
		architecture.piece("ring",Vector3(.9,.12,.9),at+Vector3.UP*2.5,"brass",Vector3(PI/2,.4*index,0))
		architecture.label(["FIRST LIGHT","THE TIDAL CROWN","ANCIENT SEAS","AGE OF GIANTS","LIVING STONE","SKY GARDENS","RESTORATION","THE STAR ARCHIVE"][index],at+Vector3(0,1.1,1),20,Color("25343c"))
	for index: int in 4:
		var x: float = [0.0,39,86,134][index]
		var y: float = 1.5 if index == 3 else 0.0
		# Original abstract collection panels give each wing a different accent.
		for tile: int in 7:
			architecture.piece("box",Vector3(1.1,1.4+sin(tile)*.6,.08),Vector3(x+(tile-3)*1.4,4.2+y,-25.5),["brass","blue","leaf","terracotta"][index])
		architecture.label(["ASTROLABE COURT","HALL OF GIANTS","LIVING TERRACE","CONSERVATION VAULT"][index],Vector3(x,6.8+y,-25.4),48,Color("ead5a9"))

func _build_navigation() -> void:
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "MuseumNavigation"
	var nav := NavigationMesh.new()
	nav.cell_size = .25
	nav.cell_height = .25
	nav.agent_radius = .75
	nav.agent_height = 2
	nav.agent_max_climb = .5
	nav.agent_max_slope = 49
	nav.region_min_size = 1
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav.geometry_source_group_name = &"museum_navigation_geometry"
	nav.filter_baking_aabb = AABB(Vector3(-65,-2.5,-39),Vector3(264,17,78))
	navigation_region.navigation_mesh = nav
	add_child(navigation_region)
	call_deferred("_bake")

func _bake() -> void:
	await get_tree().physics_frame
	navigation_region.bake_navigation_mesh(true)

func update_gates(preparation: bool) -> void:
	for gate: StaticBody3D in spawn_gates:
		var team: int = gate.get_meta("team")
		var stage: int = gate.get_meta("stage")
		var current: int = definition.attacker_stage if team == 0 else definition.defender_stage
		gate.visible = stage == current
		gate.collision_layer = (12 if preparation and team == 0 else (4 if team == 0 else 8)) if stage == current else 0
