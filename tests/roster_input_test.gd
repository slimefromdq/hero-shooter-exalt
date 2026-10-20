extends SceneTree
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func step(count: int = 2) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func event(action: String, down: bool) -> void:
	var value: InputEvent = InputMap.action_get_events(action)[0].duplicate()
	value.pressed = down
	Input.parse_input_event(value)
	Input.flush_buffered_events()

func press(action: String, frames: int = 2) -> void:
	event(action,true)
	await step(frames)
	event(action,false)
	await step(2)

func run() -> void:
	HeroRoster.selected = "relay"
	var arena: Node = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var training: TrainingManager = arena.training
	training.freeze_ai = true
	training.scenario = 1
	training.reset_scenario()
	training.despawn_bots()
	var actor: HeroActor = training.player
	var controller: PlayerController = actor.controller
	controller.yaw = 0
	controller.pitch = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var friend: HeroActor = training.spawn_bot(0,Vector3(0,.1,3),false,actor.team)
	friend.health = 50
	await step(10)
	await press("aim")
	var relay := actor.kit as RelayKit
	check(relay.recipient == friend,"native RMB assigns the aimed ally")
	await step(30)
	check(friend.health > 50 and relay.battery < 100,"drone heals without holding RMB")
	var ammo: int = relay.ammo
	await press("primary",10)
	check(relay.ammo < ammo,"native LMB fires carbine while the drone is deployed")
	await press("bomb")
	check(relay.recipient == null,"native 1 recalls drone")
	relay.transfer_cd = 0
	await press("bomb")
	check(relay.recipient == actor,"native 1 while docked selects self healing")
	await press("deflect")
	check(relay.deflect_cd > 0,"native E activates the drone blast")
	await press("hover")
	check(relay.mobility_cd > 0 and actor.position.y > .2,"native Q launches Kickstart")
	training.select_hero("dynamo")
	training.despawn_bots()
	actor = training.player
	var dynamo := actor.kit as DynamoKit
	await step(4)
	event("aim",true)
	await step(120)
	check(dynamo.spin > .99 and dynamo.ammo == 180,"native held RMB fully prespins without firing")
	event("aim",false)
	await press("primary",12)
	check(dynamo.ammo < 180,"native held LMB fires the minigun")
	await press("hover")
	check(dynamo.charge_left > 0,"native Q imbues lightning")
	await press("deflect")
	check(dynamo.previewing,"native E enters wall preview")
	var rotation_before: float = dynamo.wall_turn
	await press("aim")
	check(dynamo.wall_turn > rotation_before,"native RMB rotates wall preview")
	await press("deflect")
	check(not dynamo.previewing and dynamo.deflect_cd == 0,"native E cancels preview without a cooldown")
	await press("deflect")
	await press("primary")
	check(is_instance_valid(dynamo.wall) and not dynamo.previewing,"native LMB confirms a valid physical wall")
	await press("deflect")
	check(not is_instance_valid(dynamo.wall) and dynamo.deflect_cd > 0,"native E dismisses a wall while keeping its cooldown")
	controller.pitch = -.2
	await step(5)
	await press("bomb")
	check(dynamo.bomb_cd > 0,"native 1 places Lodestone")
	await press("ultimate")
	check(actor.state == "dynamo_storm_start" and dynamo.ultimate_charge == 100,"native storm preparation preserves charge")
	await step(55)
	check(dynamo.ultimate_active() and dynamo.ultimate_charge == 0,"native storm activates after its warning")
	training.select_hero("wisp")
	training.despawn_bots()
	actor = training.player
	var wisp := actor.kit as WispKit
	check(wisp.shells == 0,"selected Wisp begins with no shells")
	await step(5)
	await press("hover")
	var immune_time: float = wisp.step_immunity_left
	training.toggle_menu()
	await step(12)
	check(immune_time > 0 and is_equal_approx(immune_time,wisp.step_immunity_left),"pause freezes Q immunity timer")
	training.toggle_menu()
	await step(18)
	check(wisp.steps == 2 and wisp.shells == 1,"native Q dashes and loads one shell [steps=%d shells=%d position=%s]" % [wisp.steps,wisp.shells,str(actor.position)])
	await press("aim")
	check(wisp.shells == 0 and wisp.secondary_cd > 0,"native RMB fires Soulbreaker")
	await press("deflect")
	check(actor.state == "wisp_phase","native E starts phase")
	var remaining_ammo: int = wisp.ammo
	await press("primary",5)
	check(wisp.ammo == remaining_ammo,"native LMB cannot fire during phase")
	await press("deflect")
	check(actor.state == "ready" and wisp.phase_recovery_left > 0,"native second E cancels into vulnerable recovery")
	await press("primary",5)
	check(wisp.ammo == remaining_ammo,"native cancellation cannot produce an instant shot")
	await step(80)
	await press("bomb")
	check(wisp.glide_left > 0 and actor.velocity.y > 0,"native 1 launches Majestic Leap")
	var leap_ammo: int = wisp.ammo
	await press("primary")
	check(wisp.ammo < leap_ammo,"native pistol fire works during leap")
	await step(10)
	await press("bomb")
	check(wisp.diving and actor.velocity.y < -20,"native second 1 dives during the eight-second cooldown")
	wisp.shot_cd = 0
	leap_ammo = wisp.ammo
	await press("primary")
	check(wisp.ammo < leap_ammo,"native pistol fire works during dive")
	wisp.ultimate_charge = 100
	await press("ultimate")
	await step(80)
	check(is_instance_valid(wisp.heist) and wisp.heist.armed and wisp.ultimate_charge < 10,"native 2 throws and arms Grand Heist")
	training.toggle_menu()
	var duration: float = wisp.heist.remaining
	await step(12)
	check(is_equal_approx(duration,wisp.heist.remaining),"pause freezes the calling-card warning")
	training.toggle_menu()
	await step(260)
	check(actor.state == "ready" and not wisp.ultimate_active(),"native heist completes and restores ordinary controls")
	arena.queue_free()
	await step(4)
	print("ROSTER INPUT: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/roster-input-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
