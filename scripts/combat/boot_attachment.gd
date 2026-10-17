class_name BootAttachment
extends RefCounted
## Holds real, already separated capsules; only the contact pose follows the turn.
var attacker: HeroActor
var victim: HeroActor
var remaining: float
var ended: bool = false
var attacker_at: Vector3
var victim_at: Vector3

func configure(owner: HeroActor, target: HeroActor) -> void:
	attacker = owner
	victim = target
	remaining = (owner.tuning as SlayerTuning).boot_hold
	attacker_at = owner.global_position
	victim_at = target.global_position
	owner.motor.interrupt_mobility()
	target.motor.interrupt_mobility()
	owner.close.cancel()
	target.close.cancel()
	target.kit.cancel()
	owner.boot_pair = self
	target.boot_pair = self
	owner.state = "boot_attached"
	target.state = "boot_captured"
	owner.velocity = Vector3.ZERO
	target.velocity = Vector3.ZERO
	owner.motor.external_velocity = Vector3.ZERO
	target.motor.external_velocity = Vector3.ZERO
	owner.resolver.record("status",owner,"boot_attachment","target="+target.actor_id)

func tick(delta: float) -> void:
	if ended: return
	if not is_instance_valid(attacker) or not is_instance_valid(victim):
		release(false)
		return
	if not attacker.alive or not victim.alive or attacker.state != "boot_attached" or victim.state != "boot_captured" or attacker.global_position.distance_to(attacker_at) > .05 or victim.global_position.distance_to(victim_at) > .05:
		release(false)
		return
	remaining -= delta
	if remaining <= 0: release(true)

func release(kick: bool) -> void:
	if ended: return
	ended = true
	for participant: HeroActor in [attacker,victim]:
		if not is_instance_valid(participant): continue
		participant.boot_pair = null
		if participant.state in ["boot_attached","boot_captured"]: participant.state = "ready"
	if is_instance_valid(attacker) and attacker.kit is SlayerKit:
		var kit := attacker.kit as SlayerKit
		kit.boot_slow_duration = kit.data().boot_hit_recovery
		kit.boot_slow_time = kit.boot_slow_duration
	if kick and is_instance_valid(attacker) and is_instance_valid(victim) and attacker.alive and victim.alive:
		var t := attacker.tuning as SlayerTuning
		var forward := Vector3(attacker.aim_direction.x,0,attacker.aim_direction.z).normalized()
		if forward.is_zero_approx(): forward = -attacker.global_basis.z
		attacker.resolver.knockback(attacker,victim,forward*t.boot_knockback+Vector3.UP*t.boot_lift,"boot_release")
		attacker.presentation.boot_release = .18
		attacker.presentation.sound.play_slayer("boot_hit")
		attacker.resolver.record("release",attacker,"boot_kick")
