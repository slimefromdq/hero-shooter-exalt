extends SceneTree
## Deterministic real-kit exercises for THE UNQUIET integration changes.
var world: Node3D
var resolver: CombatResolver
var a: HeroActor
var b: HeroActor
var ally: HeroActor
var extra: HeroActor
var checks: int = 0
var failures: Array[String] = []
var credited: HeroActor
var credited_ability: String
var cleanup_nodes: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func near(value: float, expected: float, caption: String, tolerance: float = .035) -> void:
	check(absf(value-expected) <= tolerance,caption+" [%.3f / %.3f]" % [value,expected])

func frames(count: int = 2) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func spawn(id: String, team: int, at: Vector3) -> HeroActor:
	var actor := HeroActor.new()
	actor.tuning = HeroRoster.tuning_for(id)
	actor.team = team
	actor.actor_id = id+str(team)
	actor.position = at
	world.add_child(actor)
	actor.set_physics_process(false)
	return actor

func aim(actor: HeroActor, at: Vector3) -> void:
	actor.intent = CombatIntent.new()
	actor.intent.aim_origin = actor.body_point(1.4)
	actor.aim_direction = (at-actor.intent.aim_origin).normalized()
	actor.intent.aim = actor.aim_direction
	actor.rotation.y = atan2(-actor.aim_direction.x,-actor.aim_direction.z)

