class_name SlayerKit
extends HeroKit

signal audio_cue(cue: String)
var knives: int = 2
var knife_timer: float = 0.0
var snares: int = 2
var snare_timer: float = 0.0
var boot_direction: Vector3 = Vector3.FORWARD
var boot_remaining: float = 0.0
var boot_connected: bool = false
var boot_fall_velocity: float = 0.0
var axe_released: bool = false
var traps: Array[HunterSnare] = []
var last_shot_damage: float = 0.0
var last_shot_pellets: int = 0
var last_shot_head: bool = false

func _ready() -> void:
	refill()

func data() -> SlayerTuning:
	return actor.tuning as SlayerTuning

func tick(delta: float, input: CombatIntent) -> void:
	var t: SlayerTuning = data()
	shot_cd = maxf(0.0, shot_cd - delta)
	deflect_cd = maxf(0.0, deflect_cd - delta)
	ultimate_charge = minf(100.0, ultimate_charge + delta * 0.8)
	if knives < t.knife_charges:
		knife_timer -= delta
		while knife_timer <= 0.0 and knives < t.knife_charges:
			knives += 1
			knife_timer += t.knife_recharge
	if snares < t.trap_limit:
		snare_timer -= delta
		while snare_timer <= 0.0 and snares < t.trap_limit:
			snares += 1
			snare_timer += t.trap_recharge
	bomb_cd = maxf(0.0, snare_timer) if snares == 0 else 0.0
	if actor.infinite_resources:
		knives = t.knife_charges
		snares = t.trap_limit
		ammo = t.magazine
		deflect_cd = 0.0
		ultimate_charge = 100.0
	if actor.state == "reload" and actor.state_time <= 0.0:
		ammo = mini(ammo + 1, t.magazine)
		cue("shell")
		actor.state_time += t.shell_time
		if ammo >= t.magazine:
			actor.state = "ready"
	if actor.state == "slayer_boot_start" and actor.state_time <= 0.0:
		actor.state = "slayer_boot_active"
		actor.resolver.record("active", actor, "boot")
	if actor.state == "slayer_axe_windup":
		ultimate_age += delta
		if actor.state_time <= 0.0:
			release_axe()
			actor.state = "slayer_axe_release"
			actor.state_time = t.axe_release
	elif actor.state == "slayer_axe_release" and actor.state_time <= 0.0:
		actor.state = "slayer_axe_recovery"
		actor.state_time = t.axe_recovery
	elif actor.state in ["slayer_knife", "slayer_trap", "slayer_boot_recovery", "slayer_axe_recovery"] and actor.state_time <= 0.0:
		actor.state = "ready"
	# Offensive cancels never reset the pump lock; all abilities respect commitments.
	var cancel_window: bool = shot_cd <= t.shot_interval - t.shotgun_cancel_after
	if input.hover and knives > 0 and cancel_window and actor.permits("knife"):
		throw_knife()
	elif input.deflect and deflect_cd <= 0.0 and actor.permits("boot"):
		start_boot()
	elif input.bomb and snares > 0 and actor.permits("snare"):
		deploy_trap(input.aim_held)
	elif input.ultimate and ultimate_charge >= 100.0 and actor.permits("ultimate"):
		ultimate_charge = 0.0
		ultimate_age = 0.0
		axe_released = false
		actor.state = "slayer_axe_windup"
		actor.state_time = t.axe_windup
		actor.resolver.record("cast", actor, "heads_will_roll")
		cue("axe_draw")
	elif input.primary and shot_cd <= 0.0 and actor.permits("primary"):
		if ammo > 0:
			fire(false)
		else:
			start_reload()
	elif input.reload and actor.permits("reload"):
		start_reload()
	if input.projectile_fire:
		fire_projectile(input.aim)

func start_reload() -> void:
	if ammo >= actor.tuning.magazine or actor.state == "reload":
		return
	actor.state = "reload"
	actor.state_time = data().reload_start + data().shell_time
	actor.resolver.record("cast", actor, "shell_reload")

func aim_point(distance: float) -> Vector3:
	var origin: Vector3 = actor.intent.aim_origin
	if origin == Vector3.ZERO:
		origin = actor.global_position + Vector3.UP * 1.4
	var hit: Dictionary = actor.resolver.ray(origin, origin + actor.aim_direction * distance, [actor.get_rid()])
	return hit.get("position", origin + actor.aim_direction * distance)

func damage_scale(distance: float) -> float:
	var t: SlayerTuning = data()
	return lerpf(1.0, t.minimum_damage, clampf((distance - t.falloff_start) / maxf(.01,t.falloff_end - t.falloff_start),0,1))

