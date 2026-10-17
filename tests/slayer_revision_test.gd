extends SceneTree

var arena: Node3D
var training: TrainingManager
var player: HeroActor
var controller: PlayerController
var checks: int = 0
var failures: Array[String] = []
var native_input: bool = false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func step(frames: int = 1) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame

func kit() -> SlayerKit:
	return player.kit as SlayerKit

func key_event(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func boot_press() -> void:
	if native_input: key_event(KEY_E,true)
	else: player.intent.deflect = true
	await step()
	if native_input: key_event(KEY_E,false)
	else: player.intent.deflect = false

func reset() -> void:
	training.reset_scenario()
	player.controller = controller if native_input else null
	controller.yaw = 0
	controller.pitch = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await step(3)

func run() -> void:
	HeroRoster.selected = "slayer"
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	training = arena.training
	training.scenario = 1
	training.freeze_ai = true
	player = training.player
	controller = player.controller
	native_input = DisplayServer.get_name() != "headless"
	await reset()
	var binding := InputEventKey.new()
	binding.physical_keycode = KEY_E
	check(InputMap.action_has_event("deflect",binding),"physical E is mapped to the boot slot")
	await boot_press()
	check(player.state == "slayer_boot_start" and kit().deflect_cd > 8,"E activates Boot Rush through the live player controller" if native_input else "boot slot intent activates Boot Rush")
	await step(39)
	check(player.position.z < -1 and player.state == "ready","boot travels beyond the old eight-metre limit")
	check(kit().boot_slow_time > 0 and player.permits("primary") and player.permits("jump"),"boot recovery keeps weapon and movement actions available")
	var slow: float = kit().movement_scale()
	player.velocity = Vector3.ZERO
	if native_input: key_event(KEY_D,true)
	else: player.intent.move = Vector3.RIGHT
	await step(12)
	check(kit().movement_scale() > slow and kit().movement_scale() < 1,"recovery slow continuously decays toward full speed")
	var slowed_speed: float = Vector2(player.velocity.x,player.velocity.z).length()
	await step(45)
	check(kit().movement_scale() == 1,"recovery returns to full speed")
	check(slowed_speed < 4.5 and Vector2(player.velocity.x,player.velocity.z).length() > 5.9,"actual movement responds during the slow and returns to running speed")
	if native_input: key_event(KEY_D,false)
	else: player.intent.move = Vector3.ZERO
	await reset()
	var platform: Node3D = Geometry.box(arena,Vector3(3,6,3),Vector3(20,3,10),Color.GRAY)
	player.reset_actor(Vector3(20,6.01,10))
	controller.pitch = 0
	await step(3)
	kit().start_boot()
	await step(40)
	if native_input: key_event(KEY_SPACE,true)
	else: player.intent.jump = true
	await step()
	if native_input: key_event(KEY_SPACE,false)
	else: player.intent.jump = false
	check(not player.is_on_floor() and player.velocity.y < 0,"boot across a ledge does not preserve a stale coyote jump")
	platform.queue_free()
	await reset()
	player.state = "melee_recovery"
	player.state_time = .12
	await boot_press()
	check(kit().boot_buffer > 0 and player.state == "melee_recovery","E is buffered during the end of a committed action")
	await step(8)
	check(player.state in ["slayer_boot_start","slayer_boot_active"],"buffered boot starts when the action becomes legal")
	await reset()
	player.state = "guard"
	player.intent.guard = true
	if native_input: key_event(KEY_6,true)
	await boot_press()
	if native_input: key_event(KEY_6,false)
	player.intent.guard = false
	check(player.state == "slayer_boot_start" and player.close.guard_cd > 1,"boot can intentionally leave guard instead of silently failing")
	await reset()
	kit().ammo = 2
	kit().start_reload()
	await boot_press()
	check(player.state == "slayer_boot_start" and kit().ammo == 2,"E interrupts shell loading without granting ammunition")
	await reset()
	player.spawn_protected = true
	await boot_press()
	check(kit().deflect_cd == 0 and kit().action_hint.contains("SAFE ROOM"),"protected-room rejection gives a visible reason and spends no cooldown")
	player.spawn_protected = false
	await reset()
	player.statuses.apply("root",training.bots[0],1.5)
	await boot_press()
	check(kit().deflect_cd == 0 and kit().action_hint.contains("MOBILITY DISABLED"),"snare rejection gives feedback without spending boot")
	await reset()
	kit().deflect_cd = 5
	await boot_press()
	check(kit().action_hint.contains("s") and player.state == "ready","cooldown rejection shows remaining time")
	await reset()
	kit().throw_knife()
	await step(3)
	check(get_nodes_in_group("owned_attacks").is_empty() and player.presentation.held_knife.visible,"knife windup holds the visible blade until release")
	await step(7)
	check(get_nodes_in_group("knife_trails").size() > 0 and not player.presentation.held_knife.visible,"released knife leaves a visible fading flight trail")
	await step(90)
	check(get_nodes_in_group("knife_trails").is_empty(),"knife trail geometry expires after projectile impact")
	await reset()
	var target: HeroActor = training.bots[0]
	target.reset_actor(player.position + Vector3(0,0,-8))
	await step(3)
	player.aim_direction = Vector3.FORWARD
	player.intent.aim_origin = player.global_position + Vector3.UP * 1.05
	training.hud.numbers.entries.clear()
	kit().fire(false)
	check(is_equal_approx(kit().last_shot_damage,100),"tight close-range shotgun produces the new 100 body damage")
	check(training.hud.numbers.entries.size() == 1 and is_equal_approx(training.hud.numbers.entries[0].amount,100),"world-space damage feedback coalesces all ten pellets")
	check(training.hud.hit_timer >= .75 and training.hud.hit_text == "100","large aggregate damage stays visible longer than the old flash")
	await step(70)
	check(training.hud.numbers.entries.is_empty(),"floating damage numbers expire cleanly")
	await reset()
	check(kit().deploy_trap(),"single trap action accepts nearby clear ground")
	await step(4)
	check(player.presentation.held_trap.visible and kit().traps.is_empty(),"trap anticipation visibly holds the device before the downward release")
	await step(7)
	check(kit().traps.size() == 1 and kit().traps[0].velocity.y < 0,"trap is physically thrown downward instead of appearing on the floor")
	await step(60)
	check(kit().traps[0].armed and kit().traps[0].position.distance_to(player.position) < 2,"downward toss lands nearby and arms")
	var deployed: HunterSnare = kit().traps[0]
	player.position = Vector3(deployed.position.x,.01,deployed.position.z + 1.2)
	await step(2)
	var walk_start: Vector3 = player.position
	if native_input: key_event(KEY_W,true)
	else: player.intent.move = Vector3.FORWARD
	await step(30)
	if native_input: key_event(KEY_W,false)
	else: player.intent.move = Vector3.ZERO
	check(walk_start.z - player.position.z > 2 and not player.statuses.movement_disabled(),"actual character capsule walks over its friendly trap without snagging")
	var trap_hit: Dictionary = player.resolver.ray(deployed.position + Vector3.UP,deployed.position + Vector3.DOWN,[player.get_rid()])
	check(trap_hit.get("collider") == deployed,"the same non-blocking trap remains hittable by normal combat traces")
	await reset()
	kit().deploy_trap()
	player.close.stagger()
	await step(30)
	check(kit().traps.is_empty(),"interrupting the trap throw cancels its pending release")
	await reset()
	target = training.bots[0]
	target.reset_actor(player.position + Vector3(0,0,-2.3))
	await step(3)
	if native_input: key_event(KEY_4,true)
	else: player.intent.throw_action = true
	await step()
	if native_input: key_event(KEY_4,false)
	else: player.intent.throw_action = false
	await step(23)
	check(player.state == "throw_pair" and player.presentation.animator.current_animation == "slayer/thrower","Slayer uses her authored two-handed lift-and-slam throw")
	check(player.presentation.rifle.position.z > 0,"proper throw stows the shotgun away from both hands")
	await step(90)
	check(target.health == 155 and player.state == "ready" and target.close.pair == null,"throw deals damage once at impact and releases both participants")
	var report: String = "slayer-revision-native-results.json" if native_input else "slayer-revision-results.json"
	var file := FileAccess.open("res://artifacts/" + report,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"native_input":native_input},"\t"))
	print("SLAYER REVISION RESULT: %d checks, %d failures" % [checks,failures.size()])
	for actor: HeroActor in get_nodes_in_group("actors"):
		actor.presentation.sound.stop()
		actor.presentation.sound.stream = null
	var until: int = Time.get_ticks_msec() + 100
	while Time.get_ticks_msec() < until: await process_frame
	arena.queue_free()
	await step(3)
	quit(0 if failures.is_empty() else 1)
