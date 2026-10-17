class_name CareHUD
extends RefCounted

static func labels(a: HeroActor) -> Array[String]:
	var result: Array[String] = []
	result.assign(["FORWARD MARCH","IRON RESOLVE","BREACH LINE"] if a.kit is MarshalKit else ["HOUSE CALL","WARD ROUND","PRESCRIPTION"])
	return result

static func cooldowns(a: HeroActor) -> Array[float]:
	var k := a.kit as CareKit
	return [k.mobility_cd,k.deflect_cd,k.bomb_cd]

static func durations(a: HeroActor) -> Array[float]:
	if a.tuning is MarshalTuning:
		var t := a.tuning as MarshalTuning
		return [t.march_cooldown,t.resolve_cooldown,t.breach_cooldown]
	var t := a.tuning as DoctorTuning
	return [t.call_cooldown,t.ward_cooldown,t.prescription_cooldown]

static func ultimate_label(a: HeroActor) -> String:
	match a.tuning.hero_id:
		"marshal": return "MARSHAL'S VERDICT"
		"doctor": return "EXEMPLARY CONDITION"
		"slayer": return "HEADS WILL ROLL"
	return "FINAL NOTICE"

static func ultimate_detail(a: HeroActor) -> String:
	match a.tuning.hero_id:
		"marshal": return "%d m / LEAP SLAM" % (a.tuning as MarshalTuning).verdict_range
		"doctor": return "ALLY DAMAGE / SPEED / RESIST"
		"slayer": return "AXE / MAX HP WOUND"
	return "EXECUTE <=20% HP"

static func weapon_label(a: HeroActor) -> String:
	match a.tuning.hero_id:
		"marshal": return "CANNON"
		"doctor": return "SIDEARM"
		"slayer": return "SWEEPER"
	return "RIFLE"

static func secondary_label(a: HeroActor) -> String:
	if a.kit is MarshalKit: return "RMB HOLD SHIELD / LMB HOLD FIRE"
	if a.kit is DoctorKit: return "RMB HOLD HEAL / LMB HOLD FIRE"
	return "RMB AIM"

static func detail(a: HeroActor) -> String:
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
