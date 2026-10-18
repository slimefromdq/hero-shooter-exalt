extends Node
## Prewarm before gameplay: Godot's GPU particle constructor consumes the engine RNG
## even with fixed particle seeds. Reuse avoids that side effect on shots/switches.
const MUZZLE = preload("res://scenes/effects/slayer_shotgun_muzzle.tscn")
const IMPACT = preload("res://scenes/effects/slayer_shotgun_impact.tscn")
const ENERGY = preload("res://scenes/effects/slayer_ability_energy.tscn")
var free_ability: Array[SlayerBurstEffect] = []
var free_muzzles: Array[SlayerBurstEffect] = []
var free_impacts: Array[SlayerBurstEffect] = []

func _ready() -> void:
	for index: int in 64:
		var effect: SlayerBurstEffect = (MUZZLE if index < 16 else IMPACT).instantiate()
		effect.set_meta("muzzle", index < 16)
		add_child(effect)
		recycle(effect)
	for index: int in 32:
		var effect: SlayerBurstEffect = ENERGY.instantiate()
		effect.set_meta("ability",true)
		add_child(effect)
		recycle(effect)

func acquire_ability() -> SlayerBurstEffect:
	while not free_ability.is_empty():
		var effect: Variant = free_ability.pop_back()
		if is_instance_valid(effect) and not effect.is_queued_for_deletion(): return effect
	return null

func acquire(muzzle: bool) -> SlayerBurstEffect:
	var available: Array[SlayerBurstEffect] = free_muzzles if muzzle else free_impacts
	while not available.is_empty():
		var effect: Variant = available.pop_back()
		if is_instance_valid(effect) and not effect.is_queued_for_deletion(): return effect
	return null

func recycle(effect: SlayerBurstEffect) -> void:
	effect.deactivate()
	if effect.get_parent() != self: effect.reparent(self, false)
	var available: Array[SlayerBurstEffect] = free_ability if effect.get_meta("ability",false) else (free_muzzles if effect.get_meta("muzzle",false) else free_impacts)
	if not available.has(effect): available.append(effect)
