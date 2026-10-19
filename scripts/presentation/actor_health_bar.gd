class_name ActorHealthBar
extends Node3D
## Camera-facing world geometry keeps health readable without revealing it through cover.
const WIDTH: float = 1.3
var actor: HeroActor
var fill: MeshInstance3D
var overhealth_fill: MeshInstance3D
var shield_fill: MeshInstance3D
var caption: Label3D
var health_fraction: float = 1.0
var friendly: bool = false

func _ready() -> void:
	position.y = 2.6
	quad(Vector2(WIDTH+.1,.18),Vector3.ZERO,Color("101c2a"))
	quad(Vector2(WIDTH,.1),Vector3(0,0,.003),Color("394550"))
	fill = quad(Vector2(WIDTH,.1),Vector3(0,0,.006),Color("ff4f65"))
	shield_fill = quad(Vector2(WIDTH,.035),Vector3(0,.12,.006),Color("70ceff"))
	overhealth_fill = quad(Vector2(WIDTH,.04),Vector3(0,.18,.006),ActorOverhealth.COLOR)
	caption = Geometry.text3d(self,"",Vector3(0,.25,.01),36,Color("fbfff4"))
	caption.pixel_size = .006
	caption.outline_size = 5
	caption.outline_modulate = Color("101c2a")
	caption.no_depth_test = false

func quad(size: Vector2, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = Geometry.material(color)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return Geometry.mesh(self,mesh,at,material)

func refresh() -> void:
	var session: Node = get_tree().get_first_node_in_group("game_session")
	var viewer: HeroActor = session.player if session != null else null
	var camera: Camera3D = get_viewport().get_camera_3d()
	visible = actor.alive and actor != viewer and camera != null
	if not visible: return
	visible = not camera.is_position_behind(global_position) and camera.global_position.distance_to(global_position) <= 65
	if not visible: return
	global_basis = camera.global_basis.orthonormalized()
	friendly = viewer != null and actor.team == viewer.team
	var maximum: float = maxf(1,actor.effective_max_health())
	var health: float = clampf(actor.health,0,maximum)
	health_fraction = health / maximum
	fill.visible = health_fraction > 0
	fill.scale.x = maxf(.0001,health_fraction)
	fill.position.x = -WIDTH*(1-health_fraction)*.5
	(fill.material_override as StandardMaterial3D).albedo_color = Color("80f54e") if friendly else Color("ff4f65")
	var shield_fraction: float = clampf(actor.shields/maximum,0,1)
	shield_fill.visible = actor.shields > 0
	shield_fill.scale.x = maxf(.0001,shield_fraction)
	shield_fill.position.x = -WIDTH*(1-shield_fraction)*.5
	var temporary: float = actor.overhealth.value()
	var overhealth_fraction: float = clampf(temporary/maximum,0,1)
	overhealth_fill.visible = temporary > 0
	overhealth_fill.scale.x = maxf(.0001,overhealth_fraction)
	overhealth_fill.position.x = -WIDTH*(1-overhealth_fraction)*.5
	caption.text = "%d / %d" % [ceili(health),ceili(maximum)]
	if actor.shields > 0: caption.text += "  +%d" % ceili(actor.shields)

	if temporary > 0: caption.text += "  +%d OH" % ceili(temporary)
