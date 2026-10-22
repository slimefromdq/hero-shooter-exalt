class_name BotLocomotion
extends RefCounted
## Moment-to-moment movement style layered on top of path following, using only the
## player's inputs: irregular ADAD strafing with counter-strafe stops, crouch jiggles and
## jump-strafes; reactive dodges against seen tells and incoming projectiles; purposeful
## dashes (escape, engage, reach cover, rotate) with dash-slides; and travel liveliness.
## Every reaction is gated by the bot's skill: sometimes it fails to dodge, like a person.

const DODGE_TELLS: Array[String] = ["melee_windup","ultimate","slayer_axe","slayer_axe_windup","marshal_march","huddle_wave_start","wisp_heist_start"]

var strafe_dir: float = 1.0
var strafe_until: float = 0.0
var stop_until: float = 0.0
var crouch_until: float = 0.0
var dodge_until: float = 0.0
var dodge_ready_at: float = 0.0
var dodge_dir: Vector3 = Vector3.ZERO
var slide_until: float = 0.0
var next_scan: float = 0.0
var next_travel_roll: float = 0.0
var next_flair_hop: float = 0.0
var tracked_attacks: Dictionary = {}
var noticed_tell: Dictionary = {}
## Air dash-slide in progress: jump, dash down near the apex, press crouch just before
## touchdown (fresh press inside the motor's dash_slide_window) and ride the slide.
var air_slide: Dictionary = {}
## Bunny hop with Source-style air strafing on long rotations:
## {"started","side","hops","peak"}. Empty when not hopping.
var bhop: Dictionary = {}
var next_bhop_roll: float = 0.0
const AIR_DASH_PITCH: float = 35.0
var slope_sliding: bool = false
var counters: Dictionary = {"slope_slides":0,"bhop_chains":0,"bhops":0,"bhop_peak_speed":0.0,"air_dash_slides":0,"air_dash_slide_misses":0,"dodges":0,"missed_dodges":0,"dash_escape":0,"dash_engage":0,"dash_cover":0,"dash_rotate":0,"jump_strafes":0,"crouch_jiggles":0,"counter_strafes":0,"slides":0,"flair_hops":0}

func reset() -> void:
	strafe_until = 0
	stop_until = 0
	crouch_until = 0
	dodge_until = 0
	dodge_ready_at = 0
	slide_until = 0
	next_scan = 0
	tracked_attacks.clear()
	noticed_tell.clear()
	air_slide = {}
	bhop = {}
	slope_sliding = false

## Mobility charges the bot keeps for emergencies (escape reserve from the hero profile).
func spare_dashes(brain: BotBrain) -> int:
	return brain.actor.motor.dash_charges-brain.hero_profile.escape_reserve

