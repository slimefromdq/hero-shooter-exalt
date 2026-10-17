extends SceneTree

var world: Node3D
var attacker: HeroActor
var defender: HeroActor
var resolver: CombatResolver
var blocks: int = 0
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	print("PASS  " if condition else "FAIL  ", description)
	if not condition: failures.append(description)

func step(frames: int = 1) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame

func reset() -> void:
	attacker.reset_actor(Vector3(0,.01,0))
	defender.reset_actor(Vector3(0,.01,-1.4))
	defender.intent.aim = Vector3.BACK
	defender.aim_direction = Vector3.BACK
	resolver.clear_round()
	await step(3)

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	resolver.confirmed_block.connect(func(_a: HeroActor,_d: HeroActor) -> void: blocks += 1)
	Geometry.box(world,Vector3(60,1,60),Vector3(0,-.5,0),Color.GRAY)
	attacker = preload("res://scenes/actors/hero_actor.tscn").instantiate()
	world.add_child(attacker)
	defender = preload("res://scenes/actors/hero_actor.tscn").instantiate()
	defender.team = 1
	world.add_child(defender)
	await reset()
	defender.intent.guard = true
	await step(5)
	check(blocks == 0 and defender.presentation.block_flash == 0, "holding guard alone produces no success feedback")
	attacker.intent.melee = true
	await step()
	attacker.intent.melee = false
	for frame: int in 30:
		await step()
		if attacker.state == "stagger": break
	check(blocks == 1 and defender.health == 250, "a real frontal melee block emits one confirmed event and prevents damage")
	check(defender.presentation.block_flash > 0 and is_instance_valid(defender.presentation.block_effect), "confirmed block triggers shield flash and impact geometry")
	check(defender.presentation.block_sound.stream == ProceduralSound.guard_clang(), "confirmed block selects its dedicated metallic clang stream")
	check(attacker.presentation.block_flash == 0, "block success feedback belongs to the defender")
	var duplicate: String = resolver.damage(attacker,defender,75,"melee",attacker.close.cast_id)
	check(duplicate == "duplicate" and blocks == 1, "the same strike cannot retrigger clang or impact")
	var anchor: Vector3 = attacker.global_position
	await step(5)
	check(attacker.presentation.animator.current_animation == "stagger", "blocked attacker plays the explicit recoil animation")
	check(attacker.presentation.stagger_marks.visible, "daze markers make the stagger readable above the shield")
	check(attacker.presentation.model.rotation.x < -.5 and attacker.presentation.model.position.z > .2, "stagger visibly snaps the torso back and away")
	check(absf(attacker.presentation.left_arm.rotation.z) > 1 and attacker.presentation.left_leg.get_node("Joint").rotation.x > .5, "stagger throws arms outward and buckles the knee")
	check(attacker.global_position.distance_to(anchor) < .01, "visual recoil leaves the stationary collision capsule planted")
	check(not attacker.permits("primary") and not attacker.permits("melee"), "stagger presentation preserves the existing action lock")
	await step(36)
	check(attacker.state == "ready" and attacker.presentation.model.rotation.length() < .01, "original 0.55 s stagger ends with a clean standing pose")
	check(defender.presentation.block_flash == 0 and not is_instance_valid(defender.presentation.block_effect), "block flash and world effect expire after impact")
	var wave: AudioStreamWAV = ProceduralSound.guard_clang()
	var peak: int = 0
	var early_energy: float = 0
	var late_energy: float = 0
	for index: int in wave.data.size() / 2:
		var value: int = wave.data.decode_s16(index * 2)
		peak = maxi(peak, absi(value))
		if index < 2205: early_energy += absi(value)
		if index > wave.data.size() / 2 - 2205: late_energy += absi(value)
	check(wave.mix_rate == 44100 and is_equal_approx(wave.get_length(),.36), "clang is a finite 44.1 kHz 0.36 s waveform")
	check(peak > 15000 and peak < 32767 and early_energy > late_energy * 10, "clang has a strong unclipped attack and a decaying tail")
	await reset()
	defender.intent.guard = true
	await step()
	var before: int = blocks
	resolver.damage(attacker,defender,45,"rifle",resolver.new_cast())
	check(defender.health == 205 and blocks == before and defender.presentation.block_flash == 0, "bullets do ordinary damage without false melee block feedback")
	attacker.global_position = defender.global_position + Vector3.FORWARD * 1.4
	resolver.damage(attacker,defender,75,"melee",resolver.new_cast())
	check(defender.health == 130 and blocks == before, "rear melee bypasses guard without success feedback")
	await reset()
	defender.intent.guard = true
	await step()
	defender.close.guard_meter = 10
	resolver.damage(attacker,defender,75,"melee",resolver.new_cast())
	check(defender.state == "stagger" and defender.presentation.block_flash > 0, "a strike that exhausts guard still presents its successful block")
	defender.reset_actor()
	await step()
	check(defender.presentation.block_flash == 0 and not is_instance_valid(defender.presentation.block_effect), "reset clears an in-flight impact and its sound")
	await reset()
	defender.intent.guard = true
	await step()
	resolver.damage(attacker,defender,75,"melee",resolver.new_cast())
	defender.die()
	await step()
	check(defender.presentation.block_flash == 0 and not is_instance_valid(defender.presentation.block_effect) and not defender.presentation.stagger_marks.visible, "death clears lingering block feedback and daze markers")
	await reset()
	defender.global_position.z = -20
	attacker.kit.ammo = 3
	attacker.intent.reload = true
	attacker.intent.move = Vector3.RIGHT
	await step()
	attacker.intent.reload = false
	await step(20)
	check(attacker.state == "reload" and is_equal_approx(attacker.velocity.x,5.1), "reload allows 85 percent ground movement: 5.1 m/s")
	attacker.intent.primary = true
	await step(3)
	check(attacker.kit.ammo == 3, "faster reload movement does not permit early shooting")
	attacker.intent.primary = false
	attacker.intent.aim_held = true
	await step(20)
	check(is_equal_approx(attacker.velocity.x,3.6), "aimed reload retains the normal 60 percent aiming speed cap")
	attacker.intent.aim_held = false
	await step(65)
	check(attacker.state == "ready" and attacker.kit.ammo == 8 and is_equal_approx(attacker.velocity.x,6), "reload refills normally and restores full movement")
	attacker.reset_actor()
	attacker.intent.move = Vector3.RIGHT
	attacker.intent.guard = true
	await step(20)
	check(is_equal_approx(attacker.velocity.x,.9), "guard keeps its separate 15 percent movement penalty")
	print("BLOCK FEEDBACK RESULT: %d checks, %d failures" % [checks,failures.size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/block-feedback-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