func reset(id: String = "stitch") -> void:
	a.select_hero(id)
	a.reset_actor(Vector3(0,.035,0))
	b.select_hero("nimbus")
	b.reset_actor(Vector3(0,.035,-8))
	ally.reset_actor(Vector3(3,.035,0))
	extra.reset_actor(Vector3(15,.035,-16))
	for actor: HeroActor in [a,b,ally,extra]: actor.set_physics_process(false)
	for node: Node in get_nodes_in_group("transient"):
		node.set_physics_process(false)
		node.queue_free()
	resolver.clear_round()
	aim(a,b.body_point(1))
	await frames()

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	resolver.elimination.connect(func(killer: HeroActor, _victim: HeroActor, _assists: Array[HeroActor], ability: String) -> void:
		credited = killer
		credited_ability = ability)
	Geometry.box(world,Vector3(220,1,220),Vector3(0,-.5,0),Color.GRAY)
	a = spawn("stitch",0,Vector3(0,.035,0))
	b = spawn("nimbus",1,Vector3(0,.035,-8))
	ally = spawn("doctor",0,Vector3(3,.035,0))
	extra = spawn("marshal",1,Vector3(15,.035,-16))
	await frames(3)
	await evidence_cases()
	await disable_cases()
	await flight_cases()
	await stitch_cases()
	await perception_cases()
	await cleanup_cases()
	await ambush_edge_cases()
	await bot_edge_cases()
	world.queue_free()
	await frames(3)
	print("WAVE 1: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/wave-1-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"cleanup_nodes":cleanup_nodes},"\t"))
	quit(0 if failures.is_empty() else 1)

func evidence_cases() -> void:
	await reset("samson")
	var k := a.kit as SamsonKit
	check(k.evidence == 0,"Evidence starts empty")
	check(k.start_intervene(ally),"real Q accepts ally")
	for i: int in 90:
		if a.state == "samson_intervene": k.move_override(1.0/60)
	check(k.evidence == 1,"Q arrival grants Evidence")
	check(k.start_cross(b),"real E accepts enemy")
	k.tick(1.5,CombatIntent.new())
	check(k.evidence == 2,"completed E grants second Evidence")
	k.gain_evidence()
	check(k.evidence == 2,"Evidence caps at two")
	aim(a,Vector3(0,0,-6))
	check(k.place_notice(),"empowered 1 places on supported floor")
	check(k.evidence == 0,"successful 1 spends Evidence")
	near(k.notice.footprint.x,22,"two-Evidence width snapshots")
	near(k.notice.footprint.y,15,"two-Evidence depth snapshots")
	k.gain_evidence()
	near(k.notice.footprint.x,22,"later Evidence cannot resize placed notice")
	k.bomb_cd = 0
	aim(a,Vector3(150,0,150))
	a.position = Vector3(108,.035,108)
	check(not k.place_notice() and k.evidence == 1,"unsupported placement preserves Evidence")
	a.reset_actor(Vector3(0,.035,0))
	check(k.evidence == 0,"respawn/reset clears Evidence")
	k.start_cross(b)
	k.interrupt_cross()
	check(k.evidence == 0,"interrupted E grants no Evidence")
	for charge: int in 3:
		k.evidence = charge
		k.bomb_cd = 0
		aim(a,Vector3(0,0,-6))
		check(k.place_notice(),"real 1 placement at Evidence %d" % charge)
		near(k.notice.footprint.x,11*(1+.5*charge),"snapshot width at Evidence %d" % charge)
		k.notice._physics_process(.21)
		b.position = Vector3(k.notice.footprint.x*.49,.035,-6)
		check(k.notice.hostile_contains(b),"scaled boundary includes inner edge at Evidence %d" % charge)
		b.position.x = k.notice.footprint.x*.51
		check(not k.notice.hostile_contains(b),"scaled boundary rejects outer edge at Evidence %d" % charge)
	k.gain_evidence()
	a.die()
	check(k.evidence == 0,"death clears Evidence")

func disable_cases() -> void:
	await reset()
	check(b.statuses.apply("stun",a,1),"first hostile stun accepted")
	near(b.statuses.effects.stun.remaining,1,"first hard disable full duration")
	check(not b.statuses.apply("stun",a,3),"same-category reapplication cannot extend stun")
	b.statuses.tick(1.01)
	b.statuses.apply("root",a,1)
	near(b.statuses.effects.root.remaining,.5,"second hard disable half duration across categories")
	check(ControlFeedback.caption(b).contains("CONTROL RESISTANCE"),"reduced disable is visible")
	b.statuses.tick(.51)
	b.close.stagger(a)
	near(b.state_time,b.tuning.stagger_duration*.25,"third hostile stagger quarter duration")
	b.state = "ready"
	b.statuses.tick(4.01)
	b.statuses.apply("stun",a,1)
	near(b.statuses.effects.stun.remaining,1,"four quiet seconds restore full duration")
	b.reset_actor()
	check(b.statuses.hard_disable_count == 0,"per-life reset clears resistance history")
	a.select_hero("marshal")
	b.reset_actor(Vector3(0,.035,-5))
	# Give the target a real floor contact before Verdict's grounded eligibility.
	await frames()
	for i: int in 10:
		b.velocity = Vector3.DOWN*3
		b.move_and_slide()
	(a.kit as MarshalKit).cast_id = resolver.new_cast(a)
	(a.kit as MarshalKit).verdict_direction = Vector3.FORWARD
	(a.kit as MarshalKit).verdict()
	check(b.statuses.stunned(),"real Marshal Verdict applies status stun")
	if b.statuses.stunned(): near(b.statuses.effects.stun.remaining,1.5,"Verdict owns 1.5s stun")

func flight_cases() -> void:
	for direction: Vector3 in [Vector3.UP,Vector3.DOWN,Vector3(1,1,-1)]:
		await reset("wisp")
		a.position.y = 3
		var k := a.kit as WispKit
		var input := CombatIntent.new()
		input.deflect = true
		k.tick(0,input)
		near(a.state_time,1.6,"phase lasts 1.6 seconds")
		a.intent.flight_move = direction
		var before: Vector3 = a.position
		k.move_override(1.0/60)
		check((a.position-before).normalized().dot(direction.normalized()) > .99,"phase follows 3D flight wish")
		near((a.position-before).length(),.05,"flight diagonal is normalized")
		check(a.damage_immune(),"flight retains immunity")
	await reset("wisp")
	var k := a.kit as WispKit
	var wall := Geometry.box(world,Vector3(4,4,.4),Vector3(0,2,-1),Color.GRAY)
	await frames()
	a.state = "wisp_phase"
	a.intent.flight_move = Vector3.FORWARD
	for i: int in 20: k.move_override(.1)
	check(a.position.z > -.8,"phase remains blocked by terrain")
	wall.queue_free()
	await frames()

func stitch_cases() -> void:
	await reset()
	var k := a.kit as StitchKit
	near(k.data().conceal_speed,1.1,"concealment is slightly faster than walking")
	aim(a,b.body_point(1))
	k.start_conceal()
	k.collapse_left = 0
	var attack := CombatIntent.new()
	attack.primary = true
	k.prepare_input(attack)
	k.fire()
	for i: int in 35:
		if a.state == "stitch_lunge": k.move_override(1.0/60)
	near(b.health,205,"10m opening reaches enemy at 8m for 45 damage")
	check(b.statuses.effects.has("bleed"),"opening inflicts powerful bleed")
	b.statuses.tick(3)
	near(b.health,145,"opening bleed deals 60 over three seconds")
	check(not k.opening and a.state == "ready","opening consumed and controls restored")
	await reset()
	k = a.kit as StitchKit
	b.position.x = 20
	await frames()
	k.start_conceal()
	k.collapse_left = 0
	a.aim_direction = Vector3.FORWARD
	k.prepare_input(attack)
	k.fire()
	for i: int in 35:
		if a.state == "stitch_lunge": k.move_override(1.0/60)
	near(a.position.z,-10,"miss consumes full ten-meter lunge")
	check(not k.opening,"miss stores no second opening")
	await reset()
	k = a.kit as StitchKit
	aim(a,b.body_point(1))
	k.attach_thread()
	b.position.z = -18
	await frames()
	var before: float = b.position.z
	k.thread._physics_process(.1)
	check(b.position.z > before+.9,"taut thread noticeably pulls enemy toward Stitch")
	var mesh: Mesh = k.thread.visual.mesh
	k.thread._physics_process(.1)
	check(k.thread.visual.mesh == mesh,"thread reuses its mesh")
	var wall := Geometry.box(world,Vector3(4,4,.4),Vector3(0,2,-5),Color.GRAY)
	await frames()
	before = b.position.z
	k.thread._physics_process(.05)
	near(b.position.z,before,"blocked thread cannot pull through cover")
	wall.queue_free()
	b.statuses.cleanse()
	check(not k.thread.valid(),"cleanse retires spring thread")
	await frames()
	for kind: String in ["wall","ceiling","floor"]:
		await reset()
		k = a.kit as StitchKit
		b.position.x = 20
		var surface: Node3D
		var at: Vector3
		if kind == "wall":
			surface = Geometry.box(world,Vector3(6,5,.4),Vector3(0,2.5,-30),Color.GRAY)
			at = Vector3(0,2,-30)
		elif kind == "ceiling":
			surface = Geometry.box(world,Vector3(8,.4,8),Vector3(0,5,0),Color.GRAY)
			at = Vector3(0,5,0)
		else:
			a.position.y = 5
			at = Vector3(0,0,-4)
		await frames()
		k.start_conceal()
		k.collapse_left = 0
		aim(a,at)
		k.launch_hook()
		for i: int in 150:
			if k.hook_flying: k.tick_hook(1.0/60)
			if a.state == "stitch_reel": k.move_override(1.0/60)
		check(a.state == "stitch_hang","surface hook reaches hang: "+kind)
		check(k.concealed,"hook/reel/hang preserves concealment: "+kind)
		var held: Vector3 = a.position
		for i: int in 100: k.move_override(.1)
		check(a.position.is_equal_approx(held),"hang has no duration or gravity drift: "+kind)
		var release := CombatIntent.new()
		release.hover = true
		k.tick(0,release)
		check(a.state == "ready" and k.concealed,"Q releases during cooldown without reveal: "+kind)
		if surface != null: surface.queue_free()
		await frames()
	await reset()
	k = a.kit as StitchKit
	extra.position = Vector3(0,.035,-16)
	k.start_seam()
	a.state_time = 0
	k.tick(0,CombatIntent.new())
	for i: int in 40:
		if a.state == "stitch_seam": k.move_override(1.0/60)
	near(b.health,110,"piercing ultimate hits first enemy once")
	near(extra.health,extra.tuning.max_health-140,"piercing ultimate hits second enemy once")
	near(a.position.z,-26,"ultimate travels through actors to full range")
	await reset()
	k = a.kit as StitchKit
	b.health = 50
	k.start_conceal()
	k.collapse_left = 0
	k.prepare_input(attack)
	k.fire()
	for i: int in 35:
		if a.state == "stitch_lunge": k.move_override(1.0/60)
	b.statuses.tick(.5)
	check(not b.alive and credited == a and credited_ability == "bleed","lunge bleed elimination credits Stitch")

func perception_cases() -> void:
	await reset("samson")
	(a.kit as SamsonKit).start_cross(b)
	var perception := BotPerception.new()
	perception.sense(b,[a,b,ally],0)
	check(bool(perception.observations[a.get_instance_id()].channeling),"sampled bots recognize Samson channel")
	await reset("relay")
	var seeker := a.kit as RelayKit
	seeker.assign(ally)
	seeker.tick_spirit(.3)
	perception.sense(b,[a,b,ally],1)
	check(int(perception.observations[ally.get_instance_id()].healing_source) == a.get_instance_id(),"sampled bots recognize Seeker healing recipient")
	await reset("wisp")
	a.state = "wisp_phase"
	perception.sense(b,[a,b],2)
	check(bool(perception.observations[a.get_instance_id()].damage_immune),"sampled bots recognize Rogue immunity")

func cleanup_cases() -> void:
	for id: String in ["samson","stitch","wisp","relay"]:
		for cycle: int in 5:
			await reset(id)
			if a.kit is SamsonKit:
				var k := a.kit as SamsonKit
				k.gain_evidence()
				aim(a,Vector3(0,0,-6))
				k.place_notice()
				k.start_court()
				a.state_time = 0
				k.tick(0,CombatIntent.new())
			elif a.kit is StitchKit:
				var k := a.kit as StitchKit
				k.attach_thread()
				k.launch_hook()
			elif a.kit is WispKit:
				WispEffects.afterimage(a)
				WispEffects.flourish(a,a.body_point(1),1)
			else:
				var k := a.kit as RelayKit
				k.assign(ally)
				k.murmuration_left = 10
				k.update_extras()
				k.animate_birds(.01)
			if cycle%2 == 0: a.die()
			else: a.select_hero("nimbus")
			await frames(4)
			var owned: int = 0
			for node: Node in get_nodes_in_group("owned_attacks"):
				if node.get("source") == a: owned += 1
			var key: String = id+("_death" if cycle%2 == 0 else "_switch")
			var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			if cleanup_nodes.has(key): check(nodes <= int(cleanup_nodes[key]),"no node growth across repeated cleanup: "+key)
			else: cleanup_nodes[key] = nodes
			check(owned == 0,"owned effects clean after death/switch: %s cycle %d" % [id,cycle])
	await reset()
	var k := a.kit as StitchKit
	b.position.x = 20
	var wall := Geometry.box(world,Vector3(5,4,.4),Vector3(0,2,-5),Color.GRAY)
	await frames()
	aim(a,Vector3(0,1.5,-5))
	k.launch_hook()
	for i: int in 90:
		if k.hook_flying: k.tick_hook(1.0/60)
		if a.state == "stitch_reel": k.move_override(1.0/60)
	check(a.state == "stitch_hang","cleanup scenario reaches genuine hang")
	wall.queue_free()
	await frames()
	k.move_override(1.0/60)
	check(a.state == "ready","removed anchor releases hang")

func ambush_edge_cases() -> void:
	await reset()
	var k := a.kit as StitchKit
	b.position.x = 20
	var wall := Geometry.box(world,Vector3(5,5,.4),Vector3(0,2.5,-5),Color.GRAY)
	await frames()
	k.start_conceal()
	k.collapse_left = 0
	aim(a,Vector3(0,1.5,-5))
	k.launch_hook()
	for i: int in 90:
		if k.hook_flying: k.tick_hook(1.0/60)
		if a.state == "stitch_reel": k.move_override(1.0/60)
	check(a.state == "stitch_hang" and k.concealed,"ambush begins from genuine concealed hang")
	b.position = a.position+Vector3.BACK*7
	await frames()
	aim(a,b.body_point(1))
	var input := CombatIntent.new()
	input.primary = true
	k.prepare_input(input)
	k.tick(0,input)
	check(a.state == "stitch_lunge" and not k.concealed,"concealed attack releases hang into lunge")
	for i: int in 35:
		if a.state == "stitch_lunge": k.move_override(1.0/60)
	near(b.health,205,"hang ambush damages first enemy")
	wall.queue_free()
	await frames()
	await reset()
	k = a.kit as StitchKit
	k.reloading = true
	k.reload_remaining = 1
	k.start_conceal()
	k.collapse_left = 0
	k.prepare_input(input)
	k.fire()
	check(a.state == "stitch_lunge" and not k.reloading,"ammo-free lunge interrupts reload like scissors")
	await reset()
	k = a.kit as StitchKit
	wall = Geometry.box(world,Vector3(5,5,.4),Vector3(0,2.5,-4),Color.GRAY)
	await frames()
	k.start_conceal()
	k.collapse_left = 0
	k.prepare_input(input)
	k.fire()
	for i: int in 35:
		if a.state == "stitch_lunge": k.move_override(1.0/60)
	check(a.position.z > -3.8 and b.health == 250,"lunge stops at cover and cannot bleed through walls")
	wall.queue_free()
	await frames()
	await reset()
	k = a.kit as StitchKit
	k.start_conceal()
	k.collapse_left = 0
	a.statuses.apply("root",b,1)
	k.prepare_input(input)
	k.fire()
	check(a.state != "stitch_lunge","root prevents starting empowered primary mobility")

func bot_edge_cases() -> void:
	await reset()
	b.select_hero("wisp")
	b.state = "wisp_phase"
	var brain := BotBrain.new()
	brain.setup(a,TeamDirector.obtain(world,0),76)
	brain.now = 2
	brain.perception.sense(a,[a,b,ally,extra],2)
	brain.target_id = b.get_instance_id()
	brain.threat = brain.perception.observations[brain.target_id]
	brain.threat.first_seen = 0
	brain.acquired_at = 0
	var input := CombatIntent.new()
	input.aim_origin = a.body_point(1.4)
	brain.combat.choice = {"action":"ultimate","point":b.body_point(1),"held":false,"score":1.0}
	brain.combat.execute(brain,input,1.0/60,true)
	check(not input.primary and not input.primary_held and not input.ultimate,"bot suppresses shots and ultimate against sampled invulnerability")
	brain.diagnostics.detach()
	await reset()
	(a.kit as StitchKit).attach_thread()
	b.position.z = -14
	await frames()
	var perception := BotPerception.new()
	perception.sense(b,[a,b],3)
	check(perception.incoming_thread,"bots sample their own incoming tether")
	check(not BotMovement.new().safe_travel(b,Vector3.FORWARD,2),"bot avoids spending mobility against taut leash")
	await reset()
	var k := a.kit as StitchKit
	k.start_conceal()
	k.collapse_left = 0
	input = CombatIntent.new()
	input.move = Vector3.LEFT
	for i: int in 60: a.motor.tick(1.0/60,input)
	near(-a.velocity.x,a.tuning.ground_speed*1.1,"actual concealed walking reaches 110 percent speed",.1)
