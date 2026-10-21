class_name SlayerKit
extends HeroKit

signal audio_cue(cue: String)
var knives: int = 3
var knife_timer: float = 0.0
var snares: int = 2
var snare_timer: float = 0.0
var boot_direction: Vector3 = Vector3.FORWARD
var boot_launch_direction: Vector3 = Vector3.FORWARD
var boot_steer_angle: float = 0.0
var boot_turn_delta: float = 0.0
var boot_remaining: float = 0.0
var boot_connected: bool = false
var boot_fall_velocity: float = 0.0
var axe_released: bool = false
var traps: Array[HunterSnare] = []
var last_shot_damage: float = 0.0
var last_shot_pellets: int = 0
var last_shot_head: bool = false
var boot_buffer: float = 0.0
var boot_slow_time: float = 0.0
var boot_slow_duration: float = 0.0
var action_age: float = 0.0
var action_released: bool = false
var pending_trap_direction: Vector3
var pending_knife_aim: Vector3
var action_hint: String = ""
var action_hint_time: float = 0.0

func _ready() -> void:
	refill()

func data() -> SlayerTuning:
	return actor.tuning as SlayerTuning

func tick(delta: float, input: CombatIntent) -> void:
	var t: SlayerTuning = data()
	var boot_was_queued: bool = boot_buffer > 0.0
	shot_cd = maxf(0.0, shot_cd - delta)
	boot_slow_time = maxf(0.0, boot_slow_time - delta)
	action_hint_time = maxf(0.0, action_hint_time - delta)
	boot_buffer = maxf(0.0, boot_buffer - delta)
	deflect_cd = maxf(0.0, deflect_cd - delta)
	gain_ultimate_charge(delta * 0.8)
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
	if actor.state == "slayer_boot_start" and actor.state_time <= 0.0:
		actor.state = "slayer_boot_active"
		actor.resolver.record("active", actor, "boot")
	if actor.state in ["slayer_knife", "slayer_trap"]:
		action_age += delta
		if not action_released:
			if actor.state == "slayer_knife" and action_age >= t.knife_release_time:
				release_knife()
			elif actor.state == "slayer_trap" and action_age >= t.trap_release_time:
				release_trap()
	if actor.state == "slayer_axe_windup":
		ultimate_age += delta
		if actor.state_time <= 0.0:
			release_axe()
			actor.state = "slayer_axe_release"
			actor.state_time = t.axe_release
	elif actor.state == "slayer_axe_release" and actor.state_time <= 0.0:
		actor.state = "slayer_axe_recovery"
		actor.state_time = t.axe_recovery
	elif actor.state in ["slayer_knife", "slayer_trap", "slayer_axe_recovery"] and actor.state_time <= 0.0:
		actor.state = "ready"
	if input.deflect:
		if actor.resolver.attack_locked(actor):
			hint("BOOT RUSH / LEAVE THE SAFE ROOM")
		elif actor.statuses.movement_disabled():
			hint("BOOT RUSH / MOBILITY DISABLED")
		elif deflect_cd > 0.0:
			hint("BOOT RUSH / %.1f s" % deflect_cd)
		else:
			boot_buffer = t.boot_input_buffer
			if not actor.permits("boot") and actor.state != "guard": hint("BOOT RUSH / INPUT BUFFERED")
	if boot_buffer > 0.0 and actor.state == "guard" and not actor.statuses.movement_disabled() and not actor.resolver.attack_locked(actor):
		actor.state = "ready"
		actor.close.guard_cd = t.guard_cooldown
	# Offensive cancels never reset the pump lock; all abilities respect commitments.
	var cancel_window: bool = shot_cd <= t.shot_interval - t.shotgun_cancel_after
	if boot_buffer > 0.0 and deflect_cd <= 0.0 and actor.permits("boot"):
		start_boot()
	elif input.hover and knives > 0 and cancel_window and actor.permits("knife"):
		throw_knife()
	elif input.bomb and snares > 0 and actor.permits("snare"):
		if not deploy_trap(): hint("SNARE / NO CLEAR RELEASE SPACE")
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
	if boot_was_queued and boot_buffer <= 0.0 and deflect_cd <= 0 and actor.state not in ["slayer_boot_start", "slayer_boot_active"]:
		hint("BOOT RUSH / " + actor.state.replace("_", " ").to_upper())

func hint(message: String) -> void:
	action_hint = message
	action_hint_time = 1.2

func movement_scale() -> float:
	return lerpf(1.0,data().boot_recovery_speed,clampf(boot_slow_time / maxf(.01,boot_slow_duration),0,1))

