class_name BotAim
extends RefCounted
## Human aiming motor model. The crosshair is driven by three behaviours:
## 1. Delayed pursuit: the bot sees the target as it was a reaction-lag ago and
##    extrapolates, so steady motion is tracked well while direction changes
##    (ADAD strafing) open a temporary miss window.
## 2. Ballistic flicks: large corrections are planned as one fast movement that lands
##    with a skill-scaled over/undershoot, like a real mouse flick.
## 3. Correction: after a flick the crosshair settles onto the target more slowly.
## Rotation speed stays bounded by the skill's turn speed and tracking acceleration.

## Corrections larger than this (radians, ~9 deg) are flicks rather than tracking.
const FLICK_THRESHOLD: float = .157
## A desired direction that jumps more than this (~15 deg) is a new thing to look at.
const SWITCH_THRESHOLD: float = .26

var tracked: Vector3 = Vector3.ZERO
var last_desired: Vector3 = Vector3.ZERO
var omega: Vector2 = Vector2.ZERO
var history: Array = []
var flick_goal: Vector3 = Vector3.ZERO
var settle_until: float = -1.0
var flicks: int = 0

static func angles(direction: Vector3) -> Vector2:
	return Vector2(atan2(direction.x,direction.z),asin(clampf(direction.y,-1,1)))

static func from_angles(value: Vector2) -> Vector3:
	return Vector3(sin(value.x)*cos(value.y),sin(value.y),cos(value.x)*cos(value.y))

func reset() -> void:
	tracked = Vector3.ZERO
	last_desired = Vector3.ZERO
	omega = Vector2.ZERO
	history.clear()
	flick_goal = Vector3.ZERO
	settle_until = -1.0

## Perceived target direction. Vision runs `pursuit_lag` seconds behind reality; the
## bot extrapolates the motion it saw then. Steady movement is therefore tracked well,
## while a reversal is only noticed after the lag, exactly the window ADAD exploits.
## Precise (own-projectile) tracking anticipates a known trajectory and lags less.
func pursue(desired: Vector3, skill: BotSkillProfile, now: float, precise: bool = false) -> Vector3:
	var d: Vector3 = desired.normalized()
	var current: Vector2 = angles(d)
	if tracked.is_zero_approx() or last_desired.is_zero_approx() or last_desired.angle_to(d) > SWITCH_THRESHOLD or (not history.is_empty() and now < float(history[-1][0])):
		history.clear()
	elif not history.is_empty():
		var previous: Vector2 = history[-1][1]
		current.x = previous.x+wrapf(current.x-previous.x,-PI,PI)
	history.append([now,current])
	last_desired = d
	var lag: float = skill.pursuit_lag*(.4 if precise else 1.0)
	while history.size() > 2 and float(history[1][0]) <= now-lag-.12: history.pop_front()
	var index: int = 0
	for i: int in history.size():
		if float(history[i][0]) <= now-lag: index = i
	var seen_at: float = float(history[index][0])
	var seen: Vector2 = history[index][1]
	var earlier: int = index
	while earlier > 0 and seen_at-float(history[earlier][0]) < .05: earlier -= 1
	omega = Vector2.ZERO
	if earlier != index: omega = (seen-history[earlier][1])/maxf(seen_at-float(history[earlier][0]),.001)
	var extrapolation: float = 1.0 if precise else .5+.5*skill.prediction
	var perceived: Vector2 = seen+omega*(now-seen_at)*extrapolation
	perceived.y = clampf(perceived.y,-1.5,1.5)
	tracked = from_angles(perceived)
	return tracked

## Moves aim one physics tick toward wanted (already noise-perturbed). Returns the new aim.
func turn(aim: Vector3, wanted: Vector3, speed: float, brain: BotBrain, delta: float, precise: bool, error_scale: float) -> Array:
	var skill: BotSkillProfile = brain.skill
	var now: float = brain.actor.resolver.combat_time
	var gap: float = aim.angle_to(wanted)
	if not flick_goal.is_zero_approx() and flick_goal.angle_to(wanted) > maxf(gap,FLICK_THRESHOLD)*1.5:
		flick_goal = Vector3.ZERO
	if flick_goal.is_zero_approx() and gap > FLICK_THRESHOLD and not precise:
		var axis: Vector3 = aim.cross(wanted)
		if axis.length_squared() > .000001:
			axis = axis.normalized()
			var miss: float = gap*skill.flick_error*error_scale*brain.rng.randf_range(.4,1.25)
			var overshoot: float = 1.0 if brain.rng.randf() < .65 else -.7
			flick_goal = wanted.rotated(axis,miss*overshoot)
			var lateral: Vector3 = wanted.cross(axis).normalized()
			if not lateral.is_zero_approx(): flick_goal = flick_goal.rotated(lateral,miss*brain.rng.randf_range(-.35,.35))
			flick_goal = flick_goal.normalized()
			flicks += 1
	var goal: Vector3 = wanted if flick_goal.is_zero_approx() else flick_goal
	var cap: float = deg_to_rad(skill.turn_speed)
	if flick_goal.is_zero_approx() and now < settle_until: cap *= .4
	speed = move_toward(speed,cap,deg_to_rad(skill.tracking_acceleration)*delta)
	if speed > cap: speed = move_toward(speed,cap,deg_to_rad(skill.tracking_acceleration)*delta*2)
	var remaining: float = aim.angle_to(goal)
	if remaining > .00001: aim = aim.slerp(goal,minf(1,speed*delta/remaining)).normalized()
	if not flick_goal.is_zero_approx() and aim.angle_to(flick_goal) < .012:
		flick_goal = Vector3.ZERO
		settle_until = now+skill.correction_time
	return [aim,speed]
