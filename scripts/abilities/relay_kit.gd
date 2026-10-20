class_name RelayKit
extends ExpansionKit
## Seeker keeps Relay's stable registration. Bird meshes never own healing authority.
var recipient: HeroActor
var recipient_life: int = -1
var transfer_left: float = 0.0
var transfer_cd: float = 0.0
var sight_lost: float = 0.0
var murmuration_left: float = 0.0
var extras: Array[Dictionary] = []
var birds: Array[Node3D] = []
var omen_target: HeroActor
var omen_life: int = -1
var omen_left: float = 0.0
var volley_charging: bool = false
var volley_age: float = 0.0
var volley_cd: float = 0.0
var jump_used: bool = false
var flight_age: float = 0.0
var wing_flash: float = 0.0
var swoop_flashes: Array[Dictionary] = []

func data() -> RelayTuning:
	return actor.tuning as RelayTuning

func _ready() -> void:
	refill()
	sync_birds()

func ultimate_active() -> bool:
	return murmuration_left > .000001

func valid_friend(target: Variant, life: int = -1) -> bool:
	return actor.alive and not actor.resolver.attack_locked(actor) and is_instance_valid(target) and target.alive and target.team == actor.team and (life < 0 or target.life_serial == life) and not actor.resolver.protected_room(target) and actor.global_position.distance_to(target.global_position) <= data().assign_range

func sight(target: HeroActor) -> bool:
	return target == actor or actor.resolver.attack_ray(actor,actor.body_point(1.4),target.body_point(1.2),[],1).is_empty()

func can_assign(target: HeroActor) -> bool:
	return can_act("assign") and transfer_cd <= 0 and valid_friend(target) and sight(target) and target != recipient

func aimed_ally() -> HeroActor:
	return AllyTargeting.aimed(actor,data().assign_range)

func selection_previews() -> Array[Dictionary]:
	var target := aimed_ally()
	return [{"target":target,"action":"bomb"}] if can_assign(target) else []

func assign(target: HeroActor) -> bool:
	if not can_assign(target): return false
	recipient = target
	recipient_life = target.life_serial
	sight_lost = 0
	transfer_left = data().transfer_time
	transfer_cd = data().transfer_cooldown
	update_extras()
	actor.resolver.record("cast",actor,"guiding_spirit","target="+target.actor_id)
	return true

func recall() -> void:
	recipient = null
	recipient_life = -1
	sight_lost = 0
	transfer_left = 0

func valid_omen() -> bool:
	return omen_left > .000001 and actor.alive and not actor.resolver.attack_locked(actor) and is_instance_valid(omen_target) and omen_target.alive and omen_target.life_serial == omen_life and omen_target.team != actor.team and not omen_target.concealed() and not omen_target.ability_damage_immune() and not actor.resolver.protected_room(omen_target)

func omen_multiplier(target: HeroActor) -> float:
	return 1.0+data().omen_damage if valid_omen() and target == omen_target else 1.0

func reveals(target: HeroActor, viewer: HeroActor) -> bool:
	return valid_omen() and target == omen_target and is_instance_valid(viewer) and viewer.alive and (viewer == actor or (viewer == recipient and valid_friend(recipient,recipient_life)))

func cast_omen() -> bool:
	if mobility_cd > 0 or not can_act("bomb"): return false
	var hit := actor.resolver.attack_ray(actor,aim_origin(),aim_origin()+actor.aim_direction*data().arrow_range,friendly_exclusions())
	var target := hit.get("collider") as HeroActor
	if not is_instance_valid(target) or not target.alive or target.team == actor.team or target.concealed() or target.damage_immune() or actor.resolver.protected_room(target): return false
	if not actor.resolver.attack_ray(actor,actor.body_point(1.4),target.body_point(1.2),[],1).is_empty(): return false
	omen_target = target
	omen_life = target.life_serial
	omen_left = data().omen_duration
	mobility_cd = data().omen_cooldown
	actor.resolver.record("cast",actor,"omen","target="+target.actor_id)
	feedback(610)
	return true

