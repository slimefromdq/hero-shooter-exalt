class_name CareKit
extends HeroKit
## Shared small weapon/reload lifecycle for the two new heroes.
var mobility_cd: float = 0.0

func tick_common(delta: float) -> void:
	shot_cd = maxf(0,shot_cd - delta)
	mobility_cd = maxf(0,mobility_cd - delta)
	deflect_cd = maxf(0,deflect_cd - delta)
	bomb_cd = maxf(0,bomb_cd - delta)
	ultimate_charge = minf(100,ultimate_charge + delta * .8)
	if actor.infinite_resources:
		ammo = actor.tuning.magazine
		mobility_cd = 0
		deflect_cd = 0
		bomb_cd = 0
		ultimate_charge = 100
	if actor.state == "reload" and actor.state_time <= 0:
		ammo = actor.tuning.magazine
		actor.state = "ready"

func reload_weapon() -> void:
	if actor.permits("reload") and ammo < actor.tuning.magazine:
		actor.state = "reload"
		actor.state_time = actor.tuning.reload_time
		actor.resolver.record("cast",actor,"reload")

func weapon(amount: float, spread: float = 0.0, pellets: int = 1) -> void:
	if not actor.permits("primary") or shot_cd > 0: return
	if ammo <= 0:
		reload_weapon()
		return
	ammo -= 1
	shot_cd = actor.tuning.shot_interval
	var origin: Vector3 = actor.intent.aim_origin
	if origin == Vector3.ZERO: origin = actor.global_position + Vector3.UP * 1.6
	var view: Dictionary = actor.resolver.ray(origin,origin + actor.aim_direction * 70,[actor.get_rid()])
	var end: Vector3 = view.get("position",origin + actor.aim_direction * 70)
	var muzzle: Vector3 = safe_muzzle()
	var direction: Vector3 = (end - muzzle).normalized()
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	if right.is_zero_approx(): right = Vector3.RIGHT
	var up: Vector3 = right.cross(direction)
	for index: int in pellets:
		var radius: float = sqrt((index + .5) / pellets) * tan(deg_to_rad(spread))
		var angle: float = index * 2.39996323
		var aim: Vector3 = (direction + (right * cos(angle) + up * sin(angle)) * radius).normalized()
		var hit: Dictionary = actor.resolver.attack_ray(actor,muzzle,muzzle + aim * 70,[actor.get_rid()])
		var endpoint: Vector3 = hit.get("position",muzzle + aim * 70)
		var id: int = actor.resolver.new_cast(actor)
		var damage: float = amount / pellets
		if actor.tuning is MarshalTuning:
			var t := actor.tuning as MarshalTuning
			damage *= lerpf(1,t.cannon_minimum,clampf((muzzle.distance_to(endpoint) - t.cannon_falloff_start) / (t.cannon_falloff_end - t.cannon_falloff_start),0,1))
		var target: HeroActor = hit.get("collider") as HeroActor
		if target != null:
			var head: bool = endpoint.y - target.global_position.y >= 1.5
			actor.resolver.damage(actor,target,damage * (actor.tuning.head_multiplier if head else 1.0),"cannon" if pellets > 1 else "sidearm",id,head,false,muzzle)
		elif hit.get("collider") is CombatBarrier or hit.get("collider") is HunterSnare:
			hit.collider.receive_damage(actor,damage,id)
		CombatEffect.line(actor.get_parent(),muzzle,endpoint,Color("f5cc88") if pellets > 1 else Color("b5f2e3"))
	actor.presentation.fire_flash = .16
	actor.presentation.sound.play_tone(100 if pellets > 1 else 420,.1,.17)
	actor.resolver.record("cast",actor,"cannon" if pellets > 1 else "sidearm")

func refill() -> void:
	super.refill()
	mobility_cd = 0

func fire(_ultimate: bool = false) -> void:
	if actor.tuning is MarshalTuning:
		var t := actor.tuning as MarshalTuning
		weapon(t.cannon_damage,t.cannon_spread,t.cannon_pellets)
	else: weapon(actor.tuning.rifle_damage)