func fire(_ultimate: bool = false) -> void:
	var t: SlayerTuning = data()
	if ammo <= 0 or shot_cd > 0.0 or not actor.permits("primary"):
		return
	actor.state = "ready"
	ammo -= 1
	shot_cd = t.shot_interval
	var muzzle: Vector3 = actor.muzzle()
	var direction: Vector3 = (aim_point(t.weapon_range) - muzzle).normalized()
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	if right.is_zero_approx(): right = Vector3.RIGHT
	var up: Vector3 = right.cross(direction).normalized()
	var obstruction: Dictionary = actor.resolver.ray(actor.global_position + Vector3.UP * 1.36, muzzle, [actor.get_rid()], 1)
	last_shot_damage = 0.0
	last_shot_pellets = 0
	last_shot_head = false
	for index: int in t.pellets:
		# Fixed equal-area disk: deterministic across frame rates; each pellet gets its own cast.
		var radius: float = sqrt((index + .5) / t.pellets) * tan(deg_to_rad(t.spread_degrees))
		var angle: float = index * 2.39996323
		var pellet: Vector3 = (direction + (right * cos(angle) + up * sin(angle)) * radius).normalized()
		var hit: Dictionary = obstruction if not obstruction.is_empty() else actor.resolver.ray(muzzle, muzzle + pellet * t.weapon_range, [actor.get_rid()])
		var endpoint: Vector3 = hit.get("position", muzzle + pellet * t.weapon_range)
		if not hit.is_empty():
			var target: HeroActor = hit.get("collider") as HeroActor
			var pellet_cast: int = actor.resolver.new_cast()
			var amount: float = t.pellet_damage * damage_scale(muzzle.distance_to(endpoint))
			if target != null:
				var head: bool = endpoint.y - target.global_position.y >= 1.5
				var before: float = target.health + target.shields
				var result: String = actor.resolver.damage(actor,target,amount * (t.head_multiplier if head else 1.0),"shotgun",pellet_cast,head,false,muzzle)
				last_shot_damage += before - target.health - target.shields
				if result == "hit":
					last_shot_pellets += 1
					last_shot_head = last_shot_head or head
			elif hit.get("collider") is HunterSnare:
				(hit.collider as HunterSnare).receive_damage(actor,amount,pellet_cast)
			CombatEffect.pulse(actor.get_parent(), endpoint, Color("ffad63") if target == null else Color("ff5979"), .13)
		if index % 2 == 0:
			CombatEffect.line(actor.get_parent(), safe_muzzle(), endpoint, Color("ffd5a0"), .015)
	actor.presentation.fire_flash = .18
	CombatEffect.pulse(actor.get_parent(), safe_muzzle(), Color("ffc983"), .28)
	if actor.controller is PlayerController:
		(actor.controller as PlayerController).add_recoil(deg_to_rad(t.recoil_degrees))
	cue("shotgun")
	var session: Node = actor.get_tree().get_first_node_in_group("game_session")
	if last_shot_damage > 0 and session != null and session.player == actor:
		session.hud.hit_text = str(roundi(last_shot_damage)) + (" HEAD" if last_shot_head else "")
		session.hud.hit_head = last_shot_head
		session.hud.hit_timer = .25
	actor.resolver.record("cast",actor,"street_sweeper","pellets=%d connected=%d applied=%.2f" % [t.pellets,last_shot_pellets,last_shot_damage])

func throw_knife() -> void:
	var t: SlayerTuning = data()
	if knives == t.knife_charges: knife_timer = t.knife_recharge
	knives -= 1
	actor.state = "slayer_knife"
	actor.state_time = t.knife_recovery
	var projectile := SlayerProjectile.new()
	projectile.source = actor
	projectile.kind = "knife"
	projectile.direction = (aim_point(t.knife_range) - safe_muzzle()).normalized()
	actor.get_parent().add_child(projectile)
	projectile.global_position = safe_muzzle()
	actor.resolver.record("cast",actor,"silver_knife")
	cue("knife")

func start_boot() -> void:
	var t: SlayerTuning = data()
	actor.motor.end_hover()
	actor.motor.transition("ground" if actor.is_on_floor() else "air")
	boot_direction = actor.aim_direction
	if actor.motor.grounded():
		boot_direction = Vector3(boot_direction.x,0,boot_direction.z).normalized()
	if boot_direction.is_zero_approx(): boot_direction = -actor.global_basis.z
	boot_remaining = t.boot_distance
	boot_fall_velocity = actor.velocity.y
	boot_connected = false
	deflect_cd = t.boot_cooldown
	cast_id = actor.resolver.new_cast()
	actor.state = "slayer_boot_start"
	actor.state_time = t.boot_startup
	actor.resolver.record("cast",actor,"boot_rush")
	cue("boot_start")

