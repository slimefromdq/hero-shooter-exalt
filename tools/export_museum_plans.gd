extends SceneTree
## Deterministic vector plans use the same authored collision and route data.
var arena: Node3D
var output: String
var elevated: bool = false

func _initialize() -> void: call_deferred("run")

func point(at: Vector3) -> Vector2:
	return Vector2(400+(at.x+57)*7,220+(at.z+51)*7)

func rect(at: Vector2, size: Vector2, fill: String, stroke: String = "none") -> void:
	output += '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" stroke="%s"/>\n' % [at.x,at.y,size.x,size.y,fill,stroke]

func label(caption: String, at: Vector2, size: int = 16, color: String = "#d8e4e4") -> void:
	output += '<text x="%.1f" y="%.1f" font-size="%d" fill="%s">%s</text>\n' % [at.x,at.y,size,color,caption.xml_escape()]

func line(a: Vector3, b: Vector3, color: String, width: float = 3) -> void:
	var first: Vector2 = point(a)
	var second: Vector2 = point(b)
	output += '<path d="M %.1f %.1f L %.1f %.1f" stroke="%s" stroke-width="%.1f" fill="none"/>\n' % [first.x,first.y,second.x,second.y,color,width]

func circle(at: Vector3, radius: float, fill: String) -> void:
	var p: Vector2 = point(at)
	output += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>\n' % [p.x,p.y,radius,fill]

func export_plan(high: bool) -> void:
	elevated = high
	output = '<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1250" viewBox="0 0 1600 1250"><g font-family="Segoe UI,Arial,sans-serif">\n'
	rect(Vector2.ZERO,Vector2(1600,1250),"#101e2b")
	label("EXALT / MERIDIAN MUSEUM",Vector2(80,75),36,"#efce8c")
	label("ELEVATED ROUTES + MOVEMENT" if high else "GROUND FLOOR + SUNKEN GARDEN",Vector2(80,115),24)
	label("Capture A in three permanent thirds, then escort the artifact to CP1, CP2 and the final CP3.",Vector2(80,157),18)
	label("Gold: payload / stairs   Cyan: skill shortcuts   Green: medical   Gray: solid architecture",Vector2(80,192),17)
	var d: MuseumMapDefinition = arena.definition
	for index: int in 4:
		var area: Rect2 = d.combat_areas[index]
		var a: Vector2 = point(Vector3(area.position.x,0,area.position.y))
		var b: Vector2 = point(Vector3(area.end.x,0,area.end.y))
		rect(a,b-a,["#263e49","#30424e","#294c47","#3e424f"][index])
		label(["A / COURT","CP1 / GIANTS","CP2 / TERRACE","CP3 / VAULT"][index],a+Vector2(5,18),14,"#efce8c")
	for child: Node in arena.builder.architecture.collision_body.get_children():
		var shape := child as CollisionShape3D
		if shape.shape is BoxShape3D:
			var size: Vector3 = shape.shape.size
			var ground: float = 0.0
			if size.x > 90 or size.z > 90 or shape.position.y+size.y/2 <= ground+.2: continue
			var vertices: String = ""
			for corner: Vector3 in [Vector3(-size.x/2,0,-size.z/2),Vector3(size.x/2,0,-size.z/2),Vector3(size.x/2,0,size.z/2),Vector3(-size.x/2,0,size.z/2)]:
				var at: Vector2 = point(shape.transform*corner)
				vertices += "%.1f,%.1f " % [at.x,at.y]
			output += '<polygon points="%s" fill="%s"/>\n' % [vertices,"#94a2a4" if size.y > 3 else "#627b80"]
		elif shape.shape is CylinderShape3D: circle(shape.position,shape.shape.radius*7,"#94a2a4")
	for index: int in range(1,d.payload_path.size()): line(d.payload_path[index-1],d.payload_path[index],"#e6bc71",3)
	rect(point(d.hill_center+Vector3(-9,0,-7)),Vector2(18,14)*7,"none","#64dceb")
	for index: int in 3:
		var at: Vector3 = d.path_position(d.checkpoint_distances()[index])
		circle(at,7,"#64dceb")
		label("CP%d" % (index+1),point(at)+Vector2(0,24),15,"#e7e6d8")
	for stair: Dictionary in arena.builder.stairs: line(stair.a,stair.b,"#e6bc71",4)
	for shortcut: Dictionary in arena.builder.shortcuts:
		line(shortcut.a,shortcut.b,"#64dceb",3)
		if high: label(shortcut.kind,point(shortcut.b)+Vector2(-18,-10),11,"#64dceb")
	if high:
		for entry: Dictionary in d.tactical_routes:
			var points: Array = entry.points
			for index: int in range(1,points.size()): line(points[index-1],points[index],"#91b4db",1.5)
			label(entry.name,point(points[0])+Vector2(3,-6),11,"#91b4db")
		for index: int in 4:
			var at: Vector3 = d.high_positions[index]
			circle(at,8,"#e6bc71")
			label("+%.1f m" % at.y,point(at)+Vector2(-10,-18),17,"#efce8c")
	else:
		for at: Vector3 in d.small_pack_positions: circle(at,4,"#8fe5a5")
		for at: Vector3 in d.large_pack_positions: circle(at,7,"#8fe5a5")
	for team: int in 2:
		var rooms: Array[Vector3] = d.attacker_rooms if team == 0 else d.defender_rooms
		for index: int in rooms.size():
			var room: AABB = d.spawn_room_bounds(team,index)
			rect(point(room.position),Vector2(room.size.x,room.size.z)*7,"#245868" if team == 0 else "#70474b","#64dceb" if team == 0 else "#e6a397")
			label(("A" if team == 0 else "D")+str(index),point(rooms[index])+Vector2(-10,6),18)
	for door: MuseumSpawnDoor in arena.builder.spawn_gates:
		var side: Vector3 = Vector3.RIGHT.rotated(Vector3.UP,door.rotation.y)*door.width/2
		line(door.position-side,door.position+side,"#64dceb" if door.team == 0 else "#e6a397",3)
	line(Vector3(-54,0,46),Vector3(-34,0,46),"#e7e6d8",2)
	label("20 meters",point(Vector3(-54,0,46))+Vector2(0,-12),14)
	var notes: Array[Array] = [["ASTROLABE COURT","18 x 14 m ground capture","Café, cloister, balcony approaches","Planter mantles / wall kicks"],["HALL OF GIANTS","Fossil island breaks both bends","Gallery +4 m / bridge +5.8 m","4 m dash gap / research flank"],["LIVING TERRACE","Garden -1.5 m / roof +4.5 m","Pavilion roof / low garden loop","Three mantle steps / 5 m gap"],["CONSERVATION VAULT","Ground floor / gantry +3.5 m","Packing room and archive loops","Team doors / protected firing"]]
	for index: int in 4:
		var x: float = 80+index*365
		label(notes[index][0],Vector2(x,1020),19,"#efce8c")
		for row: int in range(1,4): label(notes[index][row],Vector2(x,1020+row*29),15)
	label("All primary high ground has ordinary access. Missed shortcuts land on lower playable routes.",Vector2(80,1185),18,"#8fe5a5")
	label("A0/D0 start · Capture activates A1/D1 · CP1 activates A2/D2 · CP2 activates A3 · CP3 ends the round",Vector2(80,1220),16)
	output += '</g></svg>'
	var file := FileAccess.open("res://docs/maps/museum-%s.svg" % ("elevated" if high else "ground"),FileAccess.WRITE)
	file.store_string(output)

