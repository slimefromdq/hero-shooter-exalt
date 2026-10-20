class_name BotCombat
extends RefCounted
## Tactical scoring is separate from input execution. No damage or teleport shortcuts.
var aim: Vector3 = Vector3.FORWARD
var aim_speed: float = 0.0
var intention: String = "pressure"
var choice: Dictionary = {}
var ability_scores: Dictionary = {}
var aim_error: Vector2 = Vector2.ZERO
var error_goal: Vector2 = Vector2.ZERO
var next_error: float = 0.0
var pending_bomb: bool = false
var bomb: PocketBomb
var bomb_life: int = -1
var bomb_cast: int = -1
var bomb_started: float = -99.0
var next_bomb_check: float = 0.0
var bomb_visible: bool = false
var bomb_value: float = 0.0
var future_bomb_value: float = 0.0
var bomb_attempt_cast: int = -1
var cancel_reason: String = ""
var wall_point: Vector3 = Vector3.ZERO

func cancel(reason: String) -> void:
	choice = {}
	intention = "cancel: "+reason
	cancel_reason = reason
	pending_bomb = false
	bomb = null
	bomb_visible = false
	bomb_value = 0

func offer(action: String, score: float, point: Vector3 = Vector3.INF, held: bool = false) -> void:
	ability_scores[action] = clampf(score,0,1)
	if score < .5 or score <= float(choice.get("score",0)): return
	choice = {"action":action,"score":score,"point":point,"held":held}

