class_name CombatStatuses
extends RefCounted
## Per-life runtime effects; never mutates shared base-stat resources.
var actor: HeroActor
var effects: Dictionary = {}
var marks: Dictionary = {}
var souls: Dictionary = {}
var stitches: Dictionary = {}

func apply(kind: String, source: HeroActor, duration: float, strength: float = 0.0) -> bool:
	if not actor.alive or actor.invulnerable or actor.state == "wisp_phase" or source.team == actor.team or actor.resolver.protected_room(actor) or actor.resolver.attack_locked(source):
		return false
	if actor.resolver.spawn_door_blocks(source.body_point(1),actor.body_point(1)): return false
	if duration <= 0: return false
	if kind in ["stun","silence"]: duration = maxf(duration,float(effects.get(kind,{}).get("remaining",0)))
	if kind == "stun":
		if actor.boot_pair != null: actor.boot_pair.release(false)
		actor.close.cancel()
		actor.kit.cancel()
		actor.motor.interrupt_mobility()
	# Refresh retains the DoT clock, preventing repeated hits from postponing ticks.
	var clock: float = float(effects.get(kind, {}).get("clock", 0.0))
	effects[kind] = {"source": weakref(source), "remaining": duration, "strength": strength, "clock": clock}
	if kind == "max_health":
		actor.health = minf(actor.health, effective_max())
	if kind in ["root", "slow"]:
		if actor.boot_pair != null: actor.boot_pair.release(false)
		actor.motor.interrupt_mobility()
	actor.resolver.record("status", source, kind, "target=%s duration=%.2f strength=%.2f" % [actor.actor_id,duration,strength])
	return true

func tick(delta: float) -> void:
	for key: int in stitches.keys():
		stitches[key].remaining -= delta
		var owner_actor: HeroActor = stitches[key].source.get_ref() as HeroActor
		if stitches[key].remaining <= 0 or not is_instance_valid(owner_actor) or not owner_actor.alive or owner_actor.life_serial != int(stitches[key].life): stitches.erase(key)
	if actor.get_tree().get_first_node_in_group("museum_match") != null and actor.resolver.protected_room(actor):
		cleanse()
		marks.clear()
		if actor.state in ["captured","throw_pair","boot_captured","stagger","counterthrow"]: actor.close.cancel()
	for key: int in souls.keys():
		souls[key].remaining -= delta
		var owner_actor: HeroActor = souls[key].source.get_ref() as HeroActor
		if souls[key].remaining <= 0 or not is_instance_valid(owner_actor) or not owner_actor.alive: souls.erase(key)
	for kind: String in effects.keys():
		if not actor.alive:
			break
		var effect: Dictionary = effects[kind]
		var active_time: float = minf(delta, effect.remaining)
		effect.remaining -= delta
		if kind == "bleed":
			effect.clock += active_time
			while effect.clock >= 0.5 - 0.00001:
				effect.clock -= 0.5
				var source: HeroActor = effect.source.get_ref() as HeroActor
				if is_instance_valid(source):
					actor.resolver.damage(source, actor, effect.strength * 0.5, "bleed", actor.resolver.new_cast(actor))
				if not actor.alive:
					break
		if float(effect.remaining) <= 0.00001:
			effects.erase(kind)
	for key: int in marks.keys():
		marks[key].remaining -= delta
		var source: HeroActor = marks[key].source.get_ref() as HeroActor
		if marks[key].remaining <= 0.0 or not is_instance_valid(source) or not source.alive:
			marks.erase(key)

func mark(source: HeroActor, duration: float) -> void:
	if actor.resolver.protected_room(actor): return
	if actor.alive:
		marks[source.get_instance_id()] = {"source": weakref(source), "remaining": duration}

func marked_for(source: HeroActor) -> bool:
	return is_instance_valid(source) and actor.alive and marks.has(source.get_instance_id())

func effective_max() -> float:
	return actor.tuning.max_health * (1.0 - float(effects.get("max_health", {}).get("strength", 0.0)))

func movement_disabled() -> bool:
	return effects.has("root") or effects.has("slow") or stunned()

func movement_scale() -> float:
	if effects.has("root") or stunned(): return 0.0
	var scale: float = minf(float(effects.get("slow",{}).get("strength",1.0)),float(effects.get("hinder",{}).get("strength",1.0)))
	for zone: Node in actor.get_tree().get_nodes_in_group("movement_zones"):
		if zone.hostile_contains(actor): scale = minf(scale,zone.movement_multiplier())
	return scale

func cleanse() -> void:
	RedThread.clear_actor(actor,true)
	stitches.clear()
	if actor.boot_pair != null and actor.boot_pair.victim == actor: actor.boot_pair.release(false)
	effects.clear()
	souls.clear()

func clear() -> void:
	RedThread.clear_actor(actor)
	stitches.clear()
	effects.clear()
	marks.clear()
	souls.clear()
	# Also retire this attacker's information immediately, including same-tick respawns.
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if other.statuses != null: other.statuses.marks.erase(actor.get_instance_id())
		if other.statuses != null: other.statuses.souls.erase(actor.get_instance_id())
		if other.statuses != null: other.statuses.stitches.erase(actor.get_instance_id())

func add_stitch(source: HeroActor, limit: int, seconds: float) -> void:
	if not actor.alive or not source.alive or source.team == actor.team or actor.invulnerable or actor.state == "wisp_phase" or actor.resolver.protected_room(actor): return
	stitches[source.get_instance_id()] = {"source":weakref(source),"life":source.life_serial,"count":mini(limit,stitch_count(source)+1),"remaining":seconds}

func stitch_count(source: HeroActor) -> int:
	if not is_instance_valid(source): return 0
	var entry: Dictionary = stitches.get(source.get_instance_id(),{})
	if entry.is_empty() or not source.alive or source.life_serial != int(entry.life) or float(entry.remaining) <= 0: return 0
	return int(entry.count)

func take_stitches(source: HeroActor) -> int:
	var count: int = stitch_count(source)
	stitches.erase(source.get_instance_id())
	return count

func add_soul(source: HeroActor, limit: int, seconds: float) -> void:
	var key: int = source.get_instance_id()
	souls[key] = {"source":weakref(source),"count":mini(limit,soul_count(source)+1),"remaining":seconds}

func soul_count(source: HeroActor) -> int:
	return int(souls.get(source.get_instance_id(),{}).get("count",0))

func take_souls(source: HeroActor) -> int:
	var result: int = soul_count(source)
	souls.erase(source.get_instance_id())
	return result

func stunned() -> bool:
	return effects.has("stun")

func silenced() -> bool:
	return effects.has("silence")

func mobility_locked() -> bool:
	for zone: Node in actor.get_tree().get_nodes_in_group("movement_zones"):
		if zone.hostile_contains(actor): return true
	return false

func permits(action: String) -> bool:
	if stunned(): return false
	if silenced() and action not in ["primary","secondary","aim","reload","jump","melee","throw","counter","guard"]: return false
	var mobility_action: bool = action in ["dash","hover","boot","march","house_call","step","lift","kickstart","scatter","wave","intervene","stitch_hook"] or (action == "ultimate" and actor.tuning.hero_id in ["marshal","wisp","stitch"])
	if mobility_action and mobility_locked(): return false
	return true

func filter_intent(input: CombatIntent) -> CombatIntent:
	if not stunned(): return input
	var filtered := CombatIntent.new()
	filtered.aim = input.aim
	filtered.aim_origin = input.aim_origin
	return filtered
