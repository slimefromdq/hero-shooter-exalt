class_name SlayerCharacterDriver
extends Node3D
## Authored Slayer skin driven by the existing presentation controls, never combat.
const SCENE_PATH := "res://assets/characters/slayer/runtime/slayer_character.tscn"
var presentation: HeroPresentation
var avatar: Node3D
var rig: Skeleton3D
var face: MeshInstance3D
var authored_weapons: Array[MeshInstance3D] = []
var legacy_meshes: Array[MeshInstance3D] = []
var legacy_visibility: Array[bool] = []
var tool_rest: Dictionary = {}
var bones: Dictionary = {}
var rest_global: Dictionary = {}
var active: bool = true
var age: float = 0.0
var muzzle: Marker3D

static func attach(p: HeroPresentation) -> SlayerCharacterDriver:
 if not ResourceLoader.exists(SCENE_PATH):
  push_warning("Slayer authored rig unavailable; using procedural visuals")
  return null
 var packed := load(SCENE_PATH) as PackedScene
 if packed == null: return null
 var driver := SlayerCharacterDriver.new()
 driver.name="SlayerCharacterDriver"
 driver.presentation=p
 p.body.add_child(driver)
 driver.install(packed)
 return driver

func install(packed: PackedScene) -> void:
 var p: HeroPresentation=presentation
 for tool: Node3D in [p.held_knife,p.held_trap]: tool_rest[tool]=tool.transform
 for node: Node in p.body.find_children("*","MeshInstance3D",true,false):
  var mesh:=node as MeshInstance3D
  if mesh==p.shield or mesh==p.muzzle_flash or p.umbrella.is_ancestor_of(mesh): continue
  if p.held_knife.is_ancestor_of(mesh) or p.held_trap.is_ancestor_of(mesh): continue
  legacy_meshes.append(mesh); legacy_visibility.append(mesh.visible)
 avatar=packed.instantiate(); add_child(avatar)
 rig=avatar.get_node("Rig")
 face=avatar.get_node("Slayer_Face")
 for index: int in rig.get_bone_count():
  var caption: String=rig.get_bone_name(index)
  bones[caption]=index
  rest_global[caption]=rig.get_bone_global_rest(index)
 var gun: MeshInstance3D=avatar.get_node("Slayer_Shotgun")
 gun.reparent(p.rifle,false); authored_weapons.append(gun)
 var axe: MeshInstance3D=avatar.get_node("Slayer_BackAxe")
 axe.reparent(p.slayer_axe,false); authored_weapons.append(axe)
 muzzle=Marker3D.new(); muzzle.name="AuthoredMuzzle"
 p.rifle.add_child(muzzle); muzzle.position=Vector3(0,0,-.911)
 set_enabled(true)

func set_enabled(value: bool) -> void:
 active=value
 if not value:
  for tool: Node3D in tool_rest:
   if is_instance_valid(tool): tool.transform=tool_rest[tool]
 if is_instance_valid(avatar): avatar.visible=value
 for index: int in legacy_meshes.size():
  if is_instance_valid(legacy_meshes[index]): legacy_meshes[index].visible=legacy_visibility[index] and not value
 for weapon: MeshInstance3D in authored_weapons:
  if is_instance_valid(weapon): weapon.visible=value
 reset_feedback()

func bone_rotation(caption: String, basis: Basis) -> void:
 rig.set_bone_pose_rotation(bones[caption],basis.orthonormalized().get_rotation_quaternion())

func global_basis(caption: String, desired: Basis) -> void:
 var index: int=bones[caption]
 var parent: int=rig.get_bone_parent(index)
 var parent_basis: Basis=rig.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
 bone_rotation(caption,parent_basis.inverse()*desired)

func solve_arm(side: String, at: Vector3, grip: Node3D = null) -> void:
 var upper: String=side+"UpperArm"; var lower: String=side+"Forearm"; var hand: String=side+"Hand"
 var start: Vector3=rig.get_bone_global_pose(bones[upper]).origin
 var rest_a: Vector3=(rest_global[lower] as Transform3D).origin-(rest_global[upper] as Transform3D).origin
 var rest_b: Vector3=(rest_global[hand] as Transform3D).origin-(rest_global[lower] as Transform3D).origin
 var first: float=rest_a.length(); var second: float=rest_b.length()
 var difference: Vector3=at-start
 var distance: float=clampf(difference.length(),absf(first-second)+.005,first+second-.005)
 var forward: Vector3=difference.normalized()
 var hint:=Vector3(-.2 if side=="Left" else .2,-1,.25)
 var bend: Vector3=(hint-forward*hint.dot(forward)).normalized()
 var along: float=(first*first-second*second+distance*distance)/(2*distance)
 var height: float=sqrt(maxf(0,first*first-along*along))
 var elbow: Vector3=start+forward*along+bend*height
 var end: Vector3=start+forward*distance
 global_basis(upper,Basis(Quaternion(rest_a.normalized(),(elbow-start).normalized())))
 global_basis(lower,Basis(Quaternion(rest_b.normalized(),(end-elbow).normalized())))
 var gun_basis: Basis=rig.global_basis.inverse()*(presentation.rifle.global_basis if grip==null else grip.global_basis)
 global_basis(hand,gun_basis*Basis(Vector3.RIGHT,PI/2))

