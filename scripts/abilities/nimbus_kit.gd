class_name NimbusKit
extends HeroKit

func tick(delta: float, input: CombatIntent) -> void:
	var t: HeroTuning = actor.tuning
	shot_cd = maxf(0.0, shot_cd - delta)
	deflect_cd = maxf(0.0, deflect_cd - delta)
	bomb_cd = maxf(0.0, bomb_cd - delta)
	ultimate_charge = minf(100.0, ultimate_charge + delta * 0.8)
	if actor.infinite_resources:
		ammo = t.magazine
		deflect_cd = 0.0
		bomb_cd = 0.0
		ultimate_charge = 100.0
	if input.projectile_fire:
		fire_projectile(input.aim)
	if actor.state == "reload" and actor.state_time <= 0.0:
		ammo = t.magazine
		actor.state = "ready"
	elif actor.state == "deflect" and actor.state_time <= 0.0:
		actor.state = "ready"
	elif actor.state == "ultimate":
		ultimate_age += delta
		if input.ultimate or actor.state_time <= 0.0:
			actor.state = "ready"
			return
	if input.reload and actor.permits("reload") and ammo < t.magazine:
		actor.state = "reload"
		actor.state_time = t.reload_time
		actor.resolver.record("cast", actor, "reload")
	if input.deflect and deflect_cd <= 0.0 and actor.permits("deflect"):
		actor.state = "deflect"
		actor.state_time = t.deflect_duration
		deflect_cd = t.deflect_cooldown
		cast_id = actor.resolver.new_cast()
		actor.resolver.record("cast", actor, "deflect")
	if input.bomb and bomb_cd <= 0.0 and actor.permits("bomb"):
		var grenade := PocketBomb.new()
		grenade.source = actor
		grenade.cast_id = actor.resolver.new_cast()
		actor.get_parent().add_child(grenade)
		grenade.global_position = safe_muzzle()
		grenade.velocity = actor.aim_direction * 13.0 + Vector3.UP * 3.8
		bomb_cd = t.bomb_cooldown
		actor.resolver.record("cast", actor, "bomb")
	if input.ultimate and ultimate_charge >= 100.0 and actor.permits("ultimate"):
		ultimate_charge = 0.0
		ultimate_age = 0.0
		actor.state = "ultimate"
		actor.state_time = t.ultimate_duration
		actor.resolver.record("cast", actor, "ultimate")
	if input.primary and shot_cd <= 0.0 and actor.permits("primary"):
		if actor.state == "ultimate":
			if ultimate_age >= t.ultimate_preparation:
				fire(true)
		elif ammo > 0:
			fire(false)
		elif actor.permits("reload"):
			actor.state = "reload"
			actor.state_time = t.reload_time

func fire(ultimate: bool) -> void:
	var t: HeroTuning = actor.tuning
	var origin: Vector3 = actor.intent.aim_origin
	if origin == Vector3.ZERO:
		origin = actor.global_position + Vector3.UP * 1.6
	var view_hit: Dictionary = actor.resolver.ray(origin, origin + actor.aim_direction * 100.0, [actor.get_rid()])
	var aim_point: Vector3 = view_hit.get("position", origin + actor.aim_direction * 100.0)
	var muzzle: Vector3 = actor.muzzle()
	# Reject a muzzle already poked through a thin wall before tracing to the aim point.
	var shoulder: Vector3 = actor.global_position + Vector3.UP * 1.36
	var blocked: Dictionary = actor.resolver.ray(shoulder, muzzle, [actor.get_rid()], 1)
	var hit: Dictionary = blocked if not blocked.is_empty() else actor.resolver.ray(muzzle, aim_point + (aim_point - muzzle).normalized() * 0.05, [actor.get_rid()])
	var endpoint: Vector3 = hit.get("position", aim_point)
	cast_id = actor.resolver.new_cast()
	if not hit.is_empty() and hit.get("collider") is HeroActor:
		var target: HeroActor = hit["collider"] as HeroActor
		var head: bool = not ultimate and endpoint.y - target.global_position.y >= 1.5
		var amount: float = t.ultimate_damage if ultimate else t.rifle_damage * (t.head_multiplier if head else 1.0)
		actor.resolver.damage(actor, target, amount, "ultimate" if ultimate else "rifle", cast_id, head, ultimate)
	elif hit.get("collider") is HunterSnare:
		(hit.collider as HunterSnare).receive_damage(actor,t.ultimate_damage if ultimate else t.rifle_damage,cast_id)
	CombatEffect.line(actor.get_parent(), muzzle, endpoint, Color("fce7ab") if not ultimate else Color("9dfbe2"), 0.04 if not ultimate else 0.09)
	actor.presentation.fire_flash = 0.18
	actor.presentation.sound.play_tone(220.0 if not ultimate else 90.0, 0.11, 0.22)
	if ultimate:
		actor.state = "ready"
	else:
		ammo -= 1
	shot_cd = t.shot_interval
	actor.resolver.record("cast", actor, "ultimate_shot" if ultimate else "rifle", "cast=%d" % cast_id)