func apply(brain: BotBrain, movement: BotMovement, input: CombatIntent) -> void:
	var a: HeroActor = brain.actor
	var now: float = a.resolver.combat_time
	var skill: BotSkillProfile = brain.skill
	var state: String = brain.tactical_state
	var engaged: bool = brain.visible_target() and state not in ["retreat","regroup"]
	var grounded: bool = a.motor.grounded()
	var ready: bool = a.state == "ready"
	if not air_slide.is_empty():
		if engaged and str(air_slide.phase) in ["jump","rise"]: air_slide = {}
		else:
			drive_air_slide(brain,input,now)
			return
	if not bhop.is_empty():
		if engaged or state in ["support","hold","retreat"]: bhop = {}
		elif drive_bhop(brain,movement,input,now): return
	# 1. Reactive dodges.
	if ready and now >= dodge_ready_at:
		var incoming: Vector3 = incoming_threat(brain,now)
		if not incoming.is_zero_approx():
			if brain.rng.randf() < lerpf(.25,.9,skill.consistency)*brain.tuning().dodge_eagerness:
				var side: Vector3 = incoming.cross(Vector3.UP).normalized()
				if brain.rng.randf() < .5: side = -side
				if not movement.safe_travel(a,side,2.0): side = -side
				if movement.safe_travel(a,side,2.0):
					dodge_dir = side
					dodge_until = now+.35
					counters.dodges += 1
					if a.motor.can_dash() and brain.level >= 1 and (spare_dashes(brain) > 0 or brain.danger > .5) and movement.safe_travel(a,side,a.tuning.dash_speed*a.tuning.dash_duration):
						input.move = side
						input.dash = true
					elif grounded and a.permits("jump"):
						input.jump = true
			else:
				counters.missed_dodges += 1
			dodge_ready_at = now+lerpf(1.6,.8,skill.consistency)
	if now < dodge_until:
		input.move = dodge_dir
		return
	# 2. Combat strafing: irregular rhythm, never periodic.
	if engaged and ready:
		var toward: Vector3 = ((Vector3(brain.threat.position)-a.global_position)*Vector3(1,0,1)).normalized()
		var lateral: Vector3 = toward.cross(Vector3.UP)
		if now >= strafe_until:
			strafe_dir = -strafe_dir if brain.rng.randf() < .72 else strafe_dir
			var slow: float = lerpf(1.25,.6,skill.consistency)
			strafe_until = now+brain.rng.randf_range(.22,.7)*slow*brain.tuning().strafe_tempo
			var roll: float = brain.rng.randf()
			var flair: float = float(brain.personality.get("flair",.3))
			if roll < .12:
				stop_until = now+brain.rng.randf_range(.12,.25)
				counters.counter_strafes += 1
			elif roll < .12+.08*(.5+flair) and brain.level >= 1:
				crouch_until = now+brain.rng.randf_range(.18,.35)
				counters.crouch_jiggles += 1
			elif roll < .12+.08*(.5+flair)+.07*(.4+flair*1.2) and brain.level >= 2 and grounded and a.permits("jump") and movement.safe_travel(a,lateral*strafe_dir,2.0):
				input.jump = true
				counters.jump_strafes += 1
		var weave: Vector3 = lateral*strafe_dir
		if input.move.length() < .2: input.move = weave
		else: input.move = (input.move.normalized()+weave*brain.tuning().weave).normalized()
		if not movement.safe_travel(a,input.move,1.2):
			strafe_dir = -strafe_dir
			var flipped: Vector3 = lateral*strafe_dir
			input.move = flipped if movement.safe_travel(a,flipped,1.2) else Vector3.ZERO
		if now < stop_until: input.move = Vector3.ZERO
		if now < crouch_until and grounded: input.slide = true
		movement.intentional_hold = true
	# 3. Slide down slopes along the route: gravity outpaces slide friction.
	slope_slide(brain,movement,input)
	if slope_sliding: return
	# 3b. Purposeful dashes.
	if ready and grounded and a.motor.can_dash() and input.move.length() > .5 and not input.dash:
		var reason: String = ""
		var distance: float = a.global_position.distance_to(Vector3(brain.threat.get("position",a.global_position)))
		var dash_length: float = a.tuning.dash_speed*a.tuning.dash_duration
		if state == "retreat" and not brain.threat.is_empty() and distance < 14 and (brain.hero_profile.mobility > .3 or brain.danger > .5):
			reason = "dash_escape"
		elif state == "commit" and engaged and distance > brain.hero_profile.minimum_range+4 and spare_dashes(brain) > 0:
			reason = "dash_engage"
		elif str(movement.last_query.get("mode","")) == "cover" and a.last_hit_age < .8 and movement.selected_position.distance_to(a.global_position) > 3.5 and spare_dashes(brain) > 0:
			reason = "dash_cover"
		elif not engaged and state not in ["support","hold"] and now >= next_travel_roll:
			next_travel_roll = now+1.0
			if a.motor.dash_charges >= a.tuning.dash_capacity and movement.selected_position.distance_to(a.global_position) > 18 and brain.rng.randf() < .12+brain.hero_profile.mobility*.25:
				reason = "dash_rotate"
		# Skilled players turn a rotation dash into an air dash-slide for extra speed.
		if reason == "dash_rotate" and brain.level >= 1 and brain.rng.randf() < .45+float(brain.personality.get("flair",.3))*.4 and a.permits("jump") and movement.safe_travel(a,input.move,dash_length+3.0):
			begin_air_slide(input.move,now)
			counters.dash_rotate += 1
			drive_air_slide(brain,input,now)
			return
		if reason != "" and movement.safe_travel(a,input.move,dash_length):
			input.dash = true
			counters[reason] += 1
			if reason in ["dash_rotate","dash_escape"] and brain.level >= 1:
				slide_until = now+a.tuning.dash_duration+.6
				counters.slides += 1
	if now < slide_until and input.move.length() > .5:
		input.slide = true
		input.slide_pressed = not a.intent.slide
	# 4. Long rotations: bunny hop and air strafe instead of jogging.
	if not engaged and ready and grounded and bhop.is_empty() and air_slide.is_empty() and input.move.length() > .5 and state not in ["support","hold","retreat"] and now >= next_bhop_roll:
		next_bhop_roll = now+1.0
		if brain.level >= 1 and movement.selected_position.distance_to(a.global_position) > 20 and brain.rng.randf() < .2+brain.level*.12+float(brain.personality.get("flair",.3))*.3 and movement.safe_travel(a,input.move,6.0) and a.permits("jump"):
			begin_bhop(brain,now)
			drive_bhop(brain,movement,input,now)
			return
	# 5. Liveliness while travelling: the occasional hop, like a bored player.
	if not engaged and ready and grounded and input.move.length() > .5 and state not in ["support","hold"]:
		if next_flair_hop <= 0: next_flair_hop = now+brain.rng.randf_range(6,16)/maxf(.3,brain.hero_profile.mobility+float(brain.personality.get("flair",.3)))
		if now >= next_flair_hop:
			next_flair_hop = 0
			if movement.safe_travel(a,input.move,2.5) and a.permits("jump"):
				input.jump = true
				counters.flair_hops += 1

