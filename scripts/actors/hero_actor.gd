class_name HeroActor
extends CharacterBody3D

signal damaged(amount: float, head: bool)
signal overhealth_changed(amount: float)
signal overhealth_cleared
signal overhealth_broken
signal movement_confirmed(kind: String, at: Vector3, direction: Vector3, normal: Vector3, strength: float)
signal dash_slide_failed(reason: String)
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
var life_serial: int = 0
var state: String = "ready"
var state_time: float = 0.0
var aim_direction: Vector3 = Vector3.FORWARD
var intent: CombatIntent = CombatIntent.new()
var resolver: CombatResolver
var controller: Node
var motor: HeroMotor
var kit: HeroKit
var overhealth: ActorOverhealth
var benefits: ActorBenefits
var statuses: CombatStatuses
var close: CloseCombat
var presentation: HeroPresentation
var spawn_position: Vector3
var last_hit_age: float = 99.0
var boot_pair: BootAttachment
var mobility_limited: bool = false

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
	overhealth = ActorOverhealth.new()
	overhealth.actor = self
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
	mobility_limited = false
	var before_motion: Vector3 = global_position
	last_hit_age += delta
	if controller != null and controller.has_method("gather_intent"):
		intent = controller.gather_intent(delta)
	if not alive:
		return
	overhealth.tick(delta)
	benefits.tick(delta)
	statuses.tick(delta)
	intent = statuses.filter_intent(intent)
	if not alive:
		return
	if state not in ["captured", "throw_pair", "mantle", "boot_captured"]:
		if state in ["huddle_wave","huddle_scatter"]:
			aim_direction = (kit as HuddleKit).travel_direction
		elif state in ["marshal_verdict","marshal_march"]:
			aim_direction = (kit as MarshalKit).verdict_direction if state == "marshal_verdict" else (kit as MarshalKit).march_direction
		elif state in ["slayer_boot_start", "slayer_boot_active"]:
			aim_direction = (kit as SlayerKit).boot_direction
		else:
			aim_direction = close.melee_direction if state.begins_with("melee_") and close.melee_age >= tuning.melee_lunge_delay else intent.aim.normalized()
		if Vector2(aim_direction.x, aim_direction.z).length() > 0.01:
			rotation.y = atan2(-aim_direction.x, -aim_direction.z)
	state_time = maxf(0.0, state_time - delta)
	kit.tick_reload(delta)
	if boot_pair != null and boot_pair.attacker == self: boot_pair.tick(delta)
	if state in ["stagger", "counterthrow", "throw_release"] and state_time <= 0.0:
		state = "ready"
	if state == "marshal_shield" and (intent.melee or intent.throw_action or intent.guard): (kit as MarshalKit).lower_barrier()
	if state == "huddle_regroup" and (intent.melee or intent.throw_action or intent.guard or intent.dash): state = "ready"
	if kit is SamsonKit: (kit as SamsonKit).prepare_actions(intent)

	kit.prepare_input(intent)
	close.tick(delta, intent)
	kit.tick(delta, intent)
	if kit.ammo <= 0 and not kit is RelayKit and not infinite_resources: kit.start_reload()
	motor.tick(delta, intent)
	if mobility_limited:
		motor.interrupt_mobility()
		if state != "ready": kit.cancel()
	var session: Node = get_tree().get_first_node_in_group("museum_match")
	if session != null: session.enforce_spawn_exclusion(self,before_motion)
	if global_position.y < -8.0:
		die()

