class_name SamsonKit
extends ExpansionKit

var charges: int = 2
var recharge: float = 0.0
var recipient: HeroActor
var recipient_life: int = -1
var travel_age: float = 0.0
var defendant: HeroActor
var defendant_life: int = -1
var channel_age: float = 0.0
var tether_clock: float = 0.0
var notice: SamsonNotice
var court: SamsonCourt
var court_at: Vector3
var court_yaw: float = 0.0
var court_warning: Node3D
var feedback_text: String = ""
var feedback_left: float = 0.0

func data() -> SamsonTuning:
	return actor.tuning as SamsonTuning

func _ready() -> void:
	refill()

func ultimate_active() -> bool:
	return is_instance_valid(court) and court.active()

func feedback_message(message: String, frequency: float) -> void:
	feedback_text = message
	feedback_left = 1.0
	if is_instance_valid(actor.presentation): actor.presentation.sound.play_tone(frequency,.14,.16)

func target_valid(target: Variant, life: int, friendly: bool, reach: float) -> bool:
	# A retained Node can be freed between ticks. Variant admits that stale
	# reference so validation can reject it before Godot's typed-argument check.
	if not is_instance_valid(target) or not (target is HeroActor): return false
	if not target.alive or target.life_serial != life or target == actor: return false
	if (target.team == actor.team) != friendly: return false
	if actor.resolver.attack_locked(actor) or actor.resolver.protected_room(target): return false
	if not friendly and (target.invulnerable or target.state == "wisp_phase"): return false
	if actor.global_position.distance_to(target.global_position) > reach: return false
	if actor.resolver.spawn_door_blocks(actor.body_point(1.4),target.body_point(1.2)): return false
	return actor.resolver.attack_ray(actor,actor.body_point(1.4),target.body_point(1.2),[],1).is_empty()

func aimed_enemy() -> HeroActor:
	var best: HeroActor
	var score: float = cos(deg_to_rad(data().acquire_angle))
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if not target_valid(other,other.life_serial,false,data().cross_range): continue
		var dot: float = (other.body_point(1.2)-aim_origin()).normalized().dot(actor.aim_direction)
		if dot > score:
			score = dot
			best = other
	return best

func can_intervene(target: HeroActor) -> bool:
	if not can_act("intervene") or charges <= 0 or not is_instance_valid(target): return false
	if not target_valid(target,target.life_serial,true,data().intervene_range): return false
	var offset: Vector3 = target.global_position-actor.global_position
	var motion: Vector3 = offset.normalized()*maxf(0,offset.length()-data().intervene_stop)
	return not actor.test_move(actor.global_transform,motion)

func start_intervene(target: HeroActor) -> bool:
	if not can_intervene(target): return false
	var offset: Vector3 = target.global_position-actor.global_position
	actor.motor.interrupt_mobility()
	recipient = target
	recipient_life = target.life_serial
	travel_age = 0
	if charges == data().intervene_charges: recharge = data().intervene_recharge
	charges -= 1
	actor.state = "samson_intervene"
	actor.resolver.record("cast",actor,"motion_to_intervene","target="+target.actor_id)
	if offset.length() <= data().intervene_stop: arrive()
	return true

func arrive() -> void:
	if not target_valid(recipient,recipient_life,true,data().intervene_range):
		cancel()
		return
	var t := data()
	actor.resolver.heal(actor,recipient,t.intervene_heal,"intervene")
	recipient.overhealth.grant(actor,t.intervene_shield,t.intervene_shield_duration,"intervene","intervene")
	actor.overhealth.grant(actor,t.intervene_self_shield,t.intervene_shield_duration,"intervene","intervene")
	for enemy: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if enemy.team == actor.team or not enemy.alive or enemy.global_position.distance_to(actor.global_position) > t.peel_radius: continue
		if not actor.resolver.attack_ray(actor,actor.body_point(1),enemy.body_point(1),[],1).is_empty(): continue
		var away: Vector3 = (enemy.global_position-actor.global_position)*Vector3(1,0,1)
		if away.is_zero_approx(): away = -actor.global_basis.z
		actor.resolver.knockback(actor,enemy,away.normalized()*t.peel_speed,"intervene")
	CombatEffect.pulse(actor.get_parent(),actor.body_point(1),Color("64edc3"),t.peel_radius)
	actor.resolver.record("arrival",actor,"motion_to_intervene")
	recipient = null
	actor.velocity = Vector3.ZERO
	actor.state = "ready"
	feedback_message("INTERVENTION GRANTED",520)

