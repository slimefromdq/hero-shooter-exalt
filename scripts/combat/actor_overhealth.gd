class_name ActorOverhealth
extends RefCounted
## Shared temporary health. Strongest grant wins; damage depletes ALL grants.
## Depleted grants retain their original source lockout until their expiry.
const COLOR: Color = Color("27f5c3")
var actor: HeroActor
var grants: Dictionary = {}

func value() -> float:
	var result: float = 0
	for entry: Dictionary in grants.values(): result = maxf(result,entry.amount)
	return result

func remaining() -> float:
	var result: float = 0
	var current: float = value()
	for entry: Dictionary in grants.values():
		if entry.amount == current and current > 0: result = maxf(result,entry.remaining)
	return result

func can_grant(source: HeroActor) -> bool:
	return is_instance_valid(source) and not grants.has(source.get_instance_id())

func grant(source: HeroActor, amount: float, duration: float, tag: String = "overhealth") -> bool:
	if not is_instance_valid(source) or not source.alive or not actor.alive or source.team != actor.team: return false
	if amount <= 0 or duration <= 0 or not is_finite(amount) or not is_finite(duration): return false
	if not can_grant(source) or source.resolver.attack_locked(source) or actor.resolver.protected_room(actor): return false
	grants[source.get_instance_id()] = {"amount":amount,"remaining":duration}
	actor.resolver.record("overhealth_grant",source,tag,"target=%s amount=%.1f duration=%.1f available=%.1f" % [actor.actor_id,amount,duration,value()])
	actor.overhealth_changed.emit(value())
	return true

func absorb(amount: float) -> float:
	var absorbed: float = minf(maxf(0,amount),value())
	if absorbed <= 0: return 0
	for entry: Dictionary in grants.values(): entry.amount = maxf(0,entry.amount-absorbed)
	actor.overhealth_changed.emit(value())
	if value() <= 0:
		actor.resolver.record("overhealth_break",actor,"overhealth")
		actor.overhealth_broken.emit()
	return absorbed

func tick(delta: float) -> void:
	var previous: float = value()
	for key: int in grants.keys():
		grants[key].remaining -= maxf(0,delta)
		if grants[key].remaining <= .000001:
			grants.erase(key)
			actor.resolver.record("overhealth_expire",actor,"overhealth","source=%d" % key)
	if value() != previous: actor.overhealth_changed.emit(value())

func clear() -> void:
	grants.clear()
	actor.overhealth_changed.emit(0.0)
	actor.overhealth_cleared.emit()

func clear_owned() -> void:
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if other.overhealth != null and other.overhealth.grants.erase(actor.get_instance_id()):
			other.overhealth_changed.emit(other.overhealth.value())
