class_name CombatProjectile
extends Node3D

var source: HeroActor
var direction: Vector3 = Vector3.FORWARD
var speed: float = 17.0
var damage_amount: float = 24.0
var cast_id: int = 0
var lifetime: float = 5.0
var max_distance: float = INF
var traveled: float = 0.0
var color: Color = Color("ff765e")
var reflections: int = 0
var reflected_events: Dictionary = {}
var headshots: bool = false
var head_multiplier: float = 1.0
var blast_radius: float = 0.0
var confirmed_impact: Callable
var needle_trail: bool = false
var trail_clock: float = 0.0

func _ready() -> void:
	add_to_group("owned_attacks")
	add_to_group("transient")
	var ball := SphereMesh.new()
	ball.radius = 0.1
	ball.height = 0.2
	if needle_trail:
		Geometry.box(self,Vector3(.025,.025,.45),Vector3.ZERO,color,false)
		if not direction.is_zero_approx(): look_at_from_position(position,position+direction,Vector3.RIGHT if absf(direction.y) > .99 else Vector3.UP)
	else: Geometry.mesh(self, ball, Vector3.ZERO, Geometry.material(color, 1.5))

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	lifetime -= delta
	if lifetime <= 0.0 or traveled >= max_distance or not is_instance_valid(source) or not source.alive:
		if blast_radius > 0 and is_instance_valid(source) and source.alive: explode(global_position)
		queue_free()
		return
	var distance: float = minf(speed*delta,max_distance-traveled)
	traveled += distance
	var next: Vector3 = global_position + direction * distance
	trail_clock += delta
	if trail_clock >= .04:
		trail_clock = 0
		if get_tree().get_nodes_in_group("knife_trails").size() < 96:
			CombatEffect.streak(get_parent(),global_position-direction*.4,global_position,.012,.07)
	var hit: Dictionary = source.resolver.attack_ray(source, global_position, next, [source.get_rid()])
	if hit.is_empty():
		global_position = next
		return
	var target: HeroActor = hit.get("collider") as HeroActor
	if blast_radius > 0:
		explode(hit.position+hit.normal*.04)
		queue_free()
		return
	if target != null:
		var head: bool = headshots and hit.position.y-target.global_position.y >= target.headshot_height()
		var result: String = source.resolver.damage(source, target, damage_amount*(head_multiplier if head else 1.0), "projectile", cast_id, head, false, global_position)
		if result == "hit" and confirmed_impact.is_valid(): confirmed_impact.call(source,target)
		if result == "deflect":
			var event_key: String = "%d:%d" % [target.get_instance_id(), target.kit.cast_id]
			if reflections < 2 and not reflected_events.has(event_key):
				reflected_events[event_key] = true
				reflections += 1
				source = target
				confirmed_impact = Callable()
				direction = target.aim_direction
				cast_id = target.resolver.new_cast(target)
				global_position = hit["position"] + direction * 0.25
				return
	CombatEffect.pulse(get_parent(), hit["position"], Color("ffae81"), 0.28)
	if hit.get("collider") is CombatBarrier:
		hit.collider.receive_damage(source,damage_amount,cast_id)
	if hit.get("collider") is HunterSnare or hit.get("collider") is CombatStructure:
		source.resolver.hit_object(hit.collider,source,damage_amount,cast_id)
	queue_free()

func explode(at: Vector3) -> void:
	source.resolver.splash(source,at,blast_radius,damage_amount,"spectral_finale",cast_id,true)
	CombatEffect.pulse(get_parent(),at,color,blast_radius)
