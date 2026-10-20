extends SceneTree
var world: Node3D
var resolver: CombatResolver
var a: HeroActor
var b: HeroActor
var c: HeroActor
var ally: HeroActor
var k: WispKit
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",label)
	if not ok: failures.append(label)
func near(value: float, expected: float, label: String, tolerance: float = .03) -> void:
	check(absf(value-expected) <= tolerance,label+" [%.3f / %.3f]" % [value,expected])
func step(count: int = 2) -> void:
	for i: int in count:
		await physics_frame
		await process_frame
func spawn(id: String, team: int, at: Vector3) -> HeroActor:
	var actor := HeroActor.new()
	actor.tuning = HeroRoster.tuning_for(id)
	actor.team = team
	actor.actor_id = id+str(team)
	world.add_child(actor)
	actor.position = at
	actor.set_physics_process(false)
	return actor
func reset(at: Vector3 = Vector3(0,2,0)) -> void:
	for effect: Node in get_nodes_in_group("transient"): effect.queue_free()
	a.reset_actor(at)
	b.reset_actor(Vector3(0,0,-8))
	c.reset_actor(Vector3(15,0,-8))
	ally.reset_actor(Vector3(20,0,10))
	for actor: HeroActor in [a,b,c,ally]: actor.spawn_protected = false
	for actor: HeroActor in [b,c,ally]:
		actor.tuning.max_health = 2000
		actor.health = 2000
	k = a.kit as WispKit
	a.intent.aim = Vector3.FORWARD
	a.aim_direction = Vector3.FORWARD
	resolver.clear_round()
	await step()
func drive(delta: float, input: CombatIntent) -> void:
	a.intent = input
	a._physics_process(delta)
func request(action: String) -> CombatIntent:
	var input := CombatIntent.new()
	input.set(action,true)
	return input
func card_at(at: Vector3) -> WispCallingCard:
	var card := WispCallingCard.new()
	card.source = a
	card.cast_id = resolver.new_cast(a)
	world.add_child(card)
	card.set_physics_process(false)
	card.arm(at)
	return card
