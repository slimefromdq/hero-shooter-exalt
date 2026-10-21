extends SceneTree
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",caption)
	if not ok: failures.append(caption)

func frames(count: int = 6) -> void:
	for index: int in count: await process_frame

func find_button(menu: GameMenu, caption: String) -> Button:
	for child: Node in menu.content.get_children():
		if child is Button and child.text.begins_with(caption): return child
	return null

func run() -> void:
	var startup: Node = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(startup)
	current_scene = startup
	await frames()
	var menu: GameMenu = startup.get_child(0).get_child(0)
	var entry: Button = find_button(menu,"SAKURA VEIL")
	check(is_instance_valid(entry),"main menu exposes Sakura Veil")
	entry.pressed.emit()
	check(menu.page == "temple","map opens team selection")
	check(find_button(menu,"ROOT TEAM") != null and find_button(menu,"CLOUD TEAM") != null and find_button(menu,"EXPLORE") != null,"both symmetric teams and Explore available")
	find_button(menu,"CLOUD TEAM").pressed.emit()
	check(menu.mode == "temple" and TempleMatch.selected_side == 1 and menu.page == "heroes","Cloud selection persists through hero choice")
	menu.choose("stitch")
	while current_scene == startup: await process_frame
	check(current_scene.scene_file_path == "res://scenes/temple/sakura_veil.tscn","hero selection launches temple")
	var m: TempleMatch = current_scene.match_controller
	check(m.player.team == 1 and m.player.tuning.hero_id == "stitch" and m.team_count(0) == 6 and m.team_count(1) == 6,"Cloud hero occupies one of twelve slots")
	m.toggle_menu()
	await frames()
	check(paused and m.hud.menu.visible,"pause menu displays and pauses simulation")
	m.hud.menu.show_heroes()
	m.hud.menu.choose("slayer")
	check(not paused and m.player.kit is SlayerKit,"hero switching in spawn resumes temple session")
	check(is_equal_approx(m.player.controller.yaw,PI),"Cloud camera continues facing the spawn exits")
	m.toggle_exploration()
	var before: float = m.objective.time_remaining
	await frames(10)
	check(m.exploration and m.player.infinite_resources and m.objective.time_remaining == before,"Explore provides a paused movement review session")
	m.restart_match()
	check(not m.exploration and m.objective.owners == [0,0,-1,1,1] and m.stages == [0,0],"restart resets territory and forward spawns")
	var world_map: RID = current_scene.get_world_3d().navigation_map
	var previous_cell: float = current_scene.previous_cell_size
	m.hud.menu.go_main()
	while current_scene is Node3D: await process_frame
	await frames()
	check(is_equal_approx(NavigationServer3D.map_get_cell_size(world_map),previous_cell),"leaving temple restores other maps' navigation settings")
	var result := FileAccess.open("res://artifacts/temple/menu.json",FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	result.close()
	print("TEMPLE MENU %d checks, %d failures" % [checks,failures.size()])
	current_scene.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
