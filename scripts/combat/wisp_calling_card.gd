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
	remaining = maxf(0,remaining-delta)
	tone_left -= delta
	if tone_left <= 0:
		tone_left = lerpf(.08,.25,remaining/data().heist_warning)
		source.presentation.sound.play_tone(lerpf(1200,500,remaining/data().heist_warning),.045,.09)
	warning_ring.scale = Vector3.ONE*(1+.025*sin(remaining*40))
	if remaining <= .000001: detonate()

func multiplier(distance: float) -> float:
	return lerpf(1.0,data().heist_minimum,clampf((distance-data().heist_full_radius)/(data().heist_radius-data().heist_full_radius),0,1))

func detonate() -> void:
	if detonated or is_queued_for_deletion() or not valid_source(): return
	detonated = true
	var t := data()
	var victims: Array[Dictionary] = []
	var objects: Array[Dictionary] = []
	if not source.resolver.attack_locked(source):
		# All cover is snapshotted before any structure or barrier takes damage.
		for target: HeroActor in get_tree().get_nodes_in_group("actors"):
			if not target.alive or target.team == source.team or target.damage_immune() or source.resolver.protected_room(target): continue
			var at: Vector3 = target.body_point(.9)
			var distance: float = global_position.distance_to(at)
			if distance <= t.heist_radius and source.resolver.attack_ray(source,global_position,at,[],1).is_empty():
				victims.append({"actor":target,"damage":(t.heist_damage+target.statuses.soul_count(source)*t.mark_damage)*multiplier(distance)})
		for barrier: CombatBarrier in get_tree().get_nodes_in_group("barriers"):
			if not barrier.active() or barrier.source.team == source.team: continue
			var at: Vector3 = barrier.nearest_point(global_position)
			var hit: Dictionary = source.resolver.attack_ray(source,global_position,at,[],1)
			if global_position.distance_to(at) <= t.heist_radius and (hit.is_empty() or hit.get("collider") == barrier):
				objects.append({"object":barrier,"damage":t.heist_damage*multiplier(global_position.distance_to(at))})
		for structure: CombatStructure in get_tree().get_nodes_in_group("structures"):
			var at: Vector3 = structure.nearest_point(global_position)
			var hit: Dictionary = source.resolver.attack_ray(source,global_position,at,[],1)
			if global_position.distance_to(at) <= t.heist_radius and (hit.is_empty() or hit.get("collider") == structure):
				objects.append({"object":structure,"damage":t.heist_damage*multiplier(global_position.distance_to(at))})
		for victim: Dictionary in victims:
			var target: HeroActor = victim.actor
			var result: String = source.resolver.damage(source,target,victim.damage,"grand_heist",cast_id,false,false,global_position)
			if result == "hit": target.statuses.take_souls(source)
		for object: Dictionary in objects: source.resolver.hit_object(object.object,source,object.damage,cast_id)
	WispEffects.flourish(source,global_position,2)
	CombatEffect.pulse(get_parent(),global_position,Color("9c42dc"),t.heist_radius)
	source.presentation.impact_sound.play_tone(110,.25,.2)
	source.resolver.record("detonation",source,"grand_heist")
	queue_free()
