class_name HeroKit
extends Node
## Shared kit contract. Movement, close combat and damage stay on their existing owners.
var actor: HeroActor
var ammo: int = 8
var shot_cd: float = 0.0
var deflect_cd: float = 0.0
var bomb_cd: float = 0.0
var ultimate_charge: float = 100.0
var ultimate_age: float = 0.0
var cast_id: int = 0

func tick(_delta: float, _input: CombatIntent) -> void:
	pass

func move_override(_delta: float) -> bool:
	return false

func fire(_ultimate: bool) -> void:
	pass

func fire_projectile(direction: Vector3) -> void:
	if not actor.permits("primary") or shot_cd > 0.0:
		return
	var projectile := CombatProjectile.new()
	projectile.source = actor
	projectile.direction = direction
	projectile.cast_id = actor.resolver.new_cast()
	actor.get_parent().add_child(projectile)
	projectile.global_position = safe_muzzle()
	shot_cd = 1.1
	actor.resolver.record("cast", actor, "projectile")

func safe_muzzle() -> Vector3:
	var shoulder: Vector3 = actor.global_position + Vector3.UP * 1.36
	var obstruction: Dictionary = actor.resolver.ray(shoulder, actor.muzzle(), [actor.get_rid()], 1)
	if not obstruction.is_empty():
		return obstruction["position"] + obstruction["normal"] * 0.16
	return actor.muzzle()

func cancel(clear_owned: bool = false) -> void:
	if actor.state in ["reload", "deflect", "ultimate"] or actor.state.begins_with("slayer_"):
		actor.state = "ready"
	ultimate_age = 0.0
	if clear_owned:
		for effect: Node in actor.get_tree().get_nodes_in_group("owned_attacks"):
			if effect.get("source") == actor:
				effect.queue_free()

func refill() -> void:
	ammo = actor.tuning.magazine
	shot_cd = 0.0
	deflect_cd = 0.0
	bomb_cd = 0.0
	ultimate_charge = 100.0
