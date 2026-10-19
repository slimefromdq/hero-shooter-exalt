class_name ExpansionKit
extends CareKit
## Common aiming and presentation for the three roster additions.
var cadence_debt: float = 0.0

func tick_common(delta: float) -> void:
	# Retain the fractional firing interval instead of rounding 18 Hz down to 15 Hz.
	cadence_debt = minf(0,shot_cd-delta) if shot_cd > 0 else 0.0
	super.tick_common(delta)

func aim_origin() -> Vector3:
	return actor.intent.aim_origin if actor.intent.aim_origin != Vector3.ZERO else actor.body_point(1.4)

func shot_direction(reach: float) -> Vector3:
	var from: Vector3 = aim_origin()
	var hit: Dictionary = actor.resolver.ray(from,from+actor.aim_direction*reach,[actor.get_rid()])
	return (hit.get("position",from+actor.aim_direction*reach)-safe_muzzle()).normalized()

func aimed_ground(reach: float) -> Dictionary:
	var from: Vector3 = aim_origin()
	var hit: Dictionary = actor.resolver.ray(from,from+actor.aim_direction*reach,[actor.get_rid()],1)
	if hit.is_empty():
		var flat: Vector3 = actor.aim_direction*Vector3(1,0,1)
		var end: Vector3 = actor.global_position+flat.normalized()*reach
		hit = actor.resolver.ray(end+Vector3.UP*3,end-Vector3.UP*8,[],1)
	if hit.is_empty() or hit.normal.y < .85: return {}
	if actor.global_position.distance_to(hit.position) > reach+.5: return {}
	if not actor.resolver.ray(actor.body_point(1.4),hit.position+Vector3.UP*.15,[actor.get_rid()],1).is_empty(): return {}
	var city: Node = actor.get_tree().get_first_node_in_group("city_match")
	if city != null:
		for team: int in 2:
			if city.definition.spawn_bounds(team).has_point(hit.position): return {}
	return hit

func hitscan(direction: Vector3, reach: float, amount: float, tag: String, headshots: bool = true) -> Dictionary:
	var from: Vector3 = safe_muzzle()
	var hit: Dictionary = actor.resolver.attack_ray(actor,from,from+direction*reach,[actor.get_rid()])
	var endpoint: Vector3 = hit.get("position",from+direction*reach)
	var target: HeroActor = hit.get("collider") as HeroActor
	var id: int = actor.resolver.new_cast(actor)
	if target != null:
		var head: bool = headshots and endpoint.y-target.global_position.y >= target.headshot_height()
		hit["result"] = actor.resolver.damage(actor,target,amount*(actor.tuning.head_multiplier if head else 1.0),tag,id,head,false,from)
	else: actor.resolver.hit_object(hit.get("collider"),actor,amount,id)
	CombatEffect.line(actor.get_parent(),from,endpoint,Color("d7b3ff") if actor.tuning.hero_id == "wisp" else Color("ffcf78"))
	return hit

func launch(direction: Vector3, amount: float, speed: float, reach: float, tint: Color, explosive: float = 0.0, headshots: bool = false) -> void:
	var projectile := CombatProjectile.new()
	projectile.source = actor
	projectile.direction = direction
	projectile.speed = speed
	projectile.damage_amount = amount
	projectile.max_distance = reach
	projectile.color = tint
	projectile.headshots = headshots
	projectile.head_multiplier = actor.tuning.head_multiplier
	projectile.blast_radius = explosive
	projectile.cast_id = actor.resolver.new_cast(actor)
	actor.get_parent().add_child(projectile)
	projectile.global_position = safe_muzzle()

func feedback(tone: float = 400.0) -> void:
	actor.presentation.fire_flash = .09
	actor.presentation.sound.play_tone(tone,.065,.12)

func can_act(action: String = "bomb") -> bool:
	return actor.permits(action) and not actor.resolver.attack_locked(actor)

func refill() -> void:
	super.refill()
	cadence_debt = 0
