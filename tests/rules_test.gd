extends SceneTree

var world: Node3D
var resolver: CombatResolver
var a: HeroActor
var b: HeroActor
var c: HeroActor
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", description)
	else:
		failures.append(description)
		push_error("FAIL  " + description)

func step(frames: int = 1) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame

func actor_at(id: String, team: int, at: Vector3) -> HeroActor:
	var actor := preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
	actor.actor_id = id
	actor.team = team
	actor.position = at
	world.add_child(actor)
	return actor

func reset(at_a: Vector3 = Vector3(0, 0.01, 0), at_b: Vector3 = Vector3(0, 0.01, -1.4)) -> void:
	a.reset_actor(at_a)
	b.reset_actor(at_b)
	c.reset_actor(Vector3(9, 0.01, 2))
	resolver.clear_round()
	b.aim_direction = Vector3.BACK
	b.intent.aim = Vector3.BACK

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world, Vector3(120, 1, 120), Vector3(0, -0.5, 0), Color.GRAY)
	a = actor_at("player", 0, Vector3(0,0.01,0))
	b = actor_at("target", 1, Vector3(0,0.01,-1.4))
	c = actor_at("interference", 2, Vector3(9,0.01,2))
	await step(3)
	await rifle_tests()
	ultimate_tests()
	await close_tests()
	await ability_tests()
	await movement_tests()
	await cleanup_tests()
	print("RESULT: %d checks, %d failures" % [checks, failures.size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/rules-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "checks": checks, "failures": failures}, "\t"))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func rifle_tests() -> void:
	reset(Vector3(0,0.01,0), Vector3(0,0.01,-8))
	await step(2)
	a.intent.aim_origin = a.global_position + Vector3.UP * 1.2
	a.aim_direction = Vector3.FORWARD
	a.kit.fire(false)
	check(is_equal_approx(b.health, 205.0), "physical body ray applies exactly 45 damage")
	check(a.kit.ammo == 7, "rifle consumes one cartridge")
	var cast: int = a.kit.cast_id
	check(resolver.damage(a,b,45,"rifle",cast) == "duplicate" and b.health == 205, "same cast cannot damage the same target twice")
	b.health = 250
	a.intent.aim_origin = a.global_position + Vector3.UP * 1.73
	a.kit.fire(false)
	check(is_equal_approx(b.health,160.0), "physical head ray applies exactly 90 damage")
	var wall: Node3D = Geometry.box(world, Vector3(2,3,0.2), Vector3(0,1.5,-2), Color.GRAY)
	await step(2)
	b.health = 250
	a.kit.fire(false)
	check(b.health == 250, "cover blocks weapon ray")
	# Camera may see around cover while the actual muzzle is blocked.
	a.intent.aim_origin = Vector3(3,1.7,0)
	a.aim_direction = (b.global_position + Vector3.UP * 1.2 - a.intent.aim_origin).normalized()
	a.kit.fire(false)
	check(b.health == 250, "muzzle obstruction prevents camera-over-cover shooting")
	wall.queue_free()
	await step(2)
	a.kit.shot_cd = 0.5
	a.intent.primary = true
	var ammo: int = a.kit.ammo
	await step(2)
	check(a.kit.ammo == ammo, "fire cadence rejects early shot intent")
	a.intent.primary = false
	a.intent.reload = true
	await step()
	a.intent.reload = false
	check(a.state == "reload", "reload has an explicit state")
	await step(100)
	check(a.kit.ammo == 8 and a.state == "ready", "reload completes and restores magazine")
	check(b.kit.ammo == 8 and b.kit.shot_cd == 0.0, "actors have independent ammunition and cooldowns")