func begin_air_slide(direction: Vector3, now: float) -> void:
	air_slide = {"phase":"jump","direction":(direction*Vector3(1,0,1)).normalized(),"started":now,"phase_at":now,"pressed":false}

## Drives the air dash-slide with ordinary inputs; the motor decides whether it lands.
func drive_air_slide(brain: BotBrain, input: CombatIntent, now: float) -> void:
	var a: HeroActor = brain.actor
	var direction: Vector3 = air_slide.direction
	var grounded: bool = a.motor.grounded()
	var mode: String = a.motor.mode
	input.move = direction
	input.primary = false
	input.primary_held = false
	if now-float(air_slide.started) > 2.5:
		counters.air_dash_slide_misses += 1
		air_slide = {}
		return
	match str(air_slide.phase):
		"jump":
			if grounded and a.state == "ready":
				input.jump = true
				air_slide.phase = "rise"
				air_slide.phase_at = now
		"rise":
			input.jump_held = true
			var height: float = height_above_ground(a)
			if not grounded and a.motor.can_dash() and (a.velocity.y < 1.5 and height > .9 or now-float(air_slide.phase_at) > .45):
				input.dash = true
				input.aim = dash_aim(direction)
				air_slide.phase = "dash"
				air_slide.phase_at = now
			elif grounded and now-float(air_slide.phase_at) > .3:
				air_slide = {}
		"dash":
			# Hold the downward aim through the windup: the motor locks direction at its end.
			input.aim = dash_aim(direction)
			var height: float = height_above_ground(a)
			var falling: float = maxf(.5,-a.velocity.y)
			var impact: float = height/falling if mode == "dash" else INF
			if not bool(air_slide.pressed) and (impact <= .08 or (mode == "dash" and height < .55)):
				input.slide = true
				input.slide_pressed = not a.intent.slide
				air_slide.pressed = true
			elif bool(air_slide.pressed):
				input.slide = true
			if mode == "slide":
				air_slide.phase = "slide"
				air_slide.phase_at = now
				counters.air_dash_slides += 1
			elif grounded and mode not in ["dash","dash_windup"] and now-float(air_slide.phase_at) > .25:
				counters.air_dash_slide_misses += 1
				air_slide = {}
		"slide":
			input.slide = true
			var speed: float = Vector2(a.velocity.x,a.velocity.z).length()
			if mode != "slide" or now-float(air_slide.phase_at) > .8 or speed < a.tuning.ground_speed:
				air_slide = {}
			elif now-float(air_slide.phase_at) > .3 and brain.level >= 2 and a.permits("jump"):
				# Slide-hop: jump out of the slide and keep the speed with a bunny hop.
				air_slide = {}
				begin_bhop(brain,now)
				input.jump = true

