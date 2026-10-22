extends SceneTree
## Combat locomotion: irregular strafing, reactive dodges (tells and projectiles), purposeful
## dashes that are not aim-gated, ledge safety and skill-dependent misses.
var world: Node3D
var resolver: CombatResolver
var a: HeroActor
var b: HeroActor
var brain: BotBrain
var director: TeamDirector
var checks: int = 0
var failures: Array[String] = []
var objective: Dictionary = {"position":Vector3(0,0,-6),"phase":"fight","urgency":.5,"radius":7.0}
const DT: float = 1.0/60.0

func _initialize() -> void:
	call_deferred("run")
	create_timer(240.0).timeout.connect(func() -> void:
		print("FAIL  locomotion test timed out")
		quit(1))

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func step(count: int = 1) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func spawn(id: String, team: int, at: Vector3) -> HeroActor:
	var actor := HeroActor.new()
	actor.tuning = HeroRoster.tuning_for(id)
	actor.actor_id = id+str(team)
	actor.team = team
	actor.position = at
	world.add_child(actor)
	actor.set_physics_process(false)
	return actor

func fresh(level: int = 2, seed_value: int = 31) -> void:
	if brain != null: brain.diagnostics.detach()
	a.reset_actor(Vector3(0,.01,0))
	b.reset_actor(Vector3(0,.01,-10))
	a.aim_direction = Vector3.FORWARD
	director.clear()
	# decide() follows the saved difficulty setting, so set it there.
	root.get_node("/root/GameSettings").values["bot_difficulty"] = level
	brain = BotBrain.new()
	brain.setup(a,director,seed_value)
	brain.set_difficulty(level)
	# Settle onto the floor so the motor reports grounded.
	for i: int in 3:
		a.intent = CombatIntent.new()
		a.intent.aim = Vector3.FORWARD
		a._physics_process(DT)
	for i: int in 4:
		resolver.combat_time += .2
		brain.decide([a,b],objective)

var frame: int = 0

