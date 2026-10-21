class_name TempleMapDefinition
extends CityMapDefinition
## Immutable layout. Ownership, progress and forward-spawn stages live in TempleMatch.
const POINTS: Array[Vector3] = [Vector3(-48,0,108),Vector3(52,8,62),Vector3(0,16,0),Vector3(-52,8,-62),Vector3(48,0,-108)]
const TITLES: Array[String] = ["A / ROOT SANCTUARY","B / BLOSSOM TERRACES","C / SKYBELL CROSSING","D / BLOSSOM TERRACES","E / CLOUD SANCTUARY"]
const CAPTURE_SIZE := Vector2(40,36)
const COURT_SIZE := Vector2(72,64)
const KILL_HEIGHT: float = -48.0
const ROOM_SIZE := Vector3(26,6,16)

func _init() -> void:
	map_title = "Sakura Veil"
	district_size = Vector2(320,288)
	hill_center = POINTS[2]
	hill_half_extents = Vector3(20,2.5,18)
	small_pack_positions = []
	large_pack_positions = []
	for sign_value: float in [1,-1]:
		for at: Vector3 in [Vector3(-72,0,108),Vector3(0,0,108),Vector3(76,8,62),Vector3(116,16,16),Vector3(148,-4,16),Vector3(-80,16,38)]:
			small_pack_positions.append(mirror(at,sign_value)+Vector3.UP*.1)
		for at: Vector3 in [Vector3(76,-8,128),Vector3(100,4,-64),Vector3(52,16,88)]:
			large_pack_positions.append(mirror(at,sign_value)+Vector3.UP*.1)

static func mirror(at: Vector3, sign_value: float) -> Vector3:
	return Vector3(at.x*sign_value,at.y,at.z*sign_value)

func surface_position(at: Vector3) -> Vector3:
	# Authored floors are never displaced by a nearby court.
	return at

func room_center(team: int, stage: int) -> Vector3:
	return mirror([Vector3(-98,0,120),Vector3(136,8,74),Vector3(-92,16,-16)][stage],1 if team == 0 else -1)

func room_bounds(team: int, stage: int) -> AABB:
	return AABB(room_center(team,stage)-Vector3(13,.3,8),ROOM_SIZE+Vector3(0,.3,0))

func spawn_center(team: int) -> Vector3:
	return room_center(team,0)

func spawn_bounds(team: int) -> AABB:
	return room_bounds(team,0)

func spawns(team: int, stage: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for slot: int in 6:
		result.append(room_center(team,stage)+Vector3((slot%3-1)*3,.12,(slot/3)*2-1))
	return result

func team_spawns(team: int) -> Array[Vector3]:
	return spawns(team,0)

func contains_point(index: int, at: Vector3) -> bool:
	var offset: Vector3 = at-POINTS[index]
	return absf(offset.x) <= 20 and absf(offset.z) <= 18 and offset.y >= -.25 and offset.y <= 2.5

## Axis-aligned segments have flat junctions; stair runs own their landings.
func connections() -> Array[Dictionary]:
	var authored: Array[Dictionary] = [
		{"sector":0,"kind":"main","width":12.0,"points":[Vector3(-24,0,108),Vector3(0,0,108),Vector3(0,0,96),Vector3(0,8,62),Vector3(28,8,62)]},
		{"sector":1,"kind":"main","width":12.0,"points":[Vector3(76,8,62),Vector3(116,8,62),Vector3(116,16,28),Vector3(116,16,0),Vector3(24,16,0)]},
		{"sector":0,"kind":"lower","width":12.0,"points":[Vector3(-24,0,120),Vector3(-12,0,120),Vector3(26,-8,120),Vector3(26,-8,128),Vector3(114,-8,128),Vector3(148,0,128),Vector3(148,0,92),Vector3(114,8,92),Vector3(114,8,62),Vector3(76,8,62)]},
		{"sector":1,"kind":"lower","width":12.0,"points":[Vector3(76,8,46),Vector3(88,8,46),Vector3(148,-4,46),Vector3(148,-4,-30),Vector3(100,-4,-30),Vector3(100,4,-64),Vector3(48,16,-64),Vector3(0,16,-64),Vector3(0,16,-18)]},
		{"sector":0,"kind":"upper","width":8.0,"points":[Vector3(-76,0,94),Vector3(-120,0,94),Vector3(-120,16,38),Vector3(-48,16,38),Vector3(-48,16,52),Vector3(52,16,52),Vector3(52,16,88)]},
		{"sector":1,"kind":"upper","width":8.0,"points":[Vector3(52,8,46),Vector3(52,8,34),Vector3(52,16,2),Vector3(52,16,-8),Vector3(52,24,-42),Vector3(0,24,-42),Vector3(0,24,-26)]}
	]
	var result: Array[Dictionary] = []
	for half: int in 2:
		for entry: Dictionary in authored:
			var copy: Dictionary = entry.duplicate(true)
			copy.points = []
			for at: Vector3 in entry.points: copy.points.append(mirror(at,1 if half == 0 else -1))
			if half == 1:
				copy.points.reverse()
				copy.sector = 3-entry.sector
			copy["id"] = "%d_%s" % [copy.sector,copy.kind]
			result.append(copy)
	return result

func galleries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in 5:
		for side: float in [-1,1]:
			result.append({"id":"gallery_%d_%d" % [index,int(side)],"point":index,"center":POINTS[index]+Vector3(0,8,side*26),"size":Vector2(28,12)})
	return result

func spawn_routes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for team: int in 2:
		var sign_value: float = 1 if team == 0 else -1
		for stage: int in 3:
			for door_side: float in [-1,1]:
				var c: Vector3 = room_center(0,stage)
				var exit: Vector3 = c+Vector3(door_side*6,0,-14)
				var points: Array = [c+Vector3(door_side*6,0,0),exit,Vector3(c.x,exit.y,exit.z)]
				if stage == 0:
					points.append(Vector3(-98,0,108))
					points.append(Vector3(-76,0,108))
				elif stage == 1:
					points.append(Vector3(136,8,62))
					points.append(Vector3(116,8,62))
				else:
					points.append(Vector3(-112,16,-30))
					points.append(Vector3(-112,16,0))
					points.append(Vector3(-24,16,0))
				for i: int in points.size(): points[i] = mirror(points[i],sign_value)
				result.append({"id":"spawn_%d_%d_%d" % [team,stage,int(door_side)],"kind":"spawn","sector":-1,"width":8.0,"points":points})
	return result

func jump_pads() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var authored: Array = [
		[0,"lower",Vector3(76,-8,128),Vector3(76,8,72),2.5],
		[0,"upper",Vector3(76,8,46),Vector3(52,16,88),2.3],
		[1,"lower",Vector3(148,-4,0),Vector3(116,16,0),2.4],
		[1,"upper",Vector3(100,16,0),Vector3(0,24,-26),3.2]]
	for side: float in [1,-1]:
		for entry: Array in authored:
			var sector: int = entry[0] if side > 0 else 3-entry[0]
			var destination: Vector3 = mirror(entry[3],side)
			result.append({"id":"pad_%d_%s" % [sector,entry[1]],"sector":sector,"kind":entry[1],"position":mirror(entry[2],side),"destination":destination,"flight_time":entry[4],"landing":AABB(destination-Vector3(4,0,4),Vector3(8,3,8))})
	return result

func route_points(_team: int, _role: String) -> Array[Vector3]:
	return []

func rest_bays() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for side: float in [1,-1]:
		for at: Vector3 in [Vector3(156,0,112),Vector3(-72,0,140)]:
			result.append({"center":mirror(at,side),"size":Vector2(8,8)})
	return result