func guiding_wing() -> bool:
	if deflect_cd > 0 or transfer_left > 0 or not can_act("bomb") or not valid_friend(recipient,recipient_life) or not sight(recipient): return false
	actor.resolver.heal(actor,recipient,data().wing_heal,"guiding_wing")
	recipient.benefits.grant("guiding_wing",actor,data().wing_duration,data().wing_speed)
	deflect_cd = data().wing_cooldown
	wing_flash = .6
	actor.resolver.record("cast",actor,"guiding_wing")
	return true

func tick(delta: float, input: CombatIntent) -> void:
	tick_common(delta)
	transfer_cd = maxf(0,transfer_cd-delta)
	volley_cd = maxf(0,volley_cd-delta)
	wing_flash = maxf(0,wing_flash-delta)
	omen_left = maxf(0,omen_left-delta)
	if not valid_omen():
		omen_target = null
		omen_left = 0
	if actor.motor.grounded(): jump_used = false
	if actor.state == "seeker_murmuration_start" and actor.state_time <= 0:
		actor.state = "ready"
		murmuration_left = data().murmuration_duration
		ultimate_charge = 0
		update_extras()
	if input.bomb:
		var target := aimed_ally()
		assign(target if is_instance_valid(target) else actor)
	if input.hover: cast_omen()
	if input.deflect: guiding_wing()
	if input.ultimate and ultimate_charge >= 100 and not ultimate_active() and can_act("ultimate"):
		volley_charging = false
		actor.state = "seeker_murmuration_start"
		actor.state_time = data().murmuration_preparation
		actor.resolver.record("cast",actor,"murmuration")
	tick_spirit(delta)
	if volley_charging and not can_act("secondary"): volley_charging = false
	if input.secondary_pressed and not volley_charging and volley_cd <= 0 and shot_cd <= 0 and can_act("secondary"):
		volley_charging = true
		volley_age = 0
	if volley_charging:
		volley_age = minf(data().volley_charge,volley_age+delta)
		if not input.secondary_held:
			volley_charging = false
			if volley_age >= data().volley_min_charge: release_volley()
	elif input.primary or input.primary_held: fire()
	animate_birds(delta)

func tick_spirit(delta: float) -> void:
	# Split at ultimate expiry; automatic channels cannot overrun their lifetime.
	var boosted: float = minf(delta,murmuration_left)
	if boosted > 0:
		update_extras()
		heal_birds(boosted,1.0+data().murmuration_healing)
		murmuration_left = maxf(0,murmuration_left-boosted)
		if not ultimate_active():
			extras.clear()
			swoop_flashes.clear()
			sync_birds()
	if delta-boosted > 0: heal_main(delta-boosted,1.0)
	if delta == 0: heal_main(0,1.0)

func heal_main(delta: float, multiplier: float) -> void:
	if not valid_friend(recipient,recipient_life):
		recall()
		return
	var active: float = delta
	if sight(recipient): sight_lost = 0
	else:
		active = minf(delta,maxf(0,data().sight_grace-sight_lost))
		sight_lost += delta
	var transfer: float = minf(active,transfer_left)
	transfer_left = maxf(0,transfer_left-delta)
	actor.resolver.heal(actor,recipient,data().heal_rate*maxf(0,active-transfer)*multiplier,"guiding_spirit",not ultimate_active())
	if sight_lost >= data().sight_grace: recall()

func heal_birds(delta: float, multiplier: float) -> void:
	heal_main(delta,multiplier)
	for entry: Dictionary in extras:
		var target: HeroActor = entry.target if is_instance_valid(entry.target) else null
		if not valid_friend(target,entry.life): continue
		var active: float = delta
		if sight(target): entry.lost = 0.0
		else:
			active = minf(delta,maxf(0,data().sight_grace-float(entry.lost)))
			entry.lost += delta
		actor.resolver.heal(actor,target,data().heal_rate*active*multiplier,"murmuration",false)
		if entry.lost >= data().sight_grace: entry.target = null

