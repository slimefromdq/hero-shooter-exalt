class_name ParryPracticeController
extends BotController
## Telegraph and launch the real Slayer knife; no direct test damage.
func gather_intent(delta: float) -> CombatIntent:
	var input := CombatIntent.new()
	if frozen or not actor.alive or not is_instance_valid(target) or not target.alive: return input
	input.aim_origin = actor.body_point(1.4)
	input.aim = (target.body_point(1.1)-input.aim_origin).normalized()
	action_timer -= delta
	if action_timer <= 0 and actor.permits("knife"):
		input.hover = true
		action_timer = 2.4
	return input
