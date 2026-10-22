extends SceneTree
## Human aim model: skill-ordered accuracy, strafe-reversal lag, flick over/undershoot and settling.
var world: Node3D
var resolver: CombatResolver
var a: HeroActor
var brain: BotBrain
var checks: int = 0
var failures: Array[String] = []
const DT: float = 1.0/60.0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func fresh(level: int, seed_value: int = 5) -> void:
	if brain != null: brain.diagnostics.detach()
	a.reset_actor(Vector3(0,.01,0))
	a.aim_direction = Vector3.FORWARD
	brain = BotBrain.new()
	brain.setup(a,TeamDirector.obtain(world,0),seed_value)
	brain.set_difficulty(level)
	brain.combat.aim = Vector3.FORWARD

## Runs an ADAD strafer at 15 m. Returns [on-target ratio, mean error just after reversals, mean steady error].
func strafe_run(level: int, seconds: float = 20.0) -> Array:
	fresh(level,17)
	var pattern := RandomNumberGenerator.new()
	pattern.seed = 99
	var eye: Vector3 = a.body_point(1.45)
	var x: float = 0.0
	var direction: float = 1.0
	var flip_in: float = .5
	var since_flip: float = 1.0
	var on_target: int = 0
	var frames: int = 0
	var spike: Array[float] = []
	var steady: Array[float] = []
	var t: float = 0.0
	while t < seconds:
		t += DT
		resolver.combat_time += DT
		flip_in -= DT
		if flip_in <= 0:
			direction *= -1
			flip_in = pattern.randf_range(.3,.8)
			since_flip = 0.0
		since_flip += DT
		x += direction*6.0*DT
		if absf(x) > 6.0 and signf(x) == direction:
			direction *= -1
			since_flip = 0.0
		var point := Vector3(x,1.2,-15)
		var desired: Vector3 = point-eye
		var aim: Vector3 = brain.combat.track_aim(desired,brain,DT)
		var error: float = aim.angle_to(desired.normalized())
		if t > 1.0:
			frames += 1
			if error < atan2(.45,desired.length()): on_target += 1
			if since_flip < .2: spike.append(error)
			elif since_flip > .35: steady.append(error)
	return [float(on_target)/frames,mean(spike),mean(steady)]

func mean(values: Array[float]) -> float:
	var total: float = 0.0
	for value: float in values: total += value
	return total/maxf(1,values.size())

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(60,1,60),Vector3(0,-.5,0),Color.GRAY)
	a = HeroActor.new()
	a.tuning = HeroRoster.tuning_for("nimbus")
	a.actor_id = "aimer"
	a.position = Vector3.ZERO
	world.add_child(a)
	a.set_physics_process(false)
	await physics_frame
	var ratios: Array[float] = []
	for level: int in 4:
		var result: Array = strafe_run(level)
		ratios.append(result[0])
		print("AIM %s on_target=%.3f reversal_error=%.2fdeg steady_error=%.2fdeg" % [BotSkillProfile.NAMES[level],result[0],rad_to_deg(result[1]),rad_to_deg(result[2])])
		if level == 1: check(result[1] > result[2]*1.3,"strafe reversals open a temporary tracking error (Normal)")
	check(ratios[3] >= ratios[2]-.02 and ratios[2] >= ratios[1]-.02 and ratios[1] >= ratios[0]-.02,"accuracy against a strafer rises monotonically with difficulty")
	check(ratios[3]-ratios[0] > .15,"Expert is clearly more accurate than Beginner")
	check(ratios[3] < .97,"Expert still misses a strafing target sometimes")
	check(ratios[0] > .05,"Beginner still lands some hits")
	# Flicks: a target appearing far off-axis is acquired with a ballistic move that misses
	# its landing point, then settles.
	var landing_errors: Array[float] = []
	var settled: int = 0
	var trials: int = 30
	var flick_rng := RandomNumberGenerator.new()
	flick_rng.seed = 3
	for trial: int in trials:
		fresh(1,100+trial)
		var angle: float = deg_to_rad(flick_rng.randf_range(40,90))*(1 if trial % 2 == 0 else -1)
		var desired: Vector3 = Vector3.FORWARD.rotated(Vector3.UP,angle)
		var landed: float = -1.0
		for frame: int in 90:
			resolver.combat_time += DT
			var aim: Vector3 = brain.combat.track_aim(desired,brain,DT)
			if landed < 0 and brain.combat.motor.flick_goal.is_zero_approx() and brain.combat.motor.flicks > 0:
				landed = aim.angle_to(desired)
		if landed >= 0: landing_errors.append(landed)
		if brain.combat.aim.angle_to(desired) < deg_to_rad(1.5): settled += 1
	var off: int = 0
	for value: float in landing_errors:
		if value > deg_to_rad(1.0): off += 1
	check(landing_errors.size() == trials,"large target offsets are acquired with a flick")
	check(off > trials/2,"most flicks land off target and need correction")
	check(settled >= trials-2,"flicks settle onto the target within 1.5 s")
	# Pressure: taking hits makes aim worse.
	fresh(1)
	var calm: float = brain.combat.pressure(brain)
	a.last_hit_age = 0.0
	check(brain.combat.pressure(brain) > calm,"being hit degrades aim")
	a.last_hit_age = 99.0
	# Reaction times vary per sighting but stay bounded.
	var samples: Array[float] = []
	for index: int in 40:
		brain.reaction_key = ""
		brain.threat = {"first_seen":float(index)}
		samples.append(brain.reaction_time())
	var lowest: float = samples.min()
	var highest: float = samples.max()
	check(highest-lowest > .05 and lowest >= brain.skill.acquisition_delay*.7-.001 and highest <= brain.skill.acquisition_delay*1.5+.001,"reaction times vary per sighting within bounds")
	brain.diagnostics.detach()
	world.queue_free()
	await physics_frame
	print("BOT AIM: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
