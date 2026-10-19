class_name MuseumBuilder
extends Node3D
## Original batched architecture; solid silhouettes carry combat readability.
var definition: MuseumMapDefinition
var architecture: MeridianArchitecture
var lighting: MuseumLighting
var navigation_region: NavigationRegion3D
var stairs: Array[Dictionary] = []
var shortcuts: Array[Dictionary] = []
var spawn_gates: Array[MuseumSpawnDoor] = []

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
	lighting = MuseumLighting.new()
	lighting.definition = definition
	add_child(lighting)

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

func _build_floors() -> void:
	# Only the garden is excavated. The footprint is 114 x 102 m, not a long strip.
	slab(Vector3(-11,-.4,0),Vector3(92,.8,102))
	slab(Vector3(50,-.4,0),Vector3(14,.8,102))
	slab(Vector3(39,-.4,-43),Vector3(8,.8,16))
	slab(Vector3(39,-.4,20),Vector3(8,.8,62))
	slab(Vector3(39,-1.9,-23),Vector3(8,.8,24),"grass")
	ramp(Vector3(39,0,-35),Vector3(39,-1.5,-28),8,"NORTH GARDEN STAIR")
	ramp(Vector3(39,-1.5,-18),Vector3(39,0,-11),8,"SOUTH GARDEN STAIR")
	for z: float in [-51,51]: wall(Vector3(-57,0,z),Vector3(57,0,z),10,"terracotta")
	for x: float in [-57,57]: wall(Vector3(x,0,-51),Vector3(x,0,51),10,"terracotta")
	# Central collection wing is substantial building mass, never a bypass lane.
	slab(Vector3(0,6,25),Vector3(16,12,40),"terracotta")
	architecture.label("MERIDIAN / COLLECTION WING",Vector3(0,10,45.4),42,Color("e5bb74"))
	# Perimeter architecture defines the four wings, with generous local connections.
	for row: Array in [
	 [Vector3(-46,0,8),Vector3(-46,0,11)], [Vector3(-46,0,34),Vector3(-46,0,40)],
	 [Vector3(-46,0,40),Vector3(-10,0,40)], [Vector3(-10,0,8),Vector3(-10,0,40)],
	 [Vector3(-46,0,8),Vector3(-35,0,8)], [Vector3(-14,0,8),Vector3(-10,0,8)],
	 [Vector3(-42,0,-38),Vector3(-42,0,-35)], [Vector3(-42,0,-15),Vector3(-42,0,4)], [Vector3(-42,0,4),Vector3(-35,0,4)],
	 [Vector3(-15,0,4),Vector3(-4,0,4)], [Vector3(-4,0,-38),Vector3(-4,0,-30)],
	 [Vector3(-4,0,-14),Vector3(-4,0,4)],
	 [Vector3(2,0,-38),Vector3(2,0,-30)], [Vector3(2,0,-14),Vector3(2,0,4)],
	 [Vector3(44,0,-38),Vector3(44,0,-37)], [Vector3(44,0,-32),Vector3(44,0,4)], [Vector3(2,0,4),Vector3(26,0,4)],
	 [Vector3(40,0,4),Vector3(44,0,4)],
	 [Vector3(8,0,10),Vector3(26,0,10)], [Vector3(40,0,10),Vector3(46,0,10)],
	 [Vector3(8,0,10),Vector3(8,0,42)], [Vector3(8,0,42),Vector3(46,0,42)],
	 [Vector3(46,0,10),Vector3(46,0,42)]]:
		wall(row[0],row[1],8)
	# Public admissions walk west of the galleries; two doors face its open porch.
	wall(Vector3(-57,0,41),Vector3(-46,0,41),8)
	# Back-of-house north edge has actual openings into its staff rooms.
	for row: Array in [[-42,-19],[-5,-3],[13,21]]:
		wall(Vector3(row[0],0,-38),Vector3(row[1],0,-38),7,"terracotta")
	# Close unused perimeter strips into inaccessible building masses.
	slab(Vector3(-2,4,47),Vector3(84,8,6),"terracotta")
	slab(Vector3(50,4,46),Vector3(14,8,8),"terracotta")
	slab(Vector3(51.5,4,26),Vector3(11,8,32),"terracotta")
	slab(Vector3(-30.5,4,-44.5),Vector3(23,8,13),"terracotta")

