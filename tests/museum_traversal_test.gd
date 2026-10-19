extends SceneTree
var checks: int = 0
var failures: Array[String] = []
var arena: Node3D
var actor: HeroActor

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func mantle(at: Vector3, direction: Vector3, height: float, caption: String) -> void:
	actor.reset_actor(at)
	actor.intent.move = direction
	actor.intent.aim = direction
	actor.intent.jump_held = true
	await frames(1)
	check(actor.motor.traversal.active,caption+" starts a collision-checked mantle")
	for index: int in 30:
		if not actor.motor.traversal.active: break
		await frames(1)
	actor.intent = CombatIntent.new()
	check(actor.global_position.y >= height-.1,caption+" reaches its supported landing")

func run() -> void:
	arena = load("res://scenes/museum/meridian_museum.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var session: MuseumMatch = arena.match_controller
	session.set_physics_process(false)
	actor = session.player
	actor.controller.active = false
	actor.controller = null
	for other: HeroActor in session.bots:
		other.set_physics_process(false)
		other.global_position = Vector3(-50,0,30)
	await frames(4)
	await mantle(Vector3(-31,.01,20.1),Vector3.FORWARD,1.2,"court planter step")
	await mantle(Vector3(-31,1.25,18.1),Vector3.FORWARD,2.4,"court second sculpture step")
	await mantle(Vector3(-31,2.45,15.4),Vector3.FORWARD,3.6,"court balcony landing")
	await mantle(Vector3(14,.01,-26.1),Vector3.BACK,1.5,"terrace first step")
	await mantle(Vector3(14,1.55,-24.1),Vector3.BACK,3.0,"terrace second step")
	await mantle(Vector3(14,3.05,-22.1),Vector3.BACK,4.5,"terrace roof connector")
	await mantle(Vector3(24.1,.01,25),Vector3.LEFT,1.6,"packing crate step")
	await mantle(Vector3(22.1,1.65,25),Vector3.LEFT,2.8,"packing second crate")
	await mantle(Vector3(19.9,2.85,25),Vector3.LEFT,3.5,"packing gantry landing")
	# Actual gap crossings use the shared dash, with no hero-specific ability.
	for row: Array in [[Vector3(-35,4.08,-33),-30,4.0,"four-meter gallery gap"],[Vector3(16,2.88,-34),22,2.8,"five-meter terrace gap"]]:
		actor.reset_actor(row[0])
		actor.velocity = Vector3(4,1,0)
		actor.intent = CombatIntent.new()
		actor.intent.aim = Vector3(1,.15,0).normalized()
		actor.intent.dash = true
		await frames(1)
		actor.intent.dash = false
		await frames(38)
		check(actor.global_position.x >= row[1] and actor.global_position.y >= row[2]-.15,str(row[3])+" crosses with shared air dash")
		actor.intent = CombatIntent.new()
		await frames(35)
		check(actor.global_position.y > -3,str(row[3])+" remains inside safe museum bounds")
	actor.reset_actor(Vector3(-18.7,1,35))
	actor.velocity = Vector3(0,0,-3)
	actor.intent = CombatIntent.new()
	actor.intent.jump = true
	actor.motor.coyote = 0
	await frames(1)
	actor.intent.jump = false
	check(actor.velocity.y > 7 and actor.velocity.x < -1,"cloister wall kick uses real museum collision")
	actor.select_hero("dynamo")
	check(not DynamoWall.placement_clear(actor,Vector3(-17,0,16),0),"Dynamo placement rejects the actual remaining cart corridor")
	check(DynamoWall.placement_clear(actor,Vector3(-28,0,37),0),"Dynamo can still place an ordinary wall beside the track")
	session.objective.payload_distance = 50
	check(session.track_intersects(AABB(Vector3(-18,0,15),Vector3(4,3,2))),"wall restriction also protects the cart's available rollback route")
	session.objective.checkpoint_index = 1
	check(not session.track_intersects(AABB(Vector3(-18,0,15),Vector3(4,3,2))),"completed checkpoint releases retired track for wall placement")
	var file := FileAccess.open("res://artifacts/museum/traversal.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("MUSEUM TRAVERSAL ",checks," checks; ",failures.size()," failures")
	arena.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
