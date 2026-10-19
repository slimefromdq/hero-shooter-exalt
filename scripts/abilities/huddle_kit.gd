class_name HuddleKit
extends CareKit
## The colony has one body and one health pool throughout all transformations.
var scatter_charges: int = 2
var scatter_timer: float = 0.0
var scatter_left: float = 0.0
var travel_direction: Vector3 = Vector3.FORWARD
var regroup_cd: float = 0.0
var regroup_age: float = 0.0
var regroup_spent: bool = false
var regroup_latched: bool = false
var screen: HuddleScreen
var wave_left: float = 0.0
var wave_cast: int = 0
var wave_hits: Dictionary = {}

func data() -> HuddleTuning:
	return actor.tuning as HuddleTuning

func _ready() -> void:
	refill()

func tick(delta: float, input: CombatIntent) -> void:
	tick_common(delta)
	var t := data()
	regroup_cd = maxf(0,regroup_cd-delta)
	if not input.secondary_held: regroup_latched = false
	if scatter_charges < t.scatter_charges:
		scatter_timer -= delta
		while scatter_timer <= 0 and scatter_charges < t.scatter_charges:
			scatter_charges += 1
			if scatter_charges < t.scatter_charges: scatter_timer += t.scatter_recharge
			else: scatter_timer = 0
	mobility_cd = scatter_timer if scatter_charges == 0 else 0.0
	if actor.infinite_resources:
		scatter_charges = t.scatter_charges
		scatter_timer = 0
		regroup_cd = 0
	var interrupt_heal: bool = input.primary or input.primary_held or input.reload or input.hover or input.deflect or input.bomb or input.ultimate or input.dash or input.melee or input.throw_action or input.guard
	if actor.state == "huddle_regroup":
		if not input.secondary_held or interrupt_heal or actor.resolver.attack_locked(actor):
			actor.state = "ready"
		else:
			var previous: float = regroup_age
			regroup_age += delta
			var active: float = maxf(0,minf(regroup_age-t.regroup_preparation,t.regroup_duration)) - maxf(0,minf(previous-t.regroup_preparation,t.regroup_duration))
			if active > 0:
				var restored: float = actor.resolver.heal(actor,actor,t.regroup_rate*active,"regroup",false)
				if restored > 0 and not regroup_spent:
					regroup_spent = true
					regroup_cd = t.regroup_cooldown
			if regroup_age >= t.regroup_preparation+t.regroup_duration or actor.health >= actor.effective_max_health(): actor.state = "ready"
	if actor.state in ["huddle_scatter","huddle_wave","huddle_wave_start"] and actor.statuses.movement_disabled(): cancel()
	if actor.state == "huddle_pulse" and actor.state_time <= 0:
		pulse()
		actor.state = "ready"
	if actor.state == "huddle_wave_start" and actor.state_time <= 0:
		if supported(actor.global_position):
			ultimate_charge = 0
			actor.state = "huddle_wave"
			wave_left = t.wave_duration
			wave_cast = actor.resolver.new_cast(actor)
			wave_hits.clear()
			actor.presentation.sound.play_tone(135,.5,.22)
		else: actor.state = "ready"
	if input.hover and scatter_charges > 0 and actor.permits("scatter"):
		start_scatter()
	if input.deflect and deflect_cd <= 0 and actor.permits("screen"):
		cast_screen()
	if input.bomb and bomb_cd <= 0 and actor.permits("bomb"):
		actor.state = "huddle_pulse"
		actor.state_time = t.pulse_preparation
		bomb_cd = t.pulse_cooldown
		actor.resolver.record("cast",actor,"personal_space")
	if input.ultimate and ultimate_charge >= 100 and actor.permits("wave") and supported(actor.global_position):
		actor.motor.interrupt_mobility()
		travel_direction = Vector3(actor.aim_direction.x,0,actor.aim_direction.z).normalized()
		if travel_direction.is_zero_approx(): travel_direction = -actor.global_basis.z
		actor.state = "huddle_wave_start"
		actor.state_time = t.wave_preparation
		actor.presentation.sound.play_tone(780,t.wave_preparation,.2)
		actor.resolver.record("cast",actor,"nobody_gets_squished")
	if input.secondary_held and not interrupt_heal and not regroup_latched and regroup_cd <= 0 and actor.health < actor.effective_max_health() and actor.permits("regroup"):
		actor.state = "huddle_regroup"
		regroup_age = 0
		regroup_spent = false
		regroup_latched = true
		actor.presentation.sound.play_tone(610,.18,.12)
	if input.primary or input.primary_held: fire()
	if input.reload: reload_weapon()