func aim_point(distance: float) -> Vector3:
	var origin: Vector3 = actor.intent.aim_origin
	if origin == Vector3.ZERO:
		origin = actor.body_point(1.4)
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
	consume_ammo()
	shot_cd = primary_interval()
	var muzzle: Vector3 = actor.muzzle()
	var direction: Vector3 = (aim_point(t.weapon_range) - muzzle).normalized()
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	if right.is_zero_approx(): right = Vector3.RIGHT
	var up: Vector3 = right.cross(direction).normalized()
	var obstruction: Dictionary = actor.resolver.ray(actor.body_point(1.36), muzzle, [actor.get_rid()], 1)
	last_shot_damage = 0.0
	last_shot_pellets = 0
	last_shot_head = false
	var contacts: Array[Dictionary] = []
	var endpoints := PackedVector3Array()
	for index: int in t.pellets:
		# Fixed equal-area disk: deterministic across frame rates; each pellet gets its own cast.
		var radius: float = sqrt((index + .5) / t.pellets) * tan(deg_to_rad(t.spread_degrees))
		var angle: float = index * 2.39996323
		var pellet: Vector3 = (direction + (right * cos(angle) + up * sin(angle)) * radius).normalized()
		var hit: Dictionary = obstruction if not obstruction.is_empty() else actor.resolver.attack_ray(actor, muzzle, muzzle + pellet * t.weapon_range, [actor.get_rid()])
		var endpoint: Vector3 = hit.get("position", muzzle + pellet * t.weapon_range)
		endpoints.append(endpoint)
		if not hit.is_empty():
			var target: HeroActor = hit.get("collider") as HeroActor
			var confirmed: bool = false
			var hit_head: bool = false
			var pellet_cast: int = actor.resolver.new_cast(actor)
			var amount: float = t.pellet_damage * damage_scale(muzzle.distance_to(endpoint))
			if target != null:
				var head: bool = endpoint.y - target.global_position.y >= target.headshot_height()
				var before: float = target.health + target.shields
				var result: String = actor.resolver.damage(actor,target,amount * (t.head_multiplier if head else 1.0),"shotgun",pellet_cast,head,false,muzzle,endpoint)
				last_shot_damage += before - target.health - target.shields
				if result == "hit":
					confirmed = before > target.health + target.shields
					hit_head = head
					last_shot_pellets += 1
					last_shot_head = last_shot_head or head
			elif hit.get("collider") is CombatBarrier:
				hit.collider.receive_damage(actor,amount,pellet_cast)
			elif hit.get("collider") is HunterSnare or hit.get("collider") is CombatStructure:
				actor.resolver.hit_object(hit.collider,actor,amount,pellet_cast)
			contacts.append({"position": endpoint, "normal": hit.get("normal", -pellet), "id": hit.collider.get_instance_id(), "actor": target != null, "confirmed": confirmed, "head": hit_head})
	actor.presentation.fire_flash = .18
	actor.presentation.slayer_shot.discharge(safe_muzzle(), direction, contacts, endpoints)
	if actor.controller is PlayerController:
		(actor.controller as PlayerController).add_recoil(deg_to_rad(t.recoil_degrees))
	cue("shotgun")
	var session: Node = actor.get_tree().get_first_node_in_group("game_session")
	if last_shot_damage > 0 and session != null and session.player == actor:
		session.hud.hit_text = str(roundi(last_shot_damage)) + (" HEAD" if last_shot_head else "")
		session.hud.hit_head = last_shot_head
		session.hud.hit_timer = .8
	actor.resolver.record("cast",actor,"street_sweeper","pellets=%d connected=%d applied=%.2f" % [t.pellets,last_shot_pellets,last_shot_damage])

func throw_knife() -> void:
	var t: SlayerTuning = data()
	if knives == t.knife_charges: knife_timer = t.knife_recharge
	knives -= 1
	actor.state = "slayer_knife"
	actor.state_time = t.knife_recovery
	action_age = 0.0
	action_released = false
	pending_knife_aim = aim_point(t.knife_range)
	actor.resolver.record("cast",actor,"silver_knife")

func release_knife() -> void:
	action_released = true
	var origin: Vector3 = throw_origin()
	var projectile := SlayerProjectile.new()
	projectile.source = actor
	projectile.kind = "knife"
	projectile.direction = (pending_knife_aim - origin).normalized()
	actor.get_parent().add_child(projectile)
	projectile.global_position = origin
	actor.presentation.slayer_abilities.burst(origin,projectile.direction,Color("e6faff"),.38)
	cue("knife")

func throw_origin() -> Vector3:
	var hand: Vector3 = actor.presentation.right_arm.get_node("Joint").to_global(Vector3(0,-.28,0))
	var shoulder: Vector3 = actor.body_point(1.36)
	var hit: Dictionary = actor.resolver.ray(shoulder,hand,[actor.get_rid()],1)
	return hit.position + hit.normal * .12 if not hit.is_empty() else hand

