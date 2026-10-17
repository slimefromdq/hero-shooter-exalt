class_name HeroActor
extends CharacterBody3D

signal damaged(amount: float, head: bool)
signal died

@export var tuning: HeroTuning
@export var team: int = 0
@export var actor_id: String = "nimbus"
var health: float = 250.0
var shields: float = 0.0
var invulnerable: bool = false
var spawn_protected: bool = false
var infinite_resources: bool = false
var alive: bool = true
var state: String = "ready"
var state_time: float = 0.0
var aim_direction: Vector3 = Vector3.FORWARD
var intent: CombatIntent = CombatIntent.new()
var resolver: CombatResolver
var controller: Node
var motor: HeroMotor
var kit: HeroKit
var benefits: ActorBenefits
var statuses: CombatStatuses
var close: CloseCombat
var presentation: HeroPresentation
var spawn_position: Vector3
var last_hit_age: float = 99.0
var boot_pair: BootAttachment

func _ready() -> void:
	if tuning == null:
		tuning = load("res://resources/nimbus.tres") as HeroTuning
	tuning = tuning.duplicate() as HeroTuning
	add_to_group("actors")
	collision_layer = 2
	collision_mask = 3
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(48.0)
	spawn_position = position
	var shape := CollisionShape3D.new()
	shape.name = "BodyCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.95
	add_child(shape)
	resolver = get_tree().get_first_node_in_group("combat_resolver") as CombatResolver
	motor = HeroMotor.new()
	motor.actor = self
	add_child(motor)
	benefits = ActorBenefits.new()
	benefits.actor = self
	statuses = CombatStatuses.new()
	statuses.actor = self
	kit = HeroRoster.kit_for(tuning.hero_id)
	kit.actor = self
	add_child(kit)
	close = CloseCombat.new()
	close.actor = self
	add_child(close)
	presentation = HeroPresentation.new()
	presentation.actor = self
	add_child(presentation)
	health = tuning.max_health

func _physics_process(delta: float) -> void:
	last_hit_age += delta
	if controller != null and controller.has_method("gather_intent"):
		intent = controller.gather_intent(delta)
	if not alive:
		return
	benefits.tick(delta)
	statuses.tick(delta)
	if not alive:
		return
	if state not in ["captured", "throw_pair", "mantle", "boot_captured"]:
		if state in ["huddle_wave","huddle_scatter"]:
			aim_direction = (kit as HuddleKit).travel_direction
		elif state == "marshal_verdict":
			aim_direction = (kit as MarshalKit).verdict_direction
		elif state in ["slayer_boot_start", "slayer_boot_active"]:
			aim_direction = (kit as SlayerKit).boot_direction
		else:
			aim_direction = close.melee_direction if state.begins_with("melee_") else intent.aim.normalized()
		if Vector2(aim_direction.x, aim_direction.z).length() > 0.01:
			rotation.y = atan2(-aim_direction.x, -aim_direction.z)
	state_time = maxf(0.0, state_time - delta)
	kit.tick_reload(delta)
	if boot_pair != null and boot_pair.attacker == self: boot_pair.tick(delta)
	if state in ["stagger", "counterthrow", "throw_release"] and state_time <= 0.0:
		state = "ready"
	if state == "marshal_shield" and (intent.melee or intent.throw_action or intent.guard): (kit as MarshalKit).lower_barrier()
	if state == "huddle_regroup" and (intent.melee or intent.throw_action or intent.guard or intent.dash): state = "ready"
	close.tick(delta, intent)
	kit.tick(delta, intent)
	motor.tick(delta, intent)
	if global_position.y < -8.0:
		die()

# One authority boundary: controllers request actions; only components resolve them.
func permits(action: String) -> bool:
	if state in ["boot_attached","boot_captured"]: return false
	if action == "primary" and kit != null and kit.reloading: return false
	if tuning.hero_id == "huddle" and action in ["scatter","screen","regroup","wave"]:
		if resolver.protected_room(self): return false
		if action in ["scatter","wave"] and statuses.movement_disabled(): return false
	if action in ["primary", "melee", "throw", "counter", "bomb", "ultimate", "knife", "boot", "snare", "march", "house_call", "barrier", "deflect"] and resolver.protected_room(self):
		return false
	if statuses.movement_disabled() and action in ["dash", "hover", "boot", "jump", "march", "house_call"]:
		return false
	if tuning.hero_id != "nimbus" and action == "hover":
		return false
	if not alive or state in ["captured", "throw_pair", "stagger", "counterthrow", "throw_release"]:
		return false
	if action == "counter":
		return state in ["ready", "guard", "throw_startup"]
	if state == "ultimate":
		return action in ["primary", "aim"]
	if state == "huddle_regroup":
		return action in ["primary","reload","scatter","screen","bomb","wave","dash","melee","throw","counter","guard","jump"]
	if state != "ready":
		return false
	if motor.mode in ["dash", "dash_windup"]:
		return false
	return true

func muzzle() -> Vector3:
	return global_position + Vector3.UP * 1.36 + global_basis.x * 0.32 + aim_direction * 0.55

func on_damage(amount: float, head: bool) -> void:
	last_hit_age = 0.0
	damaged.emit(amount, head)
	if state == "throw_startup":
		close.interrupt_startup()
	if health <= 0.0:
		die()

func die() -> void:
	if not alive:
		return
	alive = false
	if boot_pair != null: boot_pair.release(false)
	benefits.clear_owned()
	benefits.clear()
	statuses.clear()
	presentation.clear_feedback()
	close.cancel()
	kit.cancel(true)
	motor.cancel()
	state = "dead"
	velocity = Vector3.ZERO
	collision_layer = 0
	resolver.resolve_death(self)
	resolver.record("death", self, "health")
	died.emit()

func reset_actor(at: Vector3 = Vector3.INF) -> void:
	if boot_pair != null: boot_pair.release(false)
	resolver.contributions.erase(get_instance_id())

	for barrier: CombatBarrier in get_tree().get_nodes_in_group("barriers"):
		if barrier is HuddleScreen and barrier.recipient == self: barrier.retire()
	benefits.clear_owned()
	benefits.clear()
	statuses.clear()
	presentation.clear_feedback()
	close.cancel()
	kit.cancel(true)
	motor.cancel()
	alive = true
	health = tuning.max_health
	shields = 0.0
	invulnerable = false
	state = "ready"
	state_time = 0.0
	velocity = Vector3.ZERO
	global_position = spawn_position if at == Vector3.INF else at
	collision_layer = 2
	kit.refill()
	close.refill()
	intent = CombatIntent.new()
	if controller != null and controller.has_method("reset_controller"):
		controller.reset_controller()
	resolver.record("reset", self, "scenario")

func _exit_tree() -> void:
	if boot_pair != null: boot_pair.release(false)
	if benefits != null: benefits.clear_owned()
	if is_instance_valid(close):
		close.cancel()

func effective_max_health() -> float:
	return statuses.effective_max() if statuses != null else tuning.max_health

func select_hero(id: String) -> void:
	reset_actor(global_position)
	kit.cancel(true)
	remove_child(kit)
	kit.queue_free()
	remove_child(presentation)
	presentation.queue_free()
	tuning = HeroRoster.tuning_for(id)
	kit = HeroRoster.kit_for(id)
	kit.actor = self
	add_child(kit)
	kit.refill()
	presentation = HeroPresentation.new()
	presentation.actor = self
	add_child(presentation)
	health = tuning.max_health