func boot_targets() -> bool:
	for target: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		var offset: Vector3 = target.global_position + Vector3.UP * .95 - (actor.global_position + Vector3.UP * .95)
		if not target.alive or target.team == actor.team or offset.length() > data().boot_reach or offset.normalized().dot(boot_direction) < .2:
			continue
		if not actor.resolver.visible(actor.global_position + Vector3.UP,target,[actor.get_rid()]): continue
		var result: String = actor.resolver.damage(actor,target,data().boot_damage,"boot",cast_id,false,false,actor.global_position)
		if result in ["hit", "blocked"]:
			boot_connected = true
			if result == "hit" and target.state not in ["captured", "throw_pair"]:
				target.motor.external_velocity += boot_direction * data().boot_knockback
			CombatEffect.pulse(actor.get_parent(),target.global_position + Vector3.UP,Color("f7bb65"),.9)
			cue("boot_hit")
			return true
	return false

func move_override(delta: float) -> bool:
	if actor.state not in ["slayer_boot_active", "slayer_boot_recovery"]:
		return false
	var t: SlayerTuning = data()
	if actor.state == "slayer_boot_recovery":
		actor.velocity.x = move_toward(actor.velocity.x,0,delta * t.braking)
		actor.velocity.z = move_toward(actor.velocity.z,0,delta * t.braking)
		actor.velocity.y -= t.gravity * delta
		actor.move_and_slide()
		return true
	var connected: bool = boot_targets()
	if not connected and actor.state == "slayer_boot_active":
		var travel: float = minf(boot_remaining,t.boot_speed * delta)
		var before: Vector3 = actor.global_position
		actor.velocity = boot_direction * travel / delta
		if absf(boot_direction.y) < .1:
			boot_fall_velocity -= t.gravity * delta
			actor.velocity.y = boot_fall_velocity
		actor.move_and_slide()
		if actor.is_on_floor(): boot_fall_velocity = 0.0
		boot_remaining -= travel
		connected = boot_targets()
		for index: int in actor.get_slide_collision_count():
			var normal: Vector3 = actor.get_slide_collision(index).get_normal()
			if normal.dot(boot_direction) < -.2 and normal.y < cos(actor.floor_max_angle):
				boot_remaining = 0.0
		CombatEffect.line(actor.get_parent(),before + Vector3.UP * .5,actor.global_position + Vector3.UP * .5,Color("d8b4fa"),.045)
	if actor.state == "slayer_boot_active" and (connected or boot_remaining <= .001):
		actor.state = "slayer_boot_recovery"
		actor.state_time = t.boot_hit_recovery if boot_connected else t.boot_miss_recovery
		actor.velocity.x *= t.boot_momentum
		actor.velocity.z *= t.boot_momentum
		actor.resolver.record("recovery",actor,"boot","hit" if boot_connected else "miss_or_wall")
	return true

func deploy_trap(thrown: bool) -> bool:
	var at: Vector3 = safe_muzzle()
	var normal: Vector3 = Vector3.UP
	if not thrown:
		var intended: Vector3 = actor.global_position - actor.global_basis.z * .8
		var hit: Dictionary = actor.resolver.ray(intended + Vector3.UP * 1.2,intended + Vector3.DOWN * 2,[actor.get_rid()],1)
		if hit.is_empty() or (hit.normal as Vector3).y < .7: return false
		at = hit.position + hit.normal * .12
		normal = hit.normal
		if not HunterSnare.placement_clear(actor,at): return false
	var t: SlayerTuning = data()
	for index: int in range(traps.size() - 1,-1,-1):
		if not is_instance_valid(traps[index]) or traps[index].is_queued_for_deletion():
			traps.remove_at(index)
	while traps.size() >= t.trap_limit:
		traps.pop_front().queue_free()
	var trap := HunterSnare.new()
	trap.source = actor
	trap.flying = thrown
	actor.get_parent().add_child(trap)
	trap.global_position = at
	trap.align_surface(normal)
	if thrown:
		trap.velocity = (aim_point(25.0) - at).normalized() * t.trap_throw_speed + Vector3.UP * 2.0
	traps.append(trap)
	if snares == t.trap_limit: snare_timer = t.trap_recharge
	snares -= 1
	actor.state = "slayer_trap"
	actor.state_time = t.trap_recovery
	actor.resolver.record("cast",actor,"snare_throw" if thrown else "snare_place")
	cue("snare")
	return true

func release_axe() -> void:
	if axe_released: return
	axe_released = true
	var projectile := SlayerProjectile.new()
	projectile.source = actor
	projectile.kind = "axe"
	projectile.direction = (aim_point(data().axe_range) - safe_muzzle()).normalized()
	actor.get_parent().add_child(projectile)
	projectile.global_position = safe_muzzle()
	actor.resolver.record("release",actor,"heads_will_roll")
	cue("axe_release")

func cue(id: String) -> void:
	audio_cue.emit(id)
	actor.presentation.sound.play_slayer(id)

func cancel(clear_owned: bool = false) -> void:
	super.cancel(clear_owned)
	if clear_owned: traps.clear()
	boot_remaining = 0.0
	axe_released = false

func refill() -> void:
	super.refill()
	knives = data().knife_charges
	snares = data().trap_limit
	knife_timer = 0.0
	snare_timer = 0.0