func can_cross(target: HeroActor) -> bool:
	if deflect_cd > 0 or not can_act("deflect") or not is_instance_valid(target): return false
	return target_valid(target,target.life_serial,false,data().cross_range)

func selection_previews() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ally: HeroActor = AllyTargeting.aimed(actor,data().intervene_range,data().acquire_angle)
	if can_intervene(ally): result.append({"target":ally,"action":"hover"})
	var enemy: HeroActor = aimed_enemy()
	if can_cross(enemy): result.append({"target":enemy,"action":"deflect"})
	return result

func start_cross(target: HeroActor) -> bool:
	if not can_cross(target): return false
	defendant = target
	defendant_life = target.life_serial
	channel_age = 0
	tether_clock = 0
	deflect_cd = data().cross_cooldown
	actor.state = "samson_cross"
	actor.resolver.record("cast",actor,"cross_examination","target="+target.actor_id)
	feedback_message("CROSS-EXAMINING",330)
	return true

func interrupt_cross() -> void:
	defendant = null
	if actor.state == "samson_cross": actor.state = "ready"
	actor.resolver.record("interrupt",actor,"cross_examination")
	feedback_message("EXAMINATION INTERRUPTED",150)

func prepare_actions(input: CombatIntent) -> void:
	# Shared melee/throw/guard resolve before kit.tick. Release the channel first
	# so their press edges are not swallowed by its committed actor state.
	if actor.state != "samson_cross": return
	if input.deflect or input.primary or input.primary_held or input.secondary_pressed or input.hover or input.bomb or input.ultimate or input.reload or input.dash or input.jump or input.melee or input.throw_action or input.guard:
		interrupt_cross()
		if input.deflect: input.deflect = false

func tick(delta: float, input: CombatIntent) -> void:
	tick_common(delta)
	feedback_left = maxf(0,feedback_left-delta)
	if charges < data().intervene_charges:
		recharge -= delta
		while recharge <= .000001 and charges < data().intervene_charges:
			charges += 1
			if charges < data().intervene_charges: recharge += data().intervene_recharge
			else: recharge = 0
	mobility_cd = recharge if charges == 0 else 0.0
	if actor.infinite_resources:
		charges = data().intervene_charges
		recharge = 0
	if actor.state == "samson_cross":
		if not target_valid(defendant,defendant_life,false,data().cross_range):
			interrupt_cross()
			return
		if input.deflect or input.primary or input.primary_held or input.secondary_pressed or input.hover or input.bomb or input.ultimate or input.reload or input.dash or input.jump or input.melee or input.throw_action or input.guard:
			interrupt_cross()
			if input.deflect: return
		else:
			channel_age += delta
			tether_clock -= delta
			if tether_clock <= 0:
				tether_clock = .05
				CombatEffect.line(actor.get_parent(),actor.muzzle(),defendant.body_point(1.2),Color("ffcf6b"))
			if channel_age >= data().cross_duration-.000001:
				var target: HeroActor = defendant
				if target.statuses.apply("stun",actor,data().cross_stun):
					target.statuses.apply("silence",actor,data().cross_stun+data().cross_silence)
					CombatEffect.pulse(actor.get_parent(),target.body_point(1),Color("ffd178"),1.2)
					actor.resolver.record("complete",actor,"cross_examination","target="+target.actor_id)
					feedback_message("OBJECTION SUSTAINED",660)
				defendant = null
				actor.state = "ready"
			return
	if actor.state == "samson_court_start":
		if actor.state_time <= 0:
			if SamsonCourt.placement_clear(actor,court_at,court_yaw):
				court = SamsonCourt.new()
				court.source = actor
				court.position = court_at
				court.rotation.y = court_yaw
				actor.get_parent().add_child(court)
				ultimate_charge = 0
				actor.resolver.record("cast",actor,"roach_court")
				feedback_message("WITNESS PROTECTION",220)
			cancel_preparation()
		return
	if input.hover: start_intervene(AllyTargeting.aimed(actor,data().intervene_range,data().acquire_angle))
	if input.deflect: start_cross(aimed_enemy())
	if input.bomb: place_notice()
	if input.ultimate: start_court()
	if input.primary or input.primary_held: fire()
	if input.reload: start_reload()

