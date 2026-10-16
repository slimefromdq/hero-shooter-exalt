extends SceneTree

var world: Node3D
var a: HeroActor
var b: HeroActor
var resolver: CombatResolver
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

func reset(distance: float = 2.6) -> void:
	a.reset_actor(Vector3(0,.01,0))
	b.reset_actor(Vector3(0,.01,-distance))
	b.intent.aim = Vector3.BACK
	b.aim_direction = Vector3.BACK
	resolver.clear_round()
	await step(3)

func strike() -> void:
	a.intent.melee = true
	await step()
	a.intent.melee = false

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(40,1,40),Vector3(0,-.5,0),Color.GRAY)
	a = preload("res://scenes/actors/hero_actor.tscn").instantiate()
	a.actor_id = "engager"
	world.add_child(a)
	b = preload("res://scenes/actors/hero_actor.tscn").instantiate()
	b.actor_id = "defender"
	b.team = 1
	world.add_child(b)
	await reset(9)
	await strike()
	await step(28)
	check(is_equal_approx(-a.global_position.z,3.6), "unobstructed melee advances 3.6 m through swept actor movement")
	check(a.velocity.length() < .1, "lunge ends without a residual free speed boost")
	await reset(5.75)
	b.health = 50
	await strike()
	await step(30)
	check(not b.alive, "forward melee closes a 5.75 m approach and finishes a damaged enemy")
	check(a.kit.ammo == 8 and a.motor.dash_cd == 0, "melee engagement does not spend ammunition or dash")
	await reset(9)
	await strike()
	await step(7)
	a.intent.aim = Vector3.RIGHT
	await step(22)
	check(absf(a.global_position.x) < .01 and a.global_position.z < -2, "turning the camera cannot home or redirect a committed melee lunge")
	await reset(4)
	var wall: Node3D = Geometry.box(world,Vector3(3,4,.3),Vector3(0,2,-1),Color.GRAY)
	await step(2)
	await strike()
	await step(35)
	check(a.global_position.z > -.5 and b.health == 250, "lunge stops at a wall and the strike cannot hit through it")
	wall.queue_free()
	await reset(1.4)
	b.intent.guard = true
	await step()
	await strike()
	await step(18)
	check(a.state == "stagger" and b.health == 250, "guard still punishes an incoming lunging strike")
	check(Vector2(a.velocity.x,a.velocity.z).length() < .01, "a blocked lunge stops immediately instead of sliding through guard")
	await reset(9)
	await strike()
	await step(6)
	a.reset_actor()
	var reset_at: Vector3 = a.global_position
	await step(20)
	check(a.global_position.distance_to(reset_at) < .1, "reset during lunge removes its remaining travel")
	await reset()
	var original: Vector3 = b.global_position
	a.close.start_throw()
	await step(19)
	check(a.state == "throw_pair" and b.state == "captured", "expanded 2.8 m grab captures an opponent at 2.6 m")
	check(b.global_position.distance_to(original) < .2, "capture begins at the victim's actual position without an immediate pull teleport")
	check(a.get_collision_exceptions().has(b) and b.get_collision_exceptions().has(a), "only paired actors temporarily ignore each other's capsules")
	var forward: Vector3 = a.aim_direction
	a.intent.aim = Vector3.RIGHT
	await step(12)
	check(a.aim_direction == forward, "freelook does not rotate or drag the locked throw sequence")
	var max_lift: float = b.global_position.y
	var saw_flip: bool = false
	var early_damage: bool = false
	var checked_impact: bool = false
	for frame: int in 65:
		await step()
		max_lift = maxf(max_lift,b.global_position.y)
		saw_flip = saw_flip or absf(b.presentation.model.rotation.x) > 2.0
		if a.state == "throw_pair":
			if a.close.pair_progress < a.tuning.throw_impact_progress and b.health < 250:
				early_damage = true
			if a.close.pair_progress >= a.tuning.throw_impact_progress and b.health == 155:
				checked_impact = true
	check(max_lift > .9 and saw_flip, "victim is physically lifted while authored animation turns the body over Nimbus's hip")
	check(not early_damage and checked_impact and b.health == 155, "throw deals its single 95 HP hit at the slam, not at capture or lift")
	check(a.state == "ready" and b.state == "ready", "both actors regain control as the get-up animation completes")
	check(a.global_position.distance_to(b.global_position) > 1.5 and b.global_position.y < .1, "victim lands on checked ground clear of the attacker's capsule")
	check(a.get_collision_exceptions().is_empty() and b.get_collision_exceptions().is_empty(), "normal actor collisions are restored after the throw")
	check(b.presentation.model.rotation.length() < .01, "victim pose returns to standing without a stuck animation")
	await reset()
	var roof: Node3D = Geometry.box(world,Vector3(6,.3,6),Vector3(0,2.4,-1),Color.GRAY)
	await step(2)
	a.close.start_throw()
	await step(19)
	check(a.state == "throw_whiff" and b.state == "ready", "a low ceiling rejects the full throw path before capture")
	check(a.get_collision_exceptions().is_empty() and b.get_collision_exceptions().is_empty(), "rejected geometry cannot leave collision exceptions or pair protection")
	roof.queue_free()
	await reset()
	a.close.start_throw()
	await step(26)
	var obstacle: Node3D = Geometry.box(world,Vector3(3,.3,3),Vector3(0,2.5,-.3),Color.GRAY)
	await step(20)
	check(a.close.pair == null and b.close.pair == null and b.global_position.y < .8, "an obstacle introduced during lifting aborts at a safe swept position")
	check(b.health == 250 and b.state == "ready", "interrupted throw does not grant slam damage or a lingering capture")
	var clearance: Vector3 = b.global_position - a.global_position
	check(Vector2(clearance.x,clearance.z).length() >= .76 or absf(clearance.y) >= 1.9, "interrupted lift separates live capsules before restoring collisions")
	obstacle.queue_free()
	for progress: float in [.2,.5,.8]:
		await reset()
		a.close.start_throw()
		await step(19 + int(progress * a.tuning.throw_duration * 60))
		a.reset_actor()
		await step(2)
		check(b.close.pair == null and b.get_collision_exceptions().is_empty() and a.get_collision_exceptions().is_empty(), "reset safely releases the pair at throw progress %.1f" % progress)
		clearance = b.global_position - a.global_position
		check(Vector2(clearance.x,clearance.z).length() >= .76 or absf(clearance.y) >= 1.9, "reset leaves separated live capsules at throw progress %.1f" % progress)
	print("CLOSE COMBAT RESULT: %d checks, %d failures" % [checks,failures.size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/close-combat-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
