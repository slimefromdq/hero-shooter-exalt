extends "res://tests/roster_input_test.gd"
## Runs headless for regression; run natively with -- --capture for review PNGs.

var live_actor: HeroActor
var live_controller: PlayerController

func press(action: String, frames: int = 2) -> void:
	if DisplayServer.get_name() != "headless":
		await super.press(action,frames)
		return
	var input := CombatIntent.new()
	input.aim = -live_controller.camera.global_basis.z
	input.aim_origin = live_controller.camera.global_position
	input.set(action,true)
	live_actor.intent = input
	await step(1)
	input.set(action,false)
	await step(frames+2)

func capture(caption: String) -> void:
	if DisplayServer.get_name() == "headless" or not "--capture" in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/samson-"+caption+".png")

func run() -> void:
	HeroRoster.selected = "samson"
	var arena: Node3D = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var training: TrainingManager = arena.training
	training.freeze_ai = true
	training.scenario = 1
	training.reset_scenario()
	training.despawn_bots()
	var actor: HeroActor = training.player
	var k := actor.kit as SamsonKit
	var controller: PlayerController = actor.controller
	live_actor = actor
	live_controller = controller
	if DisplayServer.get_name() == "headless": actor.controller = null
	controller.yaw = 0
	controller.pitch = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var friend: HeroActor = training.spawn_bot(0,Vector3(0,.1,3),false,actor.team)
	friend.health = 80
	await step(10)
	await capture("hud")
	check(actor.tuning.hero_id == "samson" and k.charges == 2,"training selection creates playable Samson")
	await press("hover")
	await step(30)
	check(k.charges == 1 and friend.health == 136.875 and friend.overhealth.value() > 0,"bound Q event rescues ally and displays overhealth")
	await capture("intervene")
	var enemy: HeroActor = training.spawn_bot(0,Vector3(0,.1,-5))
	var look: Vector3 = (enemy.body_point(1.2)-controller.camera.global_position).normalized()
	controller.yaw = atan2(-look.x,-look.z)
	controller.pitch = asin(look.y)
	await step(5)
	await capture("enemy-selection")
	await press("deflect")
	check(actor.state == "samson_cross","bound E starts Cross-Examination")
	await step(35)
	await capture("channel")
	await step(65)
	check(enemy.statuses.stunned() or enemy.statuses.silenced(),"live physics completes cross and applies disable")
	await capture("silence")
	controller.pitch = -.35
	await step(3)
	await press("bomb")
	check(is_instance_valid(k.notice),"bound 1 places ground injunction")
	await capture("notice")
	await press("ultimate")
	await step(45)
	check(k.ultimate_active() and k.court.health == 750,"bound 2 summons 750-HP court")
	await capture("court-hud")
	if is_instance_valid(k.court):
		var camera := Camera3D.new()
		arena.add_child(camera)
		camera.current = true
		camera.position = k.court.position+Vector3(13,9,15)
		camera.look_at(k.court.position)
		training.hud.visible = false
		await step(2)
		await capture("court")
	actor.controller = controller
	training.start_samson_drill()
	check(training.scenario == 16 and training.bots.size() == 3,"Samson drill includes injured witness and two threats")
	training.freeze_ai = true
	if training.player.controller != null: training.player.controller.active = false
	await step(2)
	var bot: HeroActor = training.spawn_bot(14,Vector3(5,.1,8),false,training.player.team)
	check(bot.kit is SamsonKit,"manual Samson support bot profile instantiates the correct hero")
	var witness: HeroActor = training.bots[0]
	bot.position = Vector3(5,.1,8)
	witness.position = Vector3(5,.1,0)
	witness.health = 50
	await step(3)
	bot.intent.aim_origin = bot.body_point(1.5)
	var input := CombatIntent.new()
	input.aim_origin = bot.body_point(1.5)
	SamsonTactics.apply(bot,input)
	check(input.hover,"legacy bot tactics prioritize endangered ally")
	bot.intent = input
	bot.aim_direction = input.aim
	bot.kit.tick(.01,input)
	check((bot.kit as SamsonKit).charges == 1,"bot rescue uses ordinary intent and finite charge")
	check(BotHeroProfile.for_hero("samson").hero == "samson","Samson tactical hero profile loads")
	arena.queue_free()
	await step(4)
	for path: String in ["res://scenes/city/meridian_gardens.tscn","res://scenes/museum/meridian_museum.tscn"]:
		arena = load(path).instantiate()
		root.add_child(arena)
		current_scene = arena
		var session: CityMatch = arena.match_controller
		session.freeze_ai = true
		session.player.controller.active = false
		await step(8)
		check(session.player.kit is SamsonKit and session.actors.size() == 12,"Samson selects into twelve-actor match " + path)
		session.select_hero("doctor")
		if session.pending_hero != "": session.apply_pending_hero()
		check(session.player.kit is DoctorKit,"existing hero remains selectable after Samson")
		session.select_hero("samson")
		if session.pending_hero != "": session.apply_pending_hero()
		check(session.player.kit is SamsonKit,"queued hero factory returns to Samson")
		arena.queue_free()
		await step(4)
	check(get_nodes_in_group("movement_zones").is_empty() and get_nodes_in_group("protection_fields").is_empty(),"scene transitions release all Samson fields")
	print("SAMSON INTEGRATION: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/samson-integration-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
