class_name PlayerController
extends Node

var actor: HeroActor
var rig: Node3D
var arm: SpringArm3D
var camera: Camera3D
var yaw: float = 0.0
var pitch: float = -0.12
@export var sensitivity: float = 0.0025
# Close shoulder framing enlarges the hero without narrowing the normal 76-degree FOV.
@export var camera_distance: float = 1.85
@export var shoulder_offset: float = 0.65
@export var camera_height: float = 1.75
var active: bool = true
var recoil: float = 0.0

func _ready() -> void:
	rig = Node3D.new()
	actor.get_parent().add_child(rig)
	arm = SpringArm3D.new()
	arm.spring_length = camera_distance
	arm.collision_mask = 1
	arm.margin = 0.18
	var shape := SphereShape3D.new()
	shape.radius = 0.18
	arm.shape = shape
	rig.add_child(arm)
	arm.position.x = shoulder_offset
	camera = Camera3D.new()
	camera.fov = 76.0
	camera.near = 0.08
	arm.add_child(camera)
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * sensitivity
		pitch = clampf(pitch - event.relative.y * sensitivity, -1.3, 1.15)
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		var session: Node = get_tree().get_first_node_in_group("game_session")
		if session != null and not session.menu_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	if rig == null:
		return
	rig.global_position = actor.global_position + Vector3.UP * camera_height
	recoil = move_toward(recoil,0,delta * .22)
	rig.rotation = Vector3(pitch + recoil, yaw, 0.0)
	arm.position.x = shoulder_offset
	var aiming: bool = actor.intent.aim_held or actor.state == "ultimate"
	camera.fov = lerpf(camera.fov, 34.0 if actor.state == "ultimate" else (55.0 if aiming else 76.0), minf(1.0, delta * 12.0))
	arm.spring_length = lerpf(arm.spring_length, camera_distance * (0.8 if aiming else 1.0), delta * 10.0)

func gather_intent(_delta: float) -> CombatIntent:
	var input := CombatIntent.new()
	input.aim = -camera.global_basis.z
	input.aim_origin = camera.global_position
	if not active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return input
	var axes: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	var right: Vector3 = camera.global_basis.x
	right.y = 0.0
	input.move = (right.normalized() * axes.x - forward.normalized() * axes.y).limit_length(1.0)
	input.primary = Input.is_action_just_pressed("primary")
	input.aim_held = Input.is_action_pressed("aim")
	input.jump = Input.is_action_just_pressed("jump")
	input.jump_held = Input.is_action_pressed("jump")
	input.dash = Input.is_action_just_pressed("dash")
	input.slide = Input.is_action_pressed("slide")
	input.reload = Input.is_action_just_pressed("reload")
	input.melee = Input.is_action_just_pressed("melee")
	input.guard = Input.is_action_pressed("guard")
	input.throw_action = Input.is_action_just_pressed("throw")
	input.hover = Input.is_action_just_pressed("hover")
	input.deflect = Input.is_action_just_pressed("deflect")
	input.bomb = Input.is_action_just_pressed("bomb")
	input.ultimate = Input.is_action_just_pressed("ultimate")
	return input

func reset_controller() -> void:
	recoil = 0.0
	yaw = 0.0
	pitch = -0.12

func add_recoil(amount: float) -> void:
	recoil = minf(recoil + amount, .1)

func _exit_tree() -> void:
	if is_instance_valid(rig):
		rig.queue_free()
