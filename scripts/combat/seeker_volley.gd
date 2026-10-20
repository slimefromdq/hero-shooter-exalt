class_name SeekerVolley
extends RefCounted
## Shared flight frame outlives the central arrow's impact.
var target: WeakRef
var life: int = -1
var locked: bool = false

func acquire(actor: HeroActor) -> void:
	if locked: return
	locked = true
	target = weakref(actor)
	life = actor.life_serial

func patient() -> HeroActor:
	var actor: HeroActor = target.get_ref() as HeroActor if target != null else null
	return actor if is_instance_valid(actor) and actor.alive and actor.life_serial == life else null
