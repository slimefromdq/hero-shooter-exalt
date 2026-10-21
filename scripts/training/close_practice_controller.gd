class_name ClosePracticeController
extends BotController
var mode: String = "Mixed close combat"
func gather_intent(delta: float) -> CombatIntent:
	var input := CombatIntent.new()
	if frozen or not actor.alive or not is_instance_valid(target) or not target.alive: return input
	input.aim_origin = actor.body_point(1.4)
	input.aim = (target.body_point(1.1)-input.aim_origin).normalized()
	var offset: Vector3 = target.global_position-actor.global_position
	var distance: float = offset.length()
	time += delta
	action_timer -= delta
	if mode == "Shield defense":
		input.guard = fmod(time,3.0) < 2.4
		return input
	if distance > 2.2: input.move = (offset*Vector3(1,0,1)).normalized()
	if mode == "Mixed close combat" and fmod(time,4.8) > 3.4:
		input.move = Vector3.ZERO
		input.guard = true
	elif action_timer <= 0 and actor.state == "ready":
		if mode == "Throw only" or (mode == "Mixed close combat" and int(time/1.8)%2 == 1):
			if distance <= actor.tuning.throw_range:
				input.throw_action = true
				action_timer = 2.0
		elif distance <= actor.tuning.melee_range:
			input.melee = true
			input.stationary_melee = true
			action_timer = 1.6
	return input
