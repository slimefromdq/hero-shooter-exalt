class_name BotPerception
extends RefCounted
## Only sense() reads live opponents. Consumers receive immutable sampled data.
## Human-fair senses: a focused view cone, a peripheral band that only notices motion
## or gunfire after a delay, hearing through BotHearing, and the felt direction of incoming hits.
## Nothing behind the bot is ever seen; it can only be heard or reported by teammates.
const MEMORY_SECONDS: float = 8.0
## Point-blank presence is always felt, whatever the facing.
const PROXIMITY: float = 2.5
const TRACK_GRACE: float = .45
var observations: Dictionary = {}
var visible_ids: Array[int] = []
var ray_count: int = 0
var cursor: int = 0
var incoming_thread: bool = false
var thread_anchor: Vector3 = Vector3.ZERO
var skill: BotSkillProfile
var rng: RandomNumberGenerator
var hearing: BotHearing
var heard_until: float = -INF
var hit_checked: float = -INF
var glimpses: Dictionary = {}
## Most recent felt hit: {"position","time","source"}. Empty when none.
var hit_from: Dictionary = {}
## Most salient recent sound from an enemy: {"position","time","kind","source"}.
var last_sound: Dictionary = {}
var sounds_heard: int = 0
var peripheral_detections: int = 0

func cone_cos() -> float:
	return cos(deg_to_rad(skill.cone_degrees if skill != null else 50.0))

func peripheral_cos() -> float:
	return cos(deg_to_rad(skill.peripheral_degrees if skill != null else 100.0))

func sense(actor: HeroActor, actors: Array, now: float, budget: int = 6) -> void:
	visible_ids.clear()
	incoming_thread = false
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = actor.get_instance_id()
	if hearing == null and is_instance_valid(actor.resolver): hearing = BotHearing.obtain(actor.resolver)
	if is_instance_valid(hearing): hearing.register(actors)
	if now < heard_until:
		# Combat clock restarted (match reset or test rewind); old cues are meaningless.
		heard_until = now
		hit_checked = -INF
		hit_from = {}
		last_sound = {}
	var healing: Dictionary = {}
	var tethered: Dictionary = {}
	# Build small sampled maps once per sensing pass, not once per opponent/frame.
	for ally: HeroActor in actors:
		if not is_instance_valid(ally) or not ally.alive or not ally.kit is RelayKit: continue
		var seeker := ally.kit as RelayKit
		if seeker.valid_friend(seeker.recipient,seeker.recipient_life) and seeker.transfer_left <= 0 and seeker.sight_lost < seeker.data().sight_grace:
			healing[seeker.recipient.get_instance_id()] = ally.get_instance_id()
		for entry: Dictionary in seeker.extras:
			if seeker.valid_friend(entry.target,entry.life) and float(entry.lost) < seeker.data().sight_grace: healing[entry.target.get_instance_id()] = ally.get_instance_id()
	for thread: RedThread in actor.get_tree().get_nodes_in_group("red_threads"):
		if thread.valid():
			tethered[thread.target.get_instance_id()] = thread.source.get_instance_id()
			if thread.target == actor:
				incoming_thread = true
				thread_anchor = thread.source.global_position
	var fields: Array[Node] = actor.get_tree().get_nodes_in_group("protection_fields")
	var candidates: Array[HeroActor] = []
	for other: HeroActor in actors:
		if not is_instance_valid(other) or other == actor or other.team == actor.team: continue
		candidates.append(other)
	var eye: Vector3 = actor.body_point(1.45)
	var facing: Vector3 = actor.aim_direction.normalized() if not actor.aim_direction.is_zero_approx() else -actor.global_basis.z
	var focus_cos: float = cone_cos()
	var side_cos: float = peripheral_cos()
	var noisy: Dictionary = noisy_sources(now)
	for index: int in mini(budget,candidates.size()):
		var other: HeroActor = candidates[(cursor+index)%candidates.size()]
		var id: int = other.get_instance_id()
		if not other.alive or actor.global_position.distance_squared_to(other.global_position) > 65.0*65.0: continue
		var previous: Dictionary = observations.get(id,{})
		var same_life: bool = not previous.is_empty() and int(previous.get("life",-1)) == other.life_serial
		var tracked: bool = same_life and now-float(previous.get("sighted",-99.0)) <= TRACK_GRACE
		var offset: Vector3 = other.body_point(1.0)-eye
		var distance: float = offset.length()
		var alignment: float = facing.dot(offset/maxf(distance,.001))
		var focused: bool = distance <= PROXIMITY or alignment >= focus_cos
		var peripheral: bool = not focused and alignment >= side_cos
		if not focused and not peripheral:
			glimpses.erase(id)
			continue
		ray_count += 1
		var hit: Dictionary = actor.resolver.ray(eye,other.body_point(1.0),[actor.get_rid()])
		if not hit.is_empty() and hit.get("collider") != other:
			glimpses.erase(id)
			continue
		if actor.resolver.protected_room(other) or not other.detectable_by(actor): continue
		if peripheral and not tracked:
			# The corner of the eye catches movement and muzzle flashes, and needs a moment.
			var conspicuous: bool = Vector2(other.velocity.x,other.velocity.z).length() > 2.5 or absf(other.velocity.y) > 3.0 or noisy.has(id)
			if not conspicuous:
				glimpses.erase(id)
				continue
			if not glimpses.has(id): glimpses[id] = now
			if now-float(glimpses[id]) < (skill.peripheral_delay if skill != null else .35): continue
			peripheral_detections += 1
		glimpses.erase(id)
		var first_seen: float = float(previous.get("first_seen",now))
		if not same_life or now-float(previous.get("sighted",-99.0)) > TRACK_GRACE: first_seen = now
		var defense: float = float(previous.get("defense_seen",-99.0))
		if other.damage_immune() or other.state in ["deflect","marshal_shield"]: defense = now
		var protected: bool = false
		for field: Node in fields:
			if field is SamsonCourt and field.qualifies(other): protected = true
		observations[id] = {"id":id,"actor":weakref(other),"life":other.life_serial,"position":other.global_position,
			"velocity":other.velocity,"health":other.health,"maximum":other.effective_max_health(),"shields":other.shields,"overhealth":other.overhealth.value(),
			"blocked_by_barrier":not actor.resolver.barrier_ray(actor,actor.body_point(1.45),other.body_point(1.0)).is_empty(),
			"hero":other.tuning.hero_id,"role":HeroRoster.role_for(other.tuning.hero_id),"state":other.state,
			"channeling":other.state == "samson_cross","protected":protected,"healing_source":int(healing.get(id,0)),"tether_source":int(tethered.get(id,0)),"pursuing":other.kit is StitchKit and is_instance_valid((other.kit as StitchKit).thread),
			"damage_immune":other.damage_immune(),"facing":other.aim_direction,"seen":now,"sighted":now,"first_seen":first_seen,"defense_seen":defense,
			"source":"sight","uncertainty":0.0,
			"marks":other.statuses.stitch_count(actor) if actor.kit is StitchKit else other.statuses.soul_count(actor),"status_count":other.statuses.effects.size()}
		visible_ids.append(id)
	if not candidates.is_empty(): cursor = (cursor+budget)%candidates.size()
	listen(actor,now)
	expire(now)

