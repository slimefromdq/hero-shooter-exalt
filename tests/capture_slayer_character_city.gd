extends SceneTree
## Actual city scene, actual player controller camera, then a close inspection camera.
func _initialize() -> void: call_deferred("run")
func step(frames: int) -> void:
 for index: int in frames: await physics_frame; await process_frame
func shot(name: String) -> void:
 await process_frame; await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("res://artifacts/slayer-integration/"+name+".png")==OK)
func run() -> void:
 HeroRoster.selected="slayer"
 var arena: Node3D=load("res://scenes/city/meridian_gardens.tscn").instantiate()
 root.add_child(arena); current_scene=arena
 var city: CityMatch=arena.match_controller
 city.freeze_ai=true
 var player: HeroActor=city.player
 player.controller.active=false
 player.reset_actor(Vector3(8,.01,8)); player.controller.active=false
 var started: int=Time.get_ticks_msec()
 while not city.navigation_ready and Time.get_ticks_msec()-started<30000: await process_frame
 assert(city.navigation_ready)
 await step(12)
 assert(is_instance_valid(player.presentation.slayer_model))
 await shot("city-gameplay")
 var camera:=Camera3D.new(); arena.add_child(camera); camera.current=true
 camera.position=player.global_position+Vector3(-2.2,1.6,-3)
 camera.look_at(player.global_position+Vector3.UP*1.0)
 await step(2); await shot("city-character")
 var slayers: int=1
 for bot: HeroActor in city.bots:
  if bot.kit is SlayerKit:
   assert(is_instance_valid(bot.presentation.slayer_model)); slayers+=1
 print("SLAYER_CITY_RENDER_COMPLETE actors=",slayers)
 arena.queue_free(); await step(3); quit()
