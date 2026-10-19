class_name MuseumObjectiveMarker
extends Node3D
## Cosmetic world beacon + HUD projection. No collision or objective occupancy.
var session: MuseumMatch
var ring: MeshInstance3D
var beacon: MeshInstance3D
var label: Label3D
var material: StandardMaterial3D

static func screen_layout(camera: Camera3D, target: Vector3, viewport_size: Vector2) -> Dictionary:
 var fit: Transform2D = HUDLayout.fit(viewport_size,Vector2(1600,900))
 var behind: bool = camera.is_position_behind(target)
 var projected: Vector2 = fit.affine_inverse()*camera.unproject_position(target)
 var center := Vector2(800,450)
 # Leave room above the icon for its caption, below the team/status panels.
 var safe := Rect2(160,390,1280,230)
 var direction: Vector2 = projected-center
 if behind:
  var local: Vector3 = camera.global_transform.affine_inverse()*target
  direction = Vector2(local.x,-local.y)
  if direction.length_squared() < .001: direction = Vector2.DOWN
 var edge: bool = behind or not safe.has_point(projected)
 if edge:
  direction = direction.normalized()
  if direction.is_zero_approx(): direction = Vector2.UP
  var reach: float = INF
  if absf(direction.x) > .0001: reach = minf(reach,((safe.end.x if direction.x > 0 else safe.position.x)-center.x)/direction.x)
  if absf(direction.y) > .0001: reach = minf(reach,((safe.end.y if direction.y > 0 else safe.position.y)-center.y)/direction.y)
  projected = center+direction*reach
 return {"position":projected,"edge":edge,"direction":direction.normalized(),"behind":behind}

func _ready() -> void:
 name = "ActiveObjectiveBeacon"
 material = StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.albedo_color = Color("ffd587")
 material.emission_enabled = true
 material.emission = Color("ffb94a")
 material.emission_energy_multiplier = 1.3
 material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 material.albedo_color.a = .75
 ring = MeshInstance3D.new()
 var torus := TorusMesh.new()
 torus.inner_radius = .96
 torus.outer_radius = 1.0
 torus.rings = 64
 torus.ring_segments = 6
 ring.mesh = torus
 ring.material_override = material
 ring.position.y = .09
 add_child(ring)
 beacon = MeshInstance3D.new()
 var cylinder := CylinderMesh.new()
 cylinder.top_radius = .06
 cylinder.bottom_radius = .06
 cylinder.height = 5.5
 beacon.mesh = cylinder
 beacon.material_override = material
 beacon.position.y = 3.1
 add_child(beacon)
 label = Label3D.new()
 label.position.y = 6.5
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 label.font_size = 40
 label.outline_size = 10
 label.pixel_size = .015
 label.modulate = Color("ffd587")
 label.no_depth_test = false
 add_child(label)
 _process(0)

func _process(_delta: float) -> void:
 if not is_instance_valid(session): return
 visible = session.winner < 0 and session.phase != "finished"
 if not visible: return
 global_position = session.active_objective_position()
 var escort: bool = session.phase == "escort"
 ring.scale = Vector3(2.3,.06,2.3) if escort else Vector3(9,.06,7)
 label.text = ("PAYLOAD / CP%d" % mini(3,session.checkpoint_index+1)) if escort else "A / ASTROLABE COURT"
 var color: Color = Color("ff687b") if session.objective.contested else Color("ffd587")
 material.albedo_color = Color(color,.75)
 material.emission = color
 label.modulate = color