func room_shell(low: Vector3, high: Vector3, caption: String, key: String = "ivory", height: float = 6) -> void:
	# Opposite doors leave a genuine interior route, rather than a cover box.
	var mid: float = (low.x+high.x)/2
	wall(low,Vector3(low.x,0,high.z),height,key)
	wall(Vector3(high.x,0,low.z),high,height,key)
	for z: float in [low.z,high.z]:
		wall(Vector3(low.x,0,z),Vector3(mid-2,0,z),height,key)
		wall(Vector3(mid+2,0,z),Vector3(high.x,0,z),height,key)
	architecture.piece("box",Vector3(high.x-low.x,.2,high.z-low.z),Vector3(mid,height+.1,(low.z+high.z)/2),"roof_glass")
	architecture.label(caption,Vector3(mid,minf(4.8,height-.5),high.z+.4),25,Color("305b65"))

func platform(at: Vector3, size: Vector2, height: float, key: String = "cream") -> void:
	slab(at+Vector3.UP*(height-.2),Vector3(size.x,.4,size.y),key)

func _build_court() -> void:
	var c: Vector3 = definition.hill_center
	architecture.label("A / ASTROLABE COURT",c+Vector3(0,.1,8),34)
	architecture.cylinder(2.6,1.25,c+Vector3.UP*.625,"slate",true)
	architecture.cylinder(.45,4,c+Vector3.UP*3.25,"brass",true)
	for tilt: float in [0,.8,-.7]: architecture.piece("ring",Vector3(6,.22,6),c+Vector3.UP*4,"brass",Vector3(PI/2,tilt,.4))
	architecture.piece("sphere",Vector3(1.2,1.2,1.2),c+Vector3.UP*4,"cyan")
	slab(Vector3(-35,1.7,24),Vector3(3,3.4,5),"terracotta")
	slab(Vector3(-22,1.5,30),Vector3(3,3,4),"ivory")
	# Cafe roof and rear balcony form one occupied architectural edge.
	platform(Vector3(-32,0,12),Vector2(24,5),3.6)
	wall(Vector3(-44,0,10),Vector3(-44,0,14),6)
	wall(Vector3(-34,0,10),Vector3(-34,0,18),3.4)
	ramp(Vector3(-39,0,25),Vector3(-39,3.6,14.5),3.5,"CAFE STAIR")
	ramp(Vector3(-23,0,25),Vector3(-23,3.6,14.5),3.5,"CLOISTER STAIR")
	for x: float in [-39,-27]: slab(Vector3(x,4.15,14.2),Vector3(4,1.1,.5))
	architecture.railing(Vector3(-44,3.6,9.7),Vector3(-20,3.6,9.7),.95)
	room_shell(Vector3(-21,0,28),Vector3(-12,0,38),"SCULPTURE CLOISTER")
	for at: Vector3 in [Vector3(-40,0,33),Vector3(-13,0,24)]: architecture.planter(at,Vector3(3,1.2,2))
	for index: int in 2:
		var h: float = (index+1)*1.2
		slab(Vector3(-31,h/2,18-index*2),Vector3(2.8,h,2.8),"terracotta")
	slab(Vector3(-31,2.9,14.4),Vector3(3,1.4,.4),"terracotta")
	shortcuts.append({"a":Vector3(-31,0,20.1),"b":Vector3(-31,3.6,12),"kind":"CAFE MANTLES"})
	wall(Vector3(-18,0,34),Vector3(-18,0,37),4,"terracotta")
	wall(Vector3(-18,0,37),Vector3(-14,0,37),4,"terracotta")
	shortcuts.append({"a":Vector3(-18.7,0,35),"b":Vector3(-18,3.6,12),"kind":"CLOISTER WALL KICK"})

