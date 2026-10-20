extends SceneTree
var world: Node3D
var resolver: CombatResolver
var stitch: HeroActor
var enemy: HeroActor
var second: HeroActor
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func near(value: float, expected: float, caption: String, tolerance: float = .025) -> void:
	check(absf(value-expected) <= tolerance,caption+" [%.3f / %.3f]" % [value,expected])

func frames(count: int = 2) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func spawn(id: String, team: int, at: Vector3) -> HeroActor:
	var a := HeroActor.new()
	a.tuning = HeroRoster.tuning_for(id)
	a.team = team
	a.actor_id = id
	a.position = at
	world.add_child(a)
	a.set_physics_process(false)
	return a

func aim(a: HeroActor, target: Vector3) -> void:
	a.intent = CombatIntent.new()
	a.intent.aim_origin = a.body_point(1.2)
	a.aim_direction = (target-a.intent.aim_origin).normalized()
	a.intent.aim = a.aim_direction
	a.rotation.y = atan2(-a.aim_direction.x,-a.aim_direction.z)

func reset(distance: float = 8.0) -> void:
	for n: Node in get_nodes_in_group("transient"):
		n.set_physics_process(false)
		n.queue_free()
	stitch.reset_actor(Vector3(0,.035,0))
	enemy.select_hero("nimbus")
	enemy.reset_actor(Vector3(0,.035,-distance))
	second.reset_actor(Vector3(15,.035,0))
	for a: HeroActor in [stitch,enemy,second]: a.set_physics_process(false)
	aim(stitch,enemy.body_point(1.2))
	aim(enemy,stitch.body_point(1.2))
	resolver.clear_round()
	resolver.events.clear()
	await frames()

