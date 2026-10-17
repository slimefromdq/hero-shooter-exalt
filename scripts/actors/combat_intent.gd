class_name CombatIntent
extends RefCounted

var move: Vector3 = Vector3.ZERO
var aim: Vector3 = Vector3.FORWARD
var aim_origin: Vector3 = Vector3.ZERO
var primary: bool = false
var projectile_fire: bool = false
var aim_held: bool = false
var jump: bool = false
var jump_held: bool = false
var dash: bool = false
var slide: bool = false
var reload: bool = false
var melee: bool = false
var stationary_melee: bool = false
var guard: bool = false
var throw_action: bool = false
var hover: bool = false
var deflect: bool = false
var bomb: bool = false
var ultimate: bool = false
