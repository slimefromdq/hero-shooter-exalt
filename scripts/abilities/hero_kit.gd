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
var reloading: bool = false
var reload_remaining: float = 0.0
var reload_total: float = 0.0

## Read-only acquisition previews: target plus InputMap action. Empty for non-select kits.
## Implementations share the same target selection and admission checks as their casts.
func selection_previews() -> Array[Dictionary]:
	return []

func ultimate_active() -> bool:
	return false

func primary_interval(base: float = -1.0) -> float:
	return (actor.tuning.shot_interval if base < 0 else base) / actor.benefits.fire_rate_multiplier()

func start_reload() -> void:
	if reloading or ammo >= actor.tuning.magazine or not actor.permits("reload"): return
	reloading = true
	reload_total = actor.tuning.reload_time
	if actor.tuning is SlayerTuning:
		var t := actor.tuning as SlayerTuning
		reload_total = t.reload_start + t.shell_time * (t.magazine - ammo)
	reload_remaining = reload_total
	actor.resolver.record("cast",actor,"reload")

func tick_reload(delta: float) -> void:
	if not reloading: return
	var previous: float = reload_remaining
	reload_remaining = maxf(0,reload_remaining-delta)
	if actor.tuning is SlayerTuning:
		var t := actor.tuning as SlayerTuning
		var before: int = maxi(0,int(floor((reload_total-previous-t.reload_start + .000001)/t.shell_time)))
		var after: int = maxi(0,int(floor((reload_total-reload_remaining-t.reload_start + .000001)/t.shell_time)))
		ammo = mini(t.magazine,ammo+after-before)
	if reload_remaining <= 0:
		ammo = actor.tuning.magazine
		reloading = false

func free_slide_ammo() -> bool:
	return actor.motor.mode == "slide" and actor.motor.grounded() and actor.intent.slide and ammo > 0 and not reloading

func consume_ammo() -> void:
	if not actor.infinite_resources and not free_slide_ammo(): ammo -= 1

func tick(_delta: float, _input: CombatIntent) -> void:
	pass

func move_override(_delta: float) -> bool:
	return false

func movement_scale() -> float:
	return 1.0

func fire(_ultimate: bool) -> void:
	pass

func fire_projectile(direction: Vector3) -> void:
	if not actor.permits("primary") or shot_cd > 0.0:
		return
	var projectile := CombatProjectile.new()
	projectile.source = actor
	projectile.direction = direction
	projectile.cast_id = actor.resolver.new_cast(actor)
	actor.get_parent().add_child(projectile)
	projectile.global_position = safe_muzzle()
	shot_cd = 1.1
	actor.resolver.record("cast", actor, "projectile")

func safe_muzzle() -> Vector3:
	var shoulder: Vector3 = actor.body_point(1.36)
	var obstruction: Dictionary = actor.resolver.ray(shoulder, actor.muzzle(), [actor.get_rid()], 1)
	if not obstruction.is_empty():
		return obstruction["position"] + obstruction["normal"] * 0.16
	return actor.muzzle()

func cancel(clear_owned: bool = false) -> void:
	if clear_owned:
		reloading = false
		reload_remaining = 0
	if actor.state in ["reload", "deflect", "ultimate"] or actor.state.begins_with("slayer_"):
		actor.state = "ready"
	ultimate_age = 0.0
	if clear_owned:
		for effect: Node in actor.get_tree().get_nodes_in_group("owned_attacks"):
			if effect.get("source") == actor:
				effect.set_physics_process(false)
				effect.queue_free()

func refill() -> void:
	reloading = false
	reload_remaining = 0
	ammo = actor.tuning.magazine
	shot_cd = 0.0
	deflect_cd = 0.0
	bomb_cd = 0.0
	ultimate_charge = 100.0

func reset_life() -> void:
	refill()
