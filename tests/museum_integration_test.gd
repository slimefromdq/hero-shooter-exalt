extends SceneTree
var checks: int = 0
var failures: Array[String] = []
var details: Array[Dictionary] = []
var arena: Node3D
var session: MuseumMatch

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func connected(a: Vector3, b: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(arena.get_world_3d().navigation_map,a,b,true)
	var ok: bool = not path.is_empty() and path[0].distance_to(a) < 1.6 and path[-1].distance_to(b) < 1.6
	if not ok: details.append({"nav_from":str(a),"nav_to":str(b),"start":str(path[0]) if not path.is_empty() else "empty","end":str(path[-1]) if not path.is_empty() else "empty"})
	return ok

func walk(a: Vector3, b: Vector3, seconds: float) -> bool:
	var player: HeroActor = session.player
	player.reset_actor(a+Vector3.UP*.08)
	player.collision_mask = 1
	var intent := CombatIntent.new()
	intent.move = ((b-a)*Vector3(1,0,1)).normalized()
	intent.aim = intent.move
	for index: int in int(seconds*60):
		player.motor.tick(1.0/60,intent)
		await physics_frame
		if Vector2(player.global_position.x-b.x,player.global_position.z-b.z).length() < .55: break
	var reached: bool = Vector2(player.global_position.x-b.x,player.global_position.z-b.z).length() < .8 and absf(player.global_position.y-b.y) < .65
	if not reached:
		var hits: Array[Dictionary] = []
		for index: int in player.get_slide_collision_count():
			var hit := player.get_slide_collision(index)
			var body: Object = hit.get_collider()
			var part: int = hit.get_collider_shape_index()
			var at: String = str(body.get_child(part).position) if body is Node and part < body.get_child_count() else "unknown"
			hits.append({"at":str(hit.get_position()),"normal":str(hit.get_normal()),"shape":part,"shape_at":at})
		details.append({"from":str(a),"to":str(b),"ended":str(player.global_position),"hits":hits})
	return reached

func run() -> void:
	MuseumMatch.selected_side = 1 if "--defend" in OS.get_cmdline_user_args() else 0
	arena = load("res://scenes/museum/meridian_museum.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	session = arena.match_controller
	session.set_physics_process(false)
	session.player.controller.active = false
	for actor: HeroActor in session.actors:
		actor.set_physics_process(false)
		if actor != session.player: actor.controller.frozen = true
	var start: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec()-start < 30000:
		session._physics_process(0)
		await frames(1)
	check(session.navigation_ready,"museum navigation bakes before preparation")
	check(session.actors.size() == 12 and session.team_count(0) == 6 and session.team_count(1) == 6,"museum creates balanced 6v6 for either player side")
	check(session.player.team == MuseumMatch.selected_side,"chosen side owns the player slot")
	check(session.pickups.size() == 12,"four areas each have two small and one large pack")
	var d: MuseumMapDefinition = session.museum_definition()
	for stage: int in 4:
		d.attacker_stage = stage
		var target: Vector3 = d.hill_center+Vector3(5,0,-3) if stage == 0 else d.path_position(0 if stage == 1 else d.checkpoint_distances()[stage-2])
		check(connected(d.team_spawns(0)[0],target),"attacker spawn A%d has navigable objective route" % stage)
	for stage: int in 3:
		d.defender_stage = stage
		check(connected(d.team_spawns(1)[0],d.hill_center+Vector3(5,0,-3) if stage == 0 else d.path_position(d.checkpoint_distances()[0] if stage == 2 else 0)),"defender spawn D%d reaches its first hold" % stage)
	for index: int in 4:
		check(connected(d.high_positions[index],d.flank_positions[index]),"area %d high ground connects to lower flank by ordinary navigation" % index)
	# Inspect full payload clearance against world, excluding the cart itself.
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.5,2.8,3.5)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.exclude = [session.payload.get_rid()]
	var obstructions: Array[String] = []
	for distance: int in range(0,int(d.checkpoint_distances()[-1])+1,2):
		var at: Vector3 = d.path_position(distance)
		query.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*1.65)
		if not arena.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): obstructions.append("%d m %s" % [distance,str(at)])
	check(obstructions.is_empty(),"entire physical payload corridor is clear of museum architecture")
	if not obstructions.is_empty(): details.append({"track_obstructions":obstructions})
	# Direct physical traversal in both directions, no navigation teleporting.
	for stair: Dictionary in arena.builder.stairs:
		var seconds: float = (stair.a as Vector3).distance_to(stair.b)/4+1
		check(await walk(stair.a,stair.b,seconds),"physical ascending route "+str(stair.label)+str(stair.a))
		check(await walk(stair.b,stair.a,seconds),"physical descending route "+str(stair.label)+str(stair.a))
		if "GARDEN STAIR" in str(stair.label):
			for side: float in [-1,1]:
				var offset := Vector3(side*(float(stair.width)/2-.8),0,0)
				check(await walk(stair.a+offset,stair.b+offset,seconds),"garden edge stair traversal "+str(stair.label)+str(side))
				check(await walk(stair.b+offset,stair.a+offset,seconds),"garden edge stair return "+str(stair.label)+str(side))
	session.restart_match()
	var player: HeroActor = session.player
	for actor: HeroActor in session.actors: actor.global_position = Vector3(-50,0,38)
	player.global_position = d.hill_center+Vector3(5,.08,-3)
	session.objective.phase = "capture"
	check(session.objective_occupancy()[player.team] == 1,"ground actor contributes to capture")
	player.global_position.y = 3.6
	check(session.objective_occupancy()[player.team] == 0,"balcony actor cannot capture through floor")
	player.global_position.y = -1.5
	check(session.objective_occupancy()[player.team] == 0,"lower-floor actor cannot capture")
	session.objective.phase = "escort"
	player.global_position = d.payload_path[0]+Vector3(3,.08,0)
	check(session.objective_occupancy()[player.team] == 1,"nearby visible actor escorts cart")
	player.global_position.y = 4
	check(session.objective_occupancy()[player.team] == 0,"upper actor cannot escort cart through floor")
	# Temporary physical occluder verifies sight checks independently of distance.
	player.global_position = d.payload_path[0]+Vector3(3,.08,0)
	var blocker := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var block_shape := BoxShape3D.new()
	block_shape.size = Vector3(.5,3,4)
	collider.shape = block_shape
	blocker.add_child(collider)
	blocker.position = d.payload_path[0]+Vector3(1.5,1.5,0)
	arena.add_child(blocker)
	await frames(2)
	check(session.objective_occupancy()[player.team] == 0,"wall blocks escort and contest occupancy")
	blocker.queue_free()
	await frames(2)
	session.restart_match()
	var held: HeroActor = session.actors[0]
	var outside: HeroActor = session.actors[2]
	outside.global_position = Vector3(10,.08,10)
	var outside_at: Vector3 = outside.global_position
	var health: float = held.health
	session._relocate(1,1)
	check(held.global_position.distance_to(held.spawn_position) < .01 and held.health == health,"relocation moves safe-room occupants without resetting health")
	check(outside.global_position == outside_at,"relocation preserves living actors outside spawn")
	check(not session.spawn_contains(d.attacker_rooms[0],0),"retired room loses spawn protection")
	check(session.track_intersects(AABB(d.payload_path[0]-Vector3(1,0,1),Vector3(2,3,2))),"remaining payload track rejects wall placements")
	check(not session.track_intersects(AABB(Vector3(-38,0,33),Vector3(3,3,2))),"off-track wall positions remain available")
	for id: String in HeroRoster.IDS:
		player.global_position = player.spawn_position
		session.select_hero(id)
		check(player.tuning.hero_id == id and session.pending_hero == "","museum allows immediate spawn switch to "+id)
	player.global_position = Vector3(10,.08,10)
	session.select_hero("slayer" if player.tuning.hero_id != "slayer" else "nimbus")
	check(session.pending_hero != "","outside spawn hero switch queues")
	session.respawn_actor(player)
	check(session.pending_hero == "" and player.kit.ultimate_charge == 0,"queued hero applies on respawn with zero ultimate")
	# Pedestrian and rider transport use real swept CharacterBody motion.
	for actor: HeroActor in session.actors: actor.global_position = Vector3(-35,0,20)
	session.payload.reset_cart()
	player.global_position = d.payload_path[0]+Vector3(1.2,.5,0)
	await frames(2)
	session.payload.move_to_distance(4)
	check(player.global_position.distance_to(session.payload.global_position+Vector3(1.2,.5,0)) < .15,"payload carries a standing rider without drift")
	player.global_position = d.path_position(8)+Vector3(0,.08,0)
	session.payload.move_to_distance(10)
	check(absf(session.payload.distance-10) < .001 and player.global_position.distance_to(session.payload.global_position) > 2,"pedestrian cannot jam cart and is swept to a clear shoulder")
	check(not player.test_move(player.global_transform,Vector3.ZERO),"cart displacement leaves capsule clear")
	session.payload.reset_cart()
	session.payload.move_to_distance(11)
	player.global_position = session.payload.global_position+Vector3(1.2,.5,0)
	await frames(2)
	session.payload.move_to_distance(24)
	check(player.global_position.distance_to(session.payload.global_position+Vector3(1.2,.5,0)) < .15,"rider transport follows cart bends without lateral drift")
	session.payload.move_to_distance(5)
	check(player.global_position.distance_to(session.payload.global_position+Vector3(1.2,.5,0)) < .15,"rollback carries riders safely through previous bends")
	session.restart_match()
	check(session.phase == "preparation" and d.attacker_stage == 0 and d.defender_stage == 0 and session.winner == -1,"restart resets spawns, cart and objective")
	for index: int in 4:
		var controller := session.bots[index].controller as MuseumBotController
		var original_slot: int = controller.slot
		controller.slot = index
		session.objective.phase = "capture"
		controller.decide()
		check(controller.destination.y < 1.1 and connected(controller.actor.global_position,controller.destination),"capture bot slot %d targets reachable ground instead of the pedestal" % index)
		session.objective.phase = "escort"
		controller.decide()
		var offset: Vector3 = controller.destination-session.payload.global_position
		check(Vector2(offset.x,offset.z).length() > 2.1 and Vector2(offset.x,offset.z).length() < 5,"escort bot slot %d targets the cart shoulder" % index)
		controller.slot = original_slot
	session.restart_match()
	session.toggle_menu()
	check(paused and session.menu_open,"museum pause freezes SceneTree")
	session.toggle_menu()
	check(not paused and not session.menu_open,"resume restores play")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/museum"))
	var result := FileAccess.open("res://artifacts/museum/integration-%s.json" % ("defend" if player.team == 1 else "attack"),FileAccess.WRITE)
	result.store_string(JSON.stringify({"checks":checks,"failures":failures,"details":details},"  "))
	print("MUSEUM INTEGRATION ",checks," checks; ",failures.size()," failures ",JSON.stringify(details))
	arena.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