func ultimate_tests() -> void:
	for health: float in [49.0,50.0,51.0]:
		reset()
		b.health = health
		var result: String = resolver.damage(a,b,150,"ultimate",resolver.new_cast(),false,true)
		check(result == ("execution" if health <= 50.0 else "hit"), "execute evaluates pre-shot HP at %.1f / 250" % health)
	reset()
	resolver.damage(a,b,150,"ultimate",resolver.new_cast(),false,true)
	check(b.health == 100.0, "Final Notice deals 150 with no automatic head multiplier")
	reset()
	b.health = 50
	b.shields = 180
	var result: String = resolver.damage(a,b,150,"ultimate",resolver.new_cast(),false,true)
	check(result == "hit" and b.health == 50 and b.shields == 30, "shields prevent execution and absorb normal damage")
	reset()
	b.health = 50
	b.shields = 5
	result = resolver.damage(a,b,150,"ultimate",resolver.new_cast(),false,true)
	check(result == "hit", "depleting shields on this shot does not retroactively execute")
	reset()
	b.health = 50
	b.invulnerable = true
	check(resolver.damage(a,b,150,"ultimate",resolver.new_cast(),false,true) == "immune" and b.health == 50, "invulnerability rejects execution")
	reset()
	b.team = 0
	resolver.damage(a,b,45,"rifle",resolver.new_cast())
	check(b.health == 250, "resolver rejects friendly fire")
	b.team = 1

func close_tests() -> void:
	reset()
	await step(2)
	b.state = "guard"
	resolver.damage(a,b,75,"melee",resolver.new_cast())
	check(b.health == 250 and a.state == "stagger", "frontal guard stops melee and staggers attacker")
	check(b.close.guard_meter == 72, "blocking a strike consumes guard meter")
	a.state = "ready"
	resolver.damage(a,b,45,"rifle",resolver.new_cast())
	check(b.health == 205, "baseline guard gives no bullet protection")
	reset()
	b.state = "guard"
	b.aim_direction = Vector3.FORWARD
	resolver.damage(a,b,75,"melee",resolver.new_cast())
	check(b.health == 175, "rear melee bypasses frontal guard")
	reset()
	await step(2)
	a.intent.melee = true
	await step()
	a.intent.melee = false
	check(a.state == "melee_windup" and b.health == 250, "committed melee has damage-free windup")
	a.intent.primary = true
	a.intent.dash = true
	await step(40)
	a.intent = CombatIntent.new()
	check(b.health == 175, "active melee hits each target once")
	check(a.kit.ammo == 8 and a.motor.dash_cd == 0, "melee commitment rejects rifle and dash cancels")
	await step(24)
	check(a.state == "ready", "melee recovery returns control")
	reset()
	await step(2)
	a.close.start_throw()
	resolver.damage(b,a,24,"projectile",resolver.new_cast())
	check(a.state == "throw_whiff" and a.close.throw_target == null, "damage interrupts vulnerable throw startup")
	reset()
	await step(2)
	a.close.start_throw()
	await step(8)
	b.intent.throw_action = true
	await step()
	b.intent.throw_action = false
	await step(10)
	check(a.state == "counterthrow" and b.state == "counterthrow" and b.health == 250, "timed counterthrow breaks capture without damage")
	reset()
	await step(2)
	a.close.start_throw()
	await step(19)
	check(a.state == "throw_pair" and b.state == "captured", "successful throw captures both participants exactly once")
	resolver.damage(c,a,100,"projectile",resolver.new_cast())
	resolver.damage(c,b,100,"projectile",resolver.new_cast())
	check(a.health == 240 and b.health == 240, "both throw participants take only 10% outside damage")
	await step(ceili(a.tuning.throw_duration * Engine.physics_ticks_per_second) + 2)
	check(b.health == 145, "scripted throw damage bypasses paired mitigation")
	check(a.state == "ready" and b.state == "ready", "throw releases with no additional post-throw stun")
	check(a.close.pair == null and b.close.pair == null and b.close.grace > 0, "release clears pairing and grants short grab grace")
	reset(Vector3(0,0.01,0), Vector3(0,0.01,-5))
	await step(2)
	a.close.start_throw()
	await step(19)
	check(a.state == "throw_whiff", "out-of-range throw has punishable whiff recovery")
	reset()
	await step(2)
	a.close.start_throw()
	b.close.start_throw()
	await step(19)
	check(a.close.pair == null and b.close.pair == null, "simultaneous grabs resolve as one counter break")

