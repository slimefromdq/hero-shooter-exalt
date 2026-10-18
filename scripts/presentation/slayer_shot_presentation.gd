class_name SlayerShotPresentation
extends Node3D
## Consumes completed casts only; never alters aim, damage, or gameplay RNG.
const MUZZLE = preload("res://scenes/effects/slayer_shotgun_muzzle.tscn")
const IMPACT = preload("res://scenes/effects/slayer_shotgun_impact.tscn")
const MAX_IMPACTS: int = 4
const MAX_LOCAL_BURSTS: int = 16
const MAX_WORLD_BURSTS: int = 64
@export var enabled: bool = true
var presentation: HeroPresentation
var shot_age: float = 99.0
var effects: Array[Node3D] = []
var last_impact_count: int = 0
var last_report: Array[Dictionary] = []
var feedback_camera: Camera3D
var effect_pool: Node

func _ready() -> void:
	effect_pool = get_node("/root/SlayerEffectPool")

func discharge(origin: Vector3, forward: Vector3, contacts: Array[Dictionary], endpoints: PackedVector3Array = PackedVector3Array()) -> void:
	shot_age = 0.0
	last_report = contacts.duplicate(true)
	last_impact_count = 0
	if not enabled:
		CombatEffect.pulse(self, origin, Color("ffc983"), .28)
		for contact: Dictionary in contacts:
			CombatEffect.pulse(self, contact.position, Color("ff5979") if contact.actor else Color("ffad63"), .13)
		for index: int in endpoints.size():
			if index % 2 == 0: CombatEffect.line(self, origin, endpoints[index], Color("ffd5a0"), .015)
		for effect: Node3D in get_children(): effect.top_level = true
		return
	# Match the existing rendered barrel. This cosmetic occlusion ray has no combat outcome.
	var barrel: Vector3 = presentation.rifle.to_global(Vector3(0, .03, -.9))
	if is_instance_valid(presentation.slayer_model) and presentation.slayer_model.active:
		barrel = presentation.slayer_model.muzzle.global_position
	var obstruction: Dictionary = presentation.actor.resolver.ray(origin, barrel, [presentation.actor.get_rid()], 1)
	if not obstruction.is_empty(): barrel = obstruction.position + obstruction.normal * .025
	spawn_burst(MUZZLE, barrel, forward, Color("ffd2a0"))
	# Confirmed enemy hits get priority when a spread crosses several surfaces.
	var groups: Array[Dictionary] = []
	for contact: Dictionary in contacts:
		var found: bool = false
		for cluster: Dictionary in groups:
			if cluster.id == contact.id and (contact.actor or cluster.position.distance_to(contact.position) < 1.5):
				cluster.sum += contact.position
				cluster.count += 1
				cluster.position = cluster.sum / cluster.count
				cluster.head = cluster.head or contact.head
				cluster.confirmed = cluster.confirmed or contact.confirmed
				found = true
				break
		if not found:
			groups.append({"id": contact.id, "position": contact.position, "sum": contact.position, "count": 1, "normal": contact.normal, "confirmed": contact.confirmed, "head": contact.head})
	groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.confirmed and not b.confirmed)
	var confirmed: bool = false
	for cluster: Dictionary in groups.slice(0, MAX_IMPACTS):
		var colour := Color("ffe278") if cluster.head else Color("ff5578")
		if not cluster.confirmed: colour = Color("f5ba80")
		spawn_burst(IMPACT, cluster.position + cluster.normal * .025, cluster.normal, colour)
		last_impact_count += 1
		confirmed = confirmed or cluster.confirmed
	if not groups.is_empty():
		presentation.sound.play_slayer("shotgun_hit" if confirmed else "shotgun_surface")
	if presentation.actor.controller is PlayerController:
		feedback_camera = (presentation.actor.controller as PlayerController).camera

func spawn_burst(scene: PackedScene, at: Vector3, forward: Vector3, colour: Color) -> void:
	for index: int in range(effects.size() - 1, -1, -1):
		if not is_instance_valid(effects[index]) or effects[index].get_parent() != self: effects.remove_at(index)
	while effects.size() >= MAX_LOCAL_BURSTS:
		effect_pool.recycle(effects.pop_front())
	if get_tree().get_nodes_in_group("slayer_bursts").size() >= MAX_WORLD_BURSTS: return
	var effect: SlayerBurstEffect = effect_pool.acquire(scene == MUZZLE)
	if effect == null: return
	effect.reparent(self, false)
	effect.top_level = true
	effect.global_position = at
	if not forward.is_zero_approx(): effect.look_at(at + forward, Vector3.RIGHT if absf(forward.normalized().dot(Vector3.UP)) > .99 else Vector3.UP)
	effect.tint(colour)
	effect.activate()
	effects.append(effect)

func _process(delta: float) -> void:
	shot_age += delta
	if is_instance_valid(feedback_camera):
		# Projection offsets and local roll leave gather_intent's forward/origin unchanged.
		var kick: float = exp(-shot_age * 30.0)
		feedback_camera.h_offset = sin(shot_age * 85.0) * .012 * kick
		feedback_camera.v_offset = .022 * kick
		feedback_camera.rotation.z = sin(shot_age * 60.0) * .006 * kick
		if shot_age > .3: clear_camera()

func clear_camera() -> void:
	if is_instance_valid(feedback_camera):
		feedback_camera.h_offset = 0.0
		feedback_camera.v_offset = 0.0
		feedback_camera.rotation.z = 0.0
	feedback_camera = null

func clear() -> void:
	shot_age = 99.0
	clear_camera()
	for effect: Node in get_children():
		if effect is SlayerBurstEffect:
			effect_pool.recycle(effect)
		else:
			remove_child(effect)
			effect.queue_free()
	effects.clear()
	last_report.clear()
	last_impact_count = 0

func _exit_tree() -> void:
	clear()