func update_extras() -> void:
	if not ultimate_active(): return
	while extras.size() < 2: extras.append({"target":null,"life":-1,"lost":0.0})
	var used: Array[HeroActor] = []
	if valid_friend(recipient,recipient_life): used.append(recipient)
	for entry: Dictionary in extras:
		var target: HeroActor = entry.target if is_instance_valid(entry.target) else null
		if not valid_friend(target,entry.life) or target in used: entry.target = null
		else: used.append(target)
	for entry: Dictionary in extras:
		if is_instance_valid(entry.target): continue
		var best: HeroActor
		var best_need: float = -1.0
		var best_distance: float = INF
		for target: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
			if target in used or not valid_friend(target) or not sight(target): continue
			var need: float = 1-target.health/target.effective_max_health()
			var distance: float = actor.global_position.distance_to(target.global_position)
			if need > best_need or (is_equal_approx(need,best_need) and distance < best_distance):
				best_need = need
				best_distance = distance
				best = target
		entry.target = best
		entry.life = best.life_serial if is_instance_valid(best) else -1
		entry.lost = 0.0
		if is_instance_valid(best): used.append(best)
	sync_birds()

func arrow_hit(target: HeroActor) -> void:
	if not ultimate_active() or not actor.alive: return
	var patients: Array[HeroActor] = [recipient if is_instance_valid(recipient) else null]
	var lives: Array[int] = [recipient_life]
	for entry: Dictionary in extras:
		patients.append(entry.target if is_instance_valid(entry.target) else null)
		lives.append(int(entry.life))
	for index: int in patients.size():
		var patient := patients[index]
		if not valid_friend(patient,lives[index]) or not is_instance_valid(target) or not target.alive or patient.global_position.distance_to(target.global_position) > data().swoop_range: continue
		if not actor.resolver.attack_ray(actor,patient.body_point(1.5),target.body_point(1.2),[],1).is_empty(): continue
		var id := actor.resolver.new_cast(actor)
		actor.resolver.ultimate_casts[id] = true
		actor.resolver.damage(actor,target,data().swoop_damage,"spirit_swoop",id,false,false,patient.body_point(1.5))
		# Damage is unthrottled; only simultaneous visual count is bounded.
		if swoop_flashes.size() >= 24: swoop_flashes.pop_front()
		swoop_flashes.append({"bird":index,"at":target.body_point(1.2),"left":.3})

func friendly_exclusions() -> Array[RID]:
	var result: Array[RID] = []
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if other.team == actor.team: result.append(other.get_rid())
	return result

func shot_direction(reach: float) -> Vector3:
	var origin := aim_origin()
	var hit := actor.resolver.attack_ray(actor,origin,origin+actor.aim_direction*reach,friendly_exclusions())
	return (hit.get("position",origin+actor.aim_direction*reach)-safe_muzzle()).normalized()

func spawn_arrow(amount: float, index: int = -1, group: SeekerVolley = null) -> SeekerArrow:
	var arrow := SeekerArrow.new()
	arrow.source = actor
	arrow.kit = self
	arrow.damage_amount = amount
	arrow.direction = shot_direction(data().arrow_range)
	arrow.speed = data().arrow_speed
	arrow.max_distance = data().arrow_range
	arrow.piercing = ultimate_active()
	arrow.volley = group
	arrow.orbit_index = index
	actor.get_parent().add_child(arrow)
	arrow.initialize(safe_muzzle())
	return arrow

func fire(_ultimate: bool = false) -> void:
	if not can_act("primary") or shot_cd > 0 or volley_cd > 0 or volley_charging: return
	spawn_arrow(actor.tuning.rifle_damage)
	shot_cd = primary_interval()+cadence_debt
	feedback(520)
	actor.resolver.record("cast",actor,"spirit_bolts")

func release_volley() -> void:
	var group := SeekerVolley.new()
	var factor: float = lerpf(.4,1.0,clampf((volley_age-data().volley_min_charge)/(data().volley_charge-data().volley_min_charge),0,1))
	for index: int in 5: spawn_arrow(data().volley_damage*factor,index-1,group)
	volley_cd = data().volley_recovery
	shot_cd = maxf(shot_cd,volley_cd)
	feedback(780)
	actor.resolver.record("cast",actor,"talon_volley")

