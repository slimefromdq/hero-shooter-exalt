class_name MuseumMapDefinition
extends CityMapDefinition
## Authored meters/seconds. Runtime ownership never lives in this shared resource.
@export var preparation_seconds: float = 30.0
@export var round_seconds: float = 240.0
@export var unlock_bonus: float = 180.0
@export var checkpoint_bonus: float = 90.0
@export var capture_durations: PackedFloat32Array = PackedFloat32Array([30,24,20])
@export var escort_speeds: PackedFloat32Array = PackedFloat32Array([1.5,1.8,2])
@export var decay_delay: float = 5.0
@export var rollback_delay: float = 10.0
@export var rollback_speed: float = .5
@export var overtime_grace: float = 3.0
@export var escort_radius: float = 5.0
@export var escort_height: float = 2.0
@export var payload_path: Array[Vector3] = [Vector3(-17,0,19),Vector3(-17,0,3),Vector3(-28,0,3),Vector3(-28,0,-13),Vector3(-20,0,-13),Vector3(-20,0,-22),Vector3(-7,0,-22),Vector3(8,0,-22),Vector3(8,0,-28),Vector3(25,0,-28),Vector3(25,0,-12),Vector3(33,0,-12),Vector3(33,0,3),Vector3(33,0,16),Vector3(41,0,16),Vector3(41,0,29),Vector3(22,0,29),Vector3(22,0,36)]
@export var checkpoint_vertices: PackedInt32Array = PackedInt32Array([6,12,17])
@export var attacker_rooms: Array[Vector3] = [Vector3(-49,0,-25),Vector3(-49,0,-7),Vector3(-49,0,27),Vector3(5,0,-44)]
@export var defender_rooms: Array[Vector3] = [Vector3(-12,0,-44),Vector3(29,0,-44),Vector3(49,0,-43)]
@export var attacker_room_sizes: Array[Vector2] = [Vector2(14,10),Vector2(8,10),Vector2(14,10),Vector2(14,10)]
@export var attacker_yaws: PackedFloat32Array = PackedFloat32Array([1.5707963,0,1.5707963,0])
@export var defender_yaws: PackedFloat32Array = PackedFloat32Array([0,0,0])
@export var high_positions: Array[Vector3] = [Vector3(-32,3.6,12),Vector3(-26,5.8,-4),Vector3(15,4.5,-10),Vector3(17,3.5,23)]
@export var flank_positions: Array[Vector3] = [Vector3(-16,0,33),Vector3(-11,0,-10),Vector3(39,-1.5,-23),Vector3(13,0,35)]
@export var map_bounds: Rect2 = Rect2(-57,-51,114,102)
@export var combat_areas: Array[Rect2] = [Rect2(-46,8,36,32),Rect2(-42,-38,38,42),Rect2(2,-38,42,42),Rect2(8,10,38,32)]
# Named entry/intermediate/exit routes. Every node has ordinary navigation access.
@export var approach_positions: Array[PackedVector3Array] = [
 PackedVector3Array([Vector3(-45,0,17),Vector3(-39,0,25),Vector3(-16,0,29)]),
 PackedVector3Array([Vector3(-28,0,2),Vector3(-39,0,-8),Vector3(-12,0,-6)]),
 PackedVector3Array([Vector3(4,0,-22),Vector3(3,0,-10),Vector3(39,0,-11)]),
 PackedVector3Array([Vector3(33,0,12),Vector3(13,0,13),Vector3(13,0,35)])
]
@export var tactical_routes: Array[Dictionary] = [
 {"name":"Cafe balcony","sector":0,"kind":"high_ground","points":[Vector3(-39,0,25),Vector3(-39,3.6,14),Vector3(-32,3.6,12),Vector3(-23,3.6,14),Vector3(-23,0,25)]},
 {"name":"Sculpture cloister","sector":0,"kind":"flank","points":[Vector3(-37,0,35),Vector3(-27,0,35),Vector3(-16,0,33),Vector3(-15,0,24)]},
 {"name":"Education bridge","sector":1,"kind":"high_ground","hold_index":4,"points":[Vector3(-39,0,-8),Vector3(-39,4,-20),Vector3(-34,4,-22),Vector3(-34,5.8,-7),Vector3(-26,5.8,-4),Vector3(-7,0,-5)]},
 {"name":"Research suite","sector":1,"kind":"flank","points":[Vector3(-13,0,0),Vector3(-11,0,-10),Vector3(-11,0,-20),Vector3(-7,0,-22)]},
 {"name":"Pavilion roof","sector":2,"kind":"high_ground","points":[Vector3(5,0,-10),Vector3(15,4.5,-10),Vector3(19,4.5,-10),Vector3(19,4.5,0),Vector3(29,0,0)]},
 {"name":"Sunken garden","sector":2,"kind":"flank","points":[Vector3(39,0,-34),Vector3(39,-1.5,-27),Vector3(39,-1.5,-23),Vector3(39,-1.5,-19),Vector3(39,0,-12),Vector3(39,0,0)]},
 {"name":"Restoration gantry","sector":3,"kind":"high_ground","points":[Vector3(13,0,13),Vector3(13,3.5,23),Vector3(17,3.5,23),Vector3(17,3.5,30),Vector3(17,0,40)]},
 {"name":"Low archive","sector":3,"kind":"flank","points":[Vector3(10,0,15),Vector3(10,0,25),Vector3(13,0,35),Vector3(12,0,40),Vector3(22,0,40),Vector3(22,0,36)]}
]
var attacker_stage: int = 0
var defender_stage: int = 0

