class_name PracticeDummyController
extends BotController
var station: String = ""
var enabled: bool = false

func gather_intent(delta: float) -> CombatIntent:
	var input := CombatIntent.new()
	input.aim_origin = actor.global_position + Vector3.UP * 1.5
	input.aim = remembered_aim
	if frozen or not actor.alive: return input
	time += delta
	if station == "moving":
		var destination: Vector3 = home + Vector3(sin(time*.8)*2.5,0,cos(time*.55)*1.2)
		input.move = (destination-actor.global_position).limit_length(1)
	if station == "shooting" and enabled and is_instance_valid(target) and target.alive:
		input.aim = (target.global_position+Vector3.UP*1.1-input.aim_origin).normalized()
		input.primary = true
		input.reload = actor.kit.ammo == 0
	return input
