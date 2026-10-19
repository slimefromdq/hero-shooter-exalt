class_name CareHUD
extends RefCounted

static func labels(a: HeroActor) -> Array[String]:
	if a.kit is SamsonKit: return ["INTERVENE","CROSS-EXAMINATION","CEASE AND DESIST"]
	if a.kit is RelayKit: return ["KICKSTART","SHOCK DELIVERY","RECALL / SELF"]
	if a.kit is DynamoKit: return ["STORMCHARGE","RAISE THE LINE","LODESTONE"]
	if a.kit is WispKit: return ["GHOSTSTEP","BETWEEN WORLDS","SPECTRAL LIFT"]
	if a.kit is HuddleKit: return ["SCATTERBOUND","WE'VE GOT YOU!","PERSONAL SPACE!"]
	var result: Array[String] = []
	result.assign(["FORWARD MARCH","RALLYING COMMAND","ORBITAL BARRAGE"] if a.kit is MarshalKit else ["HOUSE CALL","WARD ROUND","PRESCRIPTION"])
	return result

static func cooldowns(a: HeroActor) -> Array[float]:
	var k := a.kit as CareKit
	return [k.mobility_cd,k.deflect_cd,k.bomb_cd]

static func durations(a: HeroActor) -> Array[float]:
	if a.tuning is SamsonTuning:
		var s := a.tuning as SamsonTuning
		return [s.intervene_recharge,s.cross_cooldown,s.notice_cooldown]
	if a.tuning is RelayTuning:
		var t := a.tuning as RelayTuning
		return [t.jump_cooldown,t.shock_cooldown,t.transfer_cooldown]
	if a.tuning is DynamoTuning:
		var t := a.tuning as DynamoTuning
		return [t.charge_cooldown,t.wall_cooldown,t.stone_cooldown]
	if a.tuning is WispTuning:
		var t := a.tuning as WispTuning
		return [t.step_recharge,t.phase_cooldown,t.lift_cooldown]
	if a.tuning is HuddleTuning:
		var h := a.tuning as HuddleTuning
		return [h.scatter_recharge,h.screen_cooldown,h.pulse_cooldown]
	if a.tuning is MarshalTuning:
		var t := a.tuning as MarshalTuning
		return [t.march_cooldown,t.rally_cooldown,t.breach_cooldown]
	var t := a.tuning as DoctorTuning
	return [t.call_cooldown,t.ward_cooldown,t.prescription_cooldown]

static func ultimate_label(a: HeroActor) -> String:
	if a.kit is SamsonKit: return "ROACH COURT"
	match a.tuning.hero_id:
		"relay": return "FULL CIRCUIT"
		"dynamo": return "STORM DOMINION"
		"wisp": return "DEATH BALLET"
		"huddle": return "NOBODY GETS SQUISHED!"
		"marshal": return "MARSHAL'S VERDICT"
		"doctor": return "EXEMPLARY CONDITION"
		"slayer": return "HEADS WILL ROLL"
	return "FINAL NOTICE"

static func ultimate_detail(a: HeroActor) -> String:
	if a.kit is SamsonKit:
		var t := a.tuning as SamsonTuning
		return "%dM / %d%% RESIST / %d HP COURT" % [roundi(t.court_radius),roundi(t.court_reduction*100),roundi(t.court_health)]
	match a.tuning.hero_id:
		"relay": return "%d HP/S / +%d%% FIRE" % [roundi((a.tuning as RelayTuning).circuit_heal),roundi((a.tuning as RelayTuning).circuit_haste*100)]
		"dynamo": return "%dM / %dM STORM / %d DPS" % [roundi((a.tuning as DynamoTuning).storm_range),roundi((a.tuning as DynamoTuning).storm_radius),roundi((a.tuning as DynamoTuning).storm_damage/(a.tuning as DynamoTuning).storm_interval)]
		"wisp": return "%sS BARRAGE + FINALE" % String.num((a.tuning as WispTuning).ballet_duration,1)
		"huddle": return "5M WAVE / STEER TO PUSH"
		"marshal": return "%d m / LEAP SLAM" % (a.tuning as MarshalTuning).verdict_range
		"doctor": return "ALLY DAMAGE / SPEED / RESIST"
		"slayer": return "AXE / MAX HP WOUND"
	return "EXECUTE <=20% HP"

static func weapon_label(a: HeroActor) -> String:
	if a.kit is SamsonKit: return "DEPOSITION"
	match a.tuning.hero_id:
		"relay": return "CARBINE"
		"dynamo": return "MINIGUN"
		"wisp": return "DUAL PISTOLS"
		"huddle": return "SEEDS"
		"marshal": return "CANNON"
		"doctor": return "SIDEARM"
		"slayer": return "SWEEPER"
	return "RIFLE"

