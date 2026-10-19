extends SceneTree
var arena: Node3D
var camera: Camera3D
func _initialize() -> void: call_deferred("run")
func frames(count: int = 8) -> void:
 for index: int in count: await process_frame
func photo(name: String, at: Vector3, target: Vector3) -> void:
 camera.position = at
 camera.look_at(target)
 camera.current = true
 await frames(15)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/museum/lighting/"+name+".png")
 print("MUSEUM LIGHTING PHOTO ",name)
func run() -> void:
 arena = load("res://scenes/museum/meridian_museum.tscn").instantiate()
 root.add_child(arena)
 current_scene = arena
 var m: MuseumMatch = arena.match_controller
 m.set_physics_process(false)
 for actor: HeroActor in m.actors: actor.set_physics_process(false)
 m.player.controller.active = false
 m.freeze_ai = true
 var start: int = Time.get_ticks_msec()
 while not m.navigation_ready and Time.get_ticks_msec()-start < 30000:
  m._physics_process(0)
  await physics_frame
 if not m.navigation_ready:
  push_error("Museum lighting capture: navigation failed")
  quit(1)
  return
 m.hud.visible = false
 camera = Camera3D.new()
 camera.fov = 78
 camera.far = 350
 arena.add_child(camera)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/museum/lighting"))
 for id: String in MuseumLighting.IDS:
  arena.builder.lighting.apply_preset(id)
  await photo(id+"-court",Vector3(-42,3,33),Vector3(-26,4,22))
  await photo(id+"-giants",Vector3(-12,2.5,-26),Vector3(-30,6,-20))
  await photo(id+"-terrace",Vector3(5,4,-31),Vector3(28,8,-14))
  await photo(id+"-vault",Vector3(25,2,18),Vector3(25,3,26))
 arena.builder.lighting.apply_preset("night")
 await photo("night-sky",Vector3(28,12,-25),Vector3(28,40,-50))
 arena.builder.lighting.apply_preset("afternoon")
 m.hud.visible = true
 m.objective.phase = "capture"
 m.player.global_position = Vector3(-38,.08,21)
 m.player.spawn_protected = m.is_protected(m.player)
 await photo("objective-capture",Vector3(-40,4,34),Vector3(-28,2,25))
 await photo("objective-offscreen",Vector3(-40,4,34),Vector3(-50,4,36))
 m.player.global_position = Vector3(26,.08,25)
 await photo("objective-through-wall",Vector3(26,3,25),Vector3(-28,3,25))
 m.objective.phase = "escort"
 m.objective.capture_progress = 1
 m.objective.checkpoint_index = 2
 m.payload.move_to_distance(163)
 m.player.global_position = Vector3(28,.08,8)
 await photo("objective-payload",Vector3(29,5,5),Vector3(33,2,16))
 m.objective.contested = true
 await photo("objective-contested",Vector3(29,5,5),Vector3(33,2,16))
 m.toggle_menu()
 await frames()
 m.hud.menu.show_museum_lighting()
 await frames()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/museum/lighting/pause-lighting-menu.png")
 arena.queue_free()
 await frames(4)
 quit()