func evaluate(brain: BotBrain) -> void:
	var a: HeroActor = brain.actor
	var k: HeroKit = a.kit
	choice = {}
	ability_scores.clear()
	if k is SamsonKit:
		var target: HeroActor = brain.threat.actor.get_ref() as HeroActor if brain.ready_to_attack() and brain.threat.has("actor") else null
		var selected: Dictionary = SamsonTactics.choice(a,target,brain.nearby_enemies)
		if not selected.is_empty(): offer(selected.action,selected.score,selected.point)
		intention = "Samson " + str(selected.get("action","support"))
		return
	if k is NimbusKit and a.state == "ultimate":
		intention = "Final Notice shots"
		return
	var seen: bool = brain.ready_to_attack()
	var enemy: Dictionary = brain.threat
	var clear_shot: bool = not bool(enemy.get("blocked_by_barrier",false))
	var point: Vector3 = enemy.get("position",a.global_position)+Vector3.UP
	var distance: float = a.global_position.distance_to(point) if seen else INF
	var health: float = a.health/a.effective_max_health()
	var escaping: bool = brain.tactical_state in ["retreat","regroup"]
	var patient: HeroActor = brain.patient
	var patient_visible: bool = false
	if is_instance_valid(patient): patient_visible = a.resolver.attack_ray(a,a.body_point(1.45),patient.body_point(1.2),[a.get_rid()],1).is_empty()
	var patient_need: float = 1-patient.health/patient.effective_max_health() if is_instance_valid(patient) else 0.0
	var impact: float = .4+mini(3,brain.nearby_enemies)*.15+(.15 if float(brain.context.get("urgency",0)) > .8 else 0.0)
	if seen and distance < 3.5 and str(enemy.state) in ["melee_windup","melee_active"] and a.close.guard_meter > 30: offer("guard",.98,point,true)
	if seen and a.close.incoming_throw() != null and brain.rng.randf() < brain.skill.consistency: offer("throw_action",.99,point)
	if seen and distance < a.tuning.melee_range and float(enemy.health) < a.tuning.melee_damage and a.permits("melee"): offer("melee",.87,point)
	if a.kit is NimbusKit:
		if seen and k.deflect_cd <= 0 and a.last_hit_age < .8: offer("deflect",.82,point)
		if seen and clear_shot and not escaping and distance > 7 and distance < 25 and k.bomb_cd <= 0 and k.ammo > 0 and not k.reloading and k.shot_cd < .2 and a.state == "ready":
			# Use a low ballistic solution; speed/gravity are the actual bomb's values.
			var flight: float = distance/a.tuning.bomb_throw_speed
			var predicted: Vector3 = point+Vector3(enemy.velocity)*flight*brain.skill.prediction
			var throw_point: Vector3 = predicted+Vector3.UP*(7.5*flight*flight-3.8*flight)
			offer("bomb",.68+minf(.15,brain.nearby_enemies*.05),throw_point)
		if seen and distance > 10 and distance < brain.hero_profile.maximum_range+6 and a.motor.hover_cd <= 0 and a.motor.grounded() and not escaping and brain.hero_profile.mobility > .5:
			if a.resolver.ray(a.body_point(2),a.body_point(6),[a.get_rid()],1).is_empty(): offer("hover",.53,point)
		var finish_value: bool = seen and (float(enemy.health)/maxf(1,float(enemy.maximum)) <= a.tuning.execute_threshold or (str(enemy.role) == "support" and float(enemy.health) <= a.tuning.ultimate_damage))
		if seen and clear_shot and not escaping and not pending_bomb and not is_instance_valid(bomb) and k.ultimate_charge >= 100 and a.state == "ready" and (impact >= .7 or finish_value): offer("ultimate",maxf(impact,.8 if finish_value else 0.0),point)
	elif k is SlayerKit:
		var hunter := k as SlayerKit
		if seen and clear_shot and hunter.knives > 0 and distance > 8 and distance < hunter.data().knife_range: offer("hover",.63,point)
		if seen and not escaping and distance > 4 and distance < hunter.data().boot_distance and hunter.deflect_cd <= 0 and (brain.follow_up > 0 or brain.nearby_enemies <= 1) and health > .4:
			var direction: Vector3 = (point-a.body_point(1)).normalized()*Vector3(1,0,1)
			if brain.movement.safe_travel(a,direction,minf(distance-1,hunter.data().boot_distance)): offer("deflect",.77,point)
		if escaping and seen and hunter.deflect_cd <= 0:
			var away: Vector3 = ((a.global_position-point)*Vector3(1,0,1)).normalized()
			if brain.movement.safe_travel(a,away,hunter.data().boot_distance): offer("deflect",.95,a.body_point(1.45)+away*12)
		if seen and hunter.snares > 0 and distance < 13 and (escaping or str(enemy.state).begins_with("melee") or brain.tactical_state == "hold"): offer("bomb",.65,point)
		if seen and clear_shot and hunter.ultimate_charge >= 100 and distance < hunter.data().axe_range and not escaping and (float(enemy.health) > 150 or brain.nearby_enemies >= 2 or (float(enemy.health) <= hunter.data().axe_damage and distance > hunter.data().falloff_start)): offer("ultimate",maxf(.75,impact),point)
	elif k is MarshalKit:
		var marshal := k as MarshalKit
		if seen and distance > 6 and marshal.barrier_hp > 120 and marshal.break_remaining <= 0 and (a.last_hit_age < 1.5 or brain.tactical_state in ["protect","hold"]): offer("secondary_held",.74,point,true)
		if CareTactics.rally_worthwhile(a): offer("deflect",.9)
		var march_toward: Vector3 = ((point-a.global_position)*Vector3(1,0,1)).normalized()
		if seen and not escaping and distance < marshal.data().march_range-1 and distance > 3 and marshal.mobility_cd <= 0 and CareTactics.marshal_safe_lane(a,march_toward,marshal.data().march_range):
			offer("hover",.82 if str(brain.threat.get("state","")) in ["ultimate","melee_windup","marshal_verdict"] else .72,point)
		if seen and distance > 6 and distance < marshal.data().breach_count*marshal.data().breach_spacing and k.bomb_cd <= 0 and MarshalOrbitalTargeting.can_strike(a,(point-a.body_point(1.2)).normalized(),Vector3(enemy.position)+Vector3.UP*.9): offer("bomb",.65,point)
		if seen and distance < marshal.data().verdict_range and k.ultimate_charge >= 100 and not escaping and CareTactics.marshal_verdict_safe(a,march_toward): offer("ultimate",impact,point)
	elif k is DoctorKit:
		var doctor := k as DoctorKit
		var self_defense: bool = seen and distance < 5 and health < .4
		if patient_visible and a.global_position.distance_to(patient.global_position) < doctor.data().beam_range:
			if patient_need > .06 and not (seen and distance < 5 and health < .4): offer("secondary_held",.55+patient_need*.4,patient.body_point(1.2),true)
			if not self_defense and k.bomb_cd <= 0 and (patient.statuses.effects.size() > 0 or patient_need > .55): offer("bomb",.89,patient.body_point(1.2))
			if not self_defense and k.ultimate_charge >= 100 and patient.last_hit_age < 2 and not patient.benefits.has_kind("exemplary") and brain.nearby_enemies > 0 and patient_need < .8: offer("ultimate",.88,patient.body_point(1.2))
			if escaping and a.global_position.distance_to(patient.global_position) > 6 and doctor.mobility_cd <= 0 and patient.last_hit_age > 1 and brain.movement.safe_travel(a,patient.global_position-a.global_position,a.global_position.distance_to(patient.global_position)-2): offer("hover",.94,patient.body_point(1.2))
		var injured: int = 0
		for ally: HeroActor in brain.allies:
			if a.global_position.distance_to(ally.global_position) <= doctor.data().ward_radius and ally.health < ally.effective_max_health()*.8: injured += 1
		if k.deflect_cd <= 0 and (injured >= 2 or health < .5): offer("deflect",.98 if self_defense else .85)
	elif k is HuddleKit:
		var huddle := k as HuddleKit
		if seen and distance < huddle.data().pulse_radius and k.bomb_cd <= 0: offer("bomb",.85,point)
		if patient_visible and patient.last_hit_age < 1.5 and a.global_position.distance_to(patient.global_position) < huddle.data().screen_range and k.deflect_cd <= 0: offer("deflect",.9,patient.body_point(1.2))
		elif a.last_hit_age < 1 and seen and k.deflect_cd <= 0: offer("deflect",.8,point)
		if health < .8 and a.last_hit_age > 1.5 and distance > 10 and (huddle.regroup_cd <= 0 or a.state == "huddle_regroup"): offer("secondary_held",.8,a.body_point(1.4)+aim,true)
		if seen and huddle.scatter_charges > (0 if escaping else brain.hero_profile.escape_reserve) and (escaping or (distance > 10 and distance < 20 and brain.follow_up > 0)):
			var direction: Vector3 = ((a.global_position-point) if escaping else (point-a.global_position)).normalized()
			if brain.movement.safe_travel(a,direction,huddle.data().scatter_distance): offer("hover",.95 if escaping else .7,a.body_point(1.45)+direction*10)
		if seen and brain.nearby_enemies >= 2 and k.ultimate_charge >= 100 and not escaping and huddle.supported(a.global_position): offer("ultimate",impact,point)
	elif k is StitchKit:
		var stitch := k as StitchKit
		if not stitch.concealed and k.deflect_cd <= 0 and a.state == "ready" and (escaping or (seen and distance > 10 and brain.nearby_enemies <= 1)): offer("deflect",.93 if escaping else .66)
		if seen and not escaping and distance > 3 and distance <= stitch.data().thread_range and k.bomb_cd <= 0: offer("bomb",.81,point)
		if seen and not escaping and distance > 5 and distance < stitch.data().hook_range and k.mobility_cd <= 0 and is_instance_valid(stitch.thread) and stitch.thread.valid() and int(enemy.id) == stitch.thread.target.get_instance_id():
			if brain.movement.safe_travel(a,point-a.body_point(1),distance-1): offer("hover",.85,point)
		if seen and clear_shot and not escaping and int(enemy.get("marks",0)) > 0 and distance < stitch.data().seam_range and k.ultimate_charge >= 100 and float(enemy.health) <= stitch.data().seam_damage+int(enemy.marks)*stitch.data().mark_damage: offer("ultimate",.94,point)
	elif k is RelayKit:
		var relay := k as RelayKit
		if is_instance_valid(relay.recipient) and relay.battery < 22 and not relay.ultimate_active(): offer("bomb",.92)
		elif patient_visible and patient_need > .18 and relay.recipient != patient and relay.transfer_cd <= 0 and (relay.battery >= 55 or relay.ultimate_active()): offer("secondary_pressed",.8,patient.body_point(1.2))
		elif not is_instance_valid(relay.recipient) and health < .55 and relay.battery >= 40: offer("bomb",.88)
		if seen and point.distance_to(relay.drone_position()) < relay.data().shock_radius and relay.battery >= relay.data().shock_energy+20 and k.deflect_cd <= 0: offer("deflect",.83,point)
		if escaping and seen and relay.mobility_cd <= 0:
			var away: Vector3 = ((a.global_position-point)*Vector3(1,0,1)).normalized()
			if brain.movement.safe_travel(a,away,5): offer("hover",.96,a.body_point(1.45)+away*10)
		var beneficiaries: int = 0
		for ally: HeroActor in brain.allies:
			if ally.global_position.distance_to(relay.drone_position()) < relay.data().circuit_radius and (ally.last_hit_age < 2 or ally.health < ally.effective_max_health()*.8): beneficiaries += 1
		if beneficiaries >= 2 and brain.nearby_enemies > 0 and k.ultimate_charge >= 100 and not relay.ultimate_active(): offer("ultimate",.9)
	elif k is DynamoKit:
		var dynamo := k as DynamoKit
		if dynamo.previewing:
			offer("primary",.99,wall_point)
		elif seen:
			if dynamo.mobility_cd <= 0 and dynamo.charge_left <= 0 and (brain.nearby_enemies >= 2 or brain.tactical_state == "commit"): offer("hover",.68,point)
			if k.bomb_cd <= 0 and distance > 5 and distance < dynamo.data().stone_range: offer("bomb",.73,enemy.position+Vector3.UP*.05)
			if k.ultimate_charge >= 100 and distance < dynamo.data().storm_range and impact >= .7: offer("ultimate",impact,enemy.position+Vector3.UP*.05)
			if k.deflect_cd <= 0 and not is_instance_valid(dynamo.wall) and brain.danger > .55 and distance > 12:
				wall_point = a.global_position+(point-a.global_position).normalized()*7
				wall_point.y = a.global_position.y+.05
				var wall_safe: bool = wall_point.distance_to(brain.context.position) > 5
				for ally: HeroActor in brain.allies:
					if ally.global_position.distance_to(wall_point) < 5: wall_safe = false
				if wall_safe: offer("deflect",.91,wall_point)
	elif k is WispKit:
		var wisp := k as WispKit
		var effective_health: float = float(enemy.get("health",INF))+float(enemy.get("shields",0))+float(enemy.get("overhealth",0))
		if seen and clear_shot and wisp.shells > 0 and distance < wisp.data().shotgun_range and (int(enemy.marks) >= 3 or effective_health <= wisp.estimated_burst(distance,int(enemy.marks))): offer("secondary_pressed",.89,point)
		if seen and health < .45 and k.deflect_cd <= 0 and a.last_hit_age < 1.5: offer("deflect",.98,point)
		var evading: bool = seen and (a.last_hit_age < .3 or str(enemy.state) in ["melee_windup","ultimate","slayer_axe","wisp_heist_start"]) and Vector3(enemy.get("facing",Vector3.ZERO)).dot((a.global_position-point).normalized()) > .6
		if evading and wisp.steps > 0:
			var evade: Vector3 = RosterTactics.wisp_escape(a,point)
			if brain.movement.safe_travel(a,evade,wisp.data().step_distance): offer("hover",.95,a.body_point(1.45)+evade*10)
		if seen and wisp.steps > (0 if escaping else brain.hero_profile.escape_reserve) and (escaping or (wisp.shells < wisp.data().shell_limit and distance > 8 and distance < 23)):
			var direction: Vector3 = ((a.global_position-point) if escaping else (point-a.global_position))*Vector3(1,0,1)
			if brain.movement.safe_travel(a,direction,wisp.data().step_distance): offer("hover",.92 if escaping else .74,a.body_point(1.45)+direction.normalized()*10)
		if seen and distance < 16 and a.motor.grounded() and k.bomb_cd <= 0 and not escaping and brain.movement.safe_travel(a,(point-a.global_position)*Vector3(1,0,1),5) and a.resolver.ray(a.body_point(2),a.body_point(6),[a.get_rid()],1).is_empty(): offer("bomb",.55,point)
		if seen and clear_shot and distance < wisp.data().heist_range and (brain.nearby_enemies >= 2 or int(enemy.marks) >= 2) and k.ultimate_charge >= 100 and not escaping:
			var predicted: Vector3 = point+Vector3(enemy.velocity)*(distance/wisp.data().heist_speed+wisp.data().heist_warning)*brain.skill.prediction
			offer("ultimate",maxf(.8,impact),predicted)
	if not choice.is_empty(): intention = str(choice.action)
	elif not is_instance_valid(bomb) and not pending_bomb: intention = "pressure" if seen else "acquire"

