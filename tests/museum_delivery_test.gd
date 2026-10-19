extends SceneTree
## Physical edge cases beyond the basic objective and route suites.
var checks: int = 0
var failures: Array[String] = []
var details: Array[Dictionary] = []
var arena: Node3D
var session: MuseumMatch
var player: HeroActor

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func frames(count: int = 2) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func clear_capsule(at: Vector3, excluded: Array[RID] = []) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = .38
	capsule.height = 1.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*.95)
	query.collision_mask = 1
	query.exclude = excluded
	return arena.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func path_reaches(at: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(arena.get_world_3d().navigation_map,session.definition.hill_center+Vector3(5,0,-3),at,true)
	return not path.is_empty() and path[-1].distance_to(at) < 1

func park_actors() -> void:
	for index: int in session.actors.size():
		session.actors[index].global_position = Vector3(-60+index*2,.08,25)

func gate_blocks(gate: MuseumSpawnDoor, team: int) -> bool:
	var original_team: int = player.team
	player.team = team
	player.collision_mask = 9 if team == 0 else 5
	var at: Vector3 = gate.global_position+Vector3(0,.08,-2).rotated(Vector3.UP,gate.rotation.y)
	player.global_position = at
	gate._physics_process(.25)
	var blocked: bool = player.test_move(Transform3D(Basis.IDENTITY,at),Vector3(0,0,4).rotated(Vector3.UP,gate.rotation.y))
	player.team = original_team
	return blocked

func run() -> void:
	arena = load("res://scenes/museum/meridian_museum.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	session = arena.match_controller
	player = session.player
	session.set_physics_process(false)
	player.controller.active = false
	for actor: HeroActor in session.actors: actor.set_physics_process(false)
	var start: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec()-start < 30000:
		session._physics_process(0)
		await frames(1)
	check(session.navigation_ready,"edge audit waits for synchronized navigation")
	park_actors()
	# Compare real collision against triangle surfaces made from the rendered
	# cart meshes. Cover must not stop bullets in visually empty space.
	var visual_cart := StaticBody3D.new()
	visual_cart.collision_layer = 32
	visual_cart.collision_mask = 0
	arena.add_child(visual_cart)
	for child: Node in session.payload.get_children():
		if child is MeshInstance3D:
			var triangle_shape := CollisionShape3D.new()
			triangle_shape.shape = child.mesh.create_trimesh_shape()
			visual_cart.add_child(triangle_shape)
			triangle_shape.global_transform = child.global_transform
	await frames()
	for x: float in [-1.6,-.9,-.5,0,.5,.9,1.6]:
		for y: float in [.25,1,2,2.4]:
			var from: Vector3 = session.payload.global_position+Vector3(x,y,-4)
			var toward: Vector3 = from+Vector3(0,0,8)
			var physical := arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,toward,1))
			var visual := arena.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,toward,32))
			var matches: bool = physical.is_empty() == visual.is_empty()
			if not physical.is_empty() and not visual.is_empty(): matches = physical.position.distance_to(visual.position) < .03
			check(matches,"cart bullet cover matches visible surface at "+str(Vector2(x,y)))
	visual_cart.queue_free()
	await frames()
	var d: MuseumMapDefinition = session.museum_definition()
	for pickup: CityHealthPack in session.pickups:
		check(clear_capsule(pickup.global_position+Vector3.UP*.08),"pickup has standing capsule clearance: "+pickup.name)
		check(path_reaches(pickup.global_position),"pickup has reachable same-floor navigation: "+pickup.name)
	for team: int in 2:
		var count: int = d.attacker_rooms.size() if team == 0 else d.defender_rooms.size()
		for stage: int in count:
			if team == 0: d.attacker_stage = stage
			else: d.defender_stage = stage
			for slot: int in 6:
				check(clear_capsule(d.team_spawns(team)[slot]),"spawn capsule is clear: %s%d slot %d" % ["A" if team == 0 else "D",stage,slot])
			arena.builder.update_gates(true)
			for gate: MuseumSpawnDoor in arena.builder.spawn_gates:
				if gate.get_meta("team") != team or gate.get_meta("stage") != stage: continue
				check(gate_blocks(gate,1-team),"active spawn exit rejects enemies: "+str(gate.name))
				check(gate_blocks(gate,team) == (team == 0),"preparation exit only locks attackers: "+str(gate.name))
			arena.builder.update_gates(false)
			for gate: MuseumSpawnDoor in arena.builder.spawn_gates:
				if gate.get_meta("team") != team or gate.get_meta("stage") != stage: continue
				check(not gate_blocks(gate,team),"released spawn exit permits its own team: "+str(gate.name))
	session.restart_match()
	park_actors()
	session.toggle_exploration()
	for gate: MuseumSpawnDoor in arena.builder.spawn_gates:
		if gate.get_meta("team") == 0 and gate.get_meta("stage") == 0:
			check(not gate_blocks(gate,0),"exploration opens preparation gates for free map access")
	session.toggle_exploration()
	session.restart_match()
	# Transfer must stop an old mantle trajectory while preserving earned state.
	player.global_position = player.spawn_position
	player.health = 100
	player.kit.ultimate_charge = 43
	player.motor.dash_cd = 2
	player.motor.traversal.active = true
	player.motor.traversal.origin = player.global_position
	player.motor.traversal.raised = player.global_position+Vector3.UP*2
	player.motor.traversal.landing = player.global_position+Vector3(0,2,1)
	player.state = "mantle"
	player.motor.mode = "mantle"
	session._relocate(1,1)
	check(not player.motor.traversal.active and player.state == "ready","spawn transfer cancels old-world mantle trajectories")
	check(player.health == 100 and player.kit.ultimate_charge == 43 and player.motor.dash_cd == 2,"spawn transfer preserves health, ultimate and movement cooldowns")
	session._relocate(2,2)
	var defender: HeroActor
	for actor: HeroActor in session.actors:
		if actor.team == 1: defender = actor; break
	defender.global_position = defender.spawn_position+Vector3(.8,0,.6)
	var before: Vector3 = defender.global_position
	session._relocate(3,2)
	check(defender.global_position == before,"CP2 does not reposition defenders in their unchanged D2 room")
	park_actors()
	player.collision_mask = 1
	for id: String in HeroRoster.IDS:
		player.select_hero(id)
		session.payload.reset_cart()
		player.global_position = session.payload.global_position+Vector3(0,2.52,0)
		await frames()
		session.payload.move_to_distance(24)
		check(player.global_position.distance_to(session.payload.global_position+Vector3(0,2.52,0)) < .15,"artifact-top rider follows cart bends: "+id)
		session.payload.move_to_distance(0)
		check(player.global_position.distance_to(session.payload.global_position+Vector3(0,2.52,0)) < .15,"artifact-top rider follows rollback: "+id)
	# All twelve capsules occupy the swept lane, with real actor collisions.
	session.payload.reset_cart()
	for index: int in session.actors.size():
		var actor: HeroActor = session.actors[index]
		actor.reset_actor(d.payload_path[0]+Vector3((index%3-1)*1.0,.08,-3-(index/3)*1.0))
		actor.collision_mask = 3
	await frames()
	session.payload.move_to_distance(15)
	await frames()
	var crowded_clear: bool = true
	for actor: HeroActor in session.actors:
		if not clear_capsule(actor.global_position):
			crowded_clear = false
			details.append({"crowded_overlap":actor.actor_id,"at":str(actor.global_position)})
	check(absf(session.payload.distance-15) < .001,"twelve crowded actors cannot jam cart progress")
	check(crowded_clear,"crowded cart transport leaves actors clear of solid geometry")
	# Shoulder camera checks use the live shared spring arm with every hero.
	park_actors()
	for id: String in HeroRoster.IDS:
		player.select_hero(id)
		for at: Vector3 in [d.hill_center+Vector3(5,.08,-3),d.high_positions[1]+Vector3.UP*.08,d.flank_positions[2]+Vector3.UP*.08,d.high_positions[3]+Vector3.UP*.08]:
			player.global_position = at
			await frames(3)
			var query := PhysicsShapeQueryParameters3D.new()
			var sphere := SphereShape3D.new()
			sphere.radius = .06
			query.shape = sphere
			query.transform = Transform3D(Basis.IDENTITY,player.controller.camera.global_position)
			query.collision_mask = 1
			check(arena.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"camera clears museum architecture: "+id+" at "+str(at))
	var file := FileAccess.open("res://artifacts/museum/delivery.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"details":details},"  "))
	print("MUSEUM DELIVERY ",checks," checks; ",failures.size()," failures ",JSON.stringify(details))
	arena.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
