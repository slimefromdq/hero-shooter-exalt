class_name DashSlideFeedback
extends RefCounted
## Observes a dash attempt; never grants movement or changes its timing.
var actor: HeroActor
var active: bool = false
var attempted: bool = false
var reported: bool = false
var pending: String = ""
var remaining: float = 0

func begin(input: CombatIntent) -> void:
	clear()
	active = true
	attempted = input.slide or input.slide_pressed

func tick(delta: float, input: CombatIntent) -> void:
	if active and input.slide_pressed: attempted = true
	if remaining > 0:
		remaining = maxf(0,remaining-delta)
		if input.slide_pressed and remaining > 0 and not reported:
			fail(pending)

func resolve(structural: String, input: CombatIntent, press_age: float, speed: float) -> void:
	if not active: return
	# Resting floor contacts happen throughout a ground dash. Keep observing
	# until an attempted crouch or the actual dash end, rather than expiring
	# the late-attempt window before the dash itself has finished.
	if structural == "ground_dash" and not attempted and actor.motor.mode in ["dash","dash_windup"] and actor.motor.timer > 0: return
	active = false
	var reason: String = structural
	if reason.is_empty():
		if press_age > actor.tuning.dash_slide_window + .000001: reason = "too_early" if attempted else "too_late"
		elif not input.slide: reason = "hold_crouch"
		elif speed < actor.tuning.slide_entry_speed: reason = "too_slow"
		else:
			success()
			return
	pending = reason
	remaining = .3
	if attempted: fail(reason)

func fail(reason: String) -> void:
	if reported: return
	reported = true
	remaining = 0
	actor.dash_slide_failed.emit(reason)

func success() -> void:
	clear()

func clear() -> void:
	active = false
	attempted = false
	reported = false
	pending = ""
	remaining = 0
