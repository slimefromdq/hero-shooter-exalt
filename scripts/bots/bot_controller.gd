class_name BotController
extends Node

enum Profile { STATIONARY, STRAFE, RANGED, BRAWLER, SPARRING, GUARD_TRAINER }
var actor: HeroActor
var target: HeroActor
var profile: int = Profile.RANGED
var reaction_delay: float = 0.38
var error_chance: float = 0.15
var aggression: float = 1.0
var frozen: bool = false
var time: float = 0.0
var think_timer: float = 0.0
var action_timer: float = 0.8
var counter_timer: float = -1.0
var remembered_aim: Vector3 = Vector3.FORWARD
var home: Vector3
var stuck_timer: float = 0.0
var previous_position: Vector3
var side: float = 1.0
var guard_trigger_range: float = 2.4
var guard_attack_interval: float = 1.6
var guard_reaction_time: float = 0.0
var guard_range_ring: MeshInstance3D
var guard_range_label: Label3D

func _ready() -> void:
	home = actor.global_position
	previous_position = home
	side = 1.0 if actor.get_instance_id() % 2 == 0 else -1.0
	if profile == Profile.GUARD_TRAINER:
		action_timer = 0.0
		var shape := ImmediateMesh.new()
		var mat: StandardMaterial3D = Geometry.material(Color("f4947e"))
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shape.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
		for index: int in 97:
			var angle: float = TAU * index / 96.0
			shape.surface_add_vertex(Vector3(cos(angle),0,sin(angle)))
		shape.surface_end()
		guard_range_ring = Geometry.mesh(actor,shape,Vector3(0,.035,0),mat)
		guard_range_label = Geometry.text3d(actor,"",Vector3(0,3.2,0),28,Color("ffe0bd"))
		guard_range_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _process(_delta: float) -> void:
	if profile == Profile.GUARD_TRAINER and is_instance_valid(guard_range_ring):
		var reach: float = minf(guard_trigger_range,actor.tuning.melee_range)
		guard_range_ring.visible = actor.alive
		guard_range_label.visible = actor.alive
		guard_range_ring.scale = Vector3(reach,1,reach)
		guard_range_label.text = "GUARD DRILL  /  %.1f m\nHOLD %s TO BLOCK" % [reach,TrainingInputs.key_label("guard")]

