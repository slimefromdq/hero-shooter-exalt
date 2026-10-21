extends SceneTree
var world: Node3D
var resolver: CombatResolver
var a: HeroActor
var b: HeroActor
var failures: int = 0
var checks: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",caption)

func step(count: int = 1) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func reset(hero: String = "nimbus", at: Vector3 = Vector3(0,.01,5)) -> void:
	a.select_hero(hero)
	a.reset_actor(at)
	b.reset_actor(Vector3(0,.01,-20))
	await step(3)

func run() -> void:
	TrainingInputs.install()
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(100,1,160),Vector3(0,-.5,-20),Color.GRAY)
	a = HeroActor.new()
	a.team = 0
	a.position = Vector3(0,.01,5)
	world.add_child(a)
	b = HeroActor.new()
	b.team = 1
	b.position = Vector3(0,.01,-20)
	world.add_child(b)
	await step(3)
	await movement()
	await reloads()
	await boots()
	await bombs()
	await ultimate()
	await menus_and_range()
	world.queue_free()
	await step(2)
	print("QOL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func movement() -> void:
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	check(InputMap.action_has_event("dash",wheel),"dash uses wheel up")
	check(TrainingInputs.key_label("dash") == "WHEEL UP","wheel prompt is readable")
	var old := InputEventKey.new()
	old.physical_keycode = KEY_3
	check(not InputMap.action_has_event("dash",old),"old 3 binding removed")
	await reset()
	a.intent.aim = Vector3(0,1,-1).normalized()
	a.intent.dash = true
	await step()
	a.intent.dash = false
	await step(11)
	check(not a.motor.dash_airborne and absf(a.motor.dash_direction.y) < .001,"ground dash stays horizontal")
	check(a.motor.mode != "slide","ground dash cannot auto-slide")
	for timing: String in ["fresh","held","expired"]:
		await reset()
		a.global_position = Vector3(0,.55,5)
		a.motor.dash_airborne = true
		a.motor.dash_direction = Vector3(0,-.6,-1).normalized()
		a.motor.dash_current_speed = 22
		a.motor.slide_rearmed = false
		a.motor.transition("dash",.35)
		a.intent.slide = true
		a.intent.slide_pressed = timing == "fresh"
		a.motor.slide_press_age = .13 if timing == "expired" else 99.0
		await step()
		a.intent.slide_pressed = false
		await step(4)
		check((a.motor.mode == "slide") == (timing == "fresh"),"air dash landing / "+timing)
		check(a.velocity.length() <= 22.01,"dash conversion never creates speed")
	await reset()
	a.velocity = Vector3(8,0,0)
	a.intent.slide = true
	a.motor.transition("slide")
	a.kit.ammo = 2
	a.kit.fire(false)
	check(a.kit.ammo == 2,"sliding shots preserve loaded ammo")
	a.intent.slide = false
	a.motor.transition("ground")
	a.kit.shot_cd = 0
	a.kit.fire(false)
	check(a.kit.ammo == 1,"ordinary shots consume ammo again")
	check(a.tuning.melee_lunge_distance == 6.5 and a.tuning.melee_lunge_duration == .4,"longer shared melee tuning")

func reloads() -> void:
	for hero: String in HeroRoster.IDS:
		await reset(hero)
		if a.kit is RelayKit:
			a.kit.start_reload()
			check(not a.kit.reloading and a.permits("primary"),"Seeker infinite bow ignores reload and remains ready")
			continue
		a.kit.ammo = 0
		a.kit.start_reload()
		check(a.state == "ready" and a.kit.reloading,hero+" reload is independent")
		check(a.permits("jump") and a.permits("dash") and a.permits("melee"),hero+" reload permits movement and combat actions")
		check(not a.permits("primary"),hero+" reload blocks fire")
		a.intent.move = Vector3.RIGHT
		await step(22)
		check(a.velocity.x >= a.tuning.ground_speed-.1,hero+" reload has no speed penalty")
		a.state = "stagger"
		a.state_time = .3
		await step(maxi(100,ceili(a.kit.reload_remaining*60)+3))
		check(not a.kit.reloading and a.kit.ammo == a.tuning.magazine,hero+" reload finishes through CC")
		a.kit.ammo = 0
		a.kit.start_reload()
		a.reset_actor()
		check(not a.kit.reloading,hero+" reset clears reload")
	await reset("slayer")
	a.kit.ammo = 2
	a.kit.start_reload()
	await step(24)
	check(a.kit.ammo == 3 and a.kit.reloading,"Slayer inserts first shell at .37 seconds")
	check(not a.permits("primary"),"inserted shells cannot cancel active reload")

func boots() -> void:
	await reset("slayer")
	b.reset_actor(Vector3(0,.01,1))
	(a.kit as SlayerKit).start_boot()
	for index: int in 20:
		await step()
		if a.boot_pair != null: break
	check(a.boot_pair != null and b.boot_pair == a.boot_pair,"boot creates one shared attachment")
	check(b.health == 195 and not b.permits("primary"),"boot deals 55 once and holds victim")
	check(not ControlFeedback.snapshot(b).is_empty(),"boot hold has CC feedback")
	a.intent.aim = Vector3.RIGHT
	await step(42)
	check(a.boot_pair == null and b.boot_pair == null,"boot releases automatically")
	check(b.global_position.x > 1 and b.health == 195,"kick follows final facing without second damage")
	for reason: String in ["cleanse","death","push","reset","stagger"]:
		await reset("slayer")
		b.reset_actor(Vector3(0,.01,1))
		var pair := BootAttachment.new()
		pair.configure(a,b)
		match reason:
			"cleanse": b.statuses.cleanse()
			"death": b.die()
			"push": resolver.knockback(a,b,Vector3.RIGHT,"test")
			"reset": a.reset_actor()
			"stagger": a.close.stagger()
		check(a.boot_pair == null and b.boot_pair == null,"boot cleanup / "+reason)
		await step(30)
		check(pair.ended,"interrupted attachment cannot kick later / "+reason)

func bombs() -> void:
	await reset()
	var bomb := PocketBomb.new()
	bomb.source = a
	bomb.cast_id = resolver.new_cast(a)
	world.add_child(bomb)
	bomb.global_position = Vector3(0,2,0)
	bomb.set_physics_process(false)
	await step()
	var from := Vector3(0,2,4)
	var to := Vector3(0,2,-4)
	check(resolver.weapon_ray(a,from,to,[a.get_rid()]).get("collider") == bomb,"owner can aim at airborne bomb")
	check(resolver.weapon_ray(b,from,to,[b.get_rid()]).is_empty(),"others ignore airborne bomb")
	bomb.receive_shot(b)
	check(not bomb.detonated,"enemy shot cannot detonate")
	bomb.airborne = false
	bomb.receive_shot(a)
	check(not bomb.detonated and resolver.weapon_ray(a,from,to).is_empty(),"first impact removes shoot eligibility")
	bomb.airborne = true
	bomb.receive_shot(a)
	bomb.explode()
	check(resolver.events.filter(func(e: Dictionary) -> bool: return e.event == "detonate").size() == 1,"bomb detonates exactly once")
	check(a.tuning.bomb_damage == 140 and a.tuning.bomb_radius == 5 and a.tuning.bomb_fuse == 2,"strong bomb tuning")
	await step()

func ultimate() -> void:
	await reset()
	a.intent.ultimate = true
	await step()
	a.intent.ultimate = false
	check((a.kit as NimbusKit).ultimate_remaining == 3 and a.state_time > 7.9,"ultimate begins with three shots / eight seconds")
	a.intent.primary = true
	await step(10)
	check((a.kit as NimbusKit).ultimate_remaining == 3,"ultimate preparation rejects early shots")
	a.intent.primary = false
	await step(30)
	for count: int in 3:
		a.intent.primary = true
		await step()
		a.intent.primary = false
		check((a.kit as NimbusKit).ultimate_remaining == 2-count,"ultimate consumes shot %d" % (count+1))
		await step(37)
	check(a.state == "ready","third shot ends stance")

func menus_and_range() -> void:
	var layer := CanvasLayer.new()
	world.add_child(layer)
	var menu := GameMenu.new()
	layer.add_child(menu)
	menu.show_heroes()
	check(menu.page == "heroes","dedicated hero select builds")
	menu.show_settings()
	check(menu.page == "settings","shared settings menu builds")
	var sensitivity: float = root.get_node("GameSettings").values.sensitivity
	root.get_node("GameSettings").set_setting("sensitivity",.003)
	check(root.get_node("GameSettings").values.sensitivity == .003,"settings update and persist")
	root.get_node("GameSettings").set_setting("sensitivity",sensitivity)
	layer.queue_free()
	var arena: Node = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	world.add_child(arena)
	await step(4)
	var training: TrainingManager = arena.training
	training.freeze_ai = true
	check(training.scenario == 11 and training.bots.size() == 15,"practice range is default with fifteen built-ins")
	var range_node: PracticeRange = training.practice_range
	check(range_node.groups.aoe.size() == 6 and range_node.groups.allies.size() == 3,"six AoE targets and three allies")
	check(not range_node.firing,"shooters begin disabled")
	range_node.toggle_firing()
	check(range_node.firing and range_node.groups.shooting[0].controller.enabled,"map control enables shooters")
	range_node.reset_group("shooting")
	check(not range_node.firing,"station reset disables shooters")
	range_node.set_health("aoe",25)
	for dummy: HeroActor in range_node.groups.aoe:
		training.player.resolver.damage(training.player,dummy,100,"bomb",training.player.resolver.new_cast(training.player))
	check(training.feedback.kills == 6 and training.feedback.banner.contains("SEXTUPLE"),"real dummy kills produce sextuple feedback")
	for index: int in 8: training.spawn_bot(0,Vector3(index*2,.01,20))
	check(training.bots.size() == 23 and training.spawn_bot(0) == null,"manual target cap is independent of built-ins")
	await step(215)
	check(range_node.groups.aoe.all(func(dummy: HeroActor) -> bool: return dummy.alive),"dummy respawn restores all targets")
	var ally: HeroActor = range_node.groups.allies[0]
	var before: float = ally.health
	training.player.resolver.heal(training.player,ally,50,"test")
	check(ally.health > before,"ally dummy accepts ordinary healing")
	training.toggle_menu()
	check(training.menu_open and paused and training.hud.menu.visible,"training pause opens shared menu")
	training.toggle_menu()
	check(not paused,"resume restores simulation")
	arena.queue_free()
	await step(3)