func marks(target: HeroActor, count: int = 4) -> void:
	for i: int in count: target.statuses.add_soul(a,4,3)

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(100,1,100),Vector3(0,-.5,0),Color.GRAY)
	a = spawn("wisp",0,Vector3(0,2,0))
	b = spawn("nimbus",1,Vector3(0,0,-8))
	c = spawn("nimbus",1,Vector3(15,0,-8))
	ally = spawn("wisp",0,Vector3(20,0,10))
	await step(3)
	await defenses()
	await leap()
	await extra_regressions()
	await burst()
	await heist_tests()
	await bots_and_presentation()
	world.queue_free()
	await step()
	print("WISP REWORK: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/wisp-rework-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)

func defenses() -> void:
	for fps: int in [30,60,144]:
		await reset()
		k.tick(0,request("hover"))
		check(a.damage_immune() and not a.objective_eligible(),"Q enters immunity immediately at %d Hz" % fps)
		var before: float = b.health
		resolver.damage(a,b,100,"projectile",resolver.new_cast(a))
		near(b.health,before,"Q suppresses already released outgoing attacks")
		var elapsed: float = 0
		for i: int in ceili(.18*fps):
			drive(1.0/fps,request("hover"))
			elapsed += 1.0/fps
			check(a.ability_damage_immune() == (elapsed < .15-.000001),"Q fixed immunity boundary %.4f at %d Hz" % [elapsed,fps])
		check(a.state == "wisp_step" and not a.damage_immune(),"Q travel outlasts its immunity")
		resolver.damage(b,a,20,"rifle",resolver.new_cast(b))
		near(a.health,205,"damage resumes before Q travel completes")
		k.cancel()
		check(not a.damage_immune() and k.step_immunity_left == 0,"interruption clears Q immunity")
	await reset()
	k.tick(0,request("hover"))
	check(a.statuses.apply("root",b,1),"Q retains crowd-control counterplay")
	check(not a.damage_immune(),"root terminates Q immunity immediately")
	await reset()
	var wall: Node3D = Geometry.box(world,Vector3(4,6,.3),Vector3(0,3,-1),Color.GRAY)
	await step()
	k.tick(0,request("hover"))
	k.move_override(.1)
	check(a.state == "ready" and not a.damage_immune() and k.shells == 0,"blocked Q ends immunity and grants no shell")
	wall.queue_free()
	await step()
	await reset()
	k.tick(0,request("deflect"))
	check(a.damage_immune() and not a.objective_eligible(),"Vanishing excludes objectives")
	check(not a.statuses.apply("root",b,1),"Vanishing retains control immunity")
	check(not a.permits("primary") and not a.permits("melee") and not a.permits("ultimate"),"Vanishing blocks every attack path")
	resolver.damage(b,a,100,"bleed",resolver.new_cast(b))
	near(a.health,225,"Vanishing blocks delayed incoming damage")
	resolver.damage(a,b,100,"grand_heist",resolver.new_cast(a))
	near(b.health,2000,"Vanishing blocks delayed outgoing damage")
	var move := CombatIntent.new()
	move.move = Vector3(1,0,1)
	move.deflect = true
	drive(.1,move)
	check(a.state == "wisp_phase","held E does not cancel without a new press")
	near(Vector2(a.velocity.x,a.velocity.z).length(),3,"Vanishing clamps diagonal reposition speed")
	near(a.position.y,2,"Vanishing hovers without ascent or descent")
	drive(.01,CombatIntent.new())
	drive(.01,request("deflect"))
	check(a.state == "ready" and not a.damage_immune() and k.phase_recovery_left > .19,"early cancellation is vulnerable and telegraphed")
	check(not a.permits("primary") and not a.permits("step") and a.permits("jump"),"reappearance locks attacks and abilities, allows movement")
	check(a.objective_eligible(),"objectives resume when immunity ends")
	drive(.21,CombatIntent.new())
	check(a.permits("primary"),"attack permission resumes after full recovery")
	await reset()
	a.invulnerable = true
	k.tick(0,request("deflect"))
	a.state_time = 0
	k.tick(0,CombatIntent.new())
	check(a.invulnerable and k.phase_recovery_left == .2,"natural exit preserves training invulnerability")
	a.invulnerable = false
	a.reset_actor()
	check(k.phase_recovery_left == 0 and not a.damage_immune(),"life reset clears defense timers")
	# Exercise the real city objective consumer rather than only the helper.
	var hill := CityHill.new()
	hill.definition = CityMapDefinition.new()
	hill.definition.hill_center = a.position
	hill.definition.hill_half_extents = Vector3(5,5,5)
	hill.definition.unlock_seconds = 0
	world.add_child(hill)
	a.state = "wisp_phase"
	hill.advance(.1,[a])
	check(hill.occupancy[0] == 0,"city capture ignores Vanishing")
	a.state = "ready"
	hill.advance(.1,[a])
	check(hill.occupancy[0] == 1,"city capture resumes after Vanishing")
	hill.queue_free()

func leap() -> void:
	await reset()
	k.tick(0,request("bomb"))
	near(a.velocity.y,12,"leap launches upward")
	near(a.velocity.z,-10,"leap launches forward")
	near(k.bomb_cd,8,"leap spends existing cooldown")
	k.tick(0,request("bomb"))
	check(not k.diving,"held activation cannot trigger immediate dive")
	k.tick(0,CombatIntent.new())
	k.tick(0,request("bomb"))
	check(k.diving and k.leap_active and k.glide_left == 0,"fresh second press dives during cooldown")
	near(a.velocity.y,-24,"dive starts immediately")
	check(a.permits("primary") and a.permits("secondary"),"dive allows pistol and burst attacks")
	a.intent.move = Vector3(1,0,1)
	k.move_override(.01)
	near(a.velocity.y,-24,"dive maintains rapid descent")
	check(Vector2(a.velocity.x,a.velocity.z).length() <= a.tuning.ground_speed+.001,"dive caps horizontal speed")
	for i: int in 30:
		if k.leap_active: k.move_override(1.0/60)
	check(not k.leap_active and not k.diving,"landing clears dive and recast")
	await reset()
	a.aim_direction = Vector3.UP
	k.tick(0,request("bomb"))
	near(Vector2(a.velocity.x,a.velocity.z).length(),10,"vertical aim falls back to forward facing")
	a.velocity.y = -1
	a.intent.jump_held = true
	k.tick(.1,CombatIntent.new())
	k.move_override(.1)
	near(a.velocity.y,-2,"hold Jump enables float")
	near(k.glide_left,1.4,"descending float opportunity counts down")
	a.intent.jump_held = false
	k.tick(.2,CombatIntent.new())
	near(k.glide_left,1.2,"released Jump still consumes descending opportunity")
	a.intent.dash = true
	check(not k.move_override(.01) and not k.leap_active,"shared dash retires leap before motor handles input")
	await reset()
	k.tick(0,request("bomb"))
	k.tick(0,CombatIntent.new())
	k.tick(0,request("hover"))
	check(not k.leap_active and a.state == "wisp_step","Q replaces leap without a stale dive")
	await reset()
	k.tick(0,request("bomb"))
	k.tick(0,request("deflect"))
	check(not k.leap_active and a.state == "wisp_phase","Vanishing retires leap")
	await reset()
	k.tick(0,request("bomb"))
	a.statuses.apply("root",b,1)
	check(not k.leap_active,"root clears leap immediately")

func burst() -> void:
	await reset(Vector3.ZERO)
	near(a.tuning.rifle_damage,13,"primary modestly reduced")
	near(k.burst_multiplier(8),1,"burst full damage at eight meters")
	near(k.burst_multiplier(16),.75,"burst midpoint falloff")
	near(k.burst_multiplier(24),.5,"burst outer falloff")
	near(k.data().pellet_count*k.data().pellet_damage,48,"wider pellet pattern retains total raw damage")
	var from: Vector3 = k.safe_muzzle()
	b.position = Vector3(from.x+.48,0,-8)
	await step()
	marks(b)
	var hit: Dictionary = k.burst_ray(Vector3.FORWARD,20,true)
	check(hit.get("result","") == "hit" and b.statuses.soul_count(a) == 0,"assisted near-miss core reliably detonates marks")
	near(2000-b.health,68,"assisted body core applies ordinary core and mark damage")
	await reset(Vector3(0,.45,0))
	b.position = Vector3(k.safe_muzzle().x+.36,0,-8)
	await step()
	hit = k.burst_ray(Vector3.FORWARD,20,true)
	check(hit.get("result","") == "hit","head-height near miss receives core assistance")
	near(2000-b.health,20,"assisted head-height contact cannot receive headshot damage")
	await reset(Vector3.ZERO)
	b.position.x = k.safe_muzzle().x
	marks(b)
	b.statuses.add_soul(ally,4,3)
	await step()
	k.burst_ray(Vector3.FORWARD,20,true)
	check(b.statuses.soul_count(a) == 0 and b.statuses.soul_count(ally) == 1,"burst consumes only owner marks")
	await reset(Vector3.ZERO)
	b.position = Vector3(k.safe_muzzle().x+.48,0,-8)
	marks(b)
	var wall: Node3D = Geometry.box(world,Vector3(5,4,.3),Vector3(0,2,-4),Color.GRAY)
	await step()
	k.burst_ray(Vector3.FORWARD,20,true)
	near(b.health,2000,"core assistance cannot cross cover")
	check(b.statuses.soul_count(a) == 4,"blocked core preserves marks")
	wall.queue_free()
	await step()
	await reset(Vector3.ZERO)
	b.position.x = k.safe_muzzle().x
	b.invulnerable = true
	marks(b)
	await step()
	k.burst_ray(Vector3.FORWARD,20,true)
	check(b.statuses.soul_count(a) == 4,"immune core preserves marks")
	b.invulnerable = false
	k.burst_ray(Vector3.FORWARD,6,false)
	check(b.statuses.soul_count(a) == 4,"pellets never consume marks")

func heist_tests() -> void:
	await reset()
	k.tick(0,request("ultimate"))
	check(k.ultimate_charge == 100 and not a.permits("primary"),"heist preparation retains charge and locks attacks")
	a.close.stagger()
	check(k.ultimate_charge == 100 and not is_instance_valid(k.heist),"interrupted preparation produces no card")
	await reset()
	k.tick(0,request("ultimate"))
	a.state_time = 0
	k.tick(0,CombatIntent.new())
	var card: WispCallingCard = k.heist
	card.set_physics_process(false)
	check(k.ultimate_charge == 0 and a.state == "ready" and a.permits("primary"),"release consumes charge and restores attacks")
	card._physics_process(1)
	check(card.armed,"card arms at maximum range")
	near(card.traveled,28,"card travel is bounded")
	near(card.remaining,.8,"arming begins full warning")
	card._physics_process(.79)
	check(not card.detonated,"warning cannot detonate early")
	card._physics_process(.01)
	check(card.detonated,"warning detonates at configured endpoint")
	await reset()
	b.position = Vector3(0,0,-8)
	c.position = Vector3(4,0,-8)
	marks(b)
	b.statuses.add_soul(ally,4,3)
	await step()
	card = card_at(Vector3(0,.9,-8))
	near(card.multiplier(2),1,"heist full damage radius")
	near(card.multiplier(5),.4,"heist edge falloff")
	card.detonate()
	near(b.health,1852,"heist combines base and four marks once")
	near(c.health,1940,"heist falloff applies to peripheral target")
	check(b.statuses.soul_count(a) == 0 and b.statuses.soul_count(ally) == 1,"heist consumes only its owner's marks")
	near(k.ultimate_charge,100,"heist does not grant additional ultimate charge")
	var hp: float = b.health
	card.detonate()
	near(b.health,hp,"repeated detonation cannot duplicate damage")
	await reset()
	k.ultimate_charge = 0
	card = card_at(b.body_point(.9))
	card.detonate()
	near(k.ultimate_charge,0,"released heist damage never charges successor")
	resolver.damage(a,b,13,"rifle",resolver.new_cast(a))
	check(k.ultimate_charge > 0,"ordinary follow-up damage can charge successor")
	await reset()
	marks(b)
	card = card_at(b.body_point(.9))
	k.tick(0,request("deflect"))
	card.detonate()
	near(b.health,2000,"Vanishing suppresses released heist damage")
	check(b.statuses.soul_count(a) == 4,"suppressed heist preserves marks")
	await reset()
	marks(b)
	b.invulnerable = true
	card = card_at(b.body_point(.9))
	card.detonate()
	check(b.statuses.soul_count(a) == 4 and b.health == 2000,"immune heist target keeps marks")
	await reset()
	marks(b)
	var wall: Node3D = Geometry.box(world,Vector3(5,4,.3),Vector3(0,2,-6),Color.GRAY)
	await step()
	card = card_at(Vector3(0,.9,-4))
	card.detonate()
	check(b.health == 2000 and b.statuses.soul_count(a) == 4,"heist respects terrain cover")
	wall.queue_free()
	await step()
	await reset()
	var structure := CombatStructure.new()
	structure.source = b
	structure.health = 1
	structure.size = Vector3(5,4,.3)
	world.add_child(structure)
	structure.position = Vector3(0,2,-6)
	await step()
	card = card_at(Vector3(0,.9,-4))
	card.detonate()
	check(structure.health == 0 and b.health == 2000,"breaking physical cover still protects against this cast")
	await step()
	await reset()
	card = card_at(b.body_point(.9))
	a.die()
	check(card.is_queued_for_deletion() and not card.is_physics_processing(),"death immediately retires calling card")
	card.detonate()
	near(b.health,2000,"retired card cannot deal late damage")
	await reset()
	card = card_at(b.body_point(.9))
	a.select_hero("nimbus")
	check(card.is_queued_for_deletion(),"hero switch retires calling card")
	a.select_hero("wisp")

func bots_and_presentation() -> void:
	await reset(Vector3.ZERO)
	var brain := BotBrain.new()
	brain.setup(a,null,76)
	brain.now = resolver.combat_time
	brain.acquired_at = brain.now-10
	brain.target_id = b.get_instance_id()
	brain.perception.visible_ids = [b.get_instance_id()]
	brain.threat = {"position":b.position,"velocity":Vector3.ZERO,"health":15.0,"maximum":250.0,"shields":0.0,"overhealth":0.0,"marks":0,"state":"ready","seen":brain.now,"first_seen":brain.now-10,"facing":Vector3.BACK}
	brain.tactical_state = "pressure"
	k.ultimate_charge = 0
	k.shells = 1
	brain.combat.evaluate(brain)
	check(brain.combat.ability_scores.has("secondary_pressed"),"bot recognizes unmarked burst finisher")
	k.shells = 0
	a.last_hit_age = .1
	brain.combat.evaluate(brain)
	check(brain.combat.ability_scores.has("hover"),"bot scores defensive Q against observed pressure")
	a.health = 60
	brain.combat.evaluate(brain)
	check(brain.combat.choice.get("action") == "deflect","low-health bot prefers longer Vanishing escape")
	k.tick(0,request("deflect"))
	var input := CombatIntent.new()
	brain.movement.apply(brain,input,false)
	brain.combat.execute(brain,input,.016,true)
	check(input.move.dot(Vector3.BACK) > 0 and not input.deflect and not input.primary,"phased bot repositions away without cancellation or firing")
	check(RosterTactics.wisp_safe_landing(a),"bot confirms safe dive landing")
	brain.diagnostics.detach()
	check(CareHUD.ultimate_label(a) == "GRAND HEIST" and CareHUD.labels(a)[2] == "MAJESTIC LEAP","HUD exposes new abilities with unchanged slots")
	var opaque: bool = true
	for mesh: MeshInstance3D in a.presentation.roster_parts.thief_meshes:
		if (mesh.material_override as StandardMaterial3D).albedo_color.a != 1: opaque = false
	check(opaque,"ordinary thief silhouette is opaque")
	WispEffects.afterimage(a)
	var effects: Array[Node] = get_nodes_in_group("owned_attacks")
	var decoys: int = 0
	for effect: Node in effects:
		if effect is WispEffects and effect.spin == 0:
			decoys += 1
			check(effect.find_children("*","CollisionObject3D",true,false).is_empty(),"decoy has no collision or gameplay body")
	check(decoys == 1,"Q afterimage is a bounded cosmetic decoy")

func extra_regressions() -> void:
	for fps: int in [30,60,144]:
		await reset()
		k.tick(0,request("bomb"))
		var flight := CombatIntent.new()
		flight.jump_held = true
		flight.primary_held = true
		for i: int in roundi(fps*.65): drive(1.0/fps,flight)
		check(a.position.y > 2.2 and k.leap_active,"leap reaches an aerial firing position at %d Hz" % fps)
		near(a.velocity.y,-2,"held float descent at %d Hz" % fps)
		check(k.ammo < 36,"ordinary primary cadence continues during leap at %d Hz" % fps)
		k.tick(0,request("bomb"))
		var before: int = k.ammo
		for i: int in roundi(fps*.3): drive(1.0/fps,flight)
		check(k.ammo < before and not k.diving,"firing continues through dive and landing at %d Hz" % fps)
	await reset()
	k.tick(0,request("hover"))
	for i: int in 15: drive(1.0/60,CombatIntent.new())
	check(a.state == "ready" and not a.damage_immune(),"first Q leaves an ordinary vulnerable endpoint")
	k.tick(0,request("hover"))
	near(k.step_immunity_left,.15,"consecutive accepted Q starts a fresh bounded window")
	near(k.steps,1,"consecutive Q spends another existing charge")
	await reset()
	a.statuses.apply("root",b,1)
	k.tick(0,request("deflect"))
	a.intent.move = Vector3.RIGHT
	k.move_override(.1)
	near(a.velocity.x,0,"Vanishing does not cleanse or bypass a pre-existing root")
	check(a.statuses.effects.has("root"),"Vanishing retains pre-existing negative status")
	await reset()
	# Use the real museum occupancy function for capture and payload phases.
	var museum := MuseumMatch.new()
	museum.definition = MuseumMapDefinition.new()
	museum.definition.hill_center = a.position
	museum.actors = [a]
	museum.player = a
	museum.objective.phase = "capture"
	a.state = "wisp_phase"
	check(museum.objective_occupancy()[0] == 0,"museum capture ignores Vanishing")
	a.state = "ready"
	check(museum.objective_occupancy()[0] == 1,"museum capture restores ordinary eligibility")
	var payload := MuseumPayload.new()
	payload.session = museum
	world.add_child(payload)
	payload.global_position = a.position+Vector3(2,0,0)
	museum.payload = payload
	museum.objective.phase = "escort"
	a.state = "wisp_phase"
	check(museum.objective_occupancy()[0] == 0,"payload ignores Vanishing")
	a.state = "ready"
	check(museum.objective_occupancy()[0] == 1,"payload restores ordinary eligibility")
	k.tick(0,request("hover"))
	check(museum.objective_occupancy()[0] == 0,"payload ignores Q immunity")
	payload.queue_free()
	museum.free()
	await step()
	await reset()
	var card := WispCallingCard.new()
	card.source = a
	card.cast_id = resolver.new_cast(a)
	card.direction = Vector3.FORWARD
	world.add_child(card)
	card.global_position = b.body_point(.9)+Vector3.BACK*2
	card.set_physics_process(false)
	card._physics_process(.1)
	check(card.armed and b.health == 2000,"calling card stops on enemy without direct damage")
	var planted: Vector3 = card.position
	b.position.x += 3
	await step()
	check(card.position.is_equal_approx(planted),"planted card does not follow an impacted enemy")
	await reset()
	var wall: Node3D = Geometry.box(world,Vector3(5,4,.3),Vector3(0,2,-4),Color.GRAY)
	await step()
	card = WispCallingCard.new()
	card.source = a
	card.cast_id = resolver.new_cast(a)
	card.direction = Vector3.FORWARD
	world.add_child(card)
	card.global_position = Vector3(0,1,-2)
	card.set_physics_process(false)
	card._physics_process(.2)
	check(card.armed and card.position.z > -4,"calling card stops on terrain")
	wall.queue_free()
	await step()
	await reset()
	c.select_hero("marshal")
	c.position = Vector3(0,0,-7)
	c.aim_direction = Vector3.BACK
	c.state = "marshal_shield"
	(c.kit as MarshalKit).barrier_hp = 1
	b.position = Vector3(0,0,-8)
	marks(b)
	await step()
	card = card_at(Vector3(0,.9,-4))
	card.detonate()
	check((c.kit as MarshalKit).barrier_hp == 0,"Grand Heist damages a hostile analytic barrier")
	check(b.health == 2000 and b.statuses.soul_count(a) == 4,"breaking analytic barrier protects this cast and preserves marks")
	c.select_hero("nimbus")
	await reset()
	marks(b)
	b.spawn_protected = true
	card = card_at(b.body_point(.9))
	card.detonate()
	check(b.health == 2000 and b.statuses.soul_count(a) == 4,"protected room rejects heist and preserves marks")
	await reset()
	marks(b)
	card = card_at(b.body_point(.9))
	b.statuses.tick(3.1)
	card.detonate()
	near(b.health,1900,"marks that expire before detonation grant no bonus")
	await reset()
	var input := CombatIntent.new()
	a.position = Vector3(80,5,80)
	k.leap_active = true
	k.leap_airborne = true
	k.glide_left = .1
	a.velocity.y = -1
	RosterTactics.wisp_air_controls(a,input,true)
	check(not input.bomb,"bot never dives into unsupported space")