## Holds crouch on a downhill (at least the motor's slide_slope, plus margin) when the
## route runs down it; releases when the slope ends, the route turns or the slide dies.
func slope_slide(brain: BotBrain, movement: BotMovement, input: CombatIntent) -> void:
	var a: HeroActor = brain.actor
	var mode: String = a.motor.mode
	var heading: Vector3 = (input.move*Vector3(1,0,1)).normalized()
	if slope_sliding:
		var along: Vector3 = (a.velocity*Vector3(1,0,1)).normalized()
		var keep: bool = mode == "slide" and not heading.is_zero_approx() and along.dot(heading) > .55 and movement.safe_travel(a,along,2.5)
		if keep:
			input.slide = true
			return
		slope_sliding = false
		return
	if brain.level < 1 or a.state != "ready" or heading.is_zero_approx() or not a.motor.grounded() or mode in ["slide","dash","dash_windup"]: return
	var normal: Vector3 = a.get_floor_normal()
	if normal.is_zero_approx(): return
	var angle: float = rad_to_deg(acos(clampf(normal.y,-1,1)))
	if angle < a.tuning.slide_slope+1.0 or angle > 40: return
	var downhill: Vector3 = (Vector3.DOWN.slide(normal)*Vector3(1,0,1)).normalized()
	if downhill.dot(heading) < .75 or not movement.safe_travel(a,heading,3.0): return
	# Run into it first, like a player: a slide from a standstill is slow to get going.
	if Vector2(a.velocity.x,a.velocity.z).length() < a.tuning.slide_entry_speed*.9: return
	input.slide = true
	input.slide_pressed = not a.intent.slide
	slope_sliding = true
	counters.slope_slides += 1

func begin_bhop(brain: BotBrain, now: float) -> void:
	bhop = {"started":now,"side":1.0 if brain.rng.randf() < .5 else -1.0,"hops":0,"airborne":false}
	counters.bhop_chains += 1

## One tick of bunny hopping. The motor gains air speed (0.75 m/s per second, up to
## 12 m/s) only when the wish points past the air_wish_cap projection angle, so the bot
## angles its input just beyond that on the side it wants to turn toward, zigzagging
## when the route is straight ahead, and re-jumps inside the jump buffer before landing.
## Returns false when the hop chain ends (the bot then moves normally this tick).
func drive_bhop(brain: BotBrain, movement: BotMovement, input: CombatIntent, now: float) -> bool:
	var a: HeroActor = brain.actor
	var t: HeroTuning = a.tuning
	var heading: Vector3 = (input.move*Vector3(1,0,1)).normalized()
	var flat: Vector3 = a.velocity*Vector3(1,0,1)
	var speed: float = flat.length()
	var grounded: bool = a.motor.grounded()
	var remaining: float = movement.selected_position.distance_to(a.global_position)
	var done: bool = heading.is_zero_approx() or remaining < 8.0 or now-float(bhop.started) > 14.0 or a.state != "ready"
	if not done and speed > 1.0 and not movement.safe_travel(a,flat.normalized(),clampf(speed*.35,1.5,4.0)): done = true
	if done:
		bhop = {}
		return false
	counters.bhop_peak_speed = maxf(float(counters.bhop_peak_speed),speed)
	if grounded:
		# Landing frame (or the first hop): jump again before ground friction bites.
		if a.permits("jump"):
			input.jump = true
			bhop.hops = int(bhop.hops)+1
			counters.bhops += 1
			bhop.side = -float(bhop.side)
		input.move = heading
		return true
	# Airborne: strafe past the projection angle toward the route.
	if speed < 1.0:
		input.move = heading
	else:
		var along: Vector3 = flat/speed
		var turn: float = along.signed_angle_to(heading,Vector3.UP)
		var side: float = signf(turn) if absf(turn) > deg_to_rad(12) else float(bhop.side)
		var gain_angle: float = acos(clampf(t.air_wish_cap/speed,-1,1))+deg_to_rad(4)
		input.move = along.rotated(Vector3.UP,side*minf(gain_angle,deg_to_rad(88)))
	# Re-jump inside the buffer window just before touchdown.
	var height: float = height_above_ground(a)
	if a.velocity.y < 0 and height/maxf(.5,-a.velocity.y) < .1:
		var wall: bool = not a.resolver.ray(a.body_point(1.0),a.body_point(1.0)+input.move*.9,[a.get_rid()],1).is_empty()
		if not wall: input.jump = true
	return true

