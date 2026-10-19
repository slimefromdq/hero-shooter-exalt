extends SceneTree
## Physical doors, authority-boundary combat policy, and authored route clearance.
var arena: Node3D
var session: MuseumMatch
var checks: int = 0
var failures: Array[String] = []
var details: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)
func frames(count: int = 2) -> void:
	for index: int in count:
		await physics_frame
		await process_frame
func park() -> void:
	for actor: HeroActor in session.actors: actor.global_position = Vector3(-54,.08,46)
func run() -> void:
	arena = load("res://scenes/museum/meridian_museum.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	session = arena.match_controller
	session.set_physics_process(false)
	for actor: HeroActor in session.actors: actor.set_physics_process(false)
	for door: MuseumSpawnDoor in arena.builder.spawn_gates: door.set_physics_process(false)
	var begin: int = Time.get_ticks_msec()
	while not session.navigation_ready and Time.get_ticks_msec()-begin < 30000:
		session._physics_process(0)
		await frames(1)
	check(session.navigation_ready,"redesign navigation synchronized")
	var d: MuseumMapDefinition = session.museum_definition()
	var friends: Array[HeroActor] = [session.actors[0],session.actors[1]]
	for actor: HeroActor in session.actors:
		if actor.team == 1: friends[1] = actor; break
	var resolver: CombatResolver = session.player.resolver
	session.objective.phase = "capture"
	park()
	for door: MuseumSpawnDoor in arena.builder.spawn_gates:
		if door.team == 0: d.attacker_stage = door.stage
		else: d.defender_stage = door.stage
		arena.builder.update_gates(false)
		var ally: HeroActor = friends[door.team]
		var enemy: HeroActor = friends[1-door.team]
		var local_inside := Vector3(0,.08,-2)
		var local_outside := Vector3(0,.08,2)
		ally.global_position = door.to_global(local_inside)
		enemy.global_position = door.to_global(local_outside)
		var original_hp: float = enemy.health
		check(door.openness == 0,"active door begins closed: "+door.name)
		check(resolver.damage(ally,enemy,10,"door_test",resolver.new_cast(ally)) == "immune" and enemy.health == original_hp,"closed shutter blocks direct offensive resolution: "+door.name)
		door._physics_process(.125)
		check(is_equal_approx(door.openness,.5),"shutter opens halfway after 0.125s: "+door.name)
		door._physics_process(.125)
		await frames()
		check(door.openness == 1 and door.shutter.collision_layer == 0,"friendly opens physical shutter in 0.25s: "+door.name)
		ally.collision_mask = 9 if ally.team == 0 else 5
		enemy.collision_mask = 9 if enemy.team == 0 else 5
		var crossing: Vector3 = Vector3(0,0,4).rotated(Vector3.UP,door.rotation.y)
		check(not ally.test_move(Transform3D(Basis.IDENTITY,door.to_global(local_inside)),crossing),"open threshold passes owning team: "+door.name)
		check(enemy.test_move(Transform3D(Basis.IDENTITY,door.to_global(local_outside)),-crossing),"open threshold physically excludes enemy: "+door.name)
		check(session.is_protected(ally) and not session.is_protected(enemy),"only friendly interior grants immunity: "+door.name)
		check(resolver.damage(ally,enemy,10,"door_test",resolver.new_cast(ally)) == "hit","protected actor can damage through open door: "+door.name)
		var hp: float = ally.health
		for tag: String in ["rifle","projectile","shotgun","bleed","ultimate","melee","snare"]:
			check(resolver.damage(enemy,ally,50,tag,resolver.new_cast(enemy)) == "immune","spawn immunity rejects "+tag+": "+door.name)
		resolver.splash(enemy,enemy.body_point(1),6,50,"bomb",resolver.new_cast(enemy))
		check(ally.health == hp,"open-door splash cannot hurt protected actor: "+door.name)
		check(not ally.statuses.apply("root",enemy,2) and not ally.statuses.apply("slow",enemy,2,.2),"hostile root and slow rejected: "+door.name)
		ally.motor.external_velocity = Vector3.ZERO
		resolver.knockback(enemy,ally,Vector3.UP*10,"door_test")
		check(ally.motor.external_velocity == Vector3.ZERO and ally.velocity.y <= .01,"hostile launch rejected: "+door.name)
		ally.global_position = door.to_global(local_outside)
		ally.spawn_protected = true # stale frame flag must not grant immunity.
		check(not resolver.protected_room(ally),"immunity ends immediately across threshold: "+door.name)
		enemy.global_position = door.to_global(local_inside)
		check(not resolver.protected_room(enemy),"enemy breach never receives protection: "+door.name)
		session.enforce_spawn_exclusion(enemy,door.to_global(local_outside))
		check(not d.spawn_bounds(door.team).has_point(enemy.global_position),"ability relocation into enemy spawn is rejected: "+door.name)
		ally.global_position = door.to_global(Vector3(0,.08,0))
		door._physics_process(1)
		check(door.openness == 1,"friendly occupying threshold prevents closure: "+door.name)
		park()
		door._physics_process(.74)
		check(door.openness == 1,"door remains open during 0.75s grace: "+door.name)
		door._physics_process(.01)
		door._physics_process(.25)
		check(door.openness == 0,"empty door closes safely: "+door.name)
		enemy.global_position = door.to_global(local_outside)
		door._physics_process(.5)
		check(door.openness == 0,"enemy proximity cannot open door: "+door.name)
		park()
	# Every hero can initiate an offensive action from released friendly spawn.
	d.attacker_stage = 0
	d.defender_stage = 0
	var player: HeroActor = session.player
	for id: String in HeroRoster.IDS:
		player.select_hero(id)
		player.global_position = d.spawn_center(player.team)
		check(player.permits("primary"),"released spawn permits offensive action for "+id)
	var enemy: HeroActor = friends[1-player.team]
	player.global_position = d.hill_center+Vector3(5,.08,3)
	enemy.global_position = d.hill_center+Vector3(7,.08,3)
	check(player.statuses.apply("root",enemy,5),"root applies outside spawn")
	player.global_position = d.spawn_center(player.team)
	player.statuses.tick(0)
	check(not player.statuses.movement_disabled(),"entering friendly spawn cleanses existing hostile effects")
	# Full cart plus standing artifact rider clears the whole route, not just endpoints.
	park()
	var box := BoxShape3D.new()
	box.size = Vector3(3.5,4.5,3.5)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.collision_mask = 1
	query.exclude = [session.payload.get_rid()]
	for step: int in int(d.checkpoint_distances()[-1]*2)+1:
		var at: Vector3 = d.path_position(step*.5)
		query.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*2.35)
		var hits := arena.get_world_3d().direct_space_state.intersect_shape(query,1)
		if not hits.is_empty(): details.append({"cart_clearance_m":step*.5,"at":str(at)})
	check(details.is_empty(),"complete folded track clears cart and standing artifact riders")
	for entry: Dictionary in d.tactical_routes:
		var points: Array = entry.points
		for index: int in range(1,points.size()):
			var path := NavigationServer3D.map_get_path(arena.get_world_3d().navigation_map,points[index-1],points[index],true)
			var ok: bool = not path.is_empty() and path[0].distance_to(points[index-1]) < 1.6 and path[-1].distance_to(points[index]) < 1.6
			check(ok,"ordinary tactical route segment: %s %d" % [entry.name,index])
			if not ok: details.append({"route":entry.name,"segment":index,"start":str(path[0]) if not path.is_empty() else "empty","end":str(path[-1]) if not path.is_empty() else "empty"})
	for sector: int in 4:
		var visible: int = 0
		for entry: Vector3 in d.approach_positions[sector]:
			if resolver.ray(d.high_positions[sector]+Vector3.UP*1.6,entry+Vector3.UP*1.2,[],1).is_empty(): visible += 1
		check(visible < 3,"primary perch cannot see every approach in area %d (visible %d/3)" % [sector,visible])
	session.restart_match()
	var door: MuseumSpawnDoor = arena.builder.spawn_gates[0]
	player.global_position = door.to_global(Vector3(0,.08,-2))
	door._physics_process(1)
	check(door.openness == 0,"attacker preparation door remains locked")
	session.toggle_exploration()
	door._physics_process(.25)
	check(door.openness == 1,"Explore releases team-operated preparation doors")
	session.toggle_exploration()
	session._relocate(1,1)
	check(door.retired and door.openness == 1 and door.threshold.collision_layer == 0,"retired spawn is open public space")
	check(not session.spawn_contains(d.attacker_rooms[0],0),"retired spawn no longer grants immunity")
	session.restart_match()
	check(not door.retired and door.locked and door.openness == 0,"restart restores initial door ownership and lock")
	session.objective.phase = "capture"
	var tactical_bot: HeroActor = session.bots[0]
	var brain := tactical_bot.controller as MuseumBotController
	var original_slot: int = brain.slot
	brain.slot = 4
	brain.elapsed = 10
	brain.detour_until = 0
	brain.stuck_time = 1.6
	brain.load_route()
	brain.decide()
	check(brain.tactical_done and brain.assignment in ["escort","contest"],"blocked optional route yields to objective pressure")
	session.respawn_actor(tactical_bot)
	check(not brain.tactical_done and brain.tactical_key == "","respawn resets tactical route state")
	brain.slot = original_slot
	var file := FileAccess.open("res://artifacts/museum/redesign.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"details":details},"  "))
	print("MUSEUM REDESIGN ",checks," checks; ",failures.size()," failures ",JSON.stringify(details))
	arena.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
