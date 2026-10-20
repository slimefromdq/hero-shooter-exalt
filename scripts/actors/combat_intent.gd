class_name CombatIntent
extends RefCounted

var move: Vector3 = Vector3.ZERO
## Optional world-space flight wish; INF means use legacy horizontal movement.
var flight_move: Vector3 = Vector3.INF
var aim: Vector3 = Vector3.FORWARD
var aim_origin: Vector3 = Vector3.ZERO
var primary: bool = false
var primary_held: bool = false
var secondary_held: bool = false
var secondary_pressed: bool = false
var projectile_fire: bool = false
var aim_held: bool = false
var jump: bool = false
var jump_held: bool = false
var dash: bool = false
var slide: bool = false
var slide_pressed: bool = false
var reload: bool = false
var melee: bool = false
var stationary_melee: bool = false
var guard: bool = false
var throw_action: bool = false
var hover: bool = false
var deflect: bool = false
var bomb: bool = false
var ultimate: bool = false
