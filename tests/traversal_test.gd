extends SceneTree

var world: Node3D
var actor: HeroActor
var resolver: CombatResolver
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	print("PASS  " if condition else "FAIL  ",description)
	if not condition: failures.append(description)

func step(frames: int = 1) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame

func reset(at: Vector3 = Vector3(0,.01,.2)) -> void:
	actor.reset_actor(at)
	actor.intent.aim = Vector3.FORWARD
	await step(3)

func jump() -> void:
	actor.intent.jump = true
	await step()
	actor.intent.jump = false

func count_casts(ability: String) -> int:
	var count: int = 0
	for event: Dictionary in resolver.events:
		if event.event == "cast" and event.ability == ability: count += 1
	return count

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(100,1,100),Vector3(0,-.5,0),Color.GRAY)
	var ledge: Node3D = Geometry.box(world,Vector3(4,2,3),Vector3(0,1,-2),Color.GRAY)
	actor = preload("res://scenes/actors/hero_actor.tscn").instantiate()
	world.add_child(actor)
	await reset()
	await jump()
	check(actor.state == "mantle" and actor.motor.traversal.active, "Space near a 2 m ledge starts a shared mantle")
	check(actor.global_position.y < .15 and actor.global_position.z > .1, "mantle begins with continuous movement rather than snapping onto the roof")
	check(not actor.permits("primary") and not actor.permits("guard") and not actor.permits("dash"), "mantling commits the actor and prevents competing combat casts")
	await step(9)
	check(actor.presentation.animator.current_animation == "mantle" and actor.presentation.left_arm.rotation.x > 2, "mantle visibly reaches both arms toward the ledge")
	actor.intent.aim = Vector3.RIGHT
	actor.intent.move = Vector3.RIGHT
	actor.intent.primary = true
	actor.intent.dash = true
	actor.intent.hover = true
	actor.intent.guard = true
	await step(8)
	check(absf(actor.global_position.x) < .01 and actor.aim_direction == Vector3.FORWARD, "camera turns and steering cannot redirect a committed climb")
	check(actor.kit.ammo == 8 and actor.motor.dash_cd == 0 and actor.motor.hover_cd == 0, "held combat and ability inputs do not spend resources during mantle")
	actor.intent = CombatIntent.new()
	await step(24)
	check(actor.state == "ready" and not actor.motor.traversal.active and actor.is_on_floor(), "mantle restores control on supported ground")
	check(absf(actor.global_position.y - 2) < .06 and actor.global_position.z < -.9, "the full capsule lands beyond the lip of the tower")
	check(actor.presentation.model.rotation.length() < .01, "mantle pose returns to standing after completion")
	Geometry.box(world,Vector3(4,3.4,3),Vector3(20,1.7,-2),Color.GRAY)
	await reset(Vector3(20,.01,.2))
	await jump()
	await step(15)
	await jump()
	check(actor.state == "mantle" and actor.motor.traversal.active, "an airborne jump near a higher tower lip starts a mantle")
	await step(40)
	check(actor.is_on_floor() and absf(actor.global_position.y - 3.4) < .06, "jump then mantle reaches a 3.4 m tower")
	await reset()
	actor.intent.hover = true
	await step()
	actor.intent.hover = false
	await step(4)
	await jump()
	check(actor.state == "mantle" and actor.motor.hover_cd > 0, "mantling out of umbrella ascent ends Hover and starts its cooldown")
	await step(40)
	await reset(Vector3(0,.01,1))
	await jump()
	check(actor.state == "ready" and not actor.motor.traversal.active and actor.velocity.y > 0, "a distant ledge leaves Space as an ordinary ground jump")
	await reset()
	var roof: Node3D = Geometry.box(world,Vector3(5,.25,6),Vector3(0,3.6,-1),Color.GRAY)
	await step(2)
	await jump()
	check(actor.state != "mantle", "mantle rejects a landing with insufficient standing headroom")
	roof.queue_free()
	await reset()
	await jump()
	await step(2)
	roof = Geometry.box(world,Vector3(5,.2,6),Vector3(0,3,-1),Color.GRAY)
	await step(28)
	check(not actor.motor.traversal.active and actor.state == "ready" and actor.global_position.y < 1.1, "a new obstacle aborts the climb at a swept safe position")
	check(actor.global_position.z > .1, "an interrupted lift never teleports through the wall onto the roof")
	roof.queue_free()
	await reset()
	await jump()
	await step(5)
	actor.close.stagger()
	await step()
	check(actor.state == "stagger" and not actor.motor.traversal.active, "stagger interrupts mantle without clearing its control restriction")
	await reset()
	await jump()
	await step(5)
	actor.reset_actor(Vector3(4,.01,5))
	await step(20)
	check(not actor.motor.traversal.active and actor.global_position.distance_to(Vector3(4,0,5)) < .06, "reset clears the path without residual climb movement")
	await reset()
	await jump()
	actor.die()
	await step(2)
	check(not actor.motor.traversal.active and actor.state == "dead", "death cancels an active mantle")
	await reset()
	await jump()
	await step(5)
	ledge.queue_free()
	await step(3)
	check(not actor.motor.traversal.active and actor.state == "ready", "removing the destination support aborts the mantle")
	var thin: Node3D = Geometry.box(world,Vector3(4,2,.2),Vector3(0,1,-.6),Color.GRAY)
	await reset()
	await jump()
	check(actor.state != "mantle", "a thin wall without enough roof for the capsule is rejected")
	thin.queue_free()
	Geometry.box(world,Vector3(4,6,3),Vector3(10,3,-2),Color.GRAY)
	await reset(Vector3(10,.01,.2))
	await jump()
	check(actor.state == "ready" and actor.velocity.y > 7, "a tall wall starts with an ordinary jump instead of an impossible ground mantle")
	await step(10)
	await jump()
	check(actor.velocity.z >= 2.9 and actor.velocity.y > 7.5 and actor.motor.mode == "air", "Space while airborne beside a wall kicks upward and outward")
	await step(3)
	check(actor.presentation.animator.current_animation == "wall_jump" and actor.presentation.left_leg.rotation.x > .5, "wall jump has a visible leg kick pose")
	var kicks: int = count_casts("wall_jump")
	await step(16)
	actor.global_position = Vector3(10,2,.2)
	actor.velocity = Vector3.ZERO
	await jump()
	check(count_casts("wall_jump") == kicks and actor.velocity.y < 0, "the same wall cannot be spammed for unlimited height before landing")
	Geometry.box(world,Vector3(4,6,3),Vector3(10,3,2.5),Color.GRAY)
	await step()
	actor.global_position = Vector3(10,2,.5)
	actor.velocity = Vector3.ZERO
	actor.intent.aim = Vector3.BACK
	await jump()
	check(count_casts("wall_jump") == kicks + 1 and actor.velocity.z <= -2.9, "a differently facing wall enables an alternating wall jump")
	actor.reset_actor(Vector3(10,.01,.2))
	await step(4)
	check(actor.motor.traversal.last_wall_normal == Vector3.ZERO, "landing and reset rearm the wall jump")
	await reset(Vector3(-15,2,0))
	actor.velocity = Vector3.ZERO
	var before: int = count_casts("wall_jump")
	await jump()
	check(count_casts("wall_jump") == before and actor.velocity.y <= 0, "Space in open air does not grant a free double jump")
	var target := preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
	target.position = Vector3(-15,2,-.65)
	target.team = 1
	world.add_child(target)
	await step()
	actor.global_position = Vector3(-15,2,0)
	actor.velocity = Vector3.ZERO
	await jump()
	check(count_casts("wall_jump") == before and actor.state != "mantle", "other actors cannot be used as mantle ledges or jump walls")
	target.queue_free()
	var diagonal: Node3D = Geometry.box(world,Vector3(4,6,.4),Vector3(-30,3,0),Color.GRAY)
	diagonal.rotation.y = PI / 4
	var normal := Vector3(1,0,1).normalized()
	await reset(Vector3(-30,2,0) + normal * .8)
	actor.intent.aim = Vector3.BACK
	await jump()
	check(actor.velocity.dot(normal) > 6 and actor.velocity.y > 7.5, "wall jump finds an angled wall even when the camera faces away")
	await reset(Vector3(-15,.01,0))
	actor.intent.hover = true
	await step()
	actor.intent.hover = false
	var peak: float = actor.global_position.y
	for frame: int in 95:
		await step()
		peak = maxf(peak,actor.global_position.y)
	check(peak > 7.4 and peak < 8.5, "Nimbus umbrella vault now reaches roughly 8 m on open ground")
	check(actor.motor.mode == "hover", "the higher umbrella launch still transitions into controlled glide")
	await step(115)
	check(actor.motor.hover_cd > 0 and actor.motor.mode != "hover", "higher vault retains finite duration and the existing cooldown")
	await reset(Vector3(-15,.01,0))
	roof = Geometry.box(world,Vector3(5,.3,5),Vector3(-15,3.5,0),Color.GRAY)
	await step(2)
	actor.intent.hover = true
	await step()
	actor.intent.hover = false
	await step(20)
	check(actor.global_position.y < 1.5 and actor.motor.mode == "hover", "the stronger vault respects low ceilings and safely enters glide")
	print("TRAVERSAL RESULT: %d checks, %d failures" % [checks,failures.size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/traversal-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
