class_name CareHUD
extends RefCounted

static func labels(a: HeroActor) -> Array[String]:
	if a.kit is SamsonKit: return ["INTERVENE","CROSS-EXAMINATION","CEASE AND DESIST"]

	if a.kit is StitchKit: return ["SPOOLSTEP","PLAY DEAD","RED THREAD"]
	if a.kit is RelayKit: return ["OMEN","GUIDING WING","GUIDING SPIRIT"]
	if a.kit is DynamoKit: return ["STORMCHARGE","RAISE THE LINE","LODESTONE"]
	if a.kit is WispKit: return ["PHANTOM DODGE","VANISHING ACT","MAJESTIC LEAP"]
	if a.kit is HuddleKit: return ["SCATTERBOUND","WE'VE GOT YOU!","PERSONAL SPACE!"]
	var result: Array[String] = []
	result.assign(["FORWARD MARCH","RALLYING COMMAND","ORBITAL BARRAGE"] if a.kit is MarshalKit else ["HOUSE CALL","WARD ROUND","PRESCRIPTION"])
	return result

static func cooldowns(a: HeroActor) -> Array[float]:
	var k := a.kit as CareKit
	if k is RelayKit: return [k.mobility_cd,k.deflect_cd,(k as RelayKit).transfer_cd]
	return [k.mobility_cd,k.deflect_cd,k.bomb_cd]

static func durations(a: HeroActor) -> Array[float]:
	if a.tuning is SamsonTuning:
		var s := a.tuning as SamsonTuning
		return [s.intervene_recharge,s.cross_cooldown,s.notice_cooldown]

	if a.tuning is StitchTuning:
		var t := a.tuning as StitchTuning
		return [t.hook_cooldown,t.conceal_cooldown,t.thread_cooldown]
	if a.tuning is RelayTuning:
		var t := a.tuning as RelayTuning
		return [t.omen_cooldown,t.wing_cooldown,t.transfer_cooldown]
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

	if a.kit is StitchKit: return "CURTAIN CALL"
	match a.tuning.hero_id:
		"relay": return "MURMURATION"
		"dynamo": return "STORM DOMINION"
		"wisp": return "GRAND HEIST"
		"huddle": return "NOBODY GETS SQUISHED!"
		"marshal": return "MARSHAL'S VERDICT"
		"doctor": return "EXEMPLARY CONDITION"
		"slayer": return "HEADS WILL ROLL"
	return "FINAL NOTICE"

static func ultimate_detail(a: HeroActor) -> String:
	if a.kit is SamsonKit:
		var t := a.tuning as SamsonTuning
		return "%dM / %d%% RESIST / %d HP COURT" % [roundi(t.court_radius),roundi(t.court_reduction*100),roundi(t.court_health)]

	if a.kit is StitchKit: return "26M PIERCE / MARK EXECUTE"
	match a.tuning.hero_id:
		"relay": return "10s / THREE BIRDS / 33.75 HP/S EACH / PIERCING"
		"dynamo": return "%dM / %dM STORM / %d DPS" % [roundi((a.tuning as DynamoTuning).storm_range),roundi((a.tuning as DynamoTuning).storm_radius),roundi((a.tuning as DynamoTuning).storm_damage/(a.tuning as DynamoTuning).storm_interval)]
		"wisp": return "%dM SUCTION / %d BLAST + MARKS" % [roundi((a.tuning as WispTuning).heist_radius),roundi((a.tuning as WispTuning).heist_damage)]
		"huddle": return "5M WAVE / STEER TO PUSH"
		"marshal": return "%d m / LEAP SLAM" % (a.tuning as MarshalTuning).verdict_range
		"doctor": return "ALLY DAMAGE / SPEED / RESIST"
		"slayer": return "AXE / MAX HP WOUND"
	return "EXECUTE <=20% HP"

static func weapon_label(a: HeroActor) -> String:
	if a.kit is SamsonKit: return "DEPOSITION"

	if a.kit is StitchKit: return "SHEARS" if (a.kit as StitchKit).shears_mode else "NEEDLEPOINT"
	match a.tuning.hero_id:
		"relay": return "SPIRIT BOLTS"
		"dynamo": return "MINIGUN"
		"wisp": return "DUAL PISTOLS"
		"huddle": return "SEEDS"
		"marshal": return "CANNON"
		"doctor": return "SIDEARM"
		"slayer": return "SWEEPER"
	return "RIFLE"

