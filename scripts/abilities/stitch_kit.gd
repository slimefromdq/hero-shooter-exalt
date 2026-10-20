class_name StitchKit
extends ExpansionKit

var shears_mode: bool = false
var switch_age: float = 0.0
var thread: RedThread
var concealed: bool = false
var collapse_left: float = 0.0
var conceal_left: float = 0.0
var opening: bool = false
var hook_flying: bool = false
var hook_position: Vector3
var hook_origin: Vector3
var hook_direction: Vector3
var hook_traveled: float = 0.0
var reel_target: HeroActor
var reel_life: int = -1
var reel_point: Vector3
var reel_left: float = 0.0
var seam_direction: Vector3
var seam_origin: Vector3
var seam_distance: float = 0.0
var seam_left: float = 0.0
var seam_cast: int = 0
var seam_hits: Dictionary = {}
var cue: String = ""
var reveal_frame: int = -1

func data() -> StitchTuning:
	return actor.tuning as StitchTuning

func _ready() -> void:
	actor.damaged.connect(_on_damage)
	reset_life()

func _on_damage(amount: float, _head: bool) -> void:
	if amount > 0: reveal("damage")

func ultimate_active() -> bool:
	return actor.state in ["stitch_windup","stitch_seam"]

func prepare_input(input: CombatIntent) -> void:
	opening = false
	if not concealed: return
	if input.primary or input.primary_held:
		opening = collapse_left <= 0
		reveal("attack")
	elif input.melee or input.guard or input.throw_action or input.hover or input.bomb or input.ultimate or input.projectile_fire:
		reveal("action")

func tick(delta: float, input: CombatIntent) -> void:
	tick_common(delta)
	if reveal_frame == Engine.get_physics_frames(): deflect_cd = data().conceal_cooldown
	if concealed:
		if actor.state != "ready": reveal("control")
		else:
			if input.deflect:
				reveal("manual")
				return
			var active_delta: float = maxf(0,delta-collapse_left)
			collapse_left = maxf(0,collapse_left-delta)
			conceal_left = maxf(0,conceal_left-active_delta)
			if conceal_left <= 0: reveal("timeout")
			else: return
	if hook_flying: tick_hook(delta)
	if actor.state in ["stitch_windup","stitch_seam","stitch_reel"]:
		if actor.statuses.movement_disabled():
			cancel()
			return
		if actor.state == "stitch_windup" and actor.state_time <= 0:
			actor.state = "stitch_seam"
			cue = "curtain_snap"
			feedback(75)
		return
	if reel_left > 0: end_reel()
	update_mode(delta)
	if input.hover and mobility_cd <= 0 and can_act("stitch_hook"):
		launch_hook()
	if input.deflect and deflect_cd <= 0 and can_act("stitch_hide"):
		start_conceal()
		return
	if input.bomb and bomb_cd <= 0 and can_act("stitch_thread"): attach_thread()
	if input.ultimate and ultimate_charge >= 100 and can_act("ultimate"):
		start_seam()
		return
	if input.primary or input.primary_held: fire()
	if input.reload: start_reload()
	opening = false

func frontal(reach: float, angle: float) -> HeroActor:
	var nearest: HeroActor
	var best: float = reach+.0001
	var forward: Vector3 = (actor.aim_direction*Vector3(1,0,1)).normalized()
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if other == actor or not other.alive or other.team == actor.team: continue
		var offset: Vector3 = other.global_position-actor.global_position
		if absf(offset.y) > 1.5: continue
		var flat: Vector3 = offset*Vector3(1,0,1)
		var distance: float = flat.length()
		if distance > best or forward.dot(flat.normalized()) < cos(deg_to_rad(angle)): continue
		if not actor.resolver.visible(actor.body_point(1),other,[actor.get_rid()]): continue
		if not actor.resolver.barrier_ray(actor,actor.body_point(1),other.body_point(1)).is_empty(): continue
		nearest = other
		best = distance
	return nearest

func update_mode(delta: float) -> void:
	var t := data()
	if frontal(t.shears_range,t.shears_angle) != null:
		shears_mode = true
		switch_age = 0
	elif shears_mode:
		if frontal(t.shears_exit_range,t.shears_exit_angle) != null: switch_age = 0
		else:
			switch_age += delta
			if switch_age >= t.switch_grace: shears_mode = false

