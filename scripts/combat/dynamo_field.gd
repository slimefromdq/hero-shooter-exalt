class_name DynamoField
extends Node3D
var source: HeroActor
var storm: bool = false
var warning: float = 0.0
var remaining: float = 0.0
var clock: float = 0.0
var visual: Node3D
var source_life: int

func _ready() -> void:
	add_to_group("owned_attacks")
	add_to_group("transient")
	source_life = source.life_serial
	var t := source.tuning as DynamoTuning
	remaining = t.storm_duration if storm else t.stone_warning
	warning = 0 if storm else t.stone_warning
	visual = RosterEffects.zone(self,Vector3.ZERO,t.storm_radius if storm else t.stone_radius,Color("99ceff") if storm else Color("ffbc72"))
	visual.position = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	if not is_instance_valid(source) or not source.alive or source.life_serial != source_life or not source.tuning is DynamoTuning:
		queue_free()
		return
	var t := source.tuning as DynamoTuning
	if not storm:
		warning -= delta
		if warning <= .00001:
			pulse(false)
			queue_free()
		return
	var active: float = minf(delta,remaining)
	clock += active
	while clock >= t.storm_interval-.00001:
		clock -= t.storm_interval
		pulse(true)
	remaining = maxf(0,remaining-active)
	if remaining <= .00001: queue_free()

func pulse(is_storm: bool) -> void:
	if source.resolver.attack_locked(source): return
	var t := source.tuning as DynamoTuning
	var radius: float = t.storm_radius if is_storm else t.stone_radius
	var at: Vector3 = global_position+Vector3.UP*.4
	var targets: Array[HeroActor] = []
	for other: HeroActor in get_tree().get_nodes_in_group("actors"):
		if not other.alive or other.team == source.team or at.distance_to(other.body_point(.9)) > radius: continue
		if source.resolver.attack_ray(source,at,other.body_point(.9),[],1).is_empty(): targets.append(other)
	var pulse_cast: int = source.resolver.classify(source.resolver.new_cast(source),CombatResolver.ImpactKind.AREA)
	if is_storm: source.resolver.ultimate_casts[pulse_cast] = true
	source.resolver.splash(source,at,radius,t.storm_damage if is_storm else t.stone_damage,"storm" if is_storm else "lodestone",pulse_cast)
	for other: HeroActor in targets:
		if not other.alive or other.invulnerable or other.state == "wisp_phase" or source.resolver.protected_room(other): continue
		if is_storm:
			other.statuses.apply("slow",source,t.storm_interval+.1,t.storm_slow)
			CombatEffect.line(get_parent(),other.body_point(4),other.body_point(.8),Color("b7ddff"),.045)
		else:
			if other.state in ["captured","throw_pair","boot_attached","boot_captured"]: continue
			var direction: Vector3 = (global_position-other.global_position)*Vector3(1,0,1)
			var distance: float = minf(t.stone_pull,maxf(0,direction.length()-.6))
			if distance <= .001: continue
			other.motor.interrupt_mobility()
			var pull := MagneticPull.new()
			pull.source = source
			pull.target = other
			pull.direction = direction.normalized()
			pull.remaining = distance
			pull.duration = t.stone_pull_time
			pull.speed = distance/t.stone_pull_time
			get_parent().add_child(pull)
	CombatEffect.pulse(get_parent(),at,Color("afd6ff") if is_storm else Color("ffc282"),radius)
