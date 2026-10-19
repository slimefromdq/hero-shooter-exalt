class_name ActorBenefits
extends RefCounted
## Source-bound, per-life beneficial effects. Different doctors cannot stack identical HoTs.
var actor: HeroActor
var effects: Dictionary = {}

func grant(kind: String, source: HeroActor, duration: float, strength: float = 0.0) -> bool:
	if not is_instance_valid(source) or not source.alive or not actor.alive or source.team != actor.team:
		return false
	if source.resolver.protected_room(source) or source.resolver.protected_room(actor): return false
	if kind == "exemplary" and has_kind(kind): return false
	var key := "%s:%d" % [kind,source.get_instance_id()]
	effects[key] = {"kind":kind,"source":weakref(source),"remaining":duration,"strength":strength}
	return true

func has_kind(kind: String) -> bool:
	for entry: Dictionary in effects.values():
		if entry.kind == kind: return true
	return false

func remaining(kind: String) -> float:
	var result: float = 0.0
	for entry: Dictionary in effects.values():
		if entry.kind == kind: result = maxf(result,entry.remaining)
	return result

func reduction() -> float:
	var value: float = 0.0
	for entry: Dictionary in effects.values():
		if entry.kind in ["prescription"]: value = maxf(value,entry.strength)
		elif entry.kind == "exemplary": value = maxf(value,(entry.source.get_ref().tuning as DoctorTuning).exemplary_reduction)
	return value

func damage_multiplier() -> float:
	for entry: Dictionary in effects.values():
		if entry.kind == "exemplary": return 1.0 + (entry.source.get_ref().tuning as DoctorTuning).exemplary_damage
	return 1.0

func speed_multiplier() -> float:
	for entry: Dictionary in effects.values():
		if entry.kind == "exemplary": return 1.0 + (entry.source.get_ref().tuning as DoctorTuning).exemplary_speed
	return 1.0

func fire_rate_multiplier() -> float:
	var haste: float = 0.0
	for entry: Dictionary in effects.values():
		var source: HeroActor = entry.source.get_ref() as HeroActor
		if entry.kind == "circuit" and is_instance_valid(source) and source.alive and source.kit.ultimate_active():
			haste = maxf(haste,entry.strength)
	return 1.0 + haste

func tick(delta: float) -> void:
	# Split at expiry boundaries so rates do not depend on physics timestep.
	var left: float = delta
	while left > 0.000001 and not effects.is_empty():
		var slice: float = left
		for key: String in effects.keys():
			var entry: Dictionary = effects[key]
			var source: HeroActor = entry.source.get_ref() as HeroActor
			if not is_instance_valid(source) or not source.alive or source.team != actor.team:
				effects.erase(key)
				continue
			slice = minf(slice,maxf(0.000001,entry.remaining))
		var strongest: Dictionary = {}
		for entry: Dictionary in effects.values():
			if entry.kind not in ["aftercare","ward"]: continue
			var source: HeroActor = entry.source.get_ref() as HeroActor
			if entry.kind == "aftercare" and source.kit is DoctorKit and source.kit.patient == actor and source.kit.beam_healing: continue
			if not strongest.has(entry.kind) or entry.strength > strongest[entry.kind].strength: strongest[entry.kind] = entry
		for entry: Dictionary in strongest.values():
			actor.resolver.heal(entry.source.get_ref(),actor,entry.strength * slice,entry.kind)
		for key: String in effects.keys():
			effects[key].remaining -= slice
			if effects[key].remaining <= 0.000001: effects.erase(key)
		left -= slice

func clear() -> void:
	effects.clear()

func clear_owned() -> void:
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if other.benefits == null: continue
		for key: String in other.benefits.effects.keys():
			if other.benefits.effects[key].source.get_ref() == actor: other.benefits.effects.erase(key)