func fire(_ultimate: bool = false) -> void:
	if concealed:
		opening = collapse_left <= 0
		reveal("attack")
	if shot_cd > 0 or actor.state != "ready" or actor.resolver.attack_locked(actor): return
	var t := data()
	if opening:
		var prey: HeroActor = frontal(t.opening_range,t.shears_angle)
		if prey != null:
			var toward: Vector3 = (prey.global_position-actor.global_position)*Vector3(1,0,1)
			actor.move_ability_collide(toward.normalized()*minf(t.opening_lunge,maxf(0,toward.length()-.85)))
		update_mode(0)
	if shears_mode:
		if reloading:
			reloading = false
			reload_remaining = 0
		if not actor.permits("primary"): return
		shot_cd = primary_interval(t.shears_interval)+cadence_debt
		var target: HeroActor = frontal(t.shears_range,t.shears_angle)
		if target != null:
			var count: int = target.statuses.stitch_count(actor)
			var result: String = actor.resolver.damage(actor,target,t.shears_damage+count*t.mark_damage+(t.opening_damage if opening else 0.0),"melee",actor.resolver.new_cast(actor))
			if result == "hit":
				target.statuses.take_stitches(actor)
				cue = "shears_hit"
				CombatEffect.pulse(actor.get_parent(),target.body_point(1),Color("ff4967"),.6)
		feedback(170)
		actor.resolver.record("cast",actor,"shears")
	else:
		if not can_act("primary"): return
		if ammo <= 0:
			start_reload()
			return
		consume_ammo()
		shot_cd = primary_interval()+cadence_debt
		var projectile := CombatProjectile.new()
		projectile.source = actor
		projectile.direction = shot_direction(t.needle_range)
		projectile.speed = t.needle_speed
		projectile.max_distance = t.needle_range
		projectile.damage_amount = t.rifle_damage+(t.opening_damage if opening else 0.0)
		projectile.color = Color("f5d9da")
		projectile.cast_id = actor.resolver.new_cast(actor)
		projectile.confirmed_impact = needle_hit
		projectile.needle_trail = true
		actor.get_parent().add_child(projectile)
		projectile.global_position = safe_muzzle()
		feedback(1050)
		actor.resolver.record("cast",actor,"needlepoint")
	opening = false

func needle_hit(owner_actor: HeroActor, target: HeroActor) -> void:
	if owner_actor != actor or not actor.alive or actor.kit != self: return
	target.statuses.add_stitch(actor,data().mark_limit,data().mark_duration)

func aimed_enemy(reach: float) -> HeroActor:
	var from: Vector3 = aim_origin()
	var hit: Dictionary = actor.resolver.attack_ray(actor,from,from+actor.aim_direction*reach,[actor.get_rid()])
	var target: HeroActor = hit.get("collider") as HeroActor
	if target == null or not target.alive or target.team == actor.team or target.invulnerable or target.state == "wisp_phase": return null
	if not target.detectable_by(actor): return null
	if actor.global_position.distance_to(target.global_position) > reach: return null
	if actor.resolver.protected_room(target) or not actor.resolver.visible(actor.body_point(1),target,[actor.get_rid()]): return null
	return target

func attach_thread() -> void:
	var target: HeroActor = aimed_enemy(data().thread_range)
	if target == null: return
	if is_instance_valid(thread): thread.retire()
	thread = RedThread.new()
	thread.source = actor
	thread.target = target
	thread.remaining = data().thread_duration
	actor.get_parent().add_child(thread)
	bomb_cd = data().thread_cooldown
	cue = "thread_attach"
	feedback(260)
	actor.resolver.record("cast",actor,"red_thread")

func movement_scale() -> float:
	if concealed: return 1.0
	if is_instance_valid(thread) and thread.valid():
		var toward: Vector3 = (thread.target.global_position-actor.global_position)*Vector3(1,0,1)
		if actor.intent.move.normalized().dot(toward.normalized()) > .5: return 1.0+data().pursuit_bonus
	return 1.0

