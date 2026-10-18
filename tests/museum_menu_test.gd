extends SceneTree
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func frames(count: int = 6) -> void:
	for index: int in count: await process_frame

func run() -> void:
	var startup: Node = load("res://scenes/menu/main_menu.tscn").instantiate()
	root.add_child(startup)
	current_scene = startup
	await frames()
	var menu: GameMenu = startup.get_child(0).get_child(0)
	var museum_button: Button
	for child: Node in menu.content.get_children():
		if child is Button and child.text.begins_with("MUSEUM"): museum_button = child
	check(is_instance_valid(museum_button),"startup exposes museum alongside city and training")
	museum_button.pressed.emit()
	check(menu.page == "museum","museum button opens side selection")
	var options: Array[String] = []
	for child: Node in menu.content.get_children():
		if child is Button: options.append(child.text)
	check(options == ["ATTACK","DEFEND","EXPLORE","BACK"],"side selection exposes attack, defense and exploration")
	var choice: Button = menu.content.get_child(4)
	check(choice.text == "DEFEND","defense button is unambiguous")
	choice.pressed.emit()
	check(menu.mode == "museum" and MuseumMatch.selected_side == 1 and menu.page == "heroes","defense selection retains map and opens heroes")
	menu.choose("wisp")
	for index: int in 180:
		await process_frame
		if current_scene != startup: break
	check(current_scene.scene_file_path == "res://scenes/museum/meridian_museum.tscn","choosing a hero launches museum scene")
	var session: MuseumMatch = current_scene.match_controller
	check(session.player.team == 1 and session.player.tuning.hero_id == "wisp","chosen defender hero is playable")
	session.toggle_menu()
	check(paused and session.hud.menu.visible == false,"pause schedules HUD menu visibility update")
	await frames()
	check(session.hud.menu.visible,"museum pause menu displays")
	session.hud.menu.show_heroes()
	session.hud.menu.choose("dynamo")
	check(session.player.kit is DynamoKit and not paused,"pause hero selection changes hero and resumes")
	check(is_equal_approx(session.player.controller.yaw,PI),"spawn hero selection keeps the camera facing museum exits")
	session.toggle_exploration()
	check(session.exploration and session.player.invulnerable and session.player.infinite_resources,"exploration enables safe movement review")
	var before: float = session.time_remaining
	await frames(20)
	check(session.time_remaining == before,"exploration suspends objective clock")
	session.toggle_exploration()
	session.objective.phase = "escort"
	session.objective.payload_distance = 80
	session.restart_match()
	check(session.phase == "preparation" and session.payload_distance == 0 and not session.exploration,"restart returns museum to a fresh round")
	var result := FileAccess.open("res://artifacts/museum/menu.json",FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("MUSEUM MENU ",checks," checks; ",failures.size()," failures")
	current_scene.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
