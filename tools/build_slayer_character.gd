extends SceneTree
## Reproducible game rig derived from the editable Slayer GLB; no combat data.
const OUTPUT := "res://assets/characters/slayer/runtime/"
var rig: Skeleton3D
var bones: Dictionary = {}
var rests: Dictionary = {}
var source_scale: float = .98242

func _initialize() -> void: call_deferred("build")

func bone(caption: String, parent: String, at: Vector3) -> void:
 var index: int = rig.get_bone_count()
 rig.add_bone(caption)
 bones[caption] = index
 var global_rest := Transform3D(Basis.IDENTITY,at)
 if parent != "":
  rig.set_bone_parent(index,bones[parent])
  rig.set_bone_rest(index,(rests[parent] as Transform3D).affine_inverse()*global_rest)
 else: rig.set_bone_rest(index,global_rest)
 rests[caption]=global_rest

func limb_weights(side: String, height: float) -> Dictionary:
 var thigh: float = smoothstep(.46,.60,height)
 var foot: float = 1.0-smoothstep(.17,.27,height)
 var hip: float = smoothstep(.82,.97,height)
 return {"Root":hip,side+"Thigh":(1-hip)*(1-foot)*thigh,side+"Calf":(1-hip)*(1-foot)*(1-thigh),side+"Foot":(1-hip)*foot}

func weights(group: String, point: Vector3) -> Dictionary:
 var side: String = "Left" if point.x < 0 else "Right"
 # Height tests use the original authored metres, independent of the root scale.
 var y: float = (point.y+.004912)/source_scale
 if group in ["Face","Head","Hair"]: return {"Head":1.0}
 if group == "Neck":
  var t: float = smoothstep(1.48,1.59,y)
  return {"Chest":1-t,"Head":t}
 if group.begins_with("UpperArm"):
  var elbow: float = 1-smoothstep(1.245,1.31,y)
  var shoulder: float = 1-smoothstep(.18,.25,absf(point.x)/source_scale)
  return {"Chest":shoulder,side+"UpperArm":(1-shoulder)*(1-elbow),side+"Forearm":(1-shoulder)*elbow}
 if group.begins_with("Forearm"):
  var hand: float = 1-smoothstep(1.02,1.075,y)
  return {side+"Forearm":1-hand,side+"Hand":hand}
 if group.begins_with("Hand"): return {side+"Hand":1.0}
 if group.begins_with("Foot"): return {side+"Foot":1.0}
 if group == "Pelvis" or group.begins_with("Thigh"): return limb_weights(side,y)
 if group.begins_with("Calf"): return {side+"Calf":1.0}
 var chest: float = smoothstep(1.12,1.38,y)
 return {"Spine":1-chest,"Chest":chest}

func transform_arrays(input: Array, transform: Transform3D, relative: bool = false) -> Array:
 var result: Array = input.duplicate(true)
 var points: PackedVector3Array = result[Mesh.ARRAY_VERTEX]
 for index: int in points.size(): points[index]=transform.basis*points[index] if relative else transform*points[index]
 result[Mesh.ARRAY_VERTEX]=points
 if result[Mesh.ARRAY_NORMAL] != null:
  var normals: PackedVector3Array=result[Mesh.ARRAY_NORMAL]
  for index: int in normals.size():
   var value: Vector3=transform.basis*normals[index]
   normals[index]=value if relative else value.normalized()
  result[Mesh.ARRAY_NORMAL]=normals
 if result[Mesh.ARRAY_TANGENT] != null:
  var tangents: PackedFloat32Array=result[Mesh.ARRAY_TANGENT]
  for index: int in range(0,tangents.size(),4):
   var value: Vector3=transform.basis*Vector3(tangents[index],tangents[index+1],tangents[index+2])
   if not relative: value=value.normalized()
   tangents[index]=value.x; tangents[index+1]=value.y; tangents[index+2]=value.z
  result[Mesh.ARRAY_TANGENT]=tangents
 return result