func tick_apply(state: String = "pressure", move: Vector3 = Vector3.ZERO) -> CombatIntent:
	resolver.combat_time += DT
	frame += 1
	# Like the real controller: tactical decisions at 5 Hz, execution every tick.
	if frame % 12 == 0: brain.decide([a,b],objective)
	brain.now = resolver.combat_time
	brain.tactical_state = state
	var input := CombatIntent.new()
	input.aim = (b.body_point(1.0)-a.body_point(1.45)).normalized()
	input.aim_origin = a.body_point(1.45)
	input.move = move
	brain.movement.apply(brain,input,false)
	return input

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(60,1,60),Vector3(0,-.5,0),Color.GRAY)
	a = spawn("nimbus",0,Vector3.ZERO)
	b = spawn("nimbus",1,Vector3(0,0,-10))
	director = TeamDirector.obtain(world,0)
	await step(2)
	await fresh()
	check(brain.visible_target(),"enemy is visible for locomotion checks")
	# Strafing: lateral input that changes direction at irregular intervals.
	var signs: Array[float] = []
	var switches: Array[float] = []
	var last_sign: float = 0.0
	var last_switch: float = resolver.combat_time
	var stops: int = 0
	for i: int in 360:
		var input: CombatIntent = tick_apply()
		var lateral: float = input.move.dot(Vector3.RIGHT)
		if input.move.is_zero_approx():
			stops += 1
			continue
		var current: float = signf(lateral)
		if current != 0 and current != last_sign:
			if last_sign != 0:
				switches.append(resolver.combat_time-last_switch)
			last_switch = resolver.combat_time
			last_sign = current
	check(switches.size() >= 4,"holding bot strafes back and forth in a fight")
	var mean: float = 0.0
	for value: float in switches: mean += value
	mean /= maxf(1,switches.size())
	var spread: float = 0.0
	for value: float in switches: spread += (value-mean)*(value-mean)
	spread = sqrt(spread/maxf(1,switches.size()))
	check(spread > .05,"strafe rhythm is irregular, not periodic")
	check(brain.movement.locomotion.counters.counter_strafes+brain.movement.locomotion.counters.crouch_jiggles+brain.movement.locomotion.counters.jump_strafes > 0,"strafing mixes in stops, crouches or jumps")
	# Dodge a telegraphed attack after reaction time.
	await fresh(3)
	b.global_position = Vector3(0,.01,-5)
	for i: int in 2:
		resolver.combat_time += .2
		brain.decide([a,b],objective)
	b.state = "melee_windup"
	resolver.combat_time += .2
	brain.decide([a,b],objective)
	var dodged: bool = false
	for i: int in 90:
		var input: CombatIntent = tick_apply()
		if (input.dash or input.jump) and absf(input.move.dot(Vector3.RIGHT)) > .7: dodged = true
	check(dodged,"Expert dodges sideways from a visible melee windup")
	b.state = "ready"
	# Dodge an incoming projectile that is in view.
	await fresh(3,77)
	var shot := CombatProjectile.new()
	shot.source = b
	shot.direction = Vector3.BACK
	shot.speed = 18
	world.add_child(shot)
	shot.set_physics_process(false)
	shot.global_position = a.body_point(1.2)+Vector3(0,0,-14)
	var reacted: bool = false
	for i: int in 60:
		shot.global_position += Vector3.BACK*18*DT
		var input: CombatIntent = tick_apply()
		if (input.dash or input.jump or brain.movement.locomotion.dodge_until > resolver.combat_time) and absf(input.move.dot(Vector3.RIGHT)) > .7: reacted = true
		if shot.global_position.z > a.global_position.z: break
	check(reacted,"bot sidesteps a projectile flying at it")
	shot.free()
	# Projectile from behind is not reacted to (cannot be seen).
	await fresh(3,78)
	var sneaky := CombatProjectile.new()
	sneaky.source = b
	sneaky.direction = Vector3.FORWARD
	sneaky.speed = 30
	world.add_child(sneaky)
	sneaky.set_physics_process(false)
	sneaky.global_position = a.body_point(1.2)+Vector3(0,0,12)
	var blind: bool = true
	for i: int in 25:
		sneaky.global_position += Vector3.FORWARD*30*DT
		tick_apply()
		if brain.movement.locomotion.counters.dodges > 0: blind = false
	check(blind,"projectiles from behind are not dodged")
	sneaky.free()
	# Dash for escape follows the movement direction, not the aim.
	await fresh(2)
	b.global_position = Vector3(0,.01,-6)
	resolver.combat_time += .2
	brain.decide([a,b],objective)
	var escaped: bool = false
	for i: int in 30:
		var input: CombatIntent = tick_apply("retreat",Vector3.BACK)
		if input.dash and input.aim.dot(Vector3.FORWARD) > .9 and input.move.dot(Vector3.BACK) > .9: escaped = true
	check(escaped,"retreating bot dashes away while still aiming at the enemy")
	# Never dash off a ledge.
	await fresh(2)
	var edge := Node3D.new()
	world.add_child(edge)
	a.global_position = Vector3(0,10.01,0)
	Geometry.box(edge,Vector3(4,1,4),Vector3(0,9.5,0),Color.GRAY)
	await step(2)
	for i: int in 3:
		a.intent = CombatIntent.new()
		a.intent.aim = Vector3.FORWARD
		a._physics_process(DT)
	b.global_position = Vector3(0,10.01,-6)
	var leapt: bool = false
	for i: int in 30:
		var input: CombatIntent = tick_apply("retreat",Vector3.BACK)
		if input.dash: leapt = true
	check(not leapt,"bots do not dash off a ledge")
	edge.queue_free()
	await step(1)
	# Air dash-slide: jump, dash down near the apex, fresh crouch just before touchdown.
	await fresh(2,91)
	b.global_position = Vector3(0,.01,200)
	brain.perception.reset()
	var loco: BotLocomotion = brain.movement.locomotion
	loco.begin_air_slide(Vector3.FORWARD,resolver.combat_time)
	var air_slid: bool = false
	var top_speed: float = 0.0
	var dash_seen: bool = false
	for i: int in 150:
		var input: CombatIntent = tick_apply("contest",Vector3.FORWARD)
		if input.dash: dash_seen = true
		a.intent = input
		a._physics_process(DT)
		if a.motor.mode == "slide" and a.motor.slide_source == "air_dash":
			air_slid = true
			top_speed = maxf(top_speed,Vector2(a.velocity.x,a.velocity.z).length())
		if loco.air_slide.is_empty() and i > 10: break
	check(dash_seen,"bot air-dashes from a jump")
	check(air_slid and loco.counters.air_dash_slides == 1,"bot lands the air dash into a slide with a last-moment crouch")
	check(top_speed > a.tuning.ground_speed+3.0,"the air dash-slide carries far more than running speed (%.1f m/s)" % top_speed)
	# Bunny hop + air strafe on a long, open rotation.
	await fresh(2,92)
	Geometry.box(world,Vector3(24,1,260),Vector3(200,-.5,-100),Color.GRAY)
	b.global_position = Vector3(0,.01,400)
	await step(2)
	a.global_position = Vector3(200,.01,20)
	a.velocity = Vector3.ZERO
	for i: int in 3:
		a.intent = CombatIntent.new()
		a.intent.aim = Vector3.FORWARD
		a._physics_process(DT)
	brain.perception.reset()
	var hop_loco: BotLocomotion = brain.movement.locomotion
	hop_loco.begin_bhop(brain,resolver.combat_time)
	var peak: float = 0.0
	var fell: bool = false
	for i: int in 540:
		brain.movement.selected_position = Vector3(200,0,-220)
		var input: CombatIntent = tick_apply("contest",((Vector3(200,0,-220)-a.global_position)*Vector3(1,0,1)).normalized())
		a.intent = input
		a._physics_process(DT)
		peak = maxf(peak,Vector2(a.velocity.x,a.velocity.z).length())
		if a.global_position.y < -1: fell = true
		if hop_loco.bhop.is_empty(): break
	check(int(hop_loco.counters.bhops) >= 6,"bot chains bunny hops on a long rotation (%d hops)" % int(hop_loco.counters.bhops))
	check(peak > a.tuning.ground_speed+2.5,"air strafing builds speed well past running speed (%.1f m/s vs %.1f)" % [peak,a.tuning.ground_speed])
	check(not fell and absf(a.global_position.x-200) < 10,"hopping stays on course and on the ground strip")
	# Slope slide: on a downhill along the route, crouch to slide and gain speed.
	await fresh(2,93)
	var ramp: Node3D = Geometry.box(world,Vector3(10,1,60),Vector3(-200,0,0),Color.GRAY)
	ramp.rotation.x = deg_to_rad(-15)
	b.global_position = Vector3(0,.01,400)
	await step(2)
	var top_z: float = 20.0
	a.global_position = Vector3(-200,tan(deg_to_rad(15))*top_z+.6,top_z)
	a.velocity = Vector3.ZERO
	for i: int in 10:
		a.intent = CombatIntent.new()
		a.intent.aim = Vector3.FORWARD
		a._physics_process(DT)
	brain.perception.reset()
	var slope_loco: BotLocomotion = brain.movement.locomotion
	var slid_down: bool = false
	var slope_peak: float = 0.0
	for i: int in 150:
		# A short hop down the hill (no long-rotation tricks), so the slope decides.
		brain.movement.selected_position = a.global_position+Vector3.FORWARD*12
		var input: CombatIntent = tick_apply("contest",Vector3.FORWARD)
		a.intent = input
		a._physics_process(DT)
		if a.motor.mode == "slide" and a.motor.slide_source != "air_dash": slid_down = true
		slope_peak = maxf(slope_peak,a.velocity.length())
		if a.global_position.z < -20: break
	check(slid_down and int(slope_loco.counters.slope_slides) >= 1,"bot slides down a slope that runs along its route")
	check(slope_peak > a.tuning.ground_speed+1.5,"the slope slide is faster than running (%.1f m/s)" % slope_peak)
	# Consistency: Beginners miss dodges more often than Experts.
	var success: Array[int] = [0,0]
	for pair: int in 2:
		var level: int = 0 if pair == 0 else 3
		for trial: int in 12:
			await fresh(level,200+trial)
			b.global_position = Vector3(0,.01,-5)
			for i: int in 3:
				resolver.combat_time += .2
				brain.decide([a,b],objective)
			b.state = "melee_windup"
			resolver.combat_time += .2
			brain.decide([a,b],objective)
			for i: int in 60: tick_apply()
			if brain.movement.locomotion.counters.dodges > 0: success[pair] += 1
			b.state = "ready"
	check(success[1] > success[0],"Experts dodge telegraphs more reliably than Beginners (%d vs %d of 12)" % [success[1],success[0]])
	root.get_node("/root/GameSettings").values["bot_difficulty"] = 1
	brain.diagnostics.detach()
	world.queue_free()
	await step(3)
	print("BOT LOCOMOTION: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