func track_aim(desired: Vector3, brain: BotBrain, delta: float, precise: bool = false) -> Vector3:
	if desired.is_zero_approx(): return aim
	var now: float = brain.actor.resolver.combat_time
	if now >= next_error:
		next_error = now+.3
		error_goal = Vector2(brain.rng.randf_range(-1,1),brain.rng.randf_range(-1,1))
	aim_error = aim_error.move_toward(error_goal,delta*3)
	var distance: float = brain.actor.global_position.distance_to(brain.threat.get("position",brain.actor.global_position))
	var penalty: float = (1+distance/50.0)*(1.4 if not brain.actor.motor.grounded() else 1.0)
	var error: float = deg_to_rad(brain.skill.error_degrees)*penalty*(.3 if precise else 1.0)
	var wanted: Vector3 = desired.normalized().rotated(Vector3.UP,aim_error.x*error)
	var right: Vector3 = wanted.cross(Vector3.UP).normalized()
	if not right.is_zero_approx(): wanted = wanted.rotated(right,aim_error.y*error)
	var angle: float = aim.angle_to(wanted)
	aim_speed = move_toward(aim_speed,deg_to_rad(brain.skill.turn_speed),deg_to_rad(brain.skill.tracking_acceleration)*delta)
	if angle > .00001: aim = aim.slerp(wanted,minf(1,aim_speed*delta/angle)).normalized()
	return aim