func marks(count: int = 3) -> void:
	for i: int in count: enemy.statuses.add_stitch(stitch,3,4)

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(180,1,180),Vector3(0,-.5,0),Color.GRAY)
	stitch = spawn("stitch",0,Vector3(0,.035,0))
	enemy = spawn("nimbus",1,Vector3(0,.035,-8))
	second = spawn("stitch",0,Vector3(15,.035,0))
	await frames(4)
	await weapon_tests()
	await mark_tests()
	await conceal_tests()
	await tether_tests()
	await actual_mobility_tests()
	await hook_tests()
	await seam_tests()
	await edge_tests()
	await perception_tests()
	await integration_tests()
	world.queue_free()
	await frames(3)
	print("STITCH RESULT: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/stitch-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)

func weapon_tests() -> void:
	await reset()
	var k := stitch.kit as StitchKit
	near(stitch.health,225,"Stitch has requested 225 HP")
	k.fire()
	near(k.shot_cd,.30,"needles use .30s cadence")
	near(k.ammo,23,"needles consume one round")
	await frames(15)
	near(enemy.health,232,"physical needle deals 18 damage")
	check(enemy.statuses.stitch_count(stitch) == 1,"needle impact adds a mark")
	k.fire()
	near(k.ammo,23,"shared cooldown prevents duplicate shots")
	enemy.global_position = Vector3(0,.035,-2.5)
	await frames()
	k.update_mode(.016)
	check(k.shears_mode,"frontal enemy enters shears mode")
	enemy.global_position.z = -2.9
	k.update_mode(.2)
	check(k.shears_mode,"exit range hysteresis retains shears")
	enemy.global_position.z = -4
	k.update_mode(.1)
	check(k.shears_mode,"switch grace prevents boundary flicker")
	k.update_mode(.06)
	check(not k.shears_mode,"switches to needles after grace")
	enemy.global_position = Vector3(0,3,-2)
	k.update_mode(.3)
	check(not k.shears_mode,"vertical separation does not trigger shears")
	enemy.global_position = Vector3(0,.035,2)
	k.update_mode(.3)
	check(not k.shears_mode,"enemy behind Stitch does not trigger shears")
	await reset(40)
	k = stitch.kit as StitchKit
	k.fire()
	await frames(45)
	near(enemy.health,232,"needle hits beyond former 35m range")
	await reset(47)
	k = stitch.kit as StitchKit
	k.fire()
	await frames(48)
	near(enemy.health,250,"needle respects 45m maximum range")
	await reset(2)
	k = stitch.kit as StitchKit
	var wall: Node3D = Geometry.box(world,Vector3(3,3,.3),Vector3(0,1.5,-1),Color.GRAY)
	await frames()
	k.update_mode(.2)
	check(not k.shears_mode,"cover prevents shears acquisition")
	wall.queue_free()
	await frames()
	k.update_mode(.1)
	k.ammo = 0
	k.reloading = true
	k.reload_remaining = 1
	k.fire()
	check(not k.reloading and k.ammo == 0,"shears interrupt reload without spending ammo")
	near(enemy.health,190,"shears deal 60 base damage")
	near(k.shot_cd,.42,"shears use .42s shared cooldown")

func mark_tests() -> void:
	await reset(2)
	var k := stitch.kit as StitchKit
	marks(5)
	check(enemy.statuses.stitch_count(stitch) == 3,"marks cap at three")
	enemy.statuses.add_stitch(second,3,4)
	k.update_mode(0)
	k.fire()
	near(enemy.health,154,"shears consume three marks for 96 damage")
	check(enemy.statuses.stitch_count(stitch) == 0 and enemy.statuses.stitch_count(second) == 1,"consumption is source-specific")
	marks()
	k.shot_cd = 0
	enemy.invulnerable = true
	k.fire()
	check(enemy.statuses.stitch_count(stitch) == 3,"immunity preserves marks")
	enemy.invulnerable = false
	enemy.state = "guard"
	enemy.aim_direction = Vector3.BACK
	k.shot_cd = 0
	k.fire()
	check(enemy.statuses.stitch_count(stitch) == 3,"guard block preserves marks")
	enemy.statuses.cleanse()
	check(enemy.statuses.stitches.is_empty(),"cleanse clears all stitch sources")
	marks()
	enemy.statuses.tick(4.01)
	check(enemy.statuses.stitch_count(stitch) == 0,"marks expire after four seconds")
	marks()
	stitch.reset_actor()
	check(enemy.statuses.stitch_count(stitch) == 0,"source reset immediately clears marks")

func conceal_tests() -> void:
	await reset()
	var k := stitch.kit as StitchKit
	k.start_conceal()
	check(stitch.concealed() and stitch.motor.crouched,"Play Dead enters low profile concealment")
	check(not stitch.objective_eligible(),"concealment cannot contribute to objectives")
	check(not stitch.permits("dash") and not stitch.permits("jump"),"concealment disallows dash and traversal")
	check(not stitch.detectable_by(enemy),"distant enemy cannot detect concealment")
	enemy.global_position.z = -4
	check(stitch.detectable_by(enemy),"nearby enemy has proximity silhouette")
	check(stitch.detectable_by(second),"allies retain visibility")
	k.tick(.25,CombatIntent.new())
	for i: int in 199: k.tick(.1,CombatIntent.new())
	check(k.concealed,"concealment survives 19.9 seconds")
	near(k.deflect_cd,0,"cooldown stays inactive throughout concealment")
	k.tick(.11,CombatIntent.new())
	check(not k.concealed,"concealment expires at twenty seconds")
	near(k.deflect_cd,12,"timeout starts full twelve-second cooldown")
	for action: String in ["deflect","primary","melee","guard","throw_action","bomb","ultimate"]:
		await reset()
		k = stitch.kit as StitchKit
		k.start_conceal()
		k.collapse_left = 0
		var input := CombatIntent.new()
		input.set(action,true)
		k.prepare_input(input)
		if action == "deflect": k.tick(0,input)
		check(not k.concealed,"action reveals before resolution: "+action)
		near(k.deflect_cd,12,"exit starts cooldown: "+action)
	await reset()
	k = stitch.kit as StitchKit
	k.start_conceal()
	resolver.damage(enemy,stitch,1,"rifle",resolver.new_cast(enemy))
	check(not k.concealed,"incoming damage reveals")
	near(k.deflect_cd,12,"damage reveal starts full cooldown")
	await reset(3.7)
	k = stitch.kit as StitchKit
	k.start_conceal()
	k.collapse_left = 0
	var attack := CombatIntent.new()
	attack.primary = true
	k.prepare_input(attack)
	k.fire()
	for i: int in 20:
		if stitch.state == "stitch_lunge": k.move_override(1.0/60)
	check(stitch.global_position.z < -1.0,"opening lunge advances collision-safely")
	near(enemy.health,205,"opening slicing lunge deals 45 direct damage")
	check(enemy.statuses.effects.has("bleed"),"opening lunge applies bleed")
	check(not k.opening,"opening bonus is consumed by one attack")
	await reset()
	k = stitch.kit as StitchKit
	k.start_conceal()
	k.reveal("manual")
	check(not k.opening,"manual exit stores no opening bonus")
	check(stitch.objective_eligible(),"revealed Stitch can contest again")

func tether_tests() -> void:
	await reset(10)
	var k := stitch.kit as StitchKit
	k.attach_thread()
	check(is_instance_valid(k.thread) and k.thread.valid(),"Red Thread attaches to selected enemy")
	near(k.bomb_cd,12,"thread cooldown starts on attachment")
	near(k.thread.remaining,5,"thread lasts five seconds")
	enemy.global_position.z = -15
	var motion: Vector3 = enemy.constrain_mobility(Vector3(0,0,-5))
	near(motion.z,0,"outward mobility is clamped outside ten metres")
	near(enemy.constrain_mobility(Vector3(0,0,4)).z,4,"inward mobility remains available")
	enemy.global_position.z = -17
	near(enemy.constrain_mobility(Vector3(0,0,-5)).length(),0,"outside leash cannot increase separation by mobility")
	near(enemy.constrain_mobility(Vector3(0,-1,0)).y,-1,"gravity remains available")
	enemy.global_position.z = -8
	enemy.state = "ready"
	check(enemy.permits("primary") and enemy.permits("dash"),"thread neither stuns nor disables ability activation")
	stitch.intent.move = Vector3.FORWARD
	near(k.movement_scale(),1.2,"pursuit grants twenty percent speed")
	stitch.intent.move = Vector3.BACK
	near(k.movement_scale(),1,"retreat receives no pursuit speed")
	check(not ControlFeedback.snapshot(enemy).is_empty(),"victim receives explicit tether warning")
	enemy.statuses.cleanse()
	check(not k.thread.valid(),"cleanse immediately retires tether")
	await reset()
	k = stitch.kit as StitchKit
	k.attach_thread()
	k.start_conceal()
	check(not k.thread.valid(),"concealment releases own tether")
	for reason: String in ["death","reset","phase","distance","expiry"]:
		await reset()
		k = stitch.kit as StitchKit
		k.attach_thread()
		match reason:
			"death": enemy.die()
			"reset": enemy.reset_actor()
			"phase": enemy.state = "wisp_phase"
			"distance": enemy.global_position.z = -29
			"expiry": k.thread.remaining = 0
		if is_instance_valid(k.thread): k.thread._physics_process(.01)
		check(not is_instance_valid(k.thread) or not k.thread.valid(),"tether cleans up on "+reason)
	await reset()
	k = stitch.kit as StitchKit
	k.attach_thread()
	var wall: Node3D = Geometry.box(world,Vector3(3,3,.3),Vector3(0,1.5,-4),Color.GRAY)
	await frames()
	k.thread._physics_process(.15)
	check(k.thread.valid(),"short obstruction does not flicker tether")
	k.thread._physics_process(.16)
	check(not k.thread.valid(),"sustained obstruction breaks tether")
	wall.queue_free()
	await frames()
	# Verify the gate is used by each existing kit's real movement override.
	for id: String in ["nimbus","slayer","marshal","doctor","huddle","relay","dynamo","wisp","samson","stitch"]:
		await reset(14)
		enemy.select_hero(id)
		enemy.global_position = Vector3(0,.035,-15.8)
		aim(stitch,enemy.body_point(1.2))
		k = stitch.kit as StitchKit
		# Attachment range is checked separately: install a valid pre-existing tether.
		var tether := RedThread.new()
		tether.source = stitch
		tether.target = enemy
		world.add_child(tether)
		var before: Vector3 = enemy.global_position
		enemy.move_ability_collide(Vector3(0,0,-6))
		check(stitch.global_position.distance_to(enemy.global_position) <= 16.01,"collision mobility gate supports "+id)
		enemy.global_position = before
		enemy.velocity = Vector3(0,0,-60)
		enemy.move_ability_slide(.1)
		check(stitch.global_position.distance_to(enemy.global_position) <= 16.01,"slide mobility gate supports "+id)

func hook_tests() -> void:
	await reset()
	var k := stitch.kit as StitchKit
	k.launch_hook()
	near(k.mobility_cd,13,"hook commits requested thirteen-second cooldown")
	for i: int in 40: k.tick_hook(.02)
	check(not k.hook_flying and stitch.state == "ready","untethered enemy blocks hook without reeling")
	await reset()
	k = stitch.kit as StitchKit
	k.attach_thread()
	k.launch_hook()
	for i: int in 15:
		if k.hook_flying: k.tick_hook(.02)
	check(stitch.state == "ready","hook rejects even a tethered enemy")
	for i: int in 60:
		if stitch.state == "stitch_reel": k.move_override(1.0/60)
	check(stitch.state == "ready" and stitch.global_position.z > -1,"rejected actor hook leaves control and position intact")
	check(stitch.global_position.distance_to(enemy.global_position) >= .8,"reel stops before overlapping victim")
	await reset()
	k = stitch.kit as StitchKit
	k.attach_thread()
	k.launch_hook()
	for i: int in 15:
		if k.hook_flying: k.tick_hook(.02)
	stitch.statuses.apply("root",enemy,1)
	k.tick(.016,CombatIntent.new())
	check(stitch.state == "ready" and k.reel_left == 0,"root interrupts reel without lockup")
	await reset()
	k = stitch.kit as StitchKit
	var wall: Node3D = Geometry.box(world,Vector3(4,3,.4),Vector3(0,1.5,-6),Color.GRAY)
	await frames()


	k.launch_hook()
	for i: int in 20:
		if k.hook_flying: k.tick_hook(.02)
	check(stitch.state == "stitch_reel","terrain hook finds supported landing")
	for i: int in 65:
		if stitch.state == "stitch_reel": k.move_override(1.0/60)
	check(stitch.state == "stitch_hang" and stitch.global_position.z > -5.8,"terrain reel hangs safely before wall")
	wall.queue_free()
	await frames()

func actual_mobility_tests() -> void:
	for id: String in ["nimbus","slayer","marshal","doctor","huddle","relay","dynamo","wisp","samson","stitch"]:
		await reset(13.5)
		enemy.select_hero(id)
		enemy.global_position = Vector3(0,.035,-13.5)
		aim(stitch,enemy.body_point(1.2))
		(stitch.kit as StitchKit).attach_thread()
		enemy.global_position.z = -15.8
		aim(enemy,enemy.body_point(1.2)+Vector3.FORWARD*10)
		var input := CombatIntent.new()
		input.aim = Vector3.FORWARD
		input.move = Vector3.FORWARD
		enemy.intent = input
		enemy.mobility_limited = false
		match id:
			"wisp":
				var w := enemy.kit as WispKit
				enemy.state = "wisp_step"
				w.step_direction = Vector3.FORWARD
				w.step_left = 7
				w.move_override(.1)
				check(w.shells == 0,"leash-truncated Ghoststep awards no completion shell")
			"samson":
				var lawyer := enemy.kit as SamsonKit
				second.team = enemy.team
				second.global_position = Vector3(0,.035,-22)
				lawyer.start_intervene(second)
				lawyer.move_override(.1)
				check(enemy.state == "ready", "leash-truncated Intervene cancels without arrival benefits")
				second.team = 0
			"doctor":
				var d := enemy.kit as DoctorKit
				enemy.state = "doctor_call"
				d.call_destination = enemy.global_position+Vector3.FORWARD*8
				d.move_override(.1)
			"huddle":
				var h := enemy.kit as HuddleKit
				enemy.state = "huddle_scatter"
				h.scatter_left = 8
				h.travel_direction = Vector3.FORWARD
				h.move_override(.1)
			"marshal":
				var m := enemy.kit as MarshalKit
				input.hover = true
				m.tick(.01,input)
				for i: int in 12:
					if enemy.state == "marshal_march": m.move_override(.03)
			"slayer":
				var s := enemy.kit as SlayerKit
				s.start_boot()
				enemy.state = "slayer_boot_active"
				s.move_override(.1)
			"relay":
				input.hover = true
				enemy.kit.tick(.01,input)
				enemy.motor.tick(.1,input)
			"stitch":
				var s := enemy.kit as StitchKit
				enemy.state = "stitch_reel"
				s.reel_point = enemy.global_position+Vector3.FORWARD*5
				s.reel_left = 1
				s.move_override(.1)
			_:
				enemy.motor.mode = "dash"
				enemy.motor.timer = .3
				enemy.motor.dash_direction = Vector3.FORWARD
				enemy.motor.dash_current_speed = 22
				enemy.motor.tick(.1,input)
		check(enemy.global_position.distance_to(stitch.global_position) <= 16.08,"actual mobility respects Red Thread: "+id)
	await reset(13.5)
	(stitch.kit as StitchKit).attach_thread()
	enemy.global_position.z = -15.8
	enemy.intent = CombatIntent.new()
	enemy.intent.move = Vector3.FORWARD
	for i: int in 30: enemy.motor.tick(.02,enemy.intent)
	check(enemy.global_position.distance_to(stitch.global_position) > 16.5,"normal walking can cross the leash")
	var before: float = enemy.global_position.z
	enemy.motor.external_velocity = Vector3.FORWARD*20
	enemy.motor.tick(.1,CombatIntent.new())
	check(enemy.global_position.z < before-1,"external knockback crosses leash unchanged")

func seam_tests() -> void:
	await reset(8)
	var k := stitch.kit as StitchKit
	marks()
	k.bomb_cd = 10
	k.start_seam()
	near(k.ultimate_charge,0,"ultimate commits charge on activation")
	near(stitch.state_time,.65,"ultimate has readable .65s windup")
	near(k.seam_distance,26,"ultimate telegraphs twenty-six-metre lane")
	stitch.state_time = 0
	k.tick(.01,CombatIntent.new())
	check(stitch.state == "stitch_seam","windup transitions into committed travel")
	for i: int in 45:
		if stitch.state == "stitch_seam": k.move_override(1.0/60)
	near(enemy.health,74,"ultimate deals 140 plus three mark bonuses once")
	check(enemy.statuses.stitch_count(stitch) == 3,"survivor retains marks")
	k.seam_damage(Vector3.ZERO,Vector3(0,.035,-18))
	near(enemy.health,74,"same cast cannot damage target twice")
	for health_value: float in [62.5,62.6]:
		await reset()
		k = stitch.kit as StitchKit
		marks(1)
		enemy.health = health_value
		k.bomb_cd = 10
		k.start_seam()
		k.seam_damage(stitch.global_position,enemy.global_position)
		var executions: int = 0
		for event: Dictionary in resolver.events:
			if event.event == "execution": executions += 1
		check(executions == (1 if health_value <= 62.5 else 0),"execute evaluates pre-hit threshold %.1f" % health_value)
		near(k.bomb_cd,0,"marked ultimate elimination refreshes thread")
	await reset()
	k = stitch.kit as StitchKit
	enemy.health = 40
	k.start_seam()
	k.seam_damage(stitch.global_position,enemy.global_position)
	check(resolver.events.filter(func(e: Dictionary) -> bool: return e.event == "execution").is_empty(),"unmarked enemy is never executed")
	await reset()
	k = stitch.kit as StitchKit
	marks()
	enemy.health = 50
	enemy.shields = 200
	k.start_seam()
	k.seam_damage(stitch.global_position,enemy.global_position)
	check(enemy.alive and enemy.health == 50,"shields prevent execution")
	await reset()
	k = stitch.kit as StitchKit
	k.start_seam()
	stitch.close.stagger()
	check(stitch.state == "stagger" and not k.ultimate_active(),"stagger interrupts ultimate windup")
	near(k.ultimate_charge,0,"interrupted ultimate has no refund")
	await reset()
	k = stitch.kit as StitchKit
	var wall: Node3D = Geometry.box(world,Vector3(4,3,.4),Vector3(0,1.5,-5),Color.GRAY)
	await frames()
	k.start_seam()
	check(k.seam_distance < 5,"wall truncates telegraph")
	stitch.state_time = 0
	k.tick(.01,CombatIntent.new())
	for i: int in 30:
		if stitch.state == "stitch_seam": k.move_override(.025)
	check(stitch.global_position.z > -5,"ultimate cannot clip through wall")
	near(enemy.health,250,"enemy behind wall receives no ultimate damage")
	wall.queue_free()
	await frames()

func perception_tests() -> void:
	await reset(12)
	var k := stitch.kit as StitchKit
	var perception := BotPerception.new()
	perception.sense(enemy,[stitch],0)
	check(stitch.get_instance_id() in perception.visible_ids,"bot initially sees visible Stitch")
	var remembered: Vector3 = perception.observations[stitch.get_instance_id()].position
	k.start_conceal()
	stitch.global_position.x = 2
	perception.sense(enemy,[stitch],1)
	check(not stitch.get_instance_id() in perception.visible_ids,"bot loses live concealed target")
	check(perception.observations[stitch.get_instance_id()].position == remembered,"concealment does not update remembered position")
	stitch.global_position = enemy.global_position+Vector3(0,0,4)
	perception.sense(enemy,[stitch],2)
	check(stitch.get_instance_id() in perception.visible_ids,"bot can read close-range concealment clue")
	enemy.select_hero("samson")
	var lawyer := enemy.kit as SamsonKit
	stitch.global_position = enemy.global_position+Vector3(0,0,-12)
	aim(enemy,stitch.body_point(1.2))
	check(lawyer.aimed_enemy() == null,"Samson selection cannot expose a distant concealed Stitch")
	stitch.global_position = enemy.global_position+Vector3(0,0,-4)
	aim(enemy,stitch.body_point(1.2))
	check(lawyer.aimed_enemy() == stitch,"Samson can select a readable proximity clue")

func edge_tests() -> void:
	await reset()
	var k := stitch.kit as StitchKit
	k.start_conceal()
	k.tick(20.3,CombatIntent.new())
	check(not k.concealed and k.deflect_cd == 12,"large delta still expires collapse plus concealment")
	await reset()
	k = stitch.kit as StitchKit
	var ceiling: Node3D = Geometry.box(world,Vector3(4,.3,4),Vector3(0,3,0),Color.GRAY)
	aim(stitch,Vector3(0,3,0))
	await frames()
	k.launch_hook()
	for i: int in 10:
		if k.hook_flying: k.tick_hook(.05)
	check(stitch.state == "stitch_reel" and not k.hook_flying,"ceiling hook accepts a capsule-safe reel")
	ceiling.queue_free()
	await frames()
	await reset()
	k = stitch.kit as StitchKit
	var wall: Node3D = Geometry.box(world,Vector3(4,3,.25),Vector3(0,1.5,-5),Color.GRAY)
	await frames()
	stitch.state = "stitch_reel"
	k.reel_point = Vector3(0,.035,-9)
	k.reel_left = 1
	k.move_override(.5)
	check(stitch.global_position.z > -4.6 and stitch.state == "ready","low frame rate reel sweeps capsule against thin wall")
	wall.queue_free()
	await frames()
	await reset()
	k = stitch.kit as StitchKit
	k.attach_thread()
	k.launch_hook()
	for i: int in 15:
		if k.hook_flying: k.tick_hook(.02)
	enemy.die()
	k.move_override(.02)
	check(stitch.state == "ready" and k.reel_left == 0,"target death immediately ends active reel")
	await reset()
	k = stitch.kit as StitchKit
	stitch.state = "stitch_reel"
	k.reel_point = Vector3(0,.035,-20)
	k.reel_left = .01
	k.move_override(.02)
	check(stitch.state == "ready","reel timeout always restores control")
	await reset()
	k = stitch.kit as StitchKit
	k.start_seam()
	enemy.global_position.x = 3
	stitch.state_time = 0
	k.tick(.01,CombatIntent.new())
	for i: int in 30:
		if stitch.state == "stitch_seam": k.move_override(.025)
	near(enemy.health,250,"perpendicular dodge escapes locked seam")
	await reset()
	k = stitch.kit as StitchKit
	k.start_seam()
	stitch.statuses.apply("slow",enemy,1,.5)
	k.tick(.01,CombatIntent.new())
	check(stitch.state == "ready" and not k.ultimate_active(),"slow interrupts seam windup")
	await reset()
	k = stitch.kit as StitchKit
	k.start_conceal()
	var low: Node3D = Geometry.box(world,Vector3(4,.4,4),Vector3(0,1.6,0),Color.GRAY)
	await frames()
	k.reveal("damage")
	check(stitch.motor.crouched,"revealing below low ceiling keeps safe crouch")
	low.queue_free()
	await frames()
	check(stitch.motor.try_stand(),"safe standing returns after ceiling clears")
	await reset()
	k = stitch.kit as StitchKit
	k.attach_thread()
	second.global_position = Vector3(6,.035,0)
	aim(second,enemy.body_point(1.2))
	(second.kit as StitchKit).attach_thread()
	check(is_instance_valid((second.kit as StitchKit).thread),"multiple Stitch sources can tether independently")
	enemy.statuses.cleanse()
	check(not k.thread.valid() and not (second.kit as StitchKit).thread.valid(),"cleanse retires every incoming thread")

func integration_tests() -> void:
	check("stitch" in HeroRoster.IDS and HeroRoster.role_for("stitch") == "dps","Stitch registered as selectable DPS")
	for seed_value: int in [76,971]:
		var roster: Array[String] = HeroRoster.composition_for("stitch",seed_value)
		check(roster[0] == "stitch" and roster.size() == 6,"seeded roster retains selected Stitch")
		for role: String in ["tank","support","dps"]:
			check(roster.filter(func(id: String) -> bool: return HeroRoster.role_for(id) == role).size() == 2,"composition preserves two "+role)
	check(BotHeroProfile.for_hero("stitch").hero == "stitch","dedicated bot profile loads")
	check(CareHUD.labels(stitch) == ["SPOOLSTEP","PLAY DEAD","RED THREAD"],"HUD matches Q / E / 1 mapping")
	var hill := CityHill.new()
	world.add_child(hill)
	await reset(30)
	var k := stitch.kit as StitchKit
	hill.definition = CityMapDefinition.new()
	stitch.global_position = hill.definition.hill_center
	k.start_conceal()
	hill.advance(.1,[stitch])
	check(hill.occupancy == [0,0],"concealed Stitch cannot contest City hill")
	hill.queue_free()