# One authority boundary: controllers request actions; only components resolve them.
func permits(action: String) -> bool:
	if not statuses.permits(action): return false
	if kit is WispKit and (kit as WispKit).phase_recovery_left > .000001 and action not in ["aim","reload","jump"]: return false
	if action == "intervene" and statuses.movement_disabled(): return false

	if kit is StitchKit:
		if concealed() and action in ["dash","jump","hover"]: return false
		if action in ["stitch_hook","stitch_hide","stitch_thread"] and resolver.attack_locked(self): return false
		if action in ["stitch_hook","stitch_lunge"] and statuses.movement_disabled(): return false
	if kit is ExpansionKit:
		if action in ["step","lift","kickstart"] and statuses.movement_disabled(): return false
		if action in ["secondary","step","lift","kickstart","phase","assign","wall"] and resolver.attack_locked(self): return false
	if state in ["boot_attached","boot_captured"]: return false
	if action == "primary" and kit != null and kit.reloading: return false
	if tuning.hero_id == "huddle" and action in ["scatter","screen","regroup","wave"]:
		if resolver.attack_locked(self): return false
		if action in ["scatter","wave"] and statuses.movement_disabled(): return false
	if action in ["primary", "melee", "throw", "counter", "bomb", "ultimate", "knife", "boot", "snare", "march", "house_call", "barrier", "deflect"] and resolver.attack_locked(self):
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
	var shoulder: float = -.32 if kit is WispKit and kit.ammo%2 == 0 else .32
	if kit is RelayKit: shoulder = -.35
	return body_point(1.36) + global_basis.x * shoulder + aim_direction * 0.55

func body_point(standing_height: float) -> Vector3:
	return global_position + Vector3.UP * (standing_height - motor.posture_lowering())

func headshot_height() -> float:
	return 1.5 - motor.posture_lowering()

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
	life_serial += 1
	if boot_pair != null: boot_pair.release(false)
	overhealth.clear_owned()
	overhealth.clear()
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
	life_serial += 1
	if has_meta("structure_route"): remove_meta("structure_route")
	if boot_pair != null: boot_pair.release(false)
	resolver.contributions.erase(get_instance_id())

	for barrier: CombatBarrier in get_tree().get_nodes_in_group("barriers"):
		if barrier is HuddleScreen and barrier.recipient == self: barrier.retire()
	overhealth.clear_owned()
	overhealth.clear()
	benefits.clear_owned()
	benefits.clear()
	statuses.clear()
	presentation.clear_feedback()
	close.cancel()
	kit.cancel(true)
	motor.cancel()
	alive = true
	last_hit_age = 99.0
	health = tuning.max_health
	shields = 0.0
	invulnerable = false
	state = "ready"
	state_time = 0.0
	velocity = Vector3.ZERO
	global_position = spawn_position if at == Vector3.INF else at
	collision_layer = 2
	kit.reset_life()
	close.refill()
	intent = CombatIntent.new()
	if controller != null and controller.has_method("reset_controller"):
		controller.reset_controller()
	resolver.record("reset", self, "scenario")

func _exit_tree() -> void:
	if is_inside_tree():
		RedThread.clear_actor(self)
		if statuses != null: statuses.clear()
	if boot_pair != null: boot_pair.release(false)
	if is_instance_valid(kit): kit.cancel(true)
	if overhealth != null:
		overhealth.clear_owned()
		overhealth.clear()
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
	kit.reset_life()
	presentation = HeroPresentation.new()
	presentation.actor = self
	add_child(presentation)
	health = tuning.max_health

func concealed() -> bool:
	return kit is StitchKit and (kit as StitchKit).concealed

func detectable_by(observer: HeroActor) -> bool:
	if not concealed() or observer == self or (is_instance_valid(observer) and observer.team == team): return true
	if not is_instance_valid(observer): return false
	return observer.global_position.distance_to(global_position) <= (tuning as StitchTuning).detection_range and resolver.visible(observer.body_point(1),self,[observer.get_rid()])

func objective_eligible() -> bool:
	return alive and not concealed() and not ability_damage_immune()

func ability_damage_immune() -> bool:
	return alive and (state == "wisp_phase" or (kit is WispKit and (kit as WispKit).ability_immune()))

func damage_immune() -> bool:
	return invulnerable or ability_damage_immune()

func constrain_mobility(motion: Vector3) -> Vector3:
	var result: Vector3 = RedThread.constrain(self,motion)
	if not result.is_equal_approx(motion): mobility_limited = true
	return result

func move_ability_collide(motion: Vector3) -> KinematicCollision3D:
	return move_and_collide(constrain_mobility(motion))

func move_ability_slide(delta: float) -> bool:
	velocity = constrain_mobility(velocity*delta)/maxf(delta,.000001)
	return move_and_slide()