func update_bomb(brain: BotBrain, input: CombatIntent, delta: float) -> bool:
	var a: HeroActor = brain.actor
	if not a.kit is NimbusKit: return false
	var now: float = a.resolver.combat_time
	if pending_bomb and not is_instance_valid(bomb):
		for owned: PocketBomb in a.get_tree().get_nodes_in_group("pocket_bombs"):
			if owned.source == a and owned.airborne and not owned.detonated:
				bomb = owned
				bomb_life = a.life_serial
				bomb_cast = owned.cast_id
				pending_bomb = false
				break
		if now-bomb_started > .3:
			cancel("throw unavailable")
			return false
	if not is_instance_valid(bomb): return false
	if bomb.source != a or bomb.cast_id != bomb_cast or a.life_serial != bomb_life or not bomb.airborne or bomb.detonated or bomb.is_queued_for_deletion() or bomb.fuse <= 0:
		cancel("bomb ineligible")
		return false
	if brain.tactical_state in ["retreat","regroup"] or a.state == "ultimate":
		cancel("survival or ultimate")
		return false
	if now >= next_bomb_check:
		next_bomb_check = now+.05
		var hit: Dictionary = a.resolver.weapon_ray(a,input.aim_origin,bomb.global_position,[a.get_rid()])
		bomb_visible = hit.get("collider") == bomb
		bomb_value = 0
		future_bomb_value = 0
		for id: int in brain.perception.visible_ids:
			var enemy: Dictionary = brain.perception.observations[id]
			var distance: float = bomb.global_position.distance_to(enemy.position+Vector3.UP*.9)
			if distance < a.tuning.bomb_radius and a.resolver.attack_ray(a,bomb.global_position,enemy.position+Vector3.UP*.9,[bomb.get_rid()],1).is_empty():
				bomb_value += a.tuning.bomb_damage*(1-distance/a.tuning.bomb_radius)
				var future: Vector3 = bomb.global_position+bomb.velocity*.1+Vector3.DOWN*.075
				var future_distance: float = future.distance_to(enemy.position+Vector3(enemy.velocity)*.1+Vector3.UP*.9)
				future_bomb_value += a.tuning.bomb_damage*maxf(0,1-future_distance/a.tuning.bomb_radius)
	if not bomb_visible:
		cancel("bomb occluded")
		return false
	if brain.threat.is_empty():
		cancel("no blast opportunity")
		return false
	# Track before entering the blast window; normal rifle shots are hitscan.
	intention = "track airborne bomb"
	input.aim = track_aim(bomb.global_position-input.aim_origin,brain,delta,true)
	var aligned: bool = input.aim.angle_to((bomb.global_position-input.aim_origin).normalized()) < atan2(.11,input.aim_origin.distance_to(bomb.global_position))
	var release_now: bool = bomb_value >= maxf(35,a.tuning.rifle_damage*.8) and (bomb_value >= future_bomb_value*.9 or bomb.fuse < .2)
	if aligned and release_now and a.kit.shot_cd <= 0 and not a.kit.reloading and a.kit.ammo > 0 and a.permits("primary") and now-bomb_started >= brain.skill.acquisition_delay:
		input.primary = true
		intention = "shoot airborne bomb"
		if bomb_attempt_cast != bomb_cast:
			brain.diagnostics.bomb_attempts += 1
			bomb_attempt_cast = bomb_cast
	return true

