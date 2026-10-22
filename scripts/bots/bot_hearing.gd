class_name BotHearing
extends Node
## Shared acoustic event log. It records *where something happened*, never a live
## reference a bot could aim with: listeners only receive fuzzed positions.
## Sources: every attack cast, every impact (with damage direction), and actor movement tech.

const KEEP_SECONDS: float = 1.5
const MAX_EVENTS: int = 256
## Audible radii in metres before the listener's skill scale and occlusion.
const RADIUS: Dictionary = {"cast":38.0,"impact":20.0,"dash":16.0,"slide":12.0,"wall_jump":12.0,"mantle":9.0,"jump":9.0,"landing":10.0}

var resolver: CombatResolver
var events: Array[Dictionary] = []
var hits: Dictionary = {}
var registered: Dictionary = {}

static func obtain(source: CombatResolver) -> BotHearing:
	var hub: BotHearing = source.get_node_or_null("BotHearing") as BotHearing
	if hub == null:
		hub = BotHearing.new()
		hub.name = "BotHearing"
		hub.resolver = source
		source.add_child(hub)
		source.cast_started.connect(hub.on_cast)
		source.impact_confirmed.connect(hub.on_impact)
	return hub

func register(actors: Array) -> void:
	for other: Variant in actors:
		var hero := other as HeroActor
		if not is_instance_valid(hero): continue
		var id: int = hero.get_instance_id()
		if registered.has(id): continue
		registered[id] = true
		hero.movement_confirmed.connect(on_movement.bind(weakref(hero)))

func push(kind: String, source: HeroActor, at: Vector3) -> void:
	if not is_instance_valid(source) or not is_instance_valid(resolver): return
	events.append({"kind":kind,"source":source.get_instance_id(),"team":source.team,"life":source.life_serial,
		"position":at,"time":resolver.combat_time,"radius":float(RADIUS.get(kind,10.0)),"hero":source.tuning.hero_id})
	if events.size() > MAX_EVENTS: events.pop_front()

func on_cast(source: HeroActor, _id: int) -> void:
	if is_instance_valid(source) and source.alive: push("cast",source,source.body_point(1.2))

func on_movement(kind: String, _at: Vector3, _direction: Vector3, _normal: Vector3, _strength: float, ref: WeakRef) -> void:
	var hero := ref.get_ref() as HeroActor
	if not is_instance_valid(hero) or not hero.alive: return
	var key: String = "slide" if kind.ends_with("slide") else kind
	if not RADIUS.has(key): return
	# Crouch-walking and ordinary running stay silent; only deliberate movement tech is audible.
	if key == "landing" and hero.velocity.y > -6.0: return
	push(key,hero,hero.global_position)

func on_impact(source: HeroActor, target: HeroActor, _amount: float, _head: bool, _executed: bool, origin: Vector3, _shield: float, _cast: int, _tag: String) -> void:
	if not is_instance_valid(target) or not is_instance_valid(source) or not is_instance_valid(resolver): return
	push("impact",target,target.body_point(1.0))
	# The victim feels the direction it was hit from. Area/periodic damage has no direction.
	var from: Vector3 = source.body_point(1.2) if origin == Vector3.INF else origin
	hits[target.get_instance_id()] = {"source":source.get_instance_id(),"life":source.life_serial,"team":source.team,
		"position":from,"time":resolver.combat_time,"directed":origin != Vector3.INF,"hero":source.tuning.hero_id}

func recent(since: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(resolver): return result
	var now: float = resolver.combat_time
	if not events.is_empty() and float(events[-1].time) > now+.01:
		clear()
		return result
	while not events.is_empty() and now-float(events[0].time) > KEEP_SECONDS: events.pop_front()
	for entry: Dictionary in events:
		if float(entry.time) >= since and float(entry.time) <= now: result.append(entry)
	return result

func last_hit(target: HeroActor) -> Dictionary:
	return hits.get(target.get_instance_id(),{})

func clear() -> void:
	events.clear()
	hits.clear()