func bake_mesh(source: MeshInstance3D, group: String, transform: Transform3D, skinned: bool) -> ArrayMesh:
 var mesh := ArrayMesh.new()
 mesh.resource_name="Slayer_"+group
 mesh.blend_shape_mode=source.mesh.blend_shape_mode
 for index: int in source.mesh.get_blend_shape_count(): mesh.add_blend_shape(source.mesh.get_blend_shape_name(index))
 for surface: int in source.mesh.get_surface_count():
  var arrays: Array=transform_arrays(source.mesh.surface_get_arrays(surface),transform)
  if skinned:
   var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var ids:=PackedInt32Array(); ids.resize(points.size()*4)
   var values:=PackedFloat32Array(); values.resize(points.size()*4)
   for index: int in points.size():
    var mapping: Dictionary=weights(group,points[index]); var slot: int=0
    for caption: String in mapping:
     var amount: float=mapping[caption]
     if amount<=.000001: continue
     assert(slot<4,"Skin influence budget exceeded")
     ids[index*4+slot]=bones[caption]; values[index*4+slot]=amount; slot+=1
   arrays[Mesh.ARRAY_BONES]=ids; arrays[Mesh.ARRAY_WEIGHTS]=values
  var shapes: Array[Array]=[]
  for shape: Array in source.mesh.surface_get_blend_shape_arrays(surface):
   shapes.append(transform_arrays(shape,transform,mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_RELATIVE))
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,shapes)
  mesh.surface_set_material(surface,source.get_active_material(surface))
 var path: String=OUTPUT+group.to_snake_case()+".res"
 assert(ResourceSaver.save(mesh,path)==OK)
 mesh.take_over_path(path)
 assert(mesh.resource_path==path)
 return mesh

func build() -> void:
 var source: Node3D=load("res://assets/characters/slayer/slayer.glb").instantiate()
 root.add_child(source)
 var character:=Node3D.new(); character.name="SlayerCharacter"
 root.add_child(character)
 rig=Skeleton3D.new(); rig.name="Rig"; character.add_child(rig); rig.owner=character
 var reference: MeshInstance3D=source.find_child("Slayer_Torso",true,false)
 source_scale=reference.global_basis.get_scale().x
 var to_world: Transform3D=reference.global_transform
 bone("Root","",to_world*Vector3(0,.93,0))
 bone("Spine","Root",to_world*Vector3(0,1.18,0))
 bone("Chest","Spine",to_world*Vector3(0,1.43,0))
 bone("Head","Chest",to_world*Vector3(0,1.58,0))
 for side: String in ["Left","Right"]:
  var sign_x: float=-1 if side=="Left" else 1
  bone(side+"UpperArm","Chest",to_world*Vector3(sign_x*.235,1.445,0))
  bone(side+"Forearm",side+"UpperArm",to_world*Vector3(sign_x*.314,1.275,-.013))
  bone(side+"Hand",side+"Forearm",to_world*Vector3(sign_x*.399,1.045,-.044))
  bone(side+"Thigh","Root",to_world*Vector3(sign_x*.105,.93,0))
  bone(side+"Calf",side+"Thigh",to_world*Vector3(sign_x*.12,.55,-.025))
  bone(side+"Foot",side+"Calf",to_world*Vector3(sign_x*.12,.18,.004))
 var skin:=Skin.new()
 for index: int in rig.get_bone_count():
  var caption: String=rig.get_bone_name(index)
  skin.add_named_bind(caption,(rests[caption] as Transform3D).affine_inverse())
 for node: Node in source.find_children("*","MeshInstance3D",true,false):
  var original:=node as MeshInstance3D
  var group: String=str(node.name).trim_prefix("Slayer_")
  var transform: Transform3D=original.global_transform
  var skinned: bool=group not in ["Shotgun","BackAxe"]
  if group=="Shotgun":
   var grip: Vector3=to_world*Vector3(-.446,.99,-.086)
   transform=Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3(0,0,-.25))*Transform3D(Basis.IDENTITY,-grip)*transform
  elif group=="BackAxe":
   var mount: Vector3=to_world*Vector3(0,1.11,.16)
   transform=Transform3D(Basis(Vector3.FORWARD,.48),Vector3.ZERO)*Transform3D(Basis.IDENTITY,-mount)*transform
  var instance:=MeshInstance3D.new(); instance.name="Slayer_"+group
  instance.mesh=bake_mesh(original,group,transform,skinned)
  character.add_child(instance); instance.owner=character
  if skinned: instance.skin=skin; instance.skeleton=NodePath("../Rig")
  # Skin poses can exceed bind bounds during kicks, crouches and throws.
  instance.extra_cull_margin=1.8
 var packed:=PackedScene.new()
 assert(packed.pack(character)==OK)
 assert(ResourceSaver.save(packed,OUTPUT+"slayer_character.tscn")==OK)
 var report={"source_sha256":FileAccess.get_sha256("res://assets/characters/slayer/slayer.glb"),"source":"res://assets/characters/slayer/slayer.glb","bones":rig.get_bone_count(),"skinned_groups":19,"facial_morphs":9,"max_influences":4,"gameplay_modified":false}
 FileAccess.open(OUTPUT+"rig-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
 print("SLAYER_GAME_RIG_BUILT ",report)
 source.queue_free(); character.queue_free(); await process_frame
 quit()
