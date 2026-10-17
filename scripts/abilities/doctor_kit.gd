class_name DoctorKit
extends CareKit

var patient: HeroActor
var beam_healing: bool = false
var obstruction_age: float = 0.0
var beam_draw_age: float = 0.0
var call_destination: Vector3
var pending_patient: HeroActor

func data() -> DoctorTuning:
	return actor.tuning as DoctorTuning

func _ready() -> void:
	refill()

func sight(target: HeroActor) -> bool:
	if not is_instance_valid(target) or not target.alive or target == actor or target.team != actor.team: return false
	if actor.resolver.protected_room(actor) or actor.resolver.protected_room(target): return false
	# Other teammates do not occlude care; environment and hostile barriers do.
	var from: Vector3 = actor.global_position + Vector3.UP * 1.4
	return actor.resolver.attack_ray(actor,from,target.global_position + Vector3.UP * 1.2,[],1).is_empty()

func targeted(maximum: float, angle: float = 12.0) -> HeroActor:
	var best: HeroActor = null
	var score: float = cos(deg_to_rad(angle))
	var origin: Vector3 = actor.intent.aim_origin
	if origin == Vector3.ZERO: origin = actor.global_position + Vector3.UP * 1.4
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if actor.global_position.distance_to(other.global_position) > maximum or not sight(other): continue
		var direction: Vector3 = (other.global_position + Vector3.UP * 1.2 - origin).normalized()
		var dot: float = direction.dot(actor.aim_direction)
		if dot > score:
			score = dot
			best = other
	return best

func disconnect_beam() -> void:
	patient = null
	beam_healing = false
	obstruction_age = 0

func tick(delta: float, input: CombatIntent) -> void:
	tick_common(delta)
	var t := data()
	beam_healing = false
	if actor.state == "doctor_ultimate" and actor.state_time <= 0:
		if sight(pending_patient) and actor.global_position.distance_to(pending_patient.global_position) <= t.exemplary_range and not pending_patient.benefits.has_kind("exemplary"):
			if pending_patient.benefits.grant("exemplary",actor,t.exemplary_duration):
				ultimate_charge = 0
				CombatEffect.pulse(actor.get_parent(),pending_patient.global_position + Vector3.UP,Color("ffe3a2"),1.5)
				actor.resolver.record("buff",actor,"exemplary","target=" + pending_patient.actor_id)
		actor.state = "ready"
		pending_patient = null
	if input.hover and mobility_cd <= 0 and actor.permits("house_call") and not actor.statuses.movement_disabled():
		start_call()
	if input.deflect and deflect_cd <= 0 and actor.permits("deflect"):
		for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
			if not other.alive or other.team != actor.team or actor.global_position.distance_to(other.global_position) > t.ward_radius: continue
			if other != actor and not sight(other): continue
			actor.resolver.heal(actor,other,t.ward_heal,"ward_round")
			other.benefits.grant("ward",actor,t.ward_duration,t.ward_rate)
		deflect_cd = t.ward_cooldown
		CombatEffect.pulse(actor.get_parent(),actor.global_position + Vector3.UP,Color("9aefca"),t.ward_radius)
		actor.presentation.sound.play_tone(520,.22,.16)
		actor.resolver.record("cast",actor,"ward_round")
	if input.bomb and bomb_cd <= 0 and actor.permits("bomb"):
		var target: HeroActor = targeted(t.beam_range)
		if target != null:
			target.statuses.cleanse()
			actor.resolver.heal(actor,target,t.prescription_heal,"prescription")
			target.benefits.grant("prescription",actor,t.prescription_duration,t.prescription_reduction)
			bomb_cd = t.prescription_cooldown
			CombatEffect.pulse(actor.get_parent(),target.global_position + Vector3.UP,Color("e5faff"),1.0)
			actor.resolver.record("cast",actor,"clean_prescription")
	if input.ultimate and ultimate_charge >= 100 and actor.permits("ultimate"):
		var target: HeroActor = targeted(t.exemplary_range)
		if target != null and not target.benefits.has_kind("exemplary"):
			pending_patient = target
			actor.state = "doctor_ultimate"
			actor.state_time = t.exemplary_windup
			actor.resolver.record("cast",actor,"exemplary_condition")
	if input.secondary_held and actor.state in ["ready","doctor_ultimate"] and actor.motor.mode not in ["dash","dash_windup"]:
		update_beam(delta)
	else: disconnect_beam()
	if not input.secondary_held and (input.primary_held or input.primary): weapon(t.rifle_damage)
	if input.reload: reload_weapon()
	if input.projectile_fire: fire_projectile(input.aim)

func update_beam(delta: float) -> void:
	var t := data()
	var candidate: HeroActor = targeted(t.beam_range,t.beam_acquire)
	# A newly aimed patient wins immediately over the old patient's retention cone.
	if candidate != null and candidate != patient:
		patient = candidate
		obstruction_age = 0
	if is_instance_valid(patient):
		var origin: Vector3 = actor.intent.aim_origin if actor.intent.aim_origin != Vector3.ZERO else actor.global_position + Vector3.UP * 1.4
		var dot: float = (patient.global_position + Vector3.UP * 1.2 - origin).normalized().dot(actor.aim_direction)
		if not patient.alive or patient.team != actor.team or actor.global_position.distance_to(patient.global_position) > t.beam_range or dot < cos(deg_to_rad(t.beam_retain)):
			disconnect_beam()
	if not is_instance_valid(patient): return
	if not sight(patient):
		obstruction_age += delta
		if obstruction_age > t.beam_grace: disconnect_beam()
		return
	obstruction_age = 0
	beam_healing = true
	actor.resolver.heal(actor,patient,t.beam_rate * delta,"attending_care")
	patient.benefits.grant("aftercare",actor,t.aftercare_duration,t.aftercare_rate)
	beam_draw_age -= delta
	if beam_draw_age <= 0:
		beam_draw_age = .045
		CombatEffect.streak(actor.get_parent(),actor.muzzle(),patient.global_position + Vector3.UP * 1.2,.055,.08)

func start_call() -> bool:
	var target: HeroActor = targeted(data().call_range)
	if target == null: return false
	var offset: Vector3 = target.global_position - actor.global_position
	if offset.length() <= data().call_stop: return false
	var destination: Vector3 = target.global_position - offset.normalized() * data().call_stop
	var motion: Vector3 = destination - actor.global_position
	# Check the full capsule sweep before spending the cooldown.
	if actor.test_move(actor.global_transform,motion): return false
	call_destination = destination
	actor.motor.interrupt_mobility()
	actor.state = "doctor_call"
	disconnect_beam()
	mobility_cd = data().call_cooldown
	actor.resolver.record("cast",actor,"house_call")
	return true

func move_override(delta: float) -> bool:
	if actor.state != "doctor_call": return false
	if actor.statuses.movement_disabled():
		actor.state = "ready"
		return false
	var offset: Vector3 = call_destination - actor.global_position
	var motion: Vector3 = offset.limit_length(data().call_speed * delta)
	var collision: KinematicCollision3D = actor.move_and_collide(motion)
	actor.velocity = Vector3.ZERO
	if collision != null or offset.length() <= data().call_speed * delta + .001: actor.state = "ready"
	return true

func cancel(clear_owned: bool = false) -> void:
	disconnect_beam()
	pending_patient = null
	if actor.state.begins_with("doctor_"): actor.state = "ready"
	super.cancel(clear_owned)
