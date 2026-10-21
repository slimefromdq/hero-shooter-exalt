class_name ParryPracticeController
extends BotController
var telegraph: Label3D
## Telegraph and launch the real Slayer knife; no direct test damage.
func _ready() -> void:
	super._ready()
	telegraph = Geometry.text3d(actor,"",Vector3(0,3.2,0),28,Color("ffcd74"))
	telegraph.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func gather_intent(delta: float) -> CombatIntent:
	var input := CombatIntent.new()
	if frozen or not actor.alive or not is_instance_valid(target) or not target.alive: return input
	input.aim_origin = actor.body_point(1.4)
	input.aim = (target.body_point(1.1)-input.aim_origin).normalized()
	action_timer -= delta
	if is_instance_valid(telegraph): telegraph.text = "KNIFE IN %.1fs / HOLD THEN RELEASE SHIELD" % maxf(0,action_timer) if action_timer < .8 else "PERFECT SHIELD PARRY"
	if action_timer <= 0 and actor.permits("knife"):
		input.hover = true
		action_timer = 2.4
	return input