func _build_giants() -> void:
	architecture.label("01 / HALL OF GIANTS",Vector3(-27,8,-36),46,Color("e5bb74"))
	slab(Vector3(-30,1.5,-28),Vector3(9,3,8),"slate")
	room_shell(Vector3(-17,0,-18),Vector3(-7,0,-7),"RESEARCH / EDUCATION")
	platform(Vector3(-32,0,-22),Vector2(18,4),4)
	ramp(Vector3(-39,0,-8),Vector3(-39,4,-20),3.5,"EDUCATION STAIR")
	# Bridge underside clears both the artifact and standing riders (4.4 m).
	ramp(Vector3(-34,4,-20),Vector3(-34,5.8,-7),3.5,"UPPER GALLERY")
	platform(Vector3(-27,0,-5),Vector2(17,4),5.8)
	ramp(Vector3(-7,0,-5),Vector3(-18.5,5.8,-5),3.5,"RESEARCH STAIR")
	for x: float in [-32,-22]: slab(Vector3(x,6.3,-3.3),Vector3(4,1,.5))
	architecture.railing(Vector3(-35,5.8,-6.8),Vector3(-19,5.8,-6.8),.95)
	# Two ledges share the gallery's ordinary access; a missed dash lands in the hall.
	platform(Vector3(-37,0,-33),Vector2(5,4),4)
	platform(Vector3(-37,0,-27.5),Vector2(3,7),4)
	platform(Vector3(-28,0,-33),Vector2(5,4),4)
	platform(Vector3(-28,0,-27.5),Vector2(3,7),4)
	shortcuts.append({"a":Vector3(-34.5,4,-33),"b":Vector3(-30.5,4,-33),"kind":"DASH 4 m"})
	for index: int in 14:
		var at := Vector3(-36+index*.9,7+sin(index*.25)*.4,-28)
		architecture.piece("sphere",Vector3(.5,.5,.5),at,"bone")
		if index > 2 and index < 11:
			for side: float in [-1,1]:
				architecture.line(at,at+Vector3(-.2,-1.5,side*1.7),.16,"bone")
				architecture.line(at+Vector3(-.2,-1.5,side*1.7),at+Vector3(.1,-2.1,side),.14,"bone")
	architecture.piece("sphere",Vector3(2.6,1.5,1.8),Vector3(-37,7,-28),"bone")
	for x: float in [-37,-25]: architecture.line(Vector3(x,7,-28),Vector3(x,12,-28),.045,"iron")
	for z: float in [-34,-24,-14]: architecture.arch(Vector3(-23,0,z),36,12,.4,"ivory",0,.35,false)
	architecture.piece("box",Vector3(37,.15,40),Vector3(-23,12.4,-17),"roof_glass")

