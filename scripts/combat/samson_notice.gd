class_name SamsonNotice
extends CombatStructure
## Shootable paper notice, traversable floor jurisdiction. Queries are live:
## no stale enter/exit cache and no interruption of already committed movement.
var age: float = 0.0
var owner_life: int
var remaining: float = 6.0

static func placement_clear(owner_actor: HeroActor, at: Vector3, yaw: float) -> bool:
	var t := owner_actor.tuning as SamsonTuning
	return SamsonCourt.ground_clear(owner_actor,at,yaw,Vector3(t.notice_width,0,t.notice_depth))

func _ready() -> void:
	var t := source.tuning as SamsonTuning
	owner_life = source.life_serial
	health = t.notice_health
	maximum = health
	size = t.notice_size
	position.y += size.y/2
	super._ready()
	collision_layer = 16
	collision_mask = 0
	add_to_group("owned_attacks")
	add_to_group("transient")
	add_to_group("movement_zones")
	remaining = t.notice_duration+t.notice_arm
	stone.material_override = Geometry.material(Color("e0c989"),.3)
	Geometry.text3d(self,"CEASE\n& DESIST",Vector3(0,.1,-.15),22,Color("183e39"))
	for side: float in [-1.0,1.0]:
		Geometry.box(self,Vector3(t.notice_width,.04,.08),Vector3(0,-size.y/2+.035,side*t.notice_depth/2),Color("ecbd6d"),false)
		Geometry.box(self,Vector3(.08,.04,t.notice_depth),Vector3(side*t.notice_width/2,-size.y/2+.035,0),Color("ecbd6d"),false)
	Geometry.text3d(self,"NO MOBILITY",Vector3(0,-size.y/2+.08,-t.notice_depth/2),23,Color("ffe49a"))

func active() -> bool:
	return not is_queued_for_deletion() and health > 0 and remaining > 0 and is_instance_valid(source) and source.alive and source.life_serial == owner_life and not source.resolver.attack_locked(source)

func hostile_contains(target: HeroActor) -> bool:
	if not active() or age < (source.tuning as SamsonTuning).notice_arm: return false
	if not target.alive or target.team == source.team or target.invulnerable or target.state == "wisp_phase" or source.resolver.protected_room(target): return false
	var t := source.tuning as SamsonTuning
	var at: Vector3 = to_local(target.global_position)+Vector3.UP*size.y/2
	if absf(at.x) > t.notice_width/2 or absf(at.z) > t.notice_depth/2 or absf(at.y) > t.notice_height: return false
	return not source.resolver.spawn_door_blocks(global_position,target.body_point(1)) and source.resolver.attack_ray(source,global_position,target.body_point(1),[get_rid()],1).is_empty()

func movement_multiplier() -> float:
	return 1.0-(source.tuning as SamsonTuning).notice_slow

func _physics_process(delta: float) -> void:
	age += delta
	remaining -= delta
	if not active(): retire()

func _process(delta: float) -> void:
	if not active(): return
	super._process(delta)
	plate.text = "INJUNCTION %d / %.1fs%s" % [ceili(health),maxf(0,remaining)," / ARMING" if age < (source.tuning as SamsonTuning).notice_arm else ""]

func retire() -> void:
	health = 0
	remaining = 0
	set_physics_process(false)
	visible = false
	queue_free()