func ability_tests() -> void:
	reset(Vector3(0,0.01,0), Vector3(0,0.01,-6))
	await step(2)
	a.intent.hover = true
	await step()
	a.intent.hover = false
	await step(15)
	check(a.global_position.y > 1.5, "Hover supplies an initial upward burst")
	await step(10)
	check(a.motor.mode == "hover", "Hover ascent transitions to controlled glide")
	await step(165)
	check(a.motor.hover_cd > 0 and a.motor.mode != "hover", "Hover ends and starts its cooldown")
	reset()
	b.state = "deflect"
	b.aim_direction = Vector3.BACK
	check(resolver.damage(a,b,45,"rifle",resolver.new_cast()) == "deflect" and b.health == 250, "frontal Deflect blocks eligible hitscan")
	resolver.damage(a,b,30,"bomb",resolver.new_cast())
	check(b.health == 220, "area explosion bypasses Deflect")
	reset(Vector3(0,0.01,0), Vector3(0,0.01,-5))
	await step(2)
	b.state = "deflect"
	b.state_time = 1.0
	b.intent.aim = Vector3.BACK
	b.aim_direction = Vector3.BACK
	var projectile := CombatProjectile.new()
	projectile.source = a
	projectile.direction = Vector3.FORWARD
	projectile.cast_id = resolver.new_cast()
	world.add_child(projectile)
	projectile.global_position = Vector3(0,1.2,-3.9)
	await step(8)
	check(is_instance_valid(projectile) and projectile.source == b and projectile.direction.z > 0 and projectile.reflections == 1, "Deflect changes projectile owner/team and direction once")
	await step(20)
	check(a.health == 226, "reflected projectile can damage its original owner")
	reset(Vector3(0,0.01,0), Vector3(0,0.01,-4))
	await step(2)
	var bomb := PocketBomb.new()
	bomb.source = a
	bomb.cast_id = resolver.new_cast()
	world.add_child(bomb)
	bomb.global_position = b.global_position + Vector3.UP * 0.9
	bomb.explode()
	check(is_equal_approx(b.health,170), "Pocket Bomb peak damage is 80 without head multiplier")
	await step()
	b.health = 250
	var cover: Node3D = Geometry.box(world, Vector3(3,3,0.3), Vector3(0,1.5,-3.1), Color.GRAY)
	await step(2)
	bomb = PocketBomb.new()
	bomb.source = a
	bomb.cast_id = resolver.new_cast()
	world.add_child(bomb)
	bomb.global_position = Vector3(0,1,-2)
	bomb.explode()
	check(b.health == 250, "solid cover blocks radial bomb damage")
	cover.queue_free()
	reset()
	a.intent.ultimate = true
	await step()
	a.intent.ultimate = false
	check(a.state == "ultimate" and a.kit.ultimate_charge < 1, "ultimate charge is consumed on activation")
	a.intent.primary = true
	await step(10)
	a.intent.primary = false
	check(a.state == "ultimate", "ultimate shot cannot bypass preparation time")
	a.kit.cancel()
	check(a.kit.ultimate_charge < 1 and a.state == "ready", "cancelling ultimate gives no refund")

