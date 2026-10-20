extends SceneTree

var world: Node3D
var actor: HeroActor
var victim: HeroActor
var resolver: CombatResolver
var checks: int = 0
var failures: int = 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",caption)

func step(count: int = 1) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func reset(hero: String = "nimbus") -> void:
	actor.select_hero(hero)
	actor.reset_actor(Vector3(0,.01,5))
	victim.reset_actor(Vector3(20,.01,5))
	await step(8)

func run() -> void:
	TrainingInputs.install()
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(100,1,100),Vector3(0,-.5,0),Color.GRAY)
	actor = HeroActor.new()
	actor.position = Vector3(0,.01,5)
	world.add_child(actor)
	victim = HeroActor.new()
	victim.team = 1
	victim.position = Vector3(20,.01,5)
	world.add_child(victim)
	await step(3)
	for hero: String in HeroRoster.IDS:
		await reset(hero)
		actor.intent.slide = true
		await step(3)
		check(actor.motor.mode == "crouch" and actor.motor.crouched,hero+" Shift at rest crouches")
		var collision := actor.get_node("BodyCollision") as CollisionShape3D
		check(is_equal_approx((collision.shape as CapsuleShape3D).height,1.2) and is_equal_approx(collision.position.y,.6),hero+" crouch capsule stays anchored at the feet")
		actor.intent.move = Vector3.RIGHT
		await step(30)
		check(is_equal_approx(actor.velocity.x,actor.tuning.ground_speed*.5) and actor.motor.mode == "crouch",hero+" walks crouched at half speed without auto-sliding")
		check(not actor.kit.free_slide_ammo(),hero+" crouch never grants free slide ammo")
		actor.kit.ammo = 1
		actor.kit.consume_ammo()
		check(actor.kit.ammo == (1 if actor.kit is RelayKit else 0),hero+" crouch respects weapon ammo policy")
		actor.kit.start_reload()
		await step(maxi(100,ceili(actor.kit.reload_total*60)+3))
		check(not actor.kit.reloading and actor.kit.ammo == actor.tuning.magazine,hero+" reload completes while crouch-walking")
		actor.intent.slide = false
		await step(20)
		check(not actor.motor.crouched and actor.motor.mode == "ground" and is_equal_approx(actor.velocity.x,actor.tuning.ground_speed),hero+" release restores standing and normal movement")
	await reset()
	actor.intent.slide = true
	await step(2)
	check(is_equal_approx(actor.muzzle().y-actor.global_position.y,.66) and is_equal_approx(actor.headshot_height(),.8),"muzzle and headshot threshold follow the crouch")
	var above: Dictionary = resolver.ray(Vector3(-2,1.6,5),Vector3(2,1.6,5),[],2)
	var torso: Dictionary = resolver.ray(Vector3(-2,1.0,5),Vector3(2,1.0,5),[],2)
	check(above.is_empty() and torso.get("collider") == actor,"weapon traces respect the lowered crouch collision")
	var ceiling: StaticBody3D = Geometry.box(world,Vector3(4,.3,4),Vector3(0,1.55,5),Color.DIM_GRAY)
	await step(2)
	actor.intent.slide = false
	await step(3)
	check(actor.motor.crouched and actor.motor.mode == "crouch","low ceiling prevents standing on release")
	actor.intent.move = Vector3.RIGHT
	await step(20)
	check(actor.velocity.x <= 3.001 and actor.motor.crouched,"forced crouch preserves crouch walking under low cover")
	await step(60)
	check(not actor.motor.crouched and actor.motor.mode == "ground","walking out of cover stands automatically")
	ceiling.queue_free()
	await reset()
	actor.velocity = Vector3(8,0,0)
	actor.intent.slide = true
	await step()
	check(actor.motor.mode == "slide" and actor.motor.crouched,"momentum slide takes priority over crouch")
	check(actor.kit.free_slide_ammo(),"real slide retains free ammo")
	actor.motor.slide_velocity = Vector3(1,0,0)
	await step(2)
	check(actor.motor.mode == "crouch" and not actor.kit.free_slide_ammo(),"slow slide falls back to crouch while Shift stays held")
	actor.intent.jump = true
	await step()
	actor.intent.jump = false
	await step(2)
	check(actor.motor.mode == "air" and actor.velocity.y > 0 and not actor.motor.crouched,"jump exits crouch normally")
	await reset()
	actor.intent.slide = true
	await step(2)
	actor.intent.aim_held = true
	actor.intent.move = Vector3.RIGHT
	await step(20)
	check(is_equal_approx(actor.velocity.x,3),"aim cannot increase crouch walking speed")
	actor.reset_actor(Vector3(0,.01,5))
	check(not actor.motor.crouched and is_equal_approx((actor.get_node("BodyCollision").shape as CapsuleShape3D).height,1.9),"reset clears crouch and restores the capsule")
	await step(5)
	actor.intent.slide = true
	await step(2)
	actor.intent.dash = true
	actor.intent.aim = Vector3(0,.5,-1).normalized()
	await step()
	actor.intent.dash = false
	await step(11)
	check(actor.motor.mode == "dash" and not actor.motor.dash_airborne and absf(actor.motor.dash_direction.y) < .001,"dash from crouch remains a horizontal ground dash")
	await step(30)
	check(actor.motor.mode == "slide" and actor.motor.slide_rearmed,"held crouch flows from ground dash into slide")
	await low_cover_weapons()
	await stronger_boot()
	world.queue_free()
	await step(3)
	await create_timer(.25).timeout
	print("CROUCH / BOOT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func low_cover_weapons() -> void:
	for hero: String in HeroRoster.IDS:
		await reset(hero)
		actor.intent.slide = true
		await step(3)
		var roof: StaticBody3D = Geometry.box(world,Vector3(3,.3,3),Vector3(0,1.4,5),Color.GRAY)
		victim.reset_actor(Vector3(0,.01,1))
		await step(3)
		actor.intent.aim = Vector3.FORWARD
		actor.aim_direction = Vector3.FORWARD
		actor.kit.fire(false)
		await step(25)
		check(victim.health < victim.tuning.max_health,hero+" fires from the lower muzzle beneath low cover")
		check(actor.kit.ammo == actor.tuning.magazine-(0 if actor.kit is RelayKit else 1),hero+" crouch firing respects weapon ammo policy")
		roof.queue_free()
		await step(2)
	await reset("doctor")
	victim.team = actor.team
	victim.reset_actor(Vector3(0,.01,1))
	victim.health = 100
	victim.intent.slide = true
	actor.intent.slide = true
	await step(3)
	var roof: StaticBody3D = Geometry.box(world,Vector3(3,.3,8),Vector3(0,1.4,3),Color.GRAY)
	actor.intent.secondary_held = true
	actor.intent.aim = (victim.body_point(1.2)-actor.body_point(1.4)).normalized()
	await step(30)
	check(victim.health > 100,"Doctor can heal a crouched ally while both are under low cover")
	victim.team = 1
	roof.queue_free()
	await step(2)

func stronger_boot() -> void:
	await reset("slayer")
	check(is_equal_approx((actor.tuning as SlayerTuning).boot_knockback,18),"stronger boot tuning defaults to 18 m/s")
	var distances: Array[float] = []
	for speed: float in [11.0,18.0]:
		actor.reset_actor(Vector3(0,.01,5))
		victim.reset_actor(Vector3(0,.01,1))
		await step(3)
		(actor.tuning as SlayerTuning).boot_knockback = speed
		var pair := BootAttachment.new()
		pair.configure(actor,victim)
		actor.intent.aim = Vector3.RIGHT
		await step(2)
		var origin: Vector3 = victim.global_position
		pair.release(true)
		check(is_equal_approx(victim.motor.external_velocity.x,speed),"boot release applies %.0f m/s along final facing" % speed)
		await step(70)
		distances.append(victim.global_position.x-origin.x)
	check(distances[1] > distances[0]*2 and distances[1] > 6,"stronger boot sends victim over twice as far (%.2f m vs %.2f m)" % [distances[1],distances[0]])
	actor.reset_actor(Vector3(0,.01,5))
	victim.reset_actor(Vector3(0,.01,1))
	await step(3)
	var wall: StaticBody3D = Geometry.box(world,Vector3(.1,4,12),Vector3(2,2,1),Color.GRAY)
	await step(2)
	var blocked := BootAttachment.new()
	blocked.configure(actor,victim)
	actor.intent.aim = Vector3.RIGHT
	await step(2)
	blocked.release(true)
	await step(70)
	check(victim.global_position.x < 1.6,"stronger boot cannot push the capsule through a thin wall")
	wall.queue_free()