func start_conceal() -> void:
	if hook_flying: hook_flying = false
	if is_instance_valid(thread): thread.retire()
	actor.motor.interrupt_mobility()
	actor.velocity.x = 0
	actor.velocity.z = 0
	concealed = true
	collapse_left = data().collapse_duration
	conceal_left = data().conceal_duration
	deflect_cd = 0
	actor.motor.set_crouched(true)
	cue = "doll_collapse"
	actor.resolver.record("cast",actor,"play_dead")

func reveal(reason: String) -> void:
	if not concealed: return
	concealed = false
	collapse_left = 0
	conceal_left = 0
	deflect_cd = data().conceal_cooldown
	reveal_frame = Engine.get_physics_frames()
	actor.motor.try_stand()
	cue = "doll_reveal"
	actor.resolver.record("reveal",actor,"play_dead",reason)

func launch_hook() -> void:
	hook_origin = safe_muzzle()
	hook_position = hook_origin
	hook_direction = shot_direction(data().hook_range)
	hook_traveled = 0
	hook_flying = true
	mobility_cd = data().hook_cooldown
	actor.resolver.record("cast",actor,"spoolstep")

func landing_clear(point: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = actor.motor.standing_clearance_capsule
	query.transform = actor.global_transform
	query.transform.origin = point+Vector3.UP*(actor.motor.standing_capsule.height*.5+.01)
	query.exclude = [actor.get_rid()]
	query.collision_mask = actor.collision_mask
	query.margin = 0
	if not actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	var session: Node = actor.get_tree().get_first_node_in_group("city_match")
	if session != null and session.spawn_contains(point,1-actor.team): return false
	return true

func tick_hook(delta: float) -> void:
	if actor.state != "ready" or actor.statuses.movement_disabled():
		hook_flying = false
		return
	var distance: float = minf(data().hook_speed*delta,data().hook_range-hook_traveled)
	var next: Vector3 = hook_position+hook_direction*distance
	var hit: Dictionary = actor.resolver.attack_ray(actor,hook_position,next,[actor.get_rid()])
	hook_position = hit.get("position",next)
	hook_traveled += distance
	if hit.is_empty():
		if hook_traveled >= data().hook_range: hook_flying = false
		return
	hook_flying = false
	reel_life = -1
	reel_target = hit.get("collider") as HeroActor
	if reel_target != null:
		if not is_instance_valid(thread) or not thread.valid() or thread.target != reel_target: return
		reel_life = reel_target.life_serial
		reel_point = enemy_landing()
	else:
		if hit.get("collider") is CombatBarrier or hit.normal.y < -.1: return
		var probe: Vector3 = hit.position+hit.normal*.65
		var ground: Dictionary = actor.resolver.ray(probe+Vector3.UP*.5,probe-Vector3.UP*2.5,[actor.get_rid()],1)
		if ground.is_empty() or ground.normal.y < cos(actor.floor_max_angle): return
		reel_point = ground.position+Vector3.UP*.035
	if not landing_clear(reel_point): return
	if actor.test_move(actor.global_transform,reel_point-actor.global_position): return
	actor.motor.interrupt_mobility()
	actor.state = "stitch_reel"
	reel_left = data().reel_timeout
	cue = "hook_connect"

func enemy_landing() -> Vector3:
	var away: Vector3 = (actor.global_position-reel_target.global_position)*Vector3(1,0,1)
	return reel_target.global_position+away.normalized()*.95

func end_reel() -> void:
	reel_left = 0
	reel_target = null
	reel_life = -1
	if actor.state == "stitch_reel": actor.state = "ready"
	actor.velocity = Vector3.ZERO
	actor.motor.transition("air")

func start_seam() -> void:
	seam_direction = (actor.aim_direction*Vector3(1,0,1)).normalized()
	if seam_direction.is_zero_approx(): return
	hook_flying = false
	actor.motor.interrupt_mobility()
	actor.state = "stitch_windup"
	actor.state_time = data().seam_preparation
	actor.velocity.x = 0
	actor.velocity.z = 0
	seam_origin = actor.global_position
	var from: Vector3 = actor.body_point(1)
	var end: Vector3 = from+seam_direction*data().seam_range
	var wall: Dictionary = actor.resolver.ray(from,end,[actor.get_rid()],1)
	var barrier: Dictionary = actor.resolver.barrier_ray(actor,from,end)
	seam_distance = data().seam_range
	if not wall.is_empty(): seam_distance = minf(seam_distance,from.distance_to(wall.position))
	if not barrier.is_empty(): seam_distance = minf(seam_distance,from.distance_to(barrier.position))
	seam_left = seam_distance
	seam_hits.clear()
	seam_cast = actor.resolver.new_cast(actor)
	ultimate_charge = 0
	cue = "curtain_windup"
	actor.resolver.record("cast",actor,"curtain_call")

func seam_damage(from: Vector3, to: Vector3) -> void:
	for target: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if target == actor or not target.alive or target.team == actor.team or seam_hits.has(target.get_instance_id()): continue
		if absf(target.global_position.y-to.y) > 1.5: continue
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(target.global_position,from,to)
		if target.global_position.distance_to(closest) > data().seam_width*.5+.38: continue
		if not actor.resolver.visible(closest+Vector3.UP,target,[actor.get_rid()]): continue
		if not actor.resolver.barrier_ray(actor,closest+Vector3.UP,target.body_point(1)).is_empty(): continue
		seam_hits[target.get_instance_id()] = true
		var count: int = target.statuses.stitch_count(actor)
		var result: String = actor.resolver.damage(actor,target,data().seam_damage+count*data().mark_damage,"curtain_call",seam_cast,false,count > 0,closest+Vector3.UP)
		if count > 0 and not target.alive and result in ["hit","execution"]: bomb_cd = 0

func move_override(delta: float) -> bool:
	if actor.state == "stitch_windup":
		actor.velocity = Vector3(0,actor.velocity.y-actor.tuning.gravity*delta,0)
		actor.move_and_slide()
		seam_origin.y = actor.global_position.y
		return true
	if actor.state == "stitch_reel":
		reel_left -= delta
		if reel_life >= 0 and not is_instance_valid(reel_target):
			end_reel()
			return true
		if is_instance_valid(reel_target):
			if not is_instance_valid(thread) or not thread.valid() or reel_target.life_serial != reel_life or not actor.resolver.visible(actor.body_point(1),reel_target,[actor.get_rid()]):
				end_reel()
				return true
			reel_point = enemy_landing()
			if not landing_clear(reel_point):
				end_reel()
				return true
		var offset: Vector3 = reel_point-actor.global_position
		var motion: Vector3 = offset.limit_length(data().reel_speed*delta)
		var hit: KinematicCollision3D = actor.move_ability_collide(motion)
		actor.velocity = motion/maxf(delta,.00001)
		if hit != null or actor.mobility_limited or offset.length() <= motion.length()+.03 or reel_left <= 0: end_reel()
		return true
	if actor.state == "stitch_seam":
		var distance: float = minf(seam_left,data().seam_speed*delta)
		var from: Vector3 = actor.global_position
		var barrier: Dictionary = actor.resolver.barrier_ray(actor,actor.body_point(1),actor.body_point(1)+seam_direction*distance)
		if not barrier.is_empty(): distance = minf(distance,actor.body_point(1).distance_to(barrier.position))
		var hit: KinematicCollision3D = actor.move_ability_collide(seam_direction*distance)
		seam_damage(from,actor.global_position)
		seam_left -= distance
		if hit != null or not barrier.is_empty() or actor.mobility_limited or seam_left <= .00001:
			actor.state = "ready"
			actor.velocity = Vector3.ZERO
			actor.motor.transition("air")
		return true
	return false

func cancel(clear_owned: bool = false) -> void:
	reveal("cancel")
	hook_flying = false
	if reel_left > 0: end_reel()
	if actor.state.begins_with("stitch_"):
		actor.state = "ready"
		actor.velocity = Vector3.ZERO
	seam_left = 0
	opening = false
	if clear_owned and is_instance_valid(thread): thread.retire()
	super.cancel(clear_owned)

func refill() -> void:
	if concealed: reveal("refill")
	super.refill()

func reset_life() -> void:
	refill()
	shears_mode = false
	switch_age = 0