static func secondary_label(a: HeroActor) -> String:
	if a.kit is SamsonKit: return "Q RESCUE / E CHANNEL / 1 NO-MOBILITY ZONE"
	if a.kit is RelayKit: return "RMB ASSIGN DRONE / 1 RECALL OR SELF"
	if a.kit is DynamoKit: return "RMB PRESPIN / WALL: LMB PLACE, RMB ROTATE, E CANCEL"
	if a.kit is WispKit: return "RMB SOULBREAKER / DASH TO LOAD SHELLS"
	if a.kit is HuddleKit: return "RMB HOLD REGROUP / LMB HOLD FIRE"
	if a.kit is MarshalKit: return "RMB HOLD SHIELD / LMB HOLD FIRE"
	if a.kit is DoctorKit: return "RMB HOLD HEAL / LMB HOLD FIRE"
	return "RMB AIM"

static func detail(a: HeroActor) -> String:
	if a.kit is SamsonKit:
		var k := a.kit as SamsonKit
		var result: String = "INTERVENE [%s][%s] %d/%d / NEXT %.1fs" % ["+" if k.charges > 0 else "-","+" if k.charges > 1 else "-",k.charges,k.data().intervene_charges,k.recharge]
		if a.state == "samson_cross": result += " / %s %d%%" % [k.defendant.actor_id if is_instance_valid(k.defendant) else "CHANNEL",roundi(100*k.channel_age/k.data().cross_duration)]
		elif k.feedback_left > 0: result += " / " + k.feedback_text
		if is_instance_valid(k.notice) and k.notice.active(): result += " / NOTICE %d %.1fs" % [ceili(k.notice.health),k.notice.remaining]
		if k.ultimate_active(): result += " / COURT %d %.1fs" % [ceili(k.court.health),k.court.remaining]
		return result
	if a.kit is RelayKit:
		var k := a.kit as RelayKit
		return "BATTERY %d/%d / %s%s" % [ceili(k.battery),ceili(k.data().battery_capacity),k.recipient.actor_id.to_upper() if is_instance_valid(k.recipient) else "DOCKED / CHARGING"," / CIRCUIT %.1fs" % k.circuit_left if k.ultimate_active() else " / TRANSFER" if k.transfer_left > 0 else ""]
	if a.kit is DynamoKit:
		var k := a.kit as DynamoKit
		return "SPIN %d%% / %s%s" % [roundi(k.spin*100),"WALL: PLACE / ROTATE" if k.previewing else "WALL %.1fs" % k.wall.remaining if is_instance_valid(k.wall) else "NO WALL"," / LIGHTNING %.1fs" % k.charge_left if k.charge_left > 0 else ""]
	if a.kit is WispKit:
		var k := a.kit as WispKit
		return "DASH %d/%d %.1fs / SHELLS %d/%d%s" % [k.steps,k.data().step_charges,k.recharge,k.shells,k.data().shell_limit," / BALLET %.1fs" % k.ballet_left if k.ultimate_active() else ""]
	if a.kit is HuddleKit:
		var k := a.kit as HuddleKit
		var shield: String = "SCREEN %d / %.1fs" % [ceili(k.screen.health),k.screen.remaining] if is_instance_valid(k.screen) and k.screen.active() else "SCREEN READY" if k.deflect_cd <= 0 else "SCREEN %.1fs" % k.deflect_cd
		return "FLIGHT %d/2 %.1fs  /  REGROUP %s  /  %s%s" % [k.scatter_charges,k.scatter_timer,"HEALING" if a.state == "huddle_regroup" else "READY" if k.regroup_cd <= 0 else "%.1fs" % k.regroup_cd,shield,"  /  WAVE %.1fs" % k.wave_left if a.state == "huddle_wave" else ""]
	if a.kit is MarshalKit:
		var k := a.kit as MarshalKit
		return "BARRIER %d / %d%s" % [ceili(k.barrier_hp),(a.tuning as MarshalTuning).barrier_health," / BROKEN %.1fs" % k.break_remaining if k.break_remaining > 0 else " / " + secondary_label(a)]
	if a.kit is DoctorKit:
		var k := a.kit as DoctorKit
		if is_instance_valid(k.patient): return "%s  %d / %d HP / %s" % [k.patient.actor_id,ceili(k.patient.health),k.patient.effective_max_health(),"HEALING" if k.beam_healing else "SIGHT BLOCKED"]
		return "RMB HEAL / Q ESCAPE TO AIMED ALLY / 1 CLEANSE + 70% RESIST"
	return ""

static func status(a: HeroActor, include_overhealth: bool = true) -> String:
	if a.benefits == null: return ""
	var disable: String = "STUNNED  " if a.statuses.stunned() else "SILENCED  " if a.statuses.silenced() else ""
	var result: String = ("OVERHEALTH +%d / %.1fs  " % [ceili(a.overhealth.value()),a.overhealth.remaining()]) if include_overhealth and a.overhealth.value() > 0 else ""
	if a.statuses.mobility_locked(): disable += "MOBILITY DENIED  "
	result = disable + result
	for kind: String in ["exemplary","prescription","aftercare","ward","circuit"]:
		var duration: float = a.benefits.remaining(kind)
		if duration > 0: result += "OVERCLOCKED  " if kind == "circuit" else "%s %.1fs  " % [kind.to_upper(),duration]
	return result
