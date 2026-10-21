class_name TrainingResources
extends RefCounted
## Restore only availability. Never touch attack cadence, active state, or reloads.
static func restore(actor: HeroActor) -> void:
	actor.motor.refill_dashes()
	actor.motor.hover_cd = 0
	actor.close.guard_cd = 0
	actor.kit.deflect_cd = 0
	actor.kit.bomb_cd = 0
	if not actor.kit.ultimate_active(): actor.kit.ultimate_charge = 100
	if actor.kit is CareKit: actor.kit.mobility_cd = 0
	if actor.kit is SlayerKit:
		actor.kit.knives = actor.tuning.knife_charges
		actor.kit.snares = actor.tuning.trap_limit
	if actor.kit is HuddleKit:
		actor.kit.scatter_charges = actor.tuning.scatter_charges
		actor.kit.regroup_cd = 0
	if actor.kit is RelayKit:
		actor.kit.transfer_cd = 0
		actor.kit.volley_cd = 0
	if actor.kit is WispKit:
		actor.kit.steps = actor.tuning.step_charges
		actor.kit.secondary_cd = 0
	if actor.kit is SamsonKit: actor.kit.charges = actor.tuning.intervene_charges
