class_name CombatStatuses
extends RefCounted
## Per-life runtime effects; never mutates shared base-stat resources.
var actor: HeroActor
var effects: Dictionary = {}
var marks: Dictionary = {}

func apply(kind: String, source: HeroActor, duration: float, strength: float = 0.0) -> bool:
	if not actor.alive or actor.invulnerable or source.team == actor.team or actor.resolver.protected_room(actor) or actor.resolver.protected_room(source):
		return false
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
	if actor.alive:
		marks[source.get_instance_id()] = {"source": weakref(source), "remaining": duration}

func marked_for(source: HeroActor) -> bool:
	return is_instance_valid(source) and actor.alive and marks.has(source.get_instance_id())

func effective_max() -> float:
	return actor.tuning.max_health * (1.0 - float(effects.get("max_health", {}).get("strength", 0.0)))

func movement_disabled() -> bool:
	return effects.has("root") or effects.has("slow")

func movement_scale() -> float:
	return 0.0 if effects.has("root") else float(effects.get("slow", {}).get("strength", 1.0))

func cleanse() -> void:
	if actor.boot_pair != null and actor.boot_pair.victim == actor: actor.boot_pair.release(false)
	effects.clear()

func clear() -> void:
	effects.clear()
	marks.clear()
	# Also retire this attacker's information immediately, including same-tick respawns.
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if other.statuses != null: other.statuses.marks.erase(actor.get_instance_id())