func run() -> void:
	arena = load("res://scenes/museum/meridian_museum.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.match_controller.freeze_ai = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/maps"))
	var start: int = Time.get_ticks_msec()
	while not arena.match_controller.navigation_ready and Time.get_ticks_msec()-start < 30000:
		await physics_frame
		await process_frame
	arena.match_controller.set_physics_process(false)
	var routes: Array[Dictionary] = []
	var d: MuseumMapDefinition = arena.definition
	for team: int in 2:
		var rooms: Array[Vector3] = d.attacker_rooms if team == 0 else d.defender_rooms
		for stage: int in rooms.size():
			var target: Vector3 = d.hill_center+Vector3(5,0,-3) if stage == 0 else d.path_position(0 if stage == 1 else d.checkpoint_distances()[stage-2])
			if team == 1 and stage == 2: target = d.path_position(d.checkpoint_distances()[0])
			var path := NavigationServer3D.map_get_path(arena.get_world_3d().navigation_map,rooms[stage],target,true)
			var length: float = 0
			for index: int in range(1,path.size()): length += path[index-1].distance_to(path[index])
			routes.append({"spawn":("A" if team == 0 else "D")+str(stage),"distance_m":length,"walk_seconds":length/6,"target":str(target),"connected":not path.is_empty() and path[0].distance_to(rooms[stage]) < 1.6 and path[-1].distance_to(target) < 1.6})
	var final_path := NavigationServer3D.map_get_path(arena.get_world_3d().navigation_map,d.defender_rooms[2],d.payload_path[-1],true)
	var final_length: float = 0
	for index: int in range(1,final_path.size()): final_length += final_path[index-1].distance_to(final_path[index])
	routes.append({"spawn":"D2 final return","distance_m":final_length,"walk_seconds":final_length/6,"connected":not final_path.is_empty()})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/validation"))
	var route_file := FileAccess.open("res://docs/validation/museum-routes.json",FileAccess.WRITE)
	route_file.store_string(JSON.stringify(routes,"  "))
	print("MUSEUM ROUTES ",JSON.stringify(routes))
	export_plan(false)
	export_plan(true)
	print("MUSEUM PLANS EXPORTED")
	arena.queue_free()
	for index: int in 4: await process_frame
	quit()