## Enemies that made an attack sound within half a second; used by peripheral vision.
func noisy_sources(now: float) -> Dictionary:
	var result: Dictionary = {}
	if not is_instance_valid(hearing): return result
	for entry: Dictionary in hearing.recent(now-.5):
		if str(entry.kind) == "cast": result[int(entry.source)] = true
	return result

func listen(actor: HeroActor, now: float) -> void:
	if not is_instance_valid(hearing): return
	var scale: float = skill.hearing_scale if skill != null else 1.0
	for entry: Dictionary in hearing.recent(heard_until):
		if int(entry.team) == actor.team: continue
		var id: int = int(entry.source)
		if id in visible_ids: continue
		var distance: float = actor.global_position.distance_to(entry.position)
		if distance > float(entry.radius)*scale: continue
		var other := instance_from_id(id) as HeroActor
		if not is_instance_valid(other) or not other.alive or other.life_serial != int(entry.life) or not other.detectable_by(actor): continue
		sounds_heard += 1
		var error: float = clampf(distance*.12/maxf(scale,.1),.5,7.0)
		heard(actor,other,entry.position,error,str(entry.kind),now)
		if last_sound.is_empty() or float(entry.time) >= float(last_sound.time) or distance < actor.global_position.distance_to(last_sound.position):
			last_sound = {"position":observations[id].position,"time":float(entry.time),"kind":str(entry.kind),"source":id}
	heard_until = now
	var hit: Dictionary = hearing.last_hit(actor)
	if not hit.is_empty() and float(hit.time) != hit_checked and int(hit.team) != actor.team:
		var source := instance_from_id(int(hit.source)) as HeroActor
		if is_instance_valid(source) and source.alive and source.life_serial == int(hit.life):
			var distance: float = actor.global_position.distance_to(hit.position)
			if not int(hit.source) in visible_ids:
				heard(actor,source,hit.position,clampf(distance*(.04 if bool(hit.directed) else .2),.4,6.0),"hit",now)
			hit_from = {"position":hit.position,"time":float(hit.time),"source":int(hit.source)}
		hit_checked = float(hit.time)

