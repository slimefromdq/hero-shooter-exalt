extends SceneTree
var arena: Node3D
var checks: int = 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
 checks += 1
 print("PASS  " if ok else "FAIL  ",caption)
 if not ok: failures.append(caption)
func frames(count: int = 2) -> void:
 for index: int in count:
  await physics_frame
  await process_frame
func run() -> void:
 var preference_existed: bool = FileAccess.file_exists(MuseumLighting.PREFERENCE_PATH)
 var preference_backup: String = FileAccess.get_file_as_string(MuseumLighting.PREFERENCE_PATH) if preference_existed else ""
 var selected_backup: String = MuseumLighting.selected_preset
 var loaded_backup: bool = MuseumLighting.preference_loaded
 MuseumLighting.choose("afternoon",false)
 arena = load("res://scenes/museum/meridian_museum.tscn").instantiate()
 root.add_child(arena)
 current_scene = arena
 var session: MuseumMatch = arena.match_controller
 session.set_physics_process(false)
 session.player.controller.active = false
 for actor: HeroActor in session.actors: actor.set_physics_process(false)
 var start: int = Time.get_ticks_msec()
 while not session.navigation_ready and Time.get_ticks_msec()-start < 30000:
  session._physics_process(0)
  await frames(1)
 check(session.navigation_ready,"presentation additions preserve museum navigation")
 var lighting: MuseumLighting = arena.builder.lighting
 var collision_count: int = arena.builder.architecture.collision_body.get_child_count()
 var lamp_count: int = lighting.lamps.size()
 var node_count: int = lighting.get_child_count()
 var time_before: float = session.time_remaining
 check(lighting.environment.fog_sky_affect == 0,"distance fog preserves procedural clouds and stars")
 for id: String in MuseumLighting.IDS:
  check(lighting.apply_preset(id),"lighting accepts "+id)
  check(lighting.current_preset == id,"lighting reports active preset "+id)
  check(lighting.key_light.light_energy > 0 and lighting.environment.ambient_light_energy >= .3,"terrain and heroes retain readable lighting in "+id)
  check(lighting.lamps.size() == lamp_count and lamp_count == 22,"bounded interior lights are reused in "+id)
  check(lighting.get_child_count() == node_count and arena.builder.architecture.collision_body.get_child_count() == collision_count,"lighting changes add neither nodes nor collision in "+id)
  check(lighting.environment.glow_enabled and lighting.fixture_material.emission_enabled,"museum fixtures glow in "+id)
  check(is_equal_approx(float(lighting.sky_material.get_shader_parameter("stars_strength")),1.0 if id == "night" else 0.0),"stars appear only at night")
  check(is_equal_approx(lighting.lamps[0].light_energy,float(MuseumLighting.PRESETS[id].lamps)),"interior light strength matches "+id)
 check(session.time_remaining == time_before,"switching time of day does not change objective time")
 check(not lighting.apply_preset("invalid") and lighting.current_preset == "night","invalid preset preserves current environment")
 check(not MuseumLighting.choose("invalid",false),"invalid saved preference is rejected")
 var marker: MuseumObjectiveMarker = arena.objective_marker
 session.objective.phase = "preparation"
 marker._process(0)
 check(marker.visible and marker.global_position == session.definition.hill_center,"preparation guides players to capture A")
 session.objective.phase = "capture"
 check(session.active_objective_caption() == "CAPTURE A","attacker guidance names the capture objective")
 var original_team: int = session.player.team
 session.player.team = 1
 check(session.active_objective_caption() == "DEFEND A","defender guidance names the capture objective")
 session.player.team = original_team
 session.objective.phase = "escort"
 session.objective.capture_progress = 1
 session.objective.checkpoint_index = 1
 session.payload.move_to_distance(session.museum_definition().checkpoint_distances()[0]+3)
 marker._process(0)
 check(marker.global_position == session.payload.global_position and marker.label.text == "PAYLOAD / CP2","unlock replaces capture beacon with moving payload guidance")
 check("CP2" in session.active_objective_caption(),"payload caption identifies next checkpoint")
 session.objective.contested = true
 marker._process(0)
 check(marker.label.modulate == Color("ff687b"),"contested objective beacon changes color")
 session.objective.phase = "finished"
 marker._process(0)
 check(not marker.visible,"finished round hides objective beacon")
 session.restart_match()
 marker._process(0)
 check(marker.visible and marker.global_position == session.definition.hill_center,"restart restores capture objective guidance")
 var camera := Camera3D.new()
 arena.add_child(camera)
 camera.position = Vector3(0,2,0)
 camera.look_at(Vector3(0,2,-10))
 var old_size: Vector2i = root.size
 for size: Vector2i in [Vector2i(1440,900),Vector2i(1280,800),Vector2i(960,600),Vector2i(2560,1080)]:
  root.size = size
  await frames()
  var view: Vector2 = root.get_visible_rect().size
  var front: Dictionary = MuseumObjectiveMarker.screen_layout(camera,Vector3(0,2,-30),view)
  check(not front.edge and (front.position as Vector2).distance_to(Vector2(800,450)) < 1,"on-screen marker projects correctly at "+str(size))
  for target: Vector3 in [Vector3(100,2,-2),Vector3(-100,2,-2),Vector3(0,2,30),Vector3(0,80,-2),Vector3(0,-80,-2)]:
   var at: Dictionary = MuseumObjectiveMarker.screen_layout(camera,target,view)
   check(at.edge and Rect2(159,389,1282,232).has_point(at.position) and (at.direction as Vector2).length() > .99,"off-screen/behind objective stays on safe HUD boundary at "+str(size)+str(target))
 root.size = old_size
 var startup := GameMenu.new()
 root.add_child(startup)
 startup.show_museum()
 var selector: OptionButton = startup.find_child("MuseumLightingPreset",true,false)
 check(is_instance_valid(selector) and selector.item_count == 3,"startup museum menu exposes three lighting choices")
 selector.select(2)
 selector.item_selected.emit(2)
 MuseumLighting.preference_loaded = false
 check(MuseumLighting.load_preference() == "night","lighting preference survives save/load")
 startup.queue_free()
 session.toggle_menu()
 await frames()
 var menu := session.hud.menu as GameMenu
 menu.show_museum_lighting()
 selector = menu.find_child("MuseumLightingPreset",true,false)
 selector.select(0)
 selector.item_selected.emit(0)
 check(paused and lighting.current_preset == "dawn","pause menu applies lighting immediately while physics stays paused")
 session.toggle_menu()
 session.restart_match()
 check(lighting.current_preset == "dawn","round restart retains selected lighting")
 if preference_existed:
  var backup_file := FileAccess.open(MuseumLighting.PREFERENCE_PATH,FileAccess.WRITE)
  backup_file.store_string(preference_backup)
  backup_file.close()
 else: DirAccess.remove_absolute(ProjectSettings.globalize_path(MuseumLighting.PREFERENCE_PATH))
 MuseumLighting.selected_preset = selected_backup
 MuseumLighting.preference_loaded = loaded_backup
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/museum"))
 var file := FileAccess.open("res://artifacts/museum/presentation.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("MUSEUM PRESENTATION ",checks," checks; ",failures.size()," failures")
 arena.queue_free()
 await frames(3)
 quit(0 if failures.is_empty() else 1)