func movement_tests() -> void:
	reset(Vector3(-15,0.01,10), Vector3(0,0.01,-15))
	await step(3)
	a.intent.move = Vector3.FORWARD
	await step(25)
	check(Vector2(a.velocity.x,a.velocity.z).length() > 5.5, "ground acceleration reaches the proposed 6 m/s baseline")
	a.intent.slide = true
	await step()
	check(a.motor.mode == "slide", "ordinary running speed enters slide")
	a.intent.move = Vector3.ZERO
	var speed: float = a.velocity.length()
	await step(10)
	check(a.velocity.length() < speed, "flat-ground slide loses speed to friction")
	a.intent.slide = false
	await step(5)
	a.intent.dash = true
	a.intent.aim = Vector3(0,-0.5,-1).normalized()
	await step()
	a.intent.dash = false
	check(a.motor.mode == "dash_windup" and a.motor.dash_cd > 4, "dash consumes one cooldown at buildup")
	a.intent.slide = false
	await step(12)
	check(a.motor.mode == "slide" and a.velocity.length() <= a.tuning.dash_speed, "downward dash projects into valid floor slide without extra speed")
	await step(3)
	check(a.motor.mode == "slide", "dash-to-ground slide continues without a held crouch key")
	var cooldown: float = a.motor.dash_cd
	a.intent.slide = false
	await step()
	a.intent.slide = true
	await step()
	check(a.motor.dash_cd < cooldown and a.motor.dash_cd > 0, "slide re-entry does not reset dash cooldown")
	reset(Vector3(-15,1,10), Vector3(0,0.01,-15))
	await step()
	a.intent.dash = true
	a.intent.aim = Vector3.UP
	await step()
	a.intent.dash = false
	await step(12)
	check(a.velocity.y > 10 and a.global_position.y > 1.5, "universal dash follows vertical crosshair direction")
	var fixed: Vector3 = a.motor.dash_direction
	a.intent.aim = Vector3.RIGHT
	await step(2)
	check(a.motor.dash_direction == fixed, "camera changes do not redirect active dash")
	reset(Vector3(-15,0.01,10), Vector3(0,0.01,-15))
	var wall: Node3D = Geometry.box(world, Vector3(3,7,0.5), Vector3(-15,3.5,7), Color.GRAY)
	await step(3)
	a.intent.dash = true
	await step()
	a.intent.dash = false
	await step(25)
	check(a.global_position.z > 7.5 and a.motor.mode != "slide", "wall collision stops dash without converting to floor slide")
	wall.queue_free()
	reset(Vector3(-15,0.01,10), Vector3(0,0.01,-15))
	var roof: Node3D = Geometry.box(world, Vector3(5,0.4,5), Vector3(-15,3.5,10), Color.GRAY)
	await step(3)
	a.intent.dash = true
	a.intent.aim = Vector3.UP
	await step()
	a.intent.dash = false
	await step(18)
	check(a.global_position.y < 1.5 and a.motor.mode != "slide", "ceiling stops upward dash without creating a slide")
	a.reset_actor(Vector3(-15,0.01,10))
	await step(3)
	a.intent.hover = true
	await step()
	a.intent.hover = false
	await step(16)
	check(a.global_position.y < 1.5 and a.motor.mode == "hover", "Hover safely transitions to glide after ceiling contact")
	roof.queue_free()
	var ramp: Node3D = Geometry.box(world, Vector3(6,0.5,14), Vector3(-30,2,0), Color.GRAY)
	ramp.rotation_degrees.x = 16
	reset(Vector3(-30,3.9,-5), Vector3(0,0.01,-15))
	await step(35)
	a.intent.slide = true
	a.velocity = Vector3.ZERO
	await step(2)
	check(a.motor.mode == "slide", "sufficient downhill slope permits slide from low speed")
	var start_z: float = a.global_position.z
	await step(30)
	check(a.global_position.z > start_z and a.velocity.length() > 0.5, "downhill gravity sustains momentum slide")
	a.velocity = Vector3(0,2,-8)
	a.motor.slide_velocity = a.velocity.slide(a.get_floor_normal())
	var uphill_speed: float = a.motor.slide_velocity.length()
	await step(15)
	check(a.motor.slide_velocity.length() < uphill_speed, "gravity and friction slow uphill sliding")
	ramp.queue_free()

func cleanup_tests() -> void:
	for state: String in ["reload","guard","melee_windup","melee_active","melee_recovery","throw_startup","throw_whiff","deflect","ultimate"]:
		reset()
		a.state = state
		a.state_time = 1
		a.die()
		a.reset_actor()
		check(a.alive and a.state == "ready" and a.kit.ammo == 8 and a.velocity == Vector3.ZERO, "death/reset clears " + state)
	for mode: String in ["dash_windup","dash","slide","hover_ascent","hover"]:
		reset()
		a.motor.mode = mode
		a.motor.timer = 1
		a.reset_actor()
		check(a.motor.mode == "ground" and a.motor.timer == 0 and a.motor.dash_cd == 0, "reset clears movement " + mode)
	reset()
	await step(2)
	a.close.start_throw()
	await step(19)
	a.die()
	check(b.close.pair == null and b.state == "throw_release", "death during capture releases the other participant")
	reset()
	a.intent.bomb = true
	await step()
	a.intent.bomb = false
	check(get_nodes_in_group("owned_attacks").size() > 0, "bomb exists during its fuse")
	a.reset_actor()
	await step()
	var owned_count: int = 0
	for attack: Node in get_nodes_in_group("owned_attacks"):
		if attack.get("source") == a: owned_count += 1
	check(owned_count == 0, "reset clears owned projectiles and bomb fuses")