func gather_intent(delta: float) -> CombatIntent:
	var input := CombatIntent.new()
	input.aim = remembered_aim
	input.aim_origin = actor.global_position + Vector3.UP * 1.5
	if frozen or not is_instance_valid(target) or not target.alive or not actor.alive:
		return input
	time += delta
	think_timer -= delta
	action_timer -= delta
	var offset: Vector3 = target.global_position - actor.global_position
	var distance: float = offset.length()
	var sees: bool = actor.resolver.visible(input.aim_origin, target, [actor.get_rid()])
	if think_timer <= 0.0:
		think_timer = reaction_delay
		if sees:
			remembered_aim = (target.global_position + Vector3.UP * 1.2 - input.aim_origin + Vector3(randf_range(-0.2, 0.2), 0.0, 0)).normalized()
	input.aim = remembered_aim
	if actor.kit is CareKit and profile in [7,8,9]:
		if distance > 7: input.move = path_direction(offset)
		CareTactics.apply(actor,input)
		return input
	if actor.kit is SlayerKit and profile == 6:
		var hunter := actor.kit as SlayerKit
		if distance > 6.0: input.move = path_direction(offset)
		elif distance < 3.0: input.move = -offset.normalized()
		if not sees:
			input.move = (input.move + Vector3(offset.z,0,-offset.x).normalized() * side * .7).limit_length(1.0)
		if sees and action_timer <= 0.0:
			input.primary = distance < 21.0
			input.reload = hunter.ammo == 0
			input.hover = distance > 9.0 and hunter.knives > 0
			input.deflect = distance > 4.0 and distance < 13.0 and hunter.deflect_cd <= 0
			input.bomb = distance < 12.0 and hunter.snares > 0 and int(time) % 5 == 0
			input.ultimate = distance < 12.0 and hunter.ultimate_charge >= 100.0
			action_timer = .5 + reaction_delay
		return input
	if profile == Profile.STATIONARY:
		return input
	if profile == Profile.STRAFE:
		var destination: Vector3 = home + Vector3(sin(time * 0.65) * 4.0, 0, 0)
		input.move = (destination - actor.global_position).limit_length(1.0)
		return input
	if profile == Profile.GUARD_TRAINER:
		input.stationary_melee = true
		var reach: float = minf(guard_trigger_range,actor.tuning.melee_range)
		if sees and distance <= reach and actor.permits("melee"):
			guard_reaction_time += delta
			if guard_reaction_time >= reaction_delay and action_timer <= 0.0:
				input.melee = true
				guard_reaction_time = 0.0
				var commitment: float = actor.tuning.melee_windup + actor.tuning.melee_active + actor.tuning.melee_recovery
				action_timer = maxf(guard_attack_interval,commitment + .15)
		else:
			guard_reaction_time = 0.0
		return input
	if profile == Profile.SPARRING and actor.close.incoming_throw() != null:
		if counter_timer < 0.0:
			counter_timer = reaction_delay
		counter_timer -= delta
		if counter_timer <= 0.0:
			input.throw_action = randf() > error_chance
			counter_timer = -1.0
	else:
		counter_timer = -1.0
	if profile == Profile.RANGED:
		if distance < 8.0:
			input.move = -offset.normalized()
		elif distance > 18.0 or not sees:
			input.move = path_direction(offset)
		else:
			input.move = Vector3(offset.z, 0.0, -offset.x).normalized() * sin(time * 0.7) * 0.45
		if sees and action_timer <= 0.0:
			input.projectile_fire = true
			action_timer = maxf(0.25, 1.3 / aggression)
	else:
		if distance > (1.4 if profile == Profile.SPARRING else 2.1):
			input.move = path_direction(offset)
		if sees and action_timer <= 0.0:
			if profile == Profile.SPARRING:
				var phase: int = int(time / 2.4) % 3
				if phase == 0:
					input.guard = true
				elif phase == 1 and distance < actor.tuning.throw_range:
					input.throw_action = true
				else:
					input.melee = distance < actor.tuning.melee_range
			else:
				input.melee = distance < actor.tuning.melee_range
			action_timer = reaction_delay + 0.8 / aggression
		if profile == Profile.SPARRING and int(time / 2.4) % 3 == 0:
			input.guard = true
			input.move *= 0.1
	if actor.global_position.distance_to(previous_position) < 0.01 and input.move.length() > 0.5:
		stuck_timer += delta
	else:
		stuck_timer = maxf(0.0, stuck_timer - delta * 2.0)
	if stuck_timer > 0.6:
		input.move = Vector3(offset.z, 0, -offset.x).normalized() * side
	if stuck_timer > 1.4:
		input.jump = true
		stuck_timer = 0.0
		side *= -1.0
	previous_position = actor.global_position
	return input

func path_direction(offset: Vector3) -> Vector3:
	var forward := Vector3(offset.x, 0, offset.z).normalized()
	var origin: Vector3 = actor.global_position + Vector3.UP * 0.8
	var hit: Dictionary = actor.resolver.ray(origin, origin + forward * 2.0, [actor.get_rid()], 1)
	if not hit.is_empty():
		var tangent := Vector3(forward.z, 0, -forward.x) * side
		return (tangent + forward * 0.15).normalized()
	return forward

func reset_controller() -> void:
	time = 0.0
	think_timer = reaction_delay
	action_timer = 0.0 if profile == Profile.GUARD_TRAINER else 0.8
	counter_timer = -1.0
	stuck_timer = 0.0
	guard_reaction_time = 0.0