func _init() -> void:
	map_title = "Meridian Museum"
	district_size = Vector2(114,102)
	hill_center = Vector3(-28,0,25)
	hill_half_extents = Vector3(9,1.1,7)
	hill_min_height = -.2
	hill_max_height = 1.1
	small_pack_positions = [Vector3(-39,0,30),Vector3(-16,0,35),Vector3(-38,0,-30),Vector3(-11,0,-9),Vector3(6,0,-34),Vector3(40.5,-1.5,-24),Vector3(17,0,12),Vector3(43,0,38)]
	large_pack_positions = [Vector3(-43,0,14),Vector3(-10,0,-33),Vector3(40.5,-1.5,-20),Vector3(12,0,36)]

func spawn_yaw(team: int, stage: int = -1) -> float:
	if stage < 0: stage = attacker_stage if team == 0 else defender_stage
	return attacker_yaws[stage] if team == 0 else defender_yaws[stage]

func spawn_room_size(team: int, stage: int) -> Vector2:
	return attacker_room_sizes[stage] if team == 0 else Vector2(14,10)

func spawn_room_bounds(team: int, stage: int) -> AABB:
	var at: Vector3 = (attacker_rooms if team == 0 else defender_rooms)[stage]
	var turned: bool = absf(sin(spawn_yaw(team,stage))) > .5
	var size: Vector2 = spawn_room_size(team,stage)
	var half := Vector3(size.y/2,.3,size.x/2) if turned else Vector3(size.x/2,.3,size.y/2)
	return AABB(at-half,Vector3(half.x*2,4.8,half.z*2))

func tactical_route(sector_index: int, kind: String) -> Dictionary:
	for entry: Dictionary in tactical_routes:
		if entry.sector == sector_index and entry.kind == kind: return entry
	return {}

func spawn_center(team: int) -> Vector3:
	return attacker_rooms[attacker_stage] if team == 0 else defender_rooms[defender_stage]

func spawn_bounds(team: int) -> AABB:
	return spawn_room_bounds(team,attacker_stage if team == 0 else defender_stage)

func team_spawns(team: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for slot: int in 6:
		result.append(spawn_center(team)+Vector3((slot%3-1)*2,.08,(slot/3-.5)*2).rotated(Vector3.UP,spawn_yaw(team)))
	return result

func route_points(_team: int, _role: String) -> Array[Vector3]:
	return []

func checkpoint_distances() -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var distance: float = 0
	for index: int in range(1,payload_path.size()):
		distance += payload_path[index-1].distance_to(payload_path[index])
		if index in checkpoint_vertices: result.append(distance)
	return result

func path_position(distance: float) -> Vector3:
	for index: int in range(1,payload_path.size()):
		var length: float = payload_path[index-1].distance_to(payload_path[index])
		if distance <= length: return payload_path[index-1].lerp(payload_path[index],maxf(0,distance)/length)
		distance -= length
	return payload_path[-1]

func sector(distance: float, escort: bool) -> int:
	if not escort: return 0
	var marks := checkpoint_distances()
	return 1 if distance < marks[0] else (2 if distance < marks[1] else 3)