func start_scatter() -> void:
	var t := data()
	actor.motor.interrupt_mobility()
	travel_direction = actor.aim_direction.normalized()
	if travel_direction.is_zero_approx(): travel_direction = Vector3.FORWARD
	if scatter_charges == t.scatter_charges: scatter_timer = t.scatter_recharge
	scatter_charges -= 1
	scatter_left = t.scatter_distance
	actor.state = "huddle_scatter"
	actor.presentation.sound.play_tone(430,.14,.16)
	actor.resolver.record("cast",actor,"scatterbound")

func cast_screen() -> void:
	var recipient: HeroActor = actor
	var score: float = cos(deg_to_rad(12))
	var origin: Vector3 = actor.intent.aim_origin
	if origin == Vector3.ZERO: origin = actor.body_point(1.4)
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if other == actor or not other.alive or other.team != actor.team or actor.resolver.protected_room(other): continue
		if actor.global_position.distance_to(other.global_position) > data().screen_range: continue
		if not actor.resolver.attack_ray(actor,actor.global_position+Vector3.UP*1.4,other.global_position+Vector3.UP*1.2,[],1).is_empty(): continue
		var dot: float = (other.global_position+Vector3.UP*1.2-origin).normalized().dot(actor.aim_direction)
		if dot > score:
			score = dot
			recipient = other
	if is_instance_valid(screen): screen.retire()
	screen = HuddleScreen.new()
	screen.source = actor
	screen.recipient = recipient
	screen.health = data().screen_health
	screen.remaining = data().screen_duration
	add_child(screen)
	deflect_cd = data().screen_cooldown
	actor.resolver.record("cast",actor,"weve_got_you","target="+recipient.actor_id)

func pulse() -> void:
	var id: int = actor.resolver.new_cast(actor)
	var origin: Vector3 = actor.global_position+Vector3.UP
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if not other.alive or other.team == actor.team or actor.global_position.distance_to(other.global_position) > data().pulse_radius: continue
		if not actor.resolver.visible(origin,other,[actor.get_rid()]): continue
		actor.resolver.damage(actor,other,data().pulse_damage,"wingbeat",id,false,false,origin)
		var direction: Vector3 = other.global_position-actor.global_position
		direction.y = 0
		actor.resolver.knockback(actor,other,direction.normalized()*data().pulse_push,"wingbeat")
	CombatEffect.pulse(actor.get_parent(),origin,Color("ffe887"),data().pulse_radius)
	actor.presentation.sound.play_tone(210,.22,.22)

func fire(_ultimate: bool = false) -> void:
	if not actor.permits("primary") or shot_cd > 0: return
	if ammo <= 0:
		reload_weapon()
		return
	consume_ammo()
	shot_cd = primary_interval()
	var muzzle: Vector3 = safe_muzzle()
	var origin: Vector3 = actor.intent.aim_origin
	if origin == Vector3.ZERO: origin = actor.global_position+Vector3.UP*1.4
	var view: Dictionary = actor.resolver.ray(origin,origin+actor.aim_direction*data().seed_range,[actor.get_rid()])
	var direction: Vector3 = (view.get("position",origin+actor.aim_direction*data().seed_range)-muzzle).normalized()
	var right: Vector3 = direction.cross(Vector3.UP).normalized()
	if right.is_zero_approx(): right = Vector3.RIGHT
	var up: Vector3 = right.cross(direction)
	for i: int in data().seed_count:
		var radius: float = sqrt((i+.5)/data().seed_count)*tan(deg_to_rad(data().seed_spread))
		var angle: float = i*2.39996323
		var seed := CombatProjectile.new()
		seed.source = actor
		seed.direction = (direction+(right*cos(angle)+up*sin(angle))*radius).normalized()
		seed.speed = data().seed_speed
		seed.damage_amount = data().seed_damage
		seed.max_distance = data().seed_range
		seed.color = Color("e8c36b")
		seed.cast_id = actor.resolver.new_cast(actor)
		actor.get_parent().add_child(seed)
		seed.global_position = muzzle
	actor.presentation.fire_flash = .14
	actor.presentation.sound.play_tone(340,.07,.12)
	actor.resolver.record("cast",actor,"seed_spitter")

