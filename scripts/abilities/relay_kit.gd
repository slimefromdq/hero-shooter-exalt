class_name RelayKit
extends ExpansionKit

var battery: float = 100.0
var recipient: HeroActor
var recipient_life: int = -1
var transfer_left: float = 0.0
var transfer_cd: float = 0.0
var circuit_left: float = 0.0
var drone: Node3D
var aura: Node3D

func data() -> RelayTuning:
	return actor.tuning as RelayTuning

func _ready() -> void:
	refill()
	drone = RosterEffects.drone(self)
	drone.global_position = drone_position()

func drone_position() -> Vector3:
	if is_instance_valid(recipient): return recipient.body_point(1.85)+Vector3(.5,.3,0)
	return actor.body_point(1.7)+actor.global_basis.x*-.5

func ultimate_active() -> bool:
	return circuit_left > 0

func assign(target: HeroActor) -> bool:
	if not can_act("assign") or transfer_cd > 0 or not is_instance_valid(target) or not target.alive or target.team != actor.team: return false
	if actor.resolver.protected_room(target): return false
	if not ultimate_active() and battery < data().deploy_energy: return false
	if target != actor:
		if actor.global_position.distance_to(target.global_position) > data().assign_range: return false
		if not actor.resolver.attack_ray(actor,actor.body_point(1.4),target.body_point(1.2),[],1).is_empty(): return false
	if target == recipient: return false
	recipient = target
	recipient_life = target.life_serial
	transfer_left = data().transfer_time
	transfer_cd = data().transfer_cooldown
	actor.resolver.record("cast",actor,"drone_assign","target="+target.actor_id)
	CombatEffect.pulse(actor.get_parent(),target.body_point(1.5),Color("ffc561"),.7)
	return true

func recall() -> void:
	recipient = null
	recipient_life = -1
	transfer_left = 0

func aimed_ally() -> HeroActor:
	var best: HeroActor
	var score: float = cos(deg_to_rad(12))
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if other == actor or other.team != actor.team or not other.alive: continue
		if other.global_position.distance_to(actor.global_position) > data().assign_range or actor.resolver.protected_room(other): continue
		if not actor.resolver.attack_ray(actor,actor.body_point(1.4),other.body_point(1.2),[],1).is_empty(): continue
		var dot: float = (other.body_point(1.2)-aim_origin()).normalized().dot(actor.aim_direction)
		if dot > score:
			score = dot
			best = other
	return best

func tick(delta: float, input: CombatIntent) -> void:
	tick_common(delta)
	var t := data()
	transfer_cd = maxf(0,transfer_cd-delta)
	if is_instance_valid(recipient) and (not recipient.alive or recipient.life_serial != recipient_life or recipient.team != actor.team): recall()
	if actor.state == "relay_circuit_start" and actor.state_time <= 0:
		actor.state = "ready"
		circuit_left = t.circuit_duration
		ultimate_charge = 0
		actor.presentation.sound.play_tone(720,.4,.22)
	if input.secondary_pressed: assign(aimed_ally())
	if input.bomb and actor.permits("recall"):
		if is_instance_valid(recipient): recall()
		else: assign(actor)
	if input.hover and mobility_cd <= 0 and can_act("kickstart"):
		actor.motor.interrupt_mobility()
		var wish: Vector3 = input.move if not input.move.is_zero_approx() else actor.aim_direction*Vector3(1,0,1)
		actor.velocity = wish.normalized()*t.jump_forward+Vector3.UP*t.jump_up
		actor.motor.transition("air")
		mobility_cd = t.jump_cooldown
		CombatEffect.pulse(actor.get_parent(),actor.global_position,Color("ffc561"),1)
	if input.deflect and deflect_cd <= 0 and battery >= t.shock_energy and can_act("deflect"):
		battery -= t.shock_energy
		deflect_cd = t.shock_cooldown
		var at: Vector3 = drone_position()
		actor.resolver.splash(actor,at,t.shock_radius,t.shock_damage,"drone_shock",actor.resolver.new_cast(actor))
		CombatEffect.pulse(actor.get_parent(),at,Color("ffb54f"),t.shock_radius)
		actor.presentation.sound.play_tone(130,.2,.2)
		actor.resolver.record("cast",actor,"shock_delivery")
	if input.ultimate and ultimate_charge >= 100 and not ultimate_active() and can_act("ultimate"):
		actor.state = "relay_circuit_start"
		actor.state_time = t.circuit_preparation
		actor.resolver.record("cast",actor,"full_circuit")
	tick_drone(delta)
	if actor.infinite_resources: battery = t.battery_capacity
	if input.primary or input.primary_held: fire()
	if input.reload: start_reload()
	if is_instance_valid(drone):
		drone.visible = actor.alive
		drone.global_position = drone_position()
		drone.rotation.y += delta*3
		drone.scale = Vector3.ONE*(.6 if transfer_left > 0 else 1.0)
	if ultimate_active():
		if not is_instance_valid(aura): aura = RosterEffects.zone(actor.get_parent(),drone_position(),t.circuit_radius,Color("ffca66"))
		aura.global_position = drone_position()-Vector3.UP*1.5
	elif is_instance_valid(aura):
		aura.queue_free()
		aura = null

