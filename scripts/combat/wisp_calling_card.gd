class_name WispCallingCard
extends Node3D
## A fixed impact location, explicit warning, and one snapshotted blast cast.
var source: HeroActor
var direction: Vector3 = Vector3.FORWARD
var cast_id: int
var source_life: int
var traveled: float = 0
var armed: bool = false
var remaining: float = 0
var detonated: bool = false
var warning_ring: MeshInstance3D
var card: Node3D
var tone_left: float = 0
var suction_started: bool = false
var suction_ring: MeshInstance3D
var pulled: Dictionary = {}

func data() -> WispTuning:
	return source.tuning as WispTuning

func _ready() -> void:
	source_life = source.life_serial
	add_to_group("owned_attacks")
	add_to_group("transient")
	card = Node3D.new()
	add_child(card)
	Geometry.box(card,Vector3(.3,.45,.025),Vector3.ZERO,Color("f4dfff"),false)
	Geometry.box(card,Vector3(.13,.15,.03),Vector3(0,0,-.02),Color("983adc"),false).rotation.z = PI/4
	# Explicit snapshot protects future damage even after Wisp returns to ready.
	source.resolver.ultimate_casts[cast_id] = true

func valid_source() -> bool:
	return is_instance_valid(source) and source.alive and source.life_serial == source_life and source.tuning is WispTuning

func arm(at: Vector3) -> void:
	if armed: return
	armed = true
	global_position = at
	remaining = data().heist_warning
	var ring := TorusMesh.new()
	ring.inner_radius = data().heist_radius-.06
	ring.outer_radius = data().heist_radius+.06
	warning_ring = Geometry.mesh(self,ring,Vector3.ZERO,Geometry.material(Color("c17dff"),1.4))
	source.presentation.sound.play_tone(440,.14,.12)
	source.resolver.record("warning",source,"grand_heist")

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion() or detonated: return
	if not valid_source():
		queue_free()
		return
	card.rotation.y += delta*9
	if not armed:
		var distance: float = minf(data().heist_speed*delta,data().heist_range-traveled)
		var next: Vector3 = global_position+direction*distance
		var hit: Dictionary = source.resolver.attack_ray(source,global_position,next,[source.get_rid()])
		traveled += distance
		if not hit.is_empty(): arm(hit.position+hit.normal*.04)
		else:
			global_position = next
			if traveled >= data().heist_range-.00001: arm(global_position)
		return
	var before: float = remaining
	remaining = maxf(0,remaining-delta)
	if remaining <= data().heist_suction_duration and not suction_started:
		suction_started = true
		var ring := TorusMesh.new()
		ring.inner_radius = data().heist_radius-.08
		ring.outer_radius = data().heist_radius+.08
		suction_ring = Geometry.mesh(self,ring,Vector3(0,.06,0),Geometry.material(Color("ead2ff"),2))
		source.presentation.sound.play_tone(180,data().heist_suction_duration,.2)
		source.resolver.record("suction",source,"grand_heist")
	if suction_started:
		var active: float = maxf(0,minf(before,data().heist_suction_duration)-minf(remaining,data().heist_suction_duration))
		suction_ring.scale = Vector3.ONE*lerpf(.13,1.0,remaining/data().heist_suction_duration)
		pull_enemies(active)
	tone_left -= delta
	if tone_left <= 0:
		tone_left = lerpf(.08,.25,remaining/data().heist_warning)
		source.presentation.sound.play_tone(lerpf(1200,500,remaining/data().heist_warning),.045,.09)
	warning_ring.scale = Vector3.ONE*(1+.025*sin(remaining*40))
	if remaining <= .000001: detonate()

func pull_enemies(delta: float) -> void:
	if delta <= 0 or detonated or is_queued_for_deletion() or not valid_source() or source.resolver.attack_locked(source): return
	var t := data()
	for target: HeroActor in get_tree().get_nodes_in_group("actors"):
		if target.team == source.team or not target.alive or target.damage_immune() or source.resolver.protected_room(target): continue
		if target.state in ["captured","throw_pair","boot_attached","boot_captured"]: continue
		var at: Vector3 = target.body_point(.9)
		if global_position.distance_to(at) > t.heist_radius: continue
		if source.resolver.spawn_door_blocks(global_position,at) or not source.resolver.attack_ray(source,global_position,at,[],1).is_empty(): continue
		# Ground-safe horizontal suction clusters bodies without lifting them into
		# an aerial card, overlapping them, or overshooting the center.
		var toward: Vector3 = (global_position-at)*Vector3(1,0,1)
		var distance: float = minf(t.heist_suction_speed*delta,maxf(0,toward.length()-t.heist_suction_stop))
		if distance <= .00001: continue
		var motion: Vector3 = toward.normalized()*distance
		var session: Node = get_tree().get_first_node_in_group("city_match")
		var crosses_spawn: bool = false
		if session != null:
			for team: int in 2:
				if session.definition.spawn_bounds(team).intersects_segment(target.global_position,target.global_position+motion) != null: crosses_spawn = true
		if crosses_spawn: continue
		var key: int = target.get_instance_id()
		if int(pulled.get(key,-1)) != target.life_serial:
			pulled[key] = target.life_serial
			target.motor.interrupt_mobility()
			source.resolver.record("displacement",source,"grand_heist","target=%s suction" % target.actor_id)
		var collision: KinematicCollision3D = target.move_ability_collide(motion)
		if collision != null and collision.get_normal().dot(toward.normalized()) >= -.02:
			target.move_ability_collide(collision.get_remainder().slide(collision.get_normal()))

func multiplier(distance: float) -> float:
	return WispBlast.multiplier(distance,data().heist_full_radius,data().heist_radius,data().heist_minimum)

func detonate() -> void:
	if detonated or is_queued_for_deletion() or not valid_source(): return
	detonated = true
	var t := data()
	WispBlast.resolve(source,global_position,t.heist_radius,t.heist_full_radius,t.heist_damage,t.heist_minimum,cast_id,"grand_heist")
	WispEffects.flourish(source,global_position,2)
	CombatEffect.pulse(get_parent(),global_position,Color("9c42dc"),t.heist_radius)
	source.presentation.impact_sound.play_tone(110,.25,.2)
	source.resolver.record("detonation",source,"grand_heist")
	queue_free()