static func secondary_label(a: HeroActor) -> String:
	if a.kit is SamsonKit: return "Q/E GAIN EVIDENCE / 1 SPENDS FOR LARGER ZONE"

	if a.kit is StitchKit: return "LMB HIDDEN LUNGE / Q HOOK-RELEASE / SPACE DROP / 1 THREAD"
	if a.kit is RelayKit: return "RMB CHARGE VOLLEY / 1 ASSIGN OR SELF / AIR SPACE SPIRIT JUMP"
	if a.kit is DynamoKit: return "RMB PRESPIN / WALL: LMB PLACE, RMB ROTATE, E CANCEL"
	if a.kit is WispKit: return "RMB %dM EXPLOSION / E FLIGHT: SPACE UP, SHIFT DOWN / LEAP: 1 DIVE" % roundi((a.tuning as WispTuning).burst_range)
	if a.kit is HuddleKit: return "RMB HOLD REGROUP / LMB HOLD FIRE"
	if a.kit is MarshalKit: return "RMB HOLD SHIELD / LMB HOLD FIRE"
	if a.kit is DoctorKit: return "RMB HOLD HEAL / LMB HOLD FIRE"
	return "RMB AIM"

static func detail(a: HeroActor) -> String:
	if a.kit is SamsonKit:
		var k := a.kit as SamsonKit
		var result: String = "INTERVENE [%s][%s] %d/%d / NEXT %.1fs" % ["+" if k.charges > 0 else "-","+" if k.charges > 1 else "-",k.charges,k.data().intervene_charges,k.recharge]
		result += " / EVIDENCE %d/2 / 1: %.1f x %.1fm" % [k.evidence,k.data().notice_width*k.notice_scale(),k.data().notice_depth*k.notice_scale()]
		if a.state == "samson_cross": result += " / %s %d%%" % [k.defendant.actor_id if is_instance_valid(k.defendant) else "CHANNEL",roundi(100*k.channel_age/k.data().cross_duration)]
		elif k.feedback_left > 0: result += " / " + k.feedback_text
		if is_instance_valid(k.notice) and k.notice.active(): result += " / NOTICE %d %.1fs" % [ceili(k.notice.health),k.notice.remaining]
		if k.ultimate_active(): result += " / COURT %d %.1fs" % [ceili(k.court.health),k.court.remaining]
		return result

	if a.kit is StitchKit:
		var k := a.kit as StitchKit
		return ("CONCEALED %.1fs / E REVEAL / COOLDOWN ON EXIT" % k.conceal_left if k.concealed else "PLAY DEAD %.1fs" % k.deflect_cd)+(" / HANG: Q/JUMP RELEASE" if a.state == "stitch_hang" else "")+(" / THREAD %.1fs" % k.thread.remaining if is_instance_valid(k.thread) and k.thread.valid() else " / NO THREAD")
	if a.kit is RelayKit:
		var k := a.kit as RelayKit
		var result: String = "BIRD: "+(k.recipient.actor_id if is_instance_valid(k.recipient) else "FOLLOWING")
		if k.sight_lost > 0: result += " / SIGHT %.1fs" % maxf(0,k.data().sight_grace-k.sight_lost)
		result += " / JUMP %.1fs" % k.bomb_cd if k.bomb_cd > 0 else " / JUMP READY"
		if k.volley_charging: result += " / VOLLEY %d%%" % roundi(100*k.volley_age/k.data().volley_charge)
		if k.ultimate_active():
			result += " / MURMURATION %.1fs" % k.murmuration_left
			for entry: Dictionary in k.extras: result += " / AUTO: "+(entry.target.actor_id if is_instance_valid(entry.target) else "SEARCHING")
		return result
	if a.kit is DynamoKit:
		var k := a.kit as DynamoKit
		return "SPIN %d%% / %s%s" % [roundi(k.spin*100),"WALL: PLACE / ROTATE" if k.previewing else "WALL %.1fs" % k.wall.remaining if is_instance_valid(k.wall) else "NO WALL"," / LIGHTNING %.1fs" % k.charge_left if k.charge_left > 0 else ""]
	if a.kit is WispKit:
		var k := a.kit as WispKit
		return "DODGE %d/%d %.1fs / BURSTS %d/%d%s" % [k.steps,k.data().step_charges,k.recharge,k.shells,k.data().shell_limit," / IMMUNE" if k.ability_immune() else " / REAPPEAR %.1fs" % k.phase_recovery_left if k.phase_recovery_left > 0 else " / DIVE" if k.diving else " / LEAP %.1fs / 1 DIVE" % k.glide_left if k.leap_active else " / THROW" if k.ultimate_active() else (" / SUCTION %.1fs" if k.heist.suction_started else " / CARD %.1fs") % k.heist.remaining if is_instance_valid(k.heist) and not k.heist.is_queued_for_deletion() and k.heist.armed else ""]
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

	for entry: Dictionary in a.statuses.stitches.values():
		result += "STITCHES %d / %.1fs  " % [entry.count,entry.remaining]
	for kind: String in ["exemplary","prescription","aftercare","ward","guiding_wing"]:
		var duration: float = a.benefits.remaining(kind)
		if duration > 0: result += "%s %.1fs  " % [kind.to_upper(),duration]
	return result