func movement_scale() -> float:
	return data().regroup_movement if actor.state == "huddle_regroup" else 1.0

func supported(at: Vector3) -> bool:
	var hit: Dictionary = actor.resolver.ray(at+Vector3.UP*.3,at-Vector3.UP*.55,[actor.get_rid()],1)
	return not hit.is_empty() and hit.normal.y >= cos(actor.floor_max_angle)

func move_override(delta: float) -> bool:
	if actor.state == "huddle_scatter":
		var distance: float = minf(scatter_left,data().scatter_speed*delta)
		var collision: KinematicCollision3D = actor.move_and_collide(travel_direction*distance)
		scatter_left -= distance
		actor.velocity = travel_direction*data().scatter_speed
		if collision != null or scatter_left <= .0001:
			actor.state = "ready"
			if collision != null: actor.velocity = actor.velocity.slide(collision.get_normal())
		return true
	if actor.state != "huddle_wave": return false
	var t := data()
	var slice: float = minf(delta,wave_left)
	var wish: Vector3 = Vector3(actor.intent.move.x,0,actor.intent.move.z).normalized()
	if not wish.is_zero_approx() and wish.dot(travel_direction) > -.95:
		var angle: float = travel_direction.signed_angle_to(wish,Vector3.UP)
		travel_direction = travel_direction.rotated(Vector3.UP,clampf(angle,-deg_to_rad(t.wave_turn_degrees)*slice,deg_to_rad(t.wave_turn_degrees)*slice))
	var start: Vector3 = actor.global_position
	if not supported(start):
		actor.state = "ready"
		return false
	actor.velocity = travel_direction*t.wave_speed+Vector3.DOWN*actor.tuning.gravity*slice
	actor.move_and_slide()
	actor.apply_floor_snap()
	wave_contacts(start,actor.global_position,slice)
	wave_left = maxf(0,wave_left-slice)
	var blocked: bool = false
	for i: int in actor.get_slide_collision_count():
		var collision: KinematicCollision3D = actor.get_slide_collision(i)
		if collision.get_collider() is HeroActor: continue
		if collision.get_normal().y < cos(actor.floor_max_angle) and collision.get_normal().dot(travel_direction) < -.2: blocked = true
	if wave_left <= .00001 or blocked or not supported(actor.global_position): actor.state = "ready"
	return true

func wave_contacts(from: Vector3, to: Vector3, _delta: float) -> void:
	var right: Vector3 = travel_direction.cross(Vector3.UP).normalized()
	for other: HeroActor in actor.get_tree().get_nodes_in_group("actors"):
		if not other.alive or other.team == actor.team: continue
		var nearest: Vector3 = Geometry3D.get_closest_point_to_segment(other.global_position,from,to)
		var offset: Vector3 = other.global_position-nearest
		if absf(offset.dot(right)) > data().wave_width/2+.38 or absf(offset.dot(travel_direction)) > .85 or offset.y > data().wave_height or offset.y < -1.0: continue
		var origin: Vector3 = nearest+Vector3.UP
		if not actor.resolver.visible(origin,other,[actor.get_rid()]): continue
		var key: int = other.get_instance_id()
		if not wave_hits.has(key):
			wave_hits[key] = true
			var damage_origin: Vector3 = origin-travel_direction*2.0
			var hit: Dictionary = actor.resolver.attack_ray(actor,damage_origin,other.global_position+Vector3.UP,[],1)
			if hit.get("collider") is CombatBarrier: hit.collider.receive_damage(actor,data().wave_damage,wave_cast)
			elif hit.is_empty(): actor.resolver.damage(actor,other,data().wave_damage,"bug_wave",wave_cast,false,false,origin)
		# Replace this wave's contribution rather than adding another 12 m/s each frame.
		var current: float = other.motor.external_velocity.dot(travel_direction)
		actor.resolver.knockback(actor,other,travel_direction*maxf(0,data().wave_push-current),"bug_wave")

func cancel(clear_owned: bool = false) -> void:
	if actor.state.begins_with("huddle_"): actor.state = "ready"
	scatter_left = 0
	wave_left = 0
	if clear_owned and is_instance_valid(screen): screen.retire()
	super.cancel(clear_owned)

func refill() -> void:
	super.refill()
	scatter_charges = data().scatter_charges
	scatter_timer = 0
	regroup_cd = 0
	regroup_age = 0
	regroup_latched = false