func _build_terrace() -> void:
	architecture.label("02 / LIVING TERRACE",Vector3(22,7,-37),43,Color("e5bb74"))
	# Pavilion sits inside the cart's curve, with an occupied roof and two ground doors.
	room_shell(Vector3(12,0,-20),Vector3(22,0,-7),"BOTANICAL PAVILION","terracotta",3.8)
	platform(Vector3(17,0,-10),Vector2(10,6),4.5,"grass")
	platform(Vector3(19,0,-3.5),Vector2(4,7),4.5,"grass")
	ramp(Vector3(3,0,-10),Vector3(12,4.5,-10),3.5,"PAVILION STAIR")
	ramp(Vector3(29,0,0),Vector3(21,4.5,0),3.5,"TERRACE RAMP")
	wall(Vector3(12,4.5,-11),Vector3(18,4.5,-11),3,"terracotta")
	platform(Vector3(14,0,-17),Vector2(3,8),4.5,"grass")
	for x: float in [14,20]: slab(Vector3(x,5,-7.3),Vector3(3,1,.45))
	for at: Vector3 in [Vector3(6,0,-17),Vector3(29,0,-3),Vector3(36.5,-1.5,-23)]:
		architecture.planter(at,Vector3(3,1.2,2))
		architecture.tree(at+Vector3.UP*1.2,1)
	for index: int in 3:
		var h: float = (index+1)*1.5
		slab(Vector3(14,h/2,-24+index*2),Vector3(2.7,h,2.7),"ivory")
	shortcuts.append({"a":Vector3(14,0,-26.1),"b":Vector3(14,4.5,-20),"kind":"ROOF MANTLES"})
	platform(Vector3(14,0,-34),Vector2(5,4),2.8)
	platform(Vector3(24,0,-34),Vector2(5,4),2.8)
	ramp(Vector3(6,0,-34),Vector3(11.5,2.8,-34),3.5,"TERRACE LEDGE")
	ramp(Vector3(32,0,-34),Vector3(26.5,2.8,-34),3.5,"GARDEN LEDGE")
	shortcuts.append({"a":Vector3(16.5,2.8,-34),"b":Vector3(21.5,2.8,-34),"kind":"DASH 5 m"})
	# Garden exits flank the promenade from separated angles.
	wall(Vector3(35,0,-27),Vector3(35,0,-22),3.2,"terracotta")
	wall(Vector3(35,0,-18),Vector3(35,0,-15),3.2,"terracotta")

func _build_vault() -> void:
	architecture.label("03 / CONSERVATION VAULT",Vector3(28,8,11),42,Color("e5bb74"))
	room_shell(Vector3(20,0,14),Vector3(30,0,23),"RESTORATION")
	room_shell(Vector3(28,0,33),Vector3(35,0,40),"PACKING","terracotta")
	platform(Vector3(15.5,0,26.5),Vector2(7,7),3.5)
	ramp(Vector3(13,0,13),Vector3(13,3.5,23),3.5,"RESTORATION STAIR")
	ramp(Vector3(17,0,40),Vector3(17,3.5,30),3.5,"PACKING STAIR")
	wall(Vector3(19,3.5,27),Vector3(19,3.5,30),3.5)
	slab(Vector3(12.5,4,25),Vector3(.5,1,3))
	for index: int in 2:
		var h: float = 1.6 if index == 0 else 2.8
		slab(Vector3(22-index*2,h/2,25),Vector3(2.7,h,2.7),"terracotta")
	shortcuts.append({"a":Vector3(24.1,0,25),"b":Vector3(17,3.5,25),"kind":"PACKING MANTLES"})
	wall(Vector3(10,0,28),Vector3(10,0,31),4,"terracotta")
	wall(Vector3(10,0,31),Vector3(14,0,31),4,"terracotta")
	shortcuts.append({"a":Vector3(9.3,0,29),"b":Vector3(13,3.5,29),"kind":"SERVICE WALL KICK"})
	architecture.cylinder(3,.12,Vector3(22,.06,36),"cyan")
	architecture.label("ARTIFACT DOCK / FINAL",Vector3(22,5,40.5),32,Color("66d6eb"))
	for z: float in [14,26,38]: architecture.arch(Vector3(27,0,z),36,11,.4,"ivory",0,.35,false)
	architecture.piece("box",Vector3(37,.15,30),Vector3(27,11.3,26),"roof_glass")

