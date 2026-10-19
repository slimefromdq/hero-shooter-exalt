class_name DynamoKit
extends ExpansionKit
var spin: float = 0.0
var spinning: bool = false
var charge_left: float = 0.0
var arc_cd: float = 0.0
var wall: DynamoWall
var preview: Node3D
var previewing: bool = false
var wall_at: Vector3
var wall_yaw: float = 0.0
var wall_turn: float = 0.0
var wall_valid: bool = false
var preview_age: float = 0.0
var storm_field: DynamoField
var storm_at: Vector3
var storm_warning: Node3D

func data() -> DynamoTuning:
	return actor.tuning as DynamoTuning

func _ready() -> void:
	refill()

func ultimate_active() -> bool:
	return is_instance_valid(storm_field) and not storm_field.is_queued_for_deletion() and storm_field.remaining > 0

func tick(delta: float, input: CombatIntent) -> void:
	tick_common(delta)
	var t := data()
	charge_left = maxf(0,charge_left-delta)
	arc_cd = maxf(0,arc_cd-delta)
	spinning = not reloading and can_act("primary") and (input.primary_held or input.secondary_held)
	spin = clampf(spin+delta/(t.spin_time if spinning else -t.spin_decay),0,1)
	if reloading: spin = 0
	if actor.state == "dynamo_storm_start" and actor.state_time <= 0:
		actor.state = "ready"
		ultimate_charge = 0
		if is_instance_valid(storm_warning): storm_warning.queue_free()
		storm_warning = null
		storm_field = DynamoField.new()
		storm_field.source = actor
		storm_field.storm = true
		actor.get_parent().add_child(storm_field)
		storm_field.global_position = storm_at
		actor.presentation.sound.play_tone(80,.5,.25)
	elif actor.state != "dynamo_storm_start" and is_instance_valid(storm_warning):
		storm_warning.queue_free()
		storm_warning = null
	if previewing:
		preview_age += delta
		if actor.state != "ready" or input.deflect or preview_age > 3.0:
			end_preview()
			return
		if input.secondary_pressed: wall_turn += PI/2
		update_preview()
		if input.primary and wall_valid: place_wall()
		return
	if input.deflect and can_act("wall"):
		if is_instance_valid(wall):
			wall.queue_free()
			wall = null
		elif deflect_cd <= 0:
			previewing = true
			preview_age = 0
			wall_turn = 0
			preview = RosterEffects.wall_preview(actor.get_parent(),t)
			update_preview()
		return
	if input.hover and mobility_cd <= 0 and can_act("bomb"):
		charge_left = t.charge_duration
		mobility_cd = t.charge_cooldown
		actor.resolver.record("cast",actor,"stormcharge")
	if input.bomb and bomb_cd <= 0 and can_act("bomb"):
		var hit: Dictionary = aimed_ground(t.stone_range)
		if not hit.is_empty():
			var field := DynamoField.new()
			field.source = actor
			actor.get_parent().add_child(field)
			field.global_position = hit.position
			bomb_cd = t.stone_cooldown
			actor.resolver.record("cast",actor,"lodestone")
	if input.ultimate and ultimate_charge >= 100 and not ultimate_active() and can_act("ultimate"):
		var hit: Dictionary = aimed_ground(t.storm_range)
		if not hit.is_empty():
			storm_at = hit.position
			storm_warning = RosterEffects.zone(actor.get_parent(),storm_at,t.storm_radius,Color("ffd698"))
			actor.state = "dynamo_storm_start"
			actor.state_time = t.storm_warning
			actor.resolver.record("cast",actor,"storm_dominion")
	if input.primary or input.primary_held: fire()
	if input.reload:
		start_reload()
		if reloading: spin = 0

func update_preview() -> void:
	var hit: Dictionary = aimed_ground(data().wall_range)
	wall_valid = false
	if hit.is_empty():
		preview.visible = false
		return
	preview.visible = true
	wall_at = hit.position
	wall_yaw = actor.rotation.y+wall_turn
	wall_valid = DynamoWall.placement_clear(actor,wall_at,wall_yaw)
	preview.global_position = wall_at+Vector3.UP*data().wall_height/2
	preview.rotation.y = wall_yaw
	var mat := (preview.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
	mat.albedo_color = Color(.25,.95,.75,.25) if wall_valid else Color(1,.25,.25,.25)

func place_wall() -> bool:
	if not wall_valid or not DynamoWall.placement_clear(actor,wall_at,wall_yaw): return false
	wall = DynamoWall.new()
	wall.source = actor
	actor.get_parent().add_child(wall)
	wall.build(wall_at,wall_yaw)
	deflect_cd = data().wall_cooldown
	end_preview()
	actor.resolver.record("cast",actor,"raise_the_line")
	return true

func end_preview() -> void:
	previewing = false
	if is_instance_valid(preview): preview.queue_free()
	preview = null

func fire(_ultimate: bool = false) -> void:
	if previewing or not can_act("primary") or shot_cd > 0: return
	if ammo <= 0:
		start_reload()
		return
	consume_ammo()
	shot_cd = primary_interval(1.0/lerpf(data().rate_low,data().rate_high,spin))+cadence_debt
	var direction: Vector3 = shot_direction(data().gun_range)
	var angle: float = (ammo%13)*2.39996323
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	var up: Vector3 = right.cross(direction)
	direction = (direction+(right*cos(angle)+up*sin(angle))*tan(deg_to_rad(data().gun_spread))).normalized()
	var hit: Dictionary = hitscan(direction,data().gun_range,actor.tuning.rifle_damage,"rifle")
	var target: HeroActor = hit.get("collider") as HeroActor
	if target != null and hit.get("result","") == "hit" and charge_left > 0 and arc_cd <= 0:
		arc(target)
	feedback(90+spin*45)
	actor.resolver.record("cast",actor,"minigun")

func arc(first: HeroActor) -> void:
	arc_cd = data().arc_interval
	var previous: HeroActor = first
	var visited: Array[HeroActor] = [first]
	for index: int in 2:
		var next: HeroActor
		var nearest: float = data().arc_range
		for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
			if other in visited or not other.alive or other.team == actor.team or other.invulnerable or other.state == "wisp_phase" or actor.resolver.protected_room(other): continue
			var distance: float = other.body_point(1).distance_to(previous.body_point(1))
			if distance > nearest or not actor.resolver.attack_ray(actor,previous.body_point(1),other.body_point(1),[],1).is_empty(): continue
			nearest = distance
			next = other
		if next == null: break
		actor.resolver.damage(actor,next,data().arc_first if index == 0 else data().arc_second,"lightning",actor.resolver.new_cast(actor),false,false,previous.body_point(1))
		CombatEffect.line(actor.get_parent(),previous.body_point(1),next.body_point(1),Color("b7e3ff"),.055)
		visited.append(next)
		previous = next

func movement_scale() -> float:
	return data().spun_movement if spinning else 1.0

func cancel(clear_owned: bool = false) -> void:
	end_preview()
	spin = 0
	spinning = false
	if is_instance_valid(storm_warning): storm_warning.queue_free()
	storm_warning = null
	if actor.state.begins_with("dynamo_"): actor.state = "ready"
	if clear_owned:
		charge_left = 0
		if is_instance_valid(wall): wall.queue_free()
		wall = null
		if is_instance_valid(storm_field): storm_field.queue_free()
		storm_field = null
	super.cancel(clear_owned)

func refill() -> void:
	super.refill()
	arc_cd = 0
