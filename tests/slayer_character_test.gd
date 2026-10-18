extends SceneTree
## Actual playable Slayer integration: shared resources, independent poses and lifecycle.
var checks: int=0
var failures: Array[String]=[]
var arena: Node3D
var player: HeroActor
var camera: Camera3D
var capture: bool=false

func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
 checks+=1
 print("PASS  " if ok else "FAIL  ",caption)
 if not ok: failures.append(caption)
func step(frames: int=1) -> void:
 for index: int in frames:
  await physics_frame; await process_frame
func image(caption: String) -> void:
 if not capture: return
 var was_paused: bool=paused
 paused=true
 await process_frame; await RenderingServer.frame_post_draw
 var path: String="res://artifacts/slayer-integration/"+caption+".png"
 check(root.get_texture().get_image().save_png(path)==OK,"rendered playable model: "+caption)
 paused=was_paused
func bone_position(driver: SlayerCharacterDriver, caption: String) -> Vector3:
 return driver.rig.get_bone_global_pose(driver.bones[caption]).origin

func run() -> void:
 capture=DisplayServer.get_name()!="headless"
 HeroRoster.selected="slayer"
 arena=load("res://scenes/training/combat_sandbox.tscn").instantiate()
 root.add_child(arena); current_scene=arena
 arena.training.freeze_ai=true
 player=arena.training.player; player.controller=null
 player.reset_actor(Vector3(0,.01,11)); player.controller=null
 await step(4)
 var p: HeroPresentation=player.presentation
 var driver: SlayerCharacterDriver=p.slayer_model
 check(is_instance_valid(driver) and driver.active,"playable Slayer selects the authored model by default")
 if not is_instance_valid(driver): quit(1); return
 var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/slayer/runtime/rig-report.json"))
 check(report.source_sha256==FileAccess.get_sha256("res://assets/characters/slayer/slayer.glb"),"game rig was generated from the current authored GLB")
 check(driver.rig.get_bone_count()==16,"game rig has sixteen articulated bones")
 check(driver.face.mesh.get_blend_shape_count()==9,"all nine authored facial morphs are retained in the game rig")
 var meshes: int=0; var normalized: bool=true; var max_influences: int=0
 for node: Node in driver.avatar.find_children("*","MeshInstance3D",true,false):
  var mesh:=node as MeshInstance3D
  meshes+=1
  check(mesh.skin!=null and mesh.skin.get_bind_count()==16,"skin bindings retained: "+str(mesh.name))
  for surface: int in mesh.mesh.get_surface_count():
   var arrays: Array=mesh.mesh.surface_get_arrays(surface)
   var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
   var ids: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
   normalized=normalized and weights.size()==positions.size()*4 and ids.size()==weights.size()
   for index: int in positions.size():
    var total: float=0; var influences: int=0
    for slot: int in 4:
     var weight: float=weights[index*4+slot]
     total+=weight
     if weight>0: influences+=1
     normalized=normalized and weight>=0 and is_finite(weight) and ids[index*4+slot]<16
    max_influences=maxi(max_influences,influences)
    normalized=normalized and absf(total-1)<4.0/65535.0
 check(meshes==19 and normalized and max_influences<=4,"all nineteen body groups have normalized four-slot weights")
 check(driver.authored_weapons.size()==2 and driver.authored_weapons[0].get_parent()==p.rifle and driver.authored_weapons[1].get_parent()==p.slayer_axe,"authored shotgun and axe use existing weapon animation anchors")
 var gun: MeshInstance3D=driver.authored_weapons[0]
 check(absf(gun.mesh.get_aabb().position.z-driver.muzzle.position.z)<.015,"muzzle marker matches the actual authored barrel crown")
 var collision:=player.get_node("BodyCollision") as CollisionShape3D
 var capsule:=collision.shape as CapsuleShape3D
 check(is_equal_approx(capsule.height,1.9) and is_equal_approx(capsule.radius,.38),"visual integration preserves exact gameplay capsule")
 var rest_hand: Vector3=(driver.rest_global["RightHand"] as Transform3D).origin
 check(bone_position(driver,"RightHand").distance_to(rest_hand)>.15,"ready gun pose actually deforms the articulated hand")
 var twin: HeroActor=arena.training.bots[0]
 twin.select_hero("slayer")
 await step(2)
 var other: SlayerCharacterDriver=twin.presentation.slayer_model
 check(driver.rig!=other.rig and driver.face!=other.face and driver.face.mesh==other.face.mesh,"actors share immutable mesh resources and retain independent skeleton/morph state")
 driver.face.set_blend_shape_value(driver.face.find_blend_shape_by_name("Smirk"),1)
 check(other.face.get_blend_shape_value(other.face.find_blend_shape_by_name("Smirk"))==0,"one actor's facial expression cannot leak to another")
 driver.reset_feedback()
 seed(13579); var expected: float=randf(); seed(13579)
 driver.update(.016)
 check(is_equal_approx(expected,randf()),"model animation and blinking never consume gameplay RNG")
 driver.set_enabled(false); await step()
 check(not driver.avatar.visible and driver.legacy_meshes[0].visible and not driver.authored_weapons[0].visible,"prototype fallback remains usable without changing hero or collision")
 driver.set_enabled(true); await step(2)
 check(driver.avatar.visible and not driver.legacy_meshes[0].visible,"authored model can be restored after fallback")
 if capture:
  arena.training.hud.visible=false
  camera=Camera3D.new(); arena.add_child(camera); camera.current=true
  camera.position=player.global_position+Vector3(-2.5,1.8,-4)
  camera.look_at(player.global_position+Vector3.UP*1.05)
  await image("ready")
  camera.position=player.global_position+Vector3(-.45,1.75,-1.3)
  camera.look_at(player.global_position+Vector3.UP*1.69)
  await image("face-in-arena")
  camera.position=player.global_position+Vector3(2.8,1.8,-4)
  camera.look_at(player.global_position+Vector3.UP*1.0)
 check(bone_position(driver,"RightThigh").x>.08 and bone_position(driver,"LeftThigh").x<-.08,"rest hip spacing survives procedural pose updates")
 var before: Vector3=bone_position(driver,"RightFoot")
 p.right_leg.rotation.x=1.4
 p.right_leg.get_node("Joint").rotation.x=-.4
 driver.update(0)
 check(bone_position(driver,"RightFoot").distance_to(before)>.25,"leg controls visibly articulate weighted trousers and boots")
 var kit:=player.kit as SlayerKit
 kit.fire(false); await step(2); await image("shotgun")
 kit.ammo=0; kit.start_reload(); await step(10); await image("reload")
 player.reset_actor(player.global_position); player.controller=null
 player.intent.move=Vector3.FORWARD; await step(16); await image("run")
 player.reset_actor(player.global_position); player.controller=null
 player.intent.jump=true; await step(4); player.intent.jump=false; await image("jump")
 player.reset_actor(player.global_position); player.controller=null
 player.intent.slide=true; await step(4); await image("crouch")
 player.intent.slide=false; await step(3)
 player.state="slayer_boot_active"; player.state_time=.2; await step(); await image("boot")
 player.reset_actor(player.global_position); player.controller=null
 kit.throw_knife(); await step(2)
 check(p.held_knife.visible,"authored hand retains knife anticipation visibility")
 await image("knife")
 driver.set_enabled(false)
 check(p.held_knife.transform.is_equal_approx(driver.tool_rest[p.held_knife]),"fallback restores held tool transforms after authored hand animation")
 driver.set_enabled(true)
 player.reset_actor(player.global_position); player.controller=null
 kit.deploy_trap(); await step(6); await image("trap")
 check(p.held_trap.visible,"authored hand retains trap anticipation visibility")
 player.reset_actor(player.global_position); player.controller=null
 kit.ultimate_charge=100; player.intent.ultimate=true; await step(8); check(player.state=="slayer_axe_windup","authored axe capture exercises an actual ultimate windup")
 check((driver.rig.global_transform*bone_position(driver,"RightHand")).distance_to(p.slayer_axe.to_global(Vector3(0,-.38,0)))<.08,
       "ultimate right hand stays on the authored axe shaft")
 check((driver.rig.global_transform*bone_position(driver,"LeftHand")).distance_to(p.slayer_axe.to_global(Vector3(0,-.25,0)))<.08,
       "ultimate support hand stays on the authored axe shaft")
 await image("axe")
 player.die(); await step(2)
 check(driver.face.get_blend_shape_value(driver.face.find_blend_shape_by_name("Blink"))>=.8,"death clears feedback and settles the authored face")
 player.reset_actor(player.global_position); await step(2)
 check(driver.face.get_blend_shape_value(driver.face.find_blend_shape_by_name("Blink"))<.01,"restart clears death expression and blink clock")
 var old_driver: WeakRef=weakref(driver); var old_gun: WeakRef=weakref(gun)
 player.select_hero("nimbus"); await step(3)
 check(old_driver.get_ref()==null and old_gun.get_ref()==null and player.presentation.slayer_model==null,"hero switching releases the rig and externally mounted authored weapons")
 player.select_hero("slayer"); await step(2)
 check(is_instance_valid(player.presentation.slayer_model),"switching back rebuilds a clean live Slayer model")
 FileAccess.open("res://artifacts/slayer-integration/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rendered":capture,"bones":16,"skinned_groups":19,"live_actor_replaced":true},"\t"))
 print("RESULT: %d checks, %d failures"%[checks,failures.size()])
 arena.queue_free(); await step(2)
 quit(0 if failures.is_empty() else 1)