func _build_spawns() -> void:
	for team: int in 2:
		var rooms: Array[Vector3] = definition.attacker_rooms if team == 0 else definition.defender_rooms
		for index: int in rooms.size():
			var center: Vector3 = rooms[index]
			var yaw: float = definition.spawn_yaw(team,index)
			var basis := Basis(Vector3.UP,yaw)
			var size: Vector2 = definition.spawn_room_size(team,index)
			var half: float = size.x/2
			var depth: float = size.y/2
			var mullion: float = 1.0 if size.x > 10 else .5
			var aperture: float = half-mullion
			for ends: Array in [[Vector3(-half,0,-depth),Vector3(half,0,-depth)],[Vector3(-half,0,-depth),Vector3(-half,0,depth)],[Vector3(half,0,-depth),Vector3(half,0,depth)],[Vector3(-mullion,0,depth),Vector3(mullion,0,depth)]]:
				wall(center+basis*ends[0],center+basis*ends[1],5,"slate")
			slab(center+Vector3.UP*5.2,Vector3(size.y,.4,size.x) if absf(sin(yaw)) > .5 else Vector3(size.x,.4,size.y),"cream")
			for sign_value: float in [-1,1]:
				var offset: float = sign_value*(mullion+aperture/2)
				var door := MuseumSpawnDoor.new()
				door.name = "%s%dDoor%s" % ["A" if team == 0 else "D",index,"Left" if offset < 0 else "Right"]
				door.team = team
				door.stage = index
				door.width = aperture
				door.set_meta("team",team)
				door.set_meta("stage",index)
				door.position = center+basis*Vector3(offset,0,depth)
				door.rotation.y = yaw
				add_child(door)
				spawn_gates.append(door)
				architecture.line(center+basis*Vector3(offset-aperture/2+.2,.03,depth-.15),center+basis*Vector3(offset+aperture/2-.2,.03,depth-.15),.12,"cyan" if team == 0 else "terracotta")
			architecture.label("%s%d / %s STAFF SPAWN" % ["A" if team == 0 else "D",index,"ADMISSIONS" if team == 0 else "CONSERVATION"],center+basis*Vector3(0,4.5,5.5),22,Color("8beaff") if team == 0 else Color("ef9f85"),yaw)

func _build_track() -> void:
	var path: Array[Vector3] = definition.payload_path
	for index: int in range(1,path.size()):
		var side: Vector3 = (path[index]-path[index-1]).normalized().cross(Vector3.UP)*.85
		for sign_value: float in [-1,1]: architecture.line(path[index-1]+side*sign_value+Vector3.UP*.035,path[index]+side*sign_value+Vector3.UP*.035,.075,"brass")
	for index: int in 3:
		architecture.label("CHECKPOINT %d" % (index+1),path[definition.checkpoint_vertices[index]]+Vector3(0,.1,3),26,Color("66d6eb"))
	var c: Vector3 = definition.hill_center
	for z: float in [-7,7]: architecture.line(c+Vector3(-9,.035,z),c+Vector3(9,.035,z),.12,"cyan")
	for x: float in [-9,9]: architecture.line(c+Vector3(x,.035,-7),c+Vector3(x,.035,7),.12,"cyan")

func _build_exhibits() -> void:
	var glass: StandardMaterial3D = architecture.mat("case_glass",Color(.55,.8,.83,.12),0,.15)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for at: Vector3 in [Vector3(-15,0,36),Vector3(-38,0,15),Vector3(-38,0,-33),Vector3(-11,0,-11),Vector3(6,0,-5),Vector3(18,0,-15),Vector3(25,0,19),Vector3(32,0,37)]:
		slab(at+Vector3.UP*.65,Vector3(1.4,1.3,1.4),"ivory")
		architecture.piece("box",Vector3(1.5,2,1.5),at+Vector3.UP*2.3,"case_glass")
		architecture.piece("ring",Vector3(.9,.14,.9),at+Vector3.UP*2,"brass",Vector3(PI/2,.4,0))

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
	nav.filter_baking_aabb = AABB(Vector3(-56.5,-2.5,-50.5),Vector3(113,17,101))
	navigation_region.navigation_mesh = nav
	add_child(navigation_region)
	call_deferred("_bake")

func _bake() -> void:
	await get_tree().physics_frame
	navigation_region.bake_navigation_mesh(true)

func update_gates(preparation: bool) -> void:
	for door: MuseumSpawnDoor in spawn_gates:
		var current: int = definition.attacker_stage if door.team == 0 else definition.defender_stage
		door.configure(door.stage == current,preparation and door.team == 0,door.stage < current)
