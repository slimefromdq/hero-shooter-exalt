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
@export var payload_path: Array[Vector3] = [Vector3(12,0,0),Vector3(24,0,0),Vector3(24,0,-10),Vector3(44,0,-10),Vector3(44,0,0),Vector3(62,0,0),Vector3(72,0,0),Vector3(72,0,12),Vector3(92,0,12),Vector3(92,0,0),Vector3(108,1.5,0),Vector3(118,1.5,0),Vector3(118,1.5,-12),Vector3(138,1.5,-12),Vector3(138,1.5,0),Vector3(154,1.5,0)]
@export var checkpoint_vertices: PackedInt32Array = PackedInt32Array([5,10,15])
@export var attacker_rooms: Array[Vector3] = [Vector3(-52,0,0),Vector3(-24,0,30),Vector3(29,0,30),Vector3(92,0,30)]
@export var defender_rooms: Array[Vector3] = [Vector3(64,0,-30),Vector3(84,0,-30),Vector3(130,1.5,-30)]
@export var high_positions: Array[Vector3] = [Vector3(-5,3.6,-15),Vector3(38,4,17),Vector3(83,4.5,-17),Vector3(131,5,17)]
@export var flank_positions: Array[Vector3] = [Vector3(-8,0,17),Vector3(42,0,-20),Vector3(83,-1.5,20),Vector3(133,1.5,-20)]
var attacker_stage: int = 0
var defender_stage: int = 0

func _init() -> void:
	map_title = "Meridian Museum"
	district_size = Vector2(252,88)
	hill_center = Vector3.ZERO
	hill_half_extents = Vector3(9,1.1,7)
	hill_min_height = -.2
	hill_max_height = 1.1
	small_pack_positions = [Vector3(-14,0,22),Vector3(10,0,-23),Vector3(29,0,20),Vector3(54,0,-20),Vector3(76,-1.5,20),Vector3(99,0,-19),Vector3(119,1.5,20),Vector3(146,1.5,-20)]
	large_pack_positions = [Vector3(-18,0,-23),Vector3(48,0,24),Vector3(90,-1.5,20),Vector3(145,1.5,22)]

func spawn_center(team: int) -> Vector3:
	return attacker_rooms[attacker_stage] if team == 0 else defender_rooms[defender_stage]

func spawn_bounds(team: int) -> AABB:
	return AABB(spawn_center(team)-Vector3(7,.3,5),Vector3(14,4.8,10))

func team_spawns(team: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for slot: int in 6:
		result.append(spawn_center(team)+Vector3((slot%3-1)*2,.08,(slot/3-.5)*2))
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