func tick_drone(delta: float) -> void:
	var t := data()
	var left: float = delta
	while left > .000001:
		var slice: float = left
		if ultimate_active(): slice = minf(slice,circuit_left)
		if transfer_left > 0:
			slice = minf(slice,transfer_left)
			transfer_left = maxf(0,transfer_left-slice)
		elif ultimate_active():
			for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
				if not other.alive or other.team != actor.team or other.body_point(1).distance_to(drone_position()) > t.circuit_radius: continue
				other.benefits.grant("circuit",actor,.12,t.circuit_haste)
				if circuit_healer(other) == actor: actor.resolver.heal(actor,other,t.circuit_heal*slice,"circuit",false)
		elif is_instance_valid(recipient):
			if battery <= .00001:
				recall()
				continue
			slice = minf(slice,battery/t.battery_drain)
			actor.resolver.heal(actor,recipient,t.heal_rate*slice,"drone")
			battery = maxf(0,battery-t.battery_drain*slice)
			if battery <= .00001: recall()
		else: battery = minf(t.battery_capacity,battery+t.battery_recharge*slice)
		if ultimate_active(): circuit_left = maxf(0,circuit_left-slice)
		left -= slice

func circuit_healer(target: HeroActor) -> HeroActor:
	var best: HeroActor = actor
	var rate: float = data().circuit_heal
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if not other.alive or other.team != actor.team or not other.kit is RelayKit: continue
		var kit := other.kit as RelayKit
		if not kit.ultimate_active() or kit.transfer_left > 0 or target.body_point(1).distance_to(kit.drone_position()) > kit.data().circuit_radius: continue
		if kit.data().circuit_heal > rate or (is_equal_approx(kit.data().circuit_heal,rate) and other.get_instance_id() < best.get_instance_id()):
			best = other
			rate = kit.data().circuit_heal
	return best

func fire(_ultimate: bool = false) -> void:
	if not can_act("primary") or shot_cd > 0: return
	if ammo <= 0:
		start_reload()
		return
	consume_ammo()
	shot_cd = primary_interval()+cadence_debt
	launch(shot_direction(data().carbine_range),actor.tuning.rifle_damage,data().carbine_speed,data().carbine_range,Color("ffcf70"),0,true)
	feedback(470)
	actor.resolver.record("cast",actor,"carbine")

func cancel(clear_owned: bool = false) -> void:
	if actor.state.begins_with("relay_"): actor.state = "ready"
	if clear_owned:
		recall()
		if is_instance_valid(drone): drone.visible = false
		circuit_left = 0
		if is_instance_valid(aura): aura.queue_free()
		aura = null
	super.cancel(clear_owned)

func refill() -> void:
	super.refill()
	battery = data().battery_capacity
	transfer_cd = 0
