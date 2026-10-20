class_name MovementPresentation
extends Node
var actor: HeroActor
var hud_kind: String = ""
var hud_left: float = 0
var failure: String = ""
var failure_left: float = 0
var fov_pulses: Array[Vector2] = []
var jump_left: float = 0
var trail_clock: float = 0
const ICONS := ["wall_jump","dash","slide","dash_slide"]
const FAILURES := {
	"too_early":"TOO EARLY - crouch just before landing",
	"too_late":"TOO LATE - crouch before impact",
	"hold_crouch":"HOLD CROUCH THROUGH LANDING",
	"ground_dash":"HOLD SHIFT THROUGH DASH EXIT",
	"not_downward":"DASH DOWN INTO THE GROUND",
	"too_slow":"NOT ENOUGH FORWARD SPEED",
	"wall":"WALL BLOCKED THE DASH",
	"ceiling":"CEILING BLOCKED THE DASH",
	"expired":"DASH ENDED BEFORE LANDING"
}

func _ready() -> void:
	actor.movement_confirmed.connect(confirm)
	actor.dash_slide_failed.connect(on_failure)

func is_local() -> bool:
	var session: Node = get_tree().get_first_node_in_group("game_session")
	return (session != null and session.get("player") == actor) or actor.controller is PlayerController

func confirm(kind: String, at: Vector3, direction: Vector3, normal: Vector3, strength: float) -> void:
	if not actor.alive: return
	if kind == "jump": jump_left = .16
	if kind == "dash_slide":
		failure = ""
		failure_left = 0
	if is_local():
		if kind in ICONS and (hud_kind != "dash_slide" or hud_left <= 0 or kind == "dash_slide"):
			hud_kind = kind
			hud_left = .35
		if kind == "dash": add_fov(4)
		elif kind == "wall_jump": add_fov(2)
		elif kind == "landing" and strength >= 1: add_fov(-1.5)
	spawn(kind,at,direction,normal,strength)

func spawn(kind: String, at: Vector3, direction: Vector3, normal: Vector3, strength: float = 1) -> void:
	if get_child_count() >= 10: return
	var camera: Camera3D = actor.get_viewport().get_camera_3d()
	if camera != null and camera.global_position.distance_squared_to(at) > 2025: return
	MovementBurst.spawn(self,kind,at,direction,normal,strength*(1 if is_local() else .5))

func on_failure(reason: String) -> void:
	if not is_local() or not actor.alive: return
	failure = FAILURES.get(reason,"")
	failure_left = .9
	hud_left = 0

func add_fov(amount: float) -> void:
	if fov_pulses.size() >= 6: fov_pulses.pop_front()
	fov_pulses.append(Vector2(amount,.25))

func camera_offset(delta: float, suppressed: bool) -> float:
	var total: float = 0
	for i: int in range(fov_pulses.size()-1,-1,-1):
		var pulse: Vector2 = fov_pulses[i]
		pulse.y -= delta
		if pulse.y <= 0: fov_pulses.remove_at(i)
		else:
			fov_pulses[i] = pulse
			total += pulse.x*pow(pulse.y/.25,2)
	if suppressed: return 0
	return clampf(total,-2,5)

func _process(delta: float) -> void:
	hud_left = maxf(0,hud_left-delta)
	failure_left = maxf(0,failure_left-delta)
	jump_left = maxf(0,jump_left-delta)
	trail_clock -= delta
	if not actor.alive or trail_clock > 0: return
	var direction: Vector3 = actor.velocity.normalized()
	if actor.motor.mode == "dash":
		spawn("dash_trail",actor.body_point(.9),actor.motor.dash_direction,Vector3.UP)
		trail_clock = .05
	elif actor.motor.mode == "slide" and actor.velocity.length() > 2:
		spawn("slide_dust",actor.global_position+Vector3.UP*.06,direction,actor.get_floor_normal())
		trail_clock = .09
	elif actor.motor.traversal.active and actor.motor.traversal.progress > .65:
		spawn("mantle_hands",actor.motor.traversal.landing+Vector3.UP*.06,actor.motor.traversal.approach_direction,Vector3.UP)
		trail_clock = .12
	elif actor.close.melee_airborne and actor.state.begins_with("melee_") and actor.close.melee_age <= actor.tuning.melee_lunge_delay+actor.tuning.melee_lunge_duration:
		spawn("air_melee",actor.body_point(1),actor.close.melee_direction,Vector3.UP)
		trail_clock = .06

func clear() -> void:
	hud_kind = ""
	hud_left = 0
	failure = ""
	failure_left = 0
	jump_left = 0
	trail_clock = 0
	fov_pulses.clear()
	for child: Node in get_children(): child.queue_free()

func _exit_tree() -> void:
	if is_instance_valid(actor):
		if actor.movement_confirmed.is_connected(confirm): actor.movement_confirmed.disconnect(confirm)
		if actor.dash_slide_failed.is_connected(on_failure): actor.dash_slide_failed.disconnect(on_failure)
	clear()
