class_name CityMapDefinition
extends Resource

## Gameplay landmarks are data, independent of the architecture used to draw them.
@export var map_title: String = "Meridian Gardens"
@export var district_size: Vector2 = Vector2(144.0, 132.0)
@export var hill_center: Vector3 = Vector3.ZERO
@export var hill_half_extents: Vector3 = Vector3(10.0, 2.5, 9.0)
@export var hill_min_height: float = -0.25
@export var hill_max_height: float = 2.5
@export var unlock_seconds: float = 20.0
@export var capture_seconds: float = 5.0
@export var score_per_second: float = 1.0
@export var score_to_win: float = 100.0
@export var respawn_seconds: float = 8.0
@export var south_spawns: Array[Vector3] = [Vector3(0, 0.08, 62), Vector3(-8, 0.08, 60), Vector3(-4, 0.08, 62), Vector3(4, 0.08, 62), Vector3(8, 0.08, 60), Vector3(0, 0.08, 64)]
@export var north_spawns: Array[Vector3] = [Vector3(0, 0.08, -62), Vector3(8, 0.08, -60), Vector3(4, 0.08, -62), Vector3(-4, 0.08, -62), Vector3(-8, 0.08, -60), Vector3(0, 0.08, -64)]
@export var spawn_half_extents: Vector3 = Vector3(12.0, 4.0, 6.0)
@export var spawn_min_height: float = -5.5
@export var spawn_max_height: float = 4.0
@export var small_pack_positions: Array[Vector3] = [Vector3(-24, 0, -28), Vector3(24, 0, -28), Vector3(-24, 0, 28), Vector3(24, 0, 28), Vector3(0, -5, -18), Vector3(0, -5, 18)]
@export var large_pack_positions: Array[Vector3] = [Vector3(-34, 0, 0), Vector3(34, 0, 0)]
@export var district_labels: Dictionary = {"Meridian Conservatory": Vector3(0, 0, 0), "Crown Station": Vector3(0, 0, -60), "Lantern Court": Vector3(0, 0, 60), "Garden Walk": Vector3(-34, 0, 0), "Lantern Market": Vector3(34, 0, 0), "Lower Meridian": Vector3(0, -5, 18), "Arcane Viaduct": Vector3(20, 6.5, 0)}
@export var navigation_region_path: NodePath = NodePath("MeridianGardensEnvironment/CityNavigation")
@export var shopping_arcade_bounds: AABB = AABB(Vector3(-21, -5, -21), Vector3(42, 4.3, 42))
@export var shopping_arcade_shops: Array[Vector3] = [Vector3(-12,-5,-10), Vector3(-12,-5,0), Vector3(-12,-5,10), Vector3(12,-5,-10), Vector3(12,-5,0), Vector3(12,-5,10)]

func team_spawns(team: int) -> Array[Vector3]:
	return south_spawns if team == 0 else north_spawns

func spawn_center(team: int) -> Vector3:
	return Vector3(0, 0, 60 if team == 0 else -60)

func spawn_bounds(team: int) -> AABB:
	var center: Vector3 = spawn_center(team)
	return AABB(Vector3(-spawn_half_extents.x, spawn_min_height, center.z - spawn_half_extents.z), Vector3(spawn_half_extents.x * 2, spawn_max_height - spawn_min_height, spawn_half_extents.z * 2))

## Routes lead into the hill; navigation supplies collision-safe stair and ramp paths.
func route_points(team: int, role: String) -> Array[Vector3]:
	var sign_z: float = 1.0 if team == 0 else -1.0
	var result: Array[Vector3] = []
	match role:
		"flank_left":
			result.assign([Vector3(-8, 0, 51), Vector3(-30, 0, 30), Vector3(-26, 0, 15), Vector3(-10, 0, 9), Vector3(-8, 0, 7)])
		"flank_right":
			result.assign([Vector3(8, 0, 51), Vector3(30, 0, 30), Vector3(26, 0, 15), Vector3(10, 0, 9), Vector3(8, 0, 7)])
		"frontline_subway":
			result.assign([Vector3(0, 0, 58), Vector3(0, -5, 38), Vector3(0, -5, 18), Vector3(6, -5, 0), Vector3(0, -5, -9), Vector3(0, 0, -25), Vector3(6, 0, -26), Vector3(4, 0, -13), Vector3(4, 0, -4)])
		"high_ground":
			result.assign([Vector3(8, 0, 51), Vector3(42, 0, 51), Vector3(42, 0, 46), Vector3(42, 6.5, 20), Vector3(23, 6.5, 20), Vector3(23, 6.5, 0), Vector3(14, 0, 0), Vector3(6, 0, 0)])
		_:
			result.assign([Vector3(7, 0, 51), Vector3(7, 0, 40), Vector3(6, 0, 26), Vector3(4, 0, 13), Vector3(4, 0, 4)])
	for index: int in result.size():
		result[index].z *= sign_z
		if role == "high_ground" and team == 1:
			result[index].x *= -1.0
	return result
