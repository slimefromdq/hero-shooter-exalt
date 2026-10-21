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
		for at: Vector3 in [Vector3(24,-8,130),Vector3(104,0,90),Vector3(-20,20,48),Vector3(112,0,76),Vector3(148,-4,4),Vector3(-72,32,8)]:
			small_pack_positions.append(mirror(at,sign_value)+Vector3.UP*.1)
		for at: Vector3 in [Vector3(76,-8,130),Vector3(148,-4,24),Vector3(-8,20,56)]:
			large_pack_positions.append(mirror(at,sign_value)+Vector3.UP*.1)

static func mirror(at: Vector3, sign_value: float) -> Vector3:
	return Vector3(at.x*sign_value,at.y,at.z*sign_value)

func surface_position(at: Vector3) -> Vector3:
	# Terrace aprons meet descending paths smoothly outside the solid court slabs.
	# This also keeps a low route from accidentally tunnelling through a court edge.
	var result: Vector3 = at
	for center: Vector3 in POINTS:
		var dx: float = maxf(0,absf(at.x-center.x)-36)
		var dz: float = maxf(0,absf(at.z-center.z)-32)
		var outside: float = Vector2(dx,dz).length()
		if outside < 48: result.y = maxf(result.y,center.y-outside*.7)
	return result

func room_center(team: int, stage: int) -> Vector3:
	return mirror([Vector3(-98,0,120),Vector3(136,8,62),Vector3(0,16,104)][stage],1 if team == 0 else -1)

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

## All paths are bidirectional. Separate floors/walls, not imaginary open-side lanes.
func connections() -> Array[Dictionary]:
	var authored: Array[Dictionary] = [
		{"sector":0,"kind":"main","width":28.0,"points":[Vector3(-24,0,108),Vector3(2,0,104),Vector3(28,8,80),Vector3(36,8,70)]},
		{"sector":0,"kind":"lower","width":16.0,"points":[Vector3(-24,0,124),Vector3(24,-8,130),Vector3(90,-8,130),Vector3(112,8,94),Vector3(92,8,90),Vector3(76,8,70)]},
		{"sector":0,"kind":"upper","width":16.0,"points":[Vector3(-70,0,90),Vector3(-84,12,50),Vector3(-20,20,48),Vector3(64,20,16),Vector3(104,20,114),Vector3(76,20,114),Vector3(76,8,70)]},
		{"sector":1,"kind":"main","width":28.0,"points":[Vector3(52,8,62),Vector3(100,16,62),Vector3(100,16,16),Vector3(40,16,-16),Vector3(20,16,0),Vector3(14,16,12),Vector3(0,16,12),Vector3(0,16,0)]},
		{"sector":1,"kind":"lower","width":16.0,"points":[Vector3(84,8,62),Vector3(112,0,76),Vector3(148,-4,40),Vector3(148,-4,-4),Vector3(72,-4,-12),Vector3(104,-4,-48),Vector3(40,16,-40),Vector3(0,16,-28)]},
		{"sector":1,"kind":"upper","width":16.0,"points":[Vector3(28,8,56),Vector3(-8,20,56),Vector3(-8,20,24),Vector3(-8,32,-20),Vector3(-72,32,8),Vector3(0,16,-28)]}
	]
	var result: Array[Dictionary] = []
	for half: int in 2:
		for entry: Dictionary in authored:
			var copy: Dictionary = entry.duplicate(true)
			copy["points"] = []
			for at: Vector3 in entry.points: copy.points.append(mirror(at,1 if half == 0 else -1))
			if half == 1:
				copy.points.reverse()
				copy.sector = 3-entry.sector
			result.append(copy)
	return result

func route_points(_team: int, _role: String) -> Array[Vector3]:
	return []