func update(delta: float) -> void:
 if not active or not is_instance_valid(rig): return
 age+=delta
 var p: HeroPresentation=presentation
 var a: HeroActor=p.actor
 rig.reset_bone_poses()
 if bones.has("Spine"): bone_rotation("Spine",MotionPose.torso(p))
 # Source left/right labels face Blender +Y; this rig names limbs by Godot X.
 for side: String in ["Left","Right"]:
  var arm: Node3D=p.left_arm if side=="Left" else p.right_arm
  var leg: Node3D=p.left_leg if side=="Left" else p.right_leg
  var correction: float=.43 if side=="Left" else -.43
  bone_rotation(side+"UpperArm",arm.basis*Basis(Vector3.BACK,correction))
  bone_rotation(side+"Forearm",(arm.get_node("Joint") as Node3D).basis)
  bone_rotation(side+"Thigh",leg.basis.orthonormalized())
  rig.set_bone_pose_scale(bones[side+"Thigh"],leg.scale)
  rig.set_bone_pose_position(bones[side+"Thigh"],rig.get_bone_rest(bones[side+"Thigh"]).origin+Vector3(0,leg.position.y-.8,0))
  bone_rotation(side+"Calf",(leg.get_node("Joint") as Node3D).basis)
  if a.motor.crouched or a.motor.mode=="slide":
   bone_rotation(side+"Foot",Basis(Vector3.RIGHT,-leg.rotation.x-(leg.get_node("Joint") as Node3D).rotation.x))
 if a.state=="ready" and a.alive:
  var right_target: Vector3=p.rifle.to_global(Vector3(0,-.035,-.19))
  var left_target: Vector3=p.rifle.to_global(Vector3(-.08,-.04,-.34))
  if a.kit.reloading:
   var phase: float=sin(a.kit.reload_remaining/(a.tuning as SlayerTuning).shell_time*TAU)
   left_target=p.rifle.to_global(Vector3(-.08,-.12-.04*phase,-.25))
  solve_arm("Right",rig.to_local(right_target))
  solve_arm("Left",rig.to_local(left_target))
 if a.state=="slayer_axe_windup" and a.alive:
  p.slayer_axe.position.x=0
  solve_arm("Right",rig.to_local(p.slayer_axe.to_global(Vector3(0,-.38,0))),p.slayer_axe)
  solve_arm("Left",rig.to_local(p.slayer_axe.to_global(Vector3(0,-.25,0))),p.slayer_axe)
 var pitch: float=asin(clampf(a.aim_direction.y,-1,1))
 bone_rotation("Head",Basis(Vector3.RIGHT,clampf(pitch,-.3,.3)*.35))
 for tool: Node3D in [p.held_knife,p.held_trap]:
  if tool.visible:
   var hand: Transform3D=rig.global_transform*rig.get_bone_global_pose(bones["RightHand"])
   tool.global_transform=hand*Transform3D(Basis.IDENTITY,Vector3(0,-.055,-.015))
   if tool==p.held_trap: tool.scale*=.8
 # Presentation clock only: no global RNG or gameplay timing is consumed.
 var cycle: float=fmod(age,4.8)
 var blink: float=maxf(0,1-absf(cycle-4.64)/.09)
 if not a.alive: blink=.85
 for index: int in face.mesh.get_blend_shape_count(): face.set_blend_shape_value(index,0)
 face.set_blend_shape_value(face.find_blend_shape_by_name("Blink"),blink)
 if blink<.01:
  face.set_blend_shape_value(face.find_blend_shape_by_name("Focused"),.5 if a.state!="ready" or p.fire_flash>0 else .12)
 if a.last_hit_age<.25: face.set_blend_shape_value(face.find_blend_shape_by_name("MouthOpen"),.15)

func reset_feedback() -> void:
 age=0
 if is_instance_valid(rig): rig.reset_bone_poses()
 if is_instance_valid(face):
  for index: int in face.mesh.get_blend_shape_count(): face.set_blend_shape_value(index,0)

func _exit_tree() -> void:
 for weapon: MeshInstance3D in authored_weapons:
  if is_instance_valid(weapon): weapon.queue_free()
 if is_instance_valid(muzzle): muzzle.queue_free()