static func dash_aim(direction: Vector3) -> Vector3:
	var pitch: float = deg_to_rad(AIR_DASH_PITCH)
	return (direction*cos(pitch)+Vector3.DOWN*sin(pitch)).normalized()

static func height_above_ground(a: HeroActor) -> float:
	var hit: Dictionary = a.resolver.ray(a.global_position+Vector3.UP*.1,a.global_position-Vector3.UP*6,[a.get_rid()],1)
	return 6.0 if hit.is_empty() else a.global_position.y-Vector3(hit.position).y

## Direction an attack is coming from that the bot can perceive, or ZERO.
func incoming_threat(brain: BotBrain, now: float) -> Vector3:
	var a: HeroActor = brain.actor
	# Telegraphed attacks from the visible target, after a human reaction time.
	if brain.visible_target() and str(brain.threat.state) in DODGE_TELLS and a.global_position.distance_to(brain.threat.position) < 14:
		var key: String = "%d:%s" % [brain.target_id,str(brain.threat.state)]
		if not noticed_tell.has(key): noticed_tell = {key:now}
		if now-float(noticed_tell[key]) >= brain.reaction_time():
			noticed_tell[key] = INF
			return ((a.global_position-Vector3(brain.threat.position))*Vector3(1,0,1)).normalized()
	else:
		noticed_tell.clear()
	if now < next_scan: return Vector3.ZERO
	next_scan = now+.1
	var facing: Vector3 = a.aim_direction.normalized()
	var side_cos: float = brain.perception.peripheral_cos()
	var seen: Dictionary = {}
	for node: Node in a.get_tree().get_nodes_in_group("owned_attacks"):
		var attack := node as Node3D
		if attack == null or not "source" in attack: continue
		var source: Variant = attack.get("source")
		if not source is HeroActor or not is_instance_valid(source) or (source as HeroActor).team == a.team: continue
		var at: Vector3 = attack.global_position
		var offset: Vector3 = at-a.body_point(1.0)
		if offset.length() > 22: continue
		var id: int = attack.get_instance_id()
		seen[id] = true
		var previous: Dictionary = tracked_attacks.get(id,{})
		tracked_attacks[id] = {"position":at,"time":now,"first":float(previous.get("first",now))}
		if previous.is_empty() or now-float(previous.time) <= 0: continue
		var velocity: Vector3 = (at-Vector3(previous.position))/(now-float(previous.time))
		if velocity.length() < 8: continue
		# Only attacks in the field of view can be reacted to.
		if facing.dot(offset.normalized()) < side_cos: continue
		if now-float(tracked_attacks[id].first) < brain.skill.acquisition_delay*.8: continue
		var relative: Vector3 = -offset
		var time_to_closest: float = relative.dot(velocity)/velocity.length_squared()
		if time_to_closest < 0 or time_to_closest > .7: continue
		var miss: float = (relative-velocity*time_to_closest).length()
		if miss < 1.4: return velocity.normalized()
	for id: int in tracked_attacks.keys():
		if not seen.has(id): tracked_attacks.erase(id)
	return Vector3.ZERO