func execute(brain: BotBrain, input: CombatIntent, delta: float, fresh: bool) -> void:
	var a: HeroActor = brain.actor
	if a.kit is SamsonKit and a.state.begins_with("samson_"): return
	if a.kit is WispKit:
		RosterTactics.wisp_air_controls(a,input,brain.tactical_state in ["retreat","regroup"])
		if a.state == "wisp_phase":
			input.primary = false
			input.primary_held = false
			input.deflect = false
			return
	if a.resolver.attack_locked(a):
		cancel("protected room")
		return
	if a.kit is StitchKit and a.concealed():
		var stitch := a.kit as StitchKit
		var close_prey: bool = brain.ready_to_attack() and a.global_position.distance_to(brain.threat.position) < stitch.data().opening_range
		if not close_prey:
			input.aim = aim
			input.deflect = stitch.conceal_left < stitch.data().conceal_duration-3 and brain.tactical_state in ["contest","hold","investigate","pressure"]
			return
	if update_bomb(brain,input,delta): return
	var acquired: bool = brain.ready_to_attack()
	var desired: Vector3 = input.move if input.move.length() > .1 else aim
	if acquired and brain.tactical_state not in ["retreat","regroup"]:
		var point: Vector3 = brain.threat.position+Vector3.UP*1.1
		var lead: float = 0.0
		if a.kit is SamsonKit: lead = a.global_position.distance_to(point)/(a.tuning as SamsonTuning).ink_speed
		elif a.kit is StitchKit: lead = a.global_position.distance_to(point)/(a.tuning as StitchTuning).needle_speed
		elif a.kit is RelayKit: lead = a.global_position.distance_to(point)/(a.tuning as RelayTuning).carbine_speed
		elif a.kit is MarshalKit: lead = a.global_position.distance_to(point)/(a.tuning as MarshalTuning).cannon_speed
		elif a.kit is HuddleKit: lead = a.global_position.distance_to(point)/(a.tuning as HuddleTuning).seed_speed
		if str(choice.get("action","")) == "hover" and a.kit is SlayerKit:
			lead = a.global_position.distance_to(point)/(a.tuning as SlayerTuning).knife_speed
			point.y += .5*(a.tuning as SlayerTuning).knife_gravity*lead*lead
		point += Vector3(brain.threat.velocity)*lead*brain.skill.prediction
		if a.kit is MarshalKit: point.y += .5*(a.tuning as MarshalTuning).cannon_gravity*lead*lead
		desired = point-input.aim_origin
	var action: String = str(choice.get("action",""))
	var action_point: Vector3 = choice.get("point",Vector3.INF)
	if action_point != Vector3.INF: desired = action_point-input.aim_origin
	input.aim = track_aim(desired,brain,delta)
	var aligned: bool = desired.normalized().dot(input.aim) >= cos(deg_to_rad(5))
	if acquired and aligned and brain.tactical_state not in ["retreat","regroup"]:
		input.primary = a.kit.shot_cd <= 0
		input.primary_held = a.kit is CareKit
	if a.kit.ammo == 0 or (not acquired and a.kit.ammo < a.tuning.magazine and a.state == "ready"):
		input.reload = not a.kit.reloading
	if a.kit is DynamoKit and acquired and not a.kit.reloading: input.secondary_held = true
	if a.kit is WispKit: input.jump_held = (a.kit as WispKit).glide_left > 0
	if action.is_empty(): return
	# Aiming can take multiple ticks. One-shot actions are consumed only when emitted.
	if action_point != Vector3.INF and not aligned: return
	if not bool(choice.held) and not fresh and not aligned: return
	if action == "ultimate" and a.kit is NimbusKit and a.state == "ultimate":
		choice = {}
		return
	input.primary = false
	input.primary_held = false
	input.secondary_held = false
	# Revalidate after aim delay: routing or an obstacle may have changed.
	if a.kit is MarshalKit and action in ["hover","ultimate","bomb"]:
		var forward: Vector3 = (input.aim*Vector3(1,0,1)).normalized()
		if action == "hover" and not CareTactics.marshal_safe_lane(a,forward,(a.tuning as MarshalTuning).march_range):
			choice = {}
			return
		if action == "ultimate" and not CareTactics.marshal_verdict_safe(a,forward):
			choice = {}
			return
	if a.kit is MarshalKit and action == "bomb" and not brain.threat.is_empty():
		if not MarshalOrbitalTargeting.can_strike(a,input.aim,Vector3(brain.threat.position)+Vector3.UP*.9):
			choice = {}
			return
	input.set(action,true)
	if a.kit is MarshalKit and action == "deflect":
		# The shout is instant: retain or raise a warranted barrier in the same tick.
		input.secondary_held = a.state == "marshal_shield" or ability_scores.has("secondary_held")
	if action == "hover" and a.kit is RelayKit: input.move = desired.normalized()*Vector3(1,0,1)
	if action == "bomb" and a.kit is NimbusKit:
		pending_bomb = true
		bomb_started = a.resolver.combat_time
		intention = "throw airborne bomb"
	if action == "primary" and a.kit is DynamoKit and (a.kit as DynamoKit).previewing:
		var dynamo := a.kit as DynamoKit
		input.primary = dynamo.wall_valid
		if not dynamo.wall_valid and dynamo.preview_age > 1.5: input.deflect = true
	if not bool(choice.held): choice = {}
