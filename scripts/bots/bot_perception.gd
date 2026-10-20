class_name BotPerception
extends RefCounted
## Only sense() reads live opponents. Consumers receive immutable sampled data.
const MEMORY_SECONDS: float = 4.0
var observations: Dictionary = {}
var visible_ids: Array[int] = []
var ray_count: int = 0
var cursor: int = 0
var incoming_thread: bool = false
var thread_anchor: Vector3 = Vector3.ZERO

func sense(actor: HeroActor, actors: Array, now: float, budget: int = 6) -> void:
	visible_ids.clear()
	incoming_thread = false
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
	for index: int in mini(budget,candidates.size()):
		var other: HeroActor = candidates[(cursor+index)%candidates.size()]
		var id: int = other.get_instance_id()
		if not other.alive or actor.global_position.distance_squared_to(other.global_position) > 65.0*65.0: continue
		ray_count += 1
		var hit: Dictionary = actor.resolver.ray(actor.body_point(1.45),other.body_point(1.0),[actor.get_rid()])
		if not hit.is_empty() and hit.get("collider") != other: continue
		if actor.resolver.protected_room(other) or not other.detectable_by(actor): continue
		var previous: Dictionary = observations.get(id,{})
		var first_seen: float = float(previous.get("first_seen",now))
		if previous.is_empty() or now-float(previous.get("seen",now)) > .45 or int(previous.get("life",-1)) != other.life_serial: first_seen = now
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
			"damage_immune":other.damage_immune(),"facing":other.aim_direction,"seen":now,"first_seen":first_seen,"defense_seen":defense,
			"marks":other.statuses.stitch_count(actor) if actor.kit is StitchKit else other.statuses.soul_count(actor),"status_count":other.statuses.effects.size()}
		visible_ids.append(id)
	if not candidates.is_empty(): cursor = (cursor+budget)%candidates.size()
	expire(now)

func expire(now: float) -> void:
	for id: int in observations.keys():
		var entry: Dictionary = observations[id]
		var other: HeroActor = entry.actor.get_ref() as HeroActor
		if now-float(entry.seen) > MEMORY_SECONDS or not is_instance_valid(other) or other.life_serial != int(entry.life):
			observations.erase(id)
			visible_ids.erase(id)

func merge_shared(shared: Dictionary, now: float) -> void:
	for id: int in shared:
		var report: Dictionary = shared[id]
		if now-float(report.seen) > MEMORY_SECONDS: continue
		if not observations.has(id) or float(observations[id].seen) < float(report.seen):
			observations[id] = report.duplicate()
	expire(now)

func reset() -> void:
	incoming_thread = false
	thread_anchor = Vector3.ZERO
	observations.clear()
	visible_ids.clear()
	cursor = 0
