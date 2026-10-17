class_name CareHUD
extends RefCounted

static func labels(a: HeroActor) -> Array[String]:
	if a.kit is HuddleKit: return ["SCATTERBOUND","WE'VE GOT YOU!","PERSONAL SPACE!"]
	var result: Array[String] = []
	result.assign(["FORWARD MARCH","IRON RESOLVE","BREACH LINE"] if a.kit is MarshalKit else ["HOUSE CALL","WARD ROUND","PRESCRIPTION"])
	return result

static func cooldowns(a: HeroActor) -> Array[float]:
	var k := a.kit as CareKit
	return [k.mobility_cd,k.deflect_cd,k.bomb_cd]

static func durations(a: HeroActor) -> Array[float]:
	if a.tuning is HuddleTuning:
		var h := a.tuning as HuddleTuning
		return [h.scatter_recharge,h.screen_cooldown,h.pulse_cooldown]
	if a.tuning is MarshalTuning:
		var t := a.tuning as MarshalTuning
		return [t.march_cooldown,t.resolve_cooldown,t.breach_cooldown]
	var t := a.tuning as DoctorTuning
	return [t.call_cooldown,t.ward_cooldown,t.prescription_cooldown]

static func ultimate_label(a: HeroActor) -> String:
	match a.tuning.hero_id:
		"huddle": return "NOBODY GETS SQUISHED!"
		"marshal": return "MARSHAL'S VERDICT"
		"doctor": return "EXEMPLARY CONDITION"
		"slayer": return "HEADS WILL ROLL"
	return "FINAL NOTICE"

static func ultimate_detail(a: HeroActor) -> String:
	match a.tuning.hero_id:
		"huddle": return "5M WAVE / STEER TO PUSH"
		"marshal": return "%d m / LEAP SLAM" % (a.tuning as MarshalTuning).verdict_range
		"doctor": return "ALLY DAMAGE / SPEED / RESIST"
		"slayer": return "AXE / MAX HP WOUND"
	return "EXECUTE <=20% HP"

static func weapon_label(a: HeroActor) -> String:
	match a.tuning.hero_id:
		"huddle": return "SEEDS"
		"marshal": return "CANNON"
		"doctor": return "SIDEARM"
		"slayer": return "SWEEPER"
	return "RIFLE"

static func secondary_label(a: HeroActor) -> String:
	if a.kit is HuddleKit: return "RMB HOLD REGROUP / LMB HOLD FIRE"
	if a.kit is MarshalKit: return "RMB HOLD SHIELD / LMB HOLD FIRE"
	if a.kit is DoctorKit: return "RMB HOLD HEAL / LMB HOLD FIRE"
	return "RMB AIM"

static func detail(a: HeroActor) -> String:
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

static func status(a: HeroActor) -> String:
	if a.benefits == null: return ""
	var result: String = ""
	for kind: String in ["exemplary","prescription","resolve","aftercare","ward"]:
		var duration: float = a.benefits.remaining(kind)
		if duration > 0: result += "%s %.1fs  " % [kind.to_upper(),duration]
	return result