func place_notice() -> bool:
	if bomb_cd > 0 or not can_act("bomb"): return false
	var hit: Dictionary = aimed_ground(data().notice_range)
	if hit.is_empty(): return false
	if not SamsonNotice.placement_clear(actor,hit.position,actor.rotation.y): return false
	if is_instance_valid(notice): notice.retire()
	notice = SamsonNotice.new()
	notice.source = actor
	notice.position = hit.position
	notice.rotation.y = actor.rotation.y
	actor.get_parent().add_child(notice)
	bomb_cd = data().notice_cooldown
	actor.resolver.record("cast",actor,"cease_and_desist")
	feedback_message("CEASE AND DESIST",410)
	return true

func start_court() -> bool:
	if ultimate_charge < 100 or ultimate_active() or not can_act("ultimate"): return false
	var hit: Dictionary = aimed_ground(data().court_range)
	if hit.is_empty() or not SamsonCourt.placement_clear(actor,hit.position,actor.rotation.y): return false
	court_at = hit.position
	court_yaw = actor.rotation.y
	actor.state = "samson_court_start"
	actor.state_time = data().court_preparation
	court_warning = RosterEffects.zone(actor.get_parent(),court_at,data().court_radius,Color("84e8c9"))
	feedback_message("COURT IS IN SESSION",110)
	actor.presentation.sound.play_tone(110,data().court_preparation,.25)
	return true

func cancel_preparation() -> void:
	if is_instance_valid(court_warning): court_warning.queue_free()
	court_warning = null
	if actor.state == "samson_court_start": actor.state = "ready"

func move_override(delta: float) -> bool:
	if actor.state != "samson_intervene": return false
	travel_age += delta
	if travel_age > data().intervene_timeout or actor.statuses.movement_disabled() or not target_valid(recipient,recipient_life,true,data().intervene_range):
		cancel()
		return false
	var offset: Vector3 = recipient.global_position-actor.global_position
	var distance: float = maxf(0,offset.length()-data().intervene_stop)
	var motion: Vector3 = offset.normalized()*minf(distance,data().intervene_speed*delta)
	var hit: KinematicCollision3D = actor.move_and_collide(motion)
	actor.velocity = Vector3.ZERO
	if hit != null:
		cancel()
	elif distance <= data().intervene_speed*delta+.001: arrive()
	return true

func fire(_ultimate: bool = false) -> void:
	if not can_act("primary") or shot_cd > 0: return
	if ammo <= 0:
		start_reload()
		return
	consume_ammo()
	shot_cd = primary_interval()+cadence_debt
	launch(shot_direction(data().ink_range),actor.tuning.rifle_damage,data().ink_speed,data().ink_range,Color("5ce0bd"),0,true)
	feedback(390)
	actor.resolver.record("cast",actor,"deposition")

func cancel(clear_owned: bool = false) -> void:
	if is_instance_valid(defendant): interrupt_cross()
	recipient = null
	cancel_preparation()
	if actor.state.begins_with("samson_"): actor.state = "ready"
	if clear_owned:
		if is_instance_valid(notice): notice.retire()
		if is_instance_valid(court): court.retire()
	super.cancel(clear_owned)

func refill() -> void:
	super.refill()
	charges = data().intervene_charges
	recharge = 0
