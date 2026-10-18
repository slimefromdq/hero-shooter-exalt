class_name SlayerAbilityPresentation
extends SlayerShotPresentation
## Ability-only presentation consumes state/results; never owns damage or movement.
const ENERGY = preload("res://scenes/effects/slayer_ability_energy.tscn")
var crimson: SlayerRibbon
var silver: SlayerRibbon
var previous_state: String = ""
var emission_clock: float = 0.0
var wind_voice: bool = false
var last_impact_category: String = ""
var wound_targets: Array[WeakRef] = []
var wound_clock: float = 0.0

func _ready() -> void:
	super._ready()
	crimson = SlayerRibbon.new()
	add_child(crimson)
	crimson.width = .10
	crimson.lifetime = .22
	crimson.material.albedo_color = Color("c63865")
	silver = SlayerRibbon.new()
	add_child(silver)
	silver.width = .025
	silver.material.albedo_color = Color("d2e7ff")

func burst(at: Vector3, forward: Vector3, colour: Color, size: float = 1.0) -> void:
	for index: int in range(effects.size()-1,-1,-1):
		if not is_instance_valid(effects[index]) or effects[index].get_parent() != self: effects.remove_at(index)
	while effects.size() >= 12: effect_pool.recycle(effects.pop_front())
	if get_tree().get_nodes_in_group("slayer_bursts").size() >= MAX_WORLD_BURSTS: return
	var effect: SlayerBurstEffect = effect_pool.acquire_ability()
	if effect == null: return
	effect.reparent(self,false)
	effect.top_level = true
	effect.global_position = at
	if not forward.is_zero_approx(): effect.look_at(at + forward,Vector3.RIGHT if absf(forward.normalized().dot(Vector3.UP)) > .99 else Vector3.UP)
	effect.scale = Vector3.ONE * size
	effect.tint(colour)
	effect.activate()
	effects.append(effect)

func begin_boot() -> void:
	crimson.clear()
	silver.clear()
	burst(presentation.actor.body_point(.48),presentation.actor.aim_direction,Color("ec769f"),.7)
	emission_clock = 0.0

func boot_path(before: Vector3, after: Vector3) -> void:
	crimson.sample(before + Vector3.UP * .55)
	crimson.sample(after + Vector3.UP * .55)
	silver.sample(after + Vector3.UP * .65 + presentation.actor.global_basis.x * .14)

func stop_wind() -> void:
	if is_instance_valid(presentation.sound): presentation.sound.stop_slayer_cue("boot_wind")
	wind_voice = false

func camera_contact() -> void:
	if presentation.actor.controller is PlayerController:
		feedback_camera = (presentation.actor.controller as PlayerController).camera
		shot_age = 0.0

func boot_contact(target: HeroActor) -> void:
	stop_wind()
	burst(target.body_point(1.0),-presentation.actor.aim_direction,Color("ffc4d4"),1.4)
	camera_contact()

func boot_kick(target: HeroActor, forward: Vector3) -> void:
	burst(target.body_point(.9),forward,Color("d5efff"),1.1)
	presentation.sound.play_slayer("boot_kick")

func boot_miss() -> void:
	stop_wind()
	burst(presentation.actor.body_point(.25),Vector3.UP,Color("a899ac"),.45)
	presentation.sound.play_slayer("boot_recover")

func wound(target: HeroActor) -> void:
	for entry: WeakRef in wound_targets:
		if entry.get_ref() == target: return
	wound_targets.append(weakref(target))
	burst(target.body_point(1.1),Vector3.UP,Color("c68bff"),.65)

func projectile_impact(kind: String, at: Vector3, normal: Vector3, category: String) -> void:
	last_impact_category = category
	var colour: Color = Color("fa819e") if category == "flesh" else Color("d9f4ff")
	if category in ["shield","barrier","deflect"]: colour = Color("77dfff")
	if category == "barrier": colour = Color("bfa0ff")
	if category == "deflect": colour = Color("7de8c7")
	if category == "world": colour = Color("e1c6a2")
	burst(at,normal,colour,.6 if kind == "knife" else 1.8)
	presentation.sound.play_slayer(kind + "_" + ("hit" if category == "flesh" else category))

func _process(delta: float) -> void:
	super._process(delta)
	var actor: HeroActor = presentation.actor
	var state: String = actor.state
	if state != previous_state:
		if state == "slayer_boot_active":
			presentation.sound.play_slayer("boot_wind")
			wind_voice = true
		elif wind_voice: stop_wind()
		if state == "slayer_axe_windup":
			burst(actor.body_point(1.8),Vector3.UP,Color("d098ff"),1.1)
		if previous_state == "slayer_axe_windup" and state != "slayer_axe_release" and state != "slayer_axe_windup":
			presentation.sound.stop_slayer_cue("axe_draw")
		previous_state = state
	emission_clock -= delta
	if emission_clock <= 0:
		if state == "slayer_boot_active":
			burst(actor.body_point(.15 if actor.is_on_floor() else .7),-actor.aim_direction,Color("cf6a91"),.38)
		elif state == "slayer_axe_windup":
			burst(actor.body_point(1.5),Vector3.UP,Color("c996ff"),.38)
		emission_clock = .10
	wound_clock -= delta
	for index: int in range(wound_targets.size()-1,-1,-1):
		var target: HeroActor = wound_targets[index].get_ref() as HeroActor
		if not is_instance_valid(target) or not target.alive or not target.statuses.effects.has("max_health"):
			wound_targets.remove_at(index)
		elif wound_clock <= 0: burst(target.body_point(1.15),Vector3.UP,Color("9a72ba"),.28)
	if wound_clock <= 0: wound_clock = 1.0

func interrupt() -> void:
	clear()
	if is_instance_valid(presentation.sound): presentation.sound.stop_slayer_cue("axe_draw")

func clear() -> void:
	clear_camera()
	stop_wind()
	shot_age = 99.0
	if is_instance_valid(crimson): crimson.clear()
	if is_instance_valid(silver): silver.clear()
	for effect: Node3D in effects:
		if is_instance_valid(effect) and effect.get_parent() == self: effect_pool.recycle(effect)
	effects.clear()
	wound_targets.clear()
	previous_state = ""