func start_boot() -> void:
	var t: SlayerTuning = data()
	actor.motor.end_hover()
	actor.motor.transition("ground" if actor.is_on_floor() else "air")
	boot_direction = actor.aim_direction
	if actor.motor.grounded():
		boot_direction = Vector3(boot_direction.x,0,boot_direction.z).normalized()
	if boot_direction.is_zero_approx(): boot_direction = -actor.global_basis.z
	boot_launch_direction = boot_direction
	boot_steer_angle = 0.0
	boot_turn_delta = 0.0
	boot_remaining = t.boot_distance
	boot_fall_velocity = actor.velocity.y
	boot_connected = false
	boot_buffer = 0.0
	boot_slow_time = 0.0
	deflect_cd = t.boot_cooldown
	cast_id = actor.resolver.classify(actor.resolver.new_cast(actor),CombatResolver.ImpactKind.ABILITY)
	actor.state = "slayer_boot_start"
	actor.state_time = t.boot_startup
	actor.resolver.record("cast",actor,"boot_rush")
	actor.presentation.slayer_abilities.begin_boot()
	cue("boot_start")

func boot_targets() -> bool:
	var candidates: Array[Node] = actor.get_tree().get_nodes_in_group("actors")
	candidates.sort_custom(func(a: Node, b: Node) -> bool: return actor.global_position.distance_squared_to(a.global_position) < actor.global_position.distance_squared_to(b.global_position))
	for target: HeroActor in candidates:
		var offset: Vector3 = target.global_position + Vector3.UP * .95 - (actor.global_position + Vector3.UP * .95)
		var along: float = offset.dot(boot_direction)
		var perpendicular: float = (offset - boot_direction * clampf(along,0,data().boot_reach)).length()
		if not target.alive or target.team == actor.team or target.boot_pair != null or target.state in ["captured","throw_pair"] or along < 0 or along > data().boot_reach or perpendicular > data().boot_radius + .38:
			continue
		if not actor.resolver.visible(actor.global_position + Vector3.UP,target,[actor.get_rid()]): continue
		var result: String = actor.resolver.damage(actor,target,data().boot_damage,"boot",cast_id,false,false,actor.global_position)
		if result in ["hit", "blocked"]:
			boot_connected = true
			if result == "hit" and target.alive:
				var attachment := BootAttachment.new()
				attachment.configure(actor,target)
			actor.presentation.slayer_abilities.boot_contact(target)
			cue("boot_hit")
			return true
	return false

func steer_boot(delta: float) -> void:
	# CombatIntent.move is live world-space WASD; aim_direction is locked by HeroActor.
	var move := Vector3(actor.intent.move.x, 0, actor.intent.move.z)
	var launch := Vector3(boot_launch_direction.x, 0, boot_launch_direction.z)
	var previous: float = boot_steer_angle
	if move.length_squared() > .001 and launch.length_squared() > .001:
		var desired: float = launch.signed_angle_to(move, Vector3.UP)
		# Pure backward input cannot reverse or choose an arbitrary turning side.
		if absf(desired) < PI - .01:
			desired = clampf(desired, -deg_to_rad(data().boot_max_steer_angle), deg_to_rad(data().boot_max_steer_angle))
			boot_steer_angle = move_toward(boot_steer_angle, desired, deg_to_rad(data().boot_turn_rate) * delta)
	boot_turn_delta = (boot_steer_angle - previous) / maxf(delta, .00001)
	boot_direction = boot_launch_direction.rotated(Vector3.UP, boot_steer_angle)
	actor.aim_direction = boot_direction
	if launch.length_squared() > .001: actor.rotation.y = atan2(-boot_direction.x, -boot_direction.z)

