extends "res://tests/care_heroes_test.gd"
## Real physics acquisition and admission; optional native run also checks rendered markers.

func offered(a: HeroActor, action: String, target: HeroActor) -> bool:
	for preview: Dictionary in a.kit.selection_previews():
		if preview.action == action and preview.target == target: return true
	return false

func run() -> void:
	TrainingInputs.install()
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(100,1,100),Vector3(0,-.5,0),Color.GRAY)
	doctor = spawn("doctor",0,Vector3.ZERO)
	friend = spawn("nimbus",0,Vector3(0,0,-8))
	enemy = spawn("wisp",1,Vector3(4,0,-8))
	aim(doctor,friend)
	await step()
	var d := doctor.kit as DoctorKit
	for action: String in ["hover","aim","bomb","ultimate"]:
		check(offered(doctor,action,friend),"Doctor offers valid ally selection: "+action)
	d.mobility_cd = 2
	d.bomb_cd = 2
	d.ultimate_charge = 99
	check(d.selection_previews().size() == 1 and offered(doctor,"aim",friend),"Doctor cooldowns and ultimate charge hide only unavailable actions")
	d.refill()
	friend.benefits.grant("exemplary",doctor,5)
	check(not offered(doctor,"ultimate",friend),"Doctor cannot preview an already empowered ally")
	friend.benefits.clear()
	doctor.statuses.apply("silence",enemy,3)
	check(d.selection_previews().is_empty(),"silence hides all Doctor select starts including beam")
	doctor.statuses.cleanse()
	# Beam LOS is clear over this low obstruction; capsule travel is not.
	var low: Node3D = Geometry.box(world,Vector3(3,.7,.5),Vector3(0,.35,-4),Color.GRAY)
	await step()
	check(not offered(doctor,"hover",friend) and offered(doctor,"aim",friend),"capsule obstruction hides House Call without hiding usable beam")
	check(not d.start_call(),"House Call rejects the same blocked path")
	low.queue_free()
	await step()
	check(offered(doctor,"hover",friend) and d.start_call(),"House Call preview agrees with valid cast")
	doctor.select_hero("relay")
	await step()
	aim(doctor,friend)
	var r := doctor.kit as RelayKit
	check(offered(doctor,"bomb",friend),"Seeker offers assignable ally")
	check(not r.selection_previews().is_empty(),"Seeker assignment requires no resource")
	check(r.assign(friend) and r.selection_previews().is_empty(),"assigned recipient and transfer cooldown remove Relay prompt")
	r.transfer_cd = 0
	check(r.selection_previews().is_empty(),"current recipient remains excluded after cooldown")
	r.recall()
	check(offered(doctor,"bomb",friend),"recall restores valid assignment preview")
	doctor.select_hero("huddle")
	await step()
	aim(doctor,friend)
	var h := doctor.kit as HuddleKit
	check(offered(doctor,"deflect",friend),"Huddle previews selected ally screen")
	h.cast_screen()
	check(h.screen.recipient == friend and h.selection_previews().is_empty(),"Huddle preview and cast select the same ally and respect cooldown")
	h.deflect_cd = 0
	doctor.aim_direction = Vector3.BACK
	check(h.selection_previews().is_empty() and h.screen_target() == doctor,"Huddle self fallback does not mark an unrelated ally")
	doctor.select_hero("samson")
	await step()
	aim(doctor,friend)
	var s := doctor.kit as SamsonKit
	near(s.data().notice_width*s.data().notice_depth,82.5,"injunction area is roughly fifty percent larger")
	near(s.data().court_radius,11,"court protection radius increased one metre")
	check(offered(doctor,"hover",friend),"Samson offers reachable rescue target")
	s.charges = 0
	check(not offered(doctor,"hover",friend),"Samson needs an independent rescue charge")
	s.charges = 2
	low = Geometry.box(world,Vector3(3,.7,.5),Vector3(0,.35,-4),Color.GRAY)
	await step()
	check(not offered(doctor,"hover",friend) and not s.start_intervene(friend),"blocked capsule travel hides and rejects Intervene")
	low.queue_free()
	await step()
	aim(doctor,enemy)
	check(offered(doctor,"deflect",enemy),"Samson offers valid enemy examination")
	enemy.invulnerable = true
	check(not offered(doctor,"deflect",enemy),"immune enemy does not show examination marker")
	enemy.invulnerable = false
	var wall: Node3D = Geometry.box(world,Vector3(10,4,.5),Vector3(0,2,-4),Color.GRAY)
	await step()
	check(s.selection_previews().is_empty(),"world cover hides both enemy and ally select prompts")
	wall.queue_free()
	await step()
	check(offered(doctor,"deflect",enemy) and s.start_cross(enemy),"examination preview agrees with cast")
	check(s.selection_previews().is_empty(),"committed channel does not advertise unavailable starts")
	s.cancel()
	s.refill()
	doctor.statuses.apply("stun",enemy,1)
	check(s.selection_previews().is_empty(),"stun removes selection prompts")
	doctor.statuses.cleanse()
	doctor.statuses.apply("silence",enemy,1)
	check(s.selection_previews().is_empty(),"silence removes Samson selection prompts")
	doctor.statuses.cleanse()
	enemy.alive = false
	check(not offered(doctor,"deflect",enemy),"dead enemy cannot remain selected")
	enemy.alive = true
	enemy.position.z = -30
	check(not offered(doctor,"deflect",enemy),"out of range enemy cannot remain selected")
	enemy.position.z = -8
	aim(doctor,friend)
	friend.queue_free()
	await step()
	check(s.selection_previews().is_empty(),"freed ally is not retained by preview")
	# Every non-select kit inherits an empty contract with no gameplay changes.
	for id: String in ["nimbus","slayer","marshal","dynamo","wisp"]:
		doctor.select_hero(id)
		check(doctor.kit.selection_previews().is_empty(),id+" has no artificial lock-on prompts")
	doctor.select_hero("samson")
	await step()
	aim(doctor,enemy)
	var markers: AbilitySelectionMarkers = doctor.presentation.selections
	markers._process(0)
	check(markers.markers.is_empty(),"bots and uncontrolled actors never draw local selection UI")
	if DisplayServer.get_name() != "headless":
		var player := PlayerController.new()
		player.actor = doctor
		doctor.controller = player
		doctor.add_child(player)
		player.set_process(false)
		await step()
		# Detach the test camera so SpringArm's physics updates cannot move it.
		player.camera.reparent(world)
		player.camera.global_position = Vector3(0,3,4)
		player.camera.look_at(enemy.body_point(1.5))
		aim(doctor,enemy)
		markers._process(0)
		check(markers.markers.size() == 1 and markers.markers[0].visible,"native current camera shows enemy selection marker")
		check(markers.markers[0].text.contains(TrainingInputs.key_label("deflect")),"marker displays established input binding")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/ability-selection-enemy.png")
		player.active = false
		markers._process(0)
		check(not markers.markers[0].visible,"inactive controller hides marker immediately")
		player.active = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		markers._process(0)
		check(not markers.markers[0].visible,"free cursor hides selection feedback")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		paused = true
		markers._process(0)
		check(not markers.markers[0].visible,"pause hides selection feedback")
		paused = false
		doctor.select_hero("doctor")
		friend = spawn("nimbus",0,Vector3(0,0,-8))
		aim(doctor,friend)
		player.camera.global_position = Vector3(6,4,4)
		player.camera.look_at(friend.body_point(1.5))
		await step()
		check(not is_instance_valid(markers),"hero switch frees old marker pool")
		markers = doctor.presentation.selections
		markers._process(0)
		check(markers.markers.size() == 1 and markers.markers[0].visible,"multiple ally abilities share one overhead marker")
		check(markers.markers[0].text.contains("RMB") and markers.markers[0].text.contains("Q") and markers.markers[0].text.contains("1") and markers.markers[0].text.contains("2"),"ally marker lists every usable selection binding")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/ability-selection-ally.png")
		doctor.alive = false
		markers._process(0)
		check(not markers.markers[0].visible,"owner death hides marker immediately")
		doctor.controller = null
		player.rig.queue_free()
	world.queue_free()
	await step()
	print("RESULT: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