## Fuses an acoustic cue into memory without granting sight: position is fuzzed and
## visible_ids is untouched, so attacking still requires actually seeing the enemy.
func heard(actor: HeroActor, other: HeroActor, at: Vector3, error: float, kind: String, now: float) -> void:
	var id: int = other.get_instance_id()
	var fuzz := Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).limit_length(1.0)*error
	var previous: Dictionary = observations.get(id,{})
	if previous.is_empty() or int(previous.get("life",-1)) != other.life_serial:
		observations[id] = {"id":id,"actor":weakref(other),"life":other.life_serial,"position":at+fuzz-Vector3.UP*1.0,
			"velocity":Vector3.ZERO,"health":other.effective_max_health(),"maximum":other.effective_max_health(),"shields":0.0,"overhealth":0.0,
			"blocked_by_barrier":false,"hero":other.tuning.hero_id,"role":HeroRoster.role_for(other.tuning.hero_id),"state":"unknown",
			"channeling":false,"protected":false,"healing_source":0,"tether_source":0,"pursuing":false,"damage_immune":false,
			"facing":Vector3.ZERO,"seen":now,"sighted":-99.0,"first_seen":now,"defense_seen":-99.0,"source":kind,"uncertainty":error,
			"marks":0,"status_count":0}
		return
	var entry: Dictionary = previous.duplicate()
	# A fresher sound only replaces older or vaguer knowledge.
	var age: float = now-float(entry.seen)
	if age < .1 and float(entry.get("uncertainty",0)) <= error: return
	entry.position = at+fuzz-Vector3.UP*1.0
	entry.velocity = Vector3.ZERO
	entry.seen = now
	entry.source = kind
	entry.uncertainty = error
	entry.state = "unknown"
	observations[id] = entry

## Where a remembered enemy probably is now: dead reckoning, capped, with growing doubt.
static func predicted(entry: Dictionary, now: float) -> Vector3:
	var age: float = clampf(now-float(entry.get("seen",now)),0,1.2)
	var drift: Vector3 = Vector3(entry.get("velocity",Vector3.ZERO))*Vector3(1,0,1)*age
	return Vector3(entry.position)+drift

static func uncertainty(entry: Dictionary, now: float) -> float:
	return float(entry.get("uncertainty",0.0))+maxf(0,now-float(entry.get("seen",now)))*4.0

## The point a human would glance at when nothing is in the crosshair, or INF.
func attention_point(actor: HeroActor, now: float, threat_id: int) -> Vector3:
	if not hit_from.is_empty() and now-float(hit_from.time) < 1.2: return Vector3(hit_from.position)
	if not last_sound.is_empty() and now-float(last_sound.time) < 1.0: return Vector3(last_sound.position)+Vector3.UP*1.2
	if observations.has(threat_id):
		var entry: Dictionary = observations[threat_id]
		if now-float(entry.seen) < 3.0: return predicted(entry,now)+Vector3.UP*1.2
	return Vector3.INF

func expire(now: float) -> void:
	for id: int in observations.keys():
		var entry: Dictionary = observations[id]
		var other: HeroActor = entry.actor.get_ref() as HeroActor
		if now-float(entry.seen) > MEMORY_SECONDS or now < float(entry.seen)-1.0 or not is_instance_valid(other) or other.life_serial != int(entry.life):
			observations.erase(id)
			visible_ids.erase(id)

func merge_shared(shared: Dictionary, now: float) -> void:
	for id: int in shared:
		var report: Dictionary = shared[id]
		if now-float(report.seen) > MEMORY_SECONDS: continue
		if not observations.has(id) or float(observations[id].seen) < float(report.seen):
			var entry: Dictionary = report.duplicate()
			# A teammate's callout is not this bot's own sighting.
			entry.sighted = float(observations.get(id,{}).get("sighted",-99.0))
			entry.source = "radio"
			observations[id] = entry
	expire(now)

func reset() -> void:
	incoming_thread = false
	thread_anchor = Vector3.ZERO
	observations.clear()
	visible_ids.clear()
	glimpses.clear()
	hit_from = {}
	last_sound = {}
	cursor = 0