func move_override(delta: float) -> bool:
	if actor.state != "slayer_boot_active":
		return false
	var t: SlayerTuning = data()
	actor.motor.coyote = .1 if actor.motor.grounded() else maxf(0.0,actor.motor.coyote - delta)
	steer_boot(delta)
	var connected: bool = boot_targets()
	if not connected and actor.state == "slayer_boot_active":
		var travel: float = minf(boot_remaining,t.boot_speed * delta)
		var before: Vector3 = actor.global_position
		actor.velocity = boot_direction * travel / delta
		if absf(boot_direction.y) < .1:
			boot_fall_velocity -= t.gravity * delta
			actor.velocity.y = boot_fall_velocity
		# Split the requested motion while refreshing floor/wall contacts each sweep.
		var step_count: int = maxi(1,int(ceil(travel / .35)))
		var requested_velocity: Vector3 = actor.velocity
		for step_index: int in step_count:
			actor.velocity = requested_velocity / step_count
			actor.move_ability_slide(delta)
			if boot_targets():
				connected = true
				break
			for collision_index: int in actor.get_slide_collision_count():
				var wall_normal: Vector3 = actor.get_slide_collision(collision_index).get_normal()
				if wall_normal.dot(boot_direction) < -.2 and wall_normal.y < cos(actor.floor_max_angle): boot_remaining = 0
			if boot_remaining <= 0: break
		if actor.state == "slayer_boot_active": actor.velocity *= step_count
		if actor.is_on_floor(): boot_fall_velocity = 0.0
		boot_remaining -= travel
		if not connected: connected = boot_targets()
		for index: int in actor.get_slide_collision_count():
			var normal: Vector3 = actor.get_slide_collision(index).get_normal()
			if normal.dot(boot_direction) < -.2 and normal.y < cos(actor.floor_max_angle):
				boot_remaining = 0.0
		actor.presentation.slayer_abilities.boot_path(before, actor.global_position)
	if actor.state == "slayer_boot_active" and (connected or boot_remaining <= .001):
		actor.state = "ready"
		actor.state_time = 0.0
		boot_slow_duration = t.boot_hit_recovery if boot_connected else t.boot_miss_recovery
		boot_slow_time = boot_slow_duration
		actor.velocity.x *= t.boot_momentum
		actor.velocity.z *= t.boot_momentum
		actor.resolver.record("recovery",actor,"boot","hit" if boot_connected else "miss_or_wall")
		if not boot_connected: actor.presentation.slayer_abilities.boot_miss()
	return true

func deploy_trap() -> bool:
	if not HunterSnare.placement_clear(actor,throw_origin(),[actor.get_rid()]): return false
	var t: SlayerTuning = data()
	pending_trap_direction = (aim_point(t.weapon_range) - throw_origin()).normalized()
	if snares == t.trap_limit: snare_timer = t.trap_recharge
	snares -= 1
	actor.state = "slayer_trap"
	actor.state_time = t.trap_recovery
	action_age = 0.0
	action_released = false
	actor.resolver.record("cast",actor,"snare_toss")
	return true

func release_trap() -> void:
	action_released = true
	var t: SlayerTuning = data()
	for index: int in range(traps.size() - 1,-1,-1):
		if not is_instance_valid(traps[index]) or traps[index].is_queued_for_deletion():
			traps.remove_at(index)
	while traps.size() >= t.trap_limit:
		traps.pop_front().queue_free()
	var trap := HunterSnare.new()
	trap.source = actor
	trap.flying = true
	actor.get_parent().add_child(trap)
	var hand: Vector3 = throw_origin()
	# Sweep the actual device from the shoulder to the hand; a thin wall cannot
	# be skipped by the release animation. Actors remain free to walk over traps.
	trap.global_position = actor.body_point(1.36)
	trap.move_and_collide(hand - trap.global_position)
	if not HunterSnare.placement_clear(actor,trap.global_position,[actor.get_rid(),trap.get_rid()]):
		trap.queue_free()
		snares = mini(snares + 1,t.trap_limit)
		hint("SNARE / RELEASE BLOCKED")
		return
	trap.velocity = pending_trap_direction * t.trap_throw_speed + Vector3.UP * t.trap_throw_lift
	traps.append(trap)
	actor.resolver.record("release",actor,"snare_toss")
	cue("snare")

func release_axe() -> void:
	if axe_released: return
	axe_released = true
	var projectile := SlayerProjectile.new()
	projectile.source = actor
	projectile.kind = "axe"
	projectile.direction = (aim_point(data().axe_range) - safe_muzzle()).normalized()
	actor.get_parent().add_child(projectile)
	projectile.global_position = safe_muzzle()
	actor.presentation.slayer_abilities.burst(projectile.global_position,projectile.direction,Color("c6a0ff"),1.1)
	actor.resolver.record("release",actor,"heads_will_roll")
	cue("axe_release")

func cue(id: String) -> void:
	audio_cue.emit(id)
	actor.presentation.sound.play_slayer(id)

func cancel(clear_owned: bool = false) -> void:
	if is_instance_valid(actor.presentation) and is_instance_valid(actor.presentation.slayer_abilities): actor.presentation.slayer_abilities.interrupt()
	if actor.boot_pair != null: actor.boot_pair.release(false)
	super.cancel(clear_owned)
	if clear_owned: traps.clear()
	boot_remaining = 0.0
	boot_buffer = 0.0
	boot_slow_time = 0.0
	action_released = true
	axe_released = false

func refill() -> void:
	super.refill()
	knives = data().knife_charges
	snares = data().trap_limit
	knife_timer = 0.0
	snare_timer = 0.0
	boot_slow_time = 0.0
	boot_buffer = 0.0
	action_hint_time = 0.0