func spirit_jump(input: CombatIntent) -> bool:
	if jump_used or bomb_cd > 0 or not input.jump or not can_act("kickstart"): return false
	jump_used = true
	bomb_cd = data().jump_cooldown
	actor.motor.voluntary_airborne = true
	actor.velocity.y = data().jump_up
	actor.velocity += input.move.normalized()*data().jump_forward
	actor.motor.transition("air")
	CombatEffect.pulse(actor.get_parent(),actor.body_point(.3),Color("86eadf"),.7)
	actor.resolver.record("cast",actor,"spirit_jump")
	return true

func consume_ammo() -> void:
	pass

func free_slide_ammo() -> bool:
	return false

func start_reload() -> void:
	pass

func sync_birds() -> void:
	var count: int = 3 if ultimate_active() else 1
	while birds.size() > count:
		var bird := birds.pop_back() as Node3D
		if is_instance_valid(bird):
			bird.visible = false
			bird.queue_free()
	while birds.size() < count:
		birds.append(SeekerPresentation.bird(self,birds.size()))
		birds.back().global_position = bird_position(birds.size()-1)

func bird_position(index: int) -> Vector3:
	var candidate: Variant = recipient if index == 0 else extras[index-1].target if extras.size() >= index else null
	var target: HeroActor = candidate if is_instance_valid(candidate) else null
	var center: Vector3 = target.body_point(1.9) if is_instance_valid(target) else actor.body_point(1.8)
	return center+Vector3(cos(flight_age*1.7+index*TAU/3)*.7,.3+sin(flight_age*3+index)*.15,sin(flight_age*1.7+index*TAU/3)*.7)

func animate_birds(delta: float) -> void:
	flight_age += delta
	sync_birds()
	for flash: Dictionary in swoop_flashes: flash.left -= delta
	swoop_flashes = swoop_flashes.filter(func(f: Dictionary) -> bool: return f.left > 0)
	for index: int in birds.size():
		var bird := birds[index]
		bird.visible = actor.alive
		var at := bird_position(index)
		for flash: Dictionary in swoop_flashes:
			if flash.bird == index: at = at.lerp(flash.at,sin((1-float(flash.left)/.3)*PI))
		if index == 0 and wing_flash > 0: at.y += sin(wing_flash/.6*PI)*.7
		bird.global_position = at
		bird.rotation.y = -flight_age*1.7-index*TAU/3
		for side: int in [-1,1]: bird.get_node("Wing%d" % side).rotation.z = side*sin(flight_age*12+index)*.55
		var candidate: Variant = recipient if index == 0 else extras[index-1].target
		var target: HeroActor = candidate if is_instance_valid(candidate) else null
		var beam := bird.get_node("Healing") as MeshInstance3D
		beam.visible = valid_friend(target) and (index != 0 or transfer_left <= 0)
		if beam.visible:
			var end: Vector3 = target.body_point(1.1)
			beam.global_position = (at+end)*.5
			beam.scale = Vector3(.025,at.distance_to(end),.025)
			if at.distance_to(end) > .001: beam.look_at(end,Vector3.RIGHT if absf((end-at).normalized().y) > .99 else Vector3.UP)
			beam.rotate_object_local(Vector3.RIGHT,PI/2)

func cancel(clear_owned: bool = false) -> void:
	volley_charging = false
	volley_age = 0
	if actor.state.begins_with("seeker_"): actor.state = "ready"
	if clear_owned:
		recall()
		omen_target = null
		omen_left = 0
		murmuration_left = 0
		extras.clear()
		swoop_flashes.clear()
		for bird: Node3D in birds:
			if is_instance_valid(bird):
				bird.visible = false
				bird.queue_free()
		birds.clear()
	super.cancel(clear_owned)

func refill() -> void:
	super.refill()
	recall()
	transfer_cd = 0
	volley_cd = 0
	volley_charging = false
	volley_age = 0
	jump_used = false
	omen_target = null
	omen_left = 0
	murmuration_left = 0
	extras.clear()
	swoop_flashes.clear()
	wing_flash = 0
	if is_inside_tree(): sync_birds()
