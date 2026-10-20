extends SceneTree
var world: Node3D
var resolver: CombatResolver
var a: HeroActor
var b: HeroActor
var friend: HeroActor
var extra: HeroActor
var brain: BotBrain
var director: TeamDirector
var checks: int = 0
var failures: Array[String] = []
var objective: Dictionary = {"position":Vector3(0,0,-10),"phase":"fight","urgency":.5,"radius":7.0}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)

func step(count: int = 1) -> void:
	for i: int in count:
		await physics_frame
		await process_frame

func spawn(id: String, team: int, at: Vector3) -> HeroActor:
	var actor := HeroActor.new()
	actor.tuning = HeroRoster.tuning_for(id)
	actor.actor_id = id+str(team)
	actor.team = team
	actor.position = at
	world.add_child(actor)
	actor.set_physics_process(false)
	return actor

func reset(id: String = "nimbus") -> void:
	if brain != null: brain.diagnostics.detach()
	for node: Node in get_nodes_in_group("owned_attacks"): node.queue_free()
	a.select_hero(id)
	a.actor_id = "subject_"+id
	a.reset_actor(Vector3(0,.01,0))
	b.select_hero("nimbus")
	b.reset_actor(Vector3(0,.01,-13))
	b.tuning.max_health = 2000
	b.health = 2000
	friend.reset_actor(Vector3(3,.01,-4))
	extra.reset_actor(Vector3(4,.01,-14))
	extra.health = 2000
	friend.health = friend.effective_max_health()
	a.kit.ultimate_charge = 0
	a.last_hit_age = 99
	a.aim_direction = Vector3.FORWARD
	director.clear()
	brain = BotBrain.new()
	brain.setup(a,director,76)
	brain.skill = brain.skill.duplicate() as BotSkillProfile
	await step(2)

func decide(acquire: bool = true, actors: Array = []) -> void:
	var participants: Array = [a,b,friend] if actors.is_empty() else actors
	brain.decide(participants,objective)
	if acquire:
		for i: int in 3:
			resolver.combat_time += .2
			brain.decide(participants,objective)

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(120,1,120),Vector3(0,-.5,0),Color.GRAY)
	a = spawn("nimbus",0,Vector3.ZERO)
	b = spawn("nimbus",1,Vector3(0,0,-13))
	friend = spawn("marshal",0,Vector3(3,0,-4))
	extra = spawn("nimbus",1,Vector3(4,0,-14))
	director = TeamDirector.obtain(world,0)
	await reset()
	await perception_and_decisions()
	await tactical_states()
	await profiles()
	await nimbus_ultimate()
	await bombs()
	brain.diagnostics.detach()
	world.queue_free()
	await step(3)
	print("BOT TACTICS: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func perception_and_decisions() -> void:
	decide(false)
	check(brain.visible_target() and not brain.ready_to_attack(),"new target requires acquisition delay")
	for i: int in 3:
		resolver.combat_time += .2
		brain.decide([a,b,friend],objective)
	check(brain.ready_to_attack(),"locally seen target becomes actionable after reaction time")
	var saved: Vector3 = brain.threat.position
	var wall: Node3D = Geometry.box(world,Vector3(12,5,1),Vector3(0,2,-6),Color.GRAY)
	await step(2)
	b.global_position.x = 3
	b.health = 15
	b.state = "deflect"
	resolver.combat_time += .2
	brain.decide([a,b,friend],objective)
	check(not brain.visible_target(),"terrain removes local sight")
	check(brain.threat.position == saved and float(brain.threat.health) == 2000,"hidden position and health stay sampled")
	check(str(brain.threat.state) != "deflect","unseen defensive use is unknown")
	var report: Dictionary = director.reports[b.get_instance_id()]
	var shared := BotPerception.new()
	shared.merge_shared(director.reports,resolver.combat_time)
	check(float(shared.observations[b.get_instance_id()].seen) == float(report.seen),"radio preserves original observation timestamp")
	resolver.combat_time += 4.1
	brain.decide([a,b,friend],objective)
	check(brain.threat.is_empty() and brain.target_id == 0,"four-second memory expires behind cover")
	wall.queue_free()
	await reset()
	b.select_hero("marshal")
	b.intent = CombatIntent.new()
	b.intent.aim = Vector3.BACK
	b.intent.secondary_held = true
	b._physics_process(1.0/60)
	await step(2)
	decide()
	check(brain.ready_to_attack() and bool(brain.threat.blocked_by_barrier),"transparent shield preserves visual observation while blocking projectiles")
	brain.combat.choice = {}
	brain.combat.aim = (b.body_point(1.1)-a.body_point(1.45)).normalized()
	brain.combat.next_error = resolver.combat_time+10
	brain.combat.aim_error = Vector2.ZERO
	brain.combat.error_goal = Vector2.ZERO
	var pressure := CombatIntent.new()
	pressure.aim_origin = a.body_point(1.45)
	brain.combat.execute(brain,pressure,1.0/60,true)
	a.intent = pressure
	a._physics_process(1.0/60)
	check((b.kit as MarshalKit).barrier_hp < (b.tuning as MarshalTuning).barrier_health,"bot's ordinary rifle ray damages a visible hostile shield")
	await reset()
	b.health = 2000
	extra.health = 10
	decide(true,[a,b,extra,friend])
	check(brain.target_id == extra.get_instance_id(),"vulnerable target can outrank the nearest enemy")
	var first_target: int = brain.target_id
	var human := PlayerController.new()
	extra.controller = human
	brain.decide([a,b,extra,friend],objective)
	check(brain.target_id == first_target,"human controller receives the same target priority as a bot")
	extra.controller = null
	human.free()
	var state: String = brain.tactical_state
	brain.committed_until = resolver.combat_time+1
	objective.urgency = .55
	brain.decide([a,b,extra,friend],objective)
	check(brain.tactical_state == state,"commitment prevents tactical oscillation")
	a.health = a.effective_max_health()*.15
	a.last_hit_age = 0
	brain.decide([a,b,extra,friend],objective)
	check(brain.tactical_state == "retreat","critical danger interrupts commitment to disengage")
	director.reserve(a,Vector3(2,0,2),resolver.combat_time)
	check(director.reserved(Vector3(2,0,2),friend.get_instance_id()) and not director.reserved(Vector3(2,0,2),a.get_instance_id()),"cover reservation excludes owner and discourages teammates")
	brain.combat.pending_bomb = true
	brain.set_difficulty(3)
	check(not brain.combat.pending_bomb and is_equal_approx(brain.skill.acquisition_delay,.18),"difficulty changes clear pending reactions and load Expert")
	a.reset_actor()
	brain.reset()
	check(brain.target_id == 0 and brain.perception.observations.is_empty(),"respawn reset clears stale targets and sequences")
	objective.urgency = .5
	await reset("slayer")
	friend.global_position = Vector3(50,0,50)
	extra.global_position = Vector3(2,.01,-10)
	b.global_position = Vector3(0,.01,-9)
	await step(2)
	decide(true,[a,b,extra])
	check(float(brain.scores.commit) == 0 and not brain.combat.ability_scores.has("deflect"),"dive hero avoids committing into protected numerical disadvantage")
	brain.combat.aim = Vector3.FORWARD
	brain.combat.aim_speed = 0
	brain.combat.next_error = resolver.combat_time+10
	brain.combat.aim_error = Vector2.ZERO
	brain.combat.error_goal = Vector2.ZERO
	var before: Vector3 = brain.combat.aim
	brain.combat.track_aim(Vector3.RIGHT,brain,.01)
	check(before.angle_to(brain.combat.aim) <= deg_to_rad(brain.skill.turn_speed)*.01+.0001,"aim rotation respects finite speed and tracking acceleration")


func tactical_states() -> void:
	await reset("nimbus")
	var local: Dictionary = {"position":a.global_position,"phase":"fight","urgency":.7,"radius":7.0,"secured":true}
	for i: int in 5:
		brain.decide([a,b,friend],local)
		resolver.combat_time += .2
	check(brain.tactical_state == "flank","assigned DPS actually switches from contest to flank once objective is covered")
	await reset("marshal")
	for i: int in 5:
		brain.decide([a,b,friend],local)
		resolver.combat_time += .2
	check(brain.tactical_state == "hold","anchor tank actually selects hold on secured objective")
	await reset("slayer")
	b.health = 10
	for i: int in 5:
		brain.decide([a,b,friend],local)
		resolver.combat_time += .2
	check(brain.tactical_state == "commit","duelist actually commits to a vulnerable target when allies can follow")
	await reset("doctor")
	friend.health = 60
	friend.last_hit_age = 0
	for i: int in 5:
		brain.decide([a,b,friend],local)
		resolver.combat_time += .2
	check(brain.tactical_state == "support","support actually chooses triage over objective travel")
	await reset()

func profiles() -> void:
	for hero: String in HeroRoster.IDS:
		await reset(hero)
		check(brain.hero_profile.hero == hero and brain.hero_profile.maximum_range > brain.hero_profile.minimum_range,"connected class/hero profile: "+hero)
		decide()
		check(brain.ready_to_attack(),"ranged opponent is acquired: "+hero)
	await reset("slayer")
	b.position = Vector3(0,.01,-8)
	await step(2)
	a.kit.deflect_cd = 0
	decide()
	check(float(brain.combat.ability_scores.get("deflect",0)) >= .7,"Slayer scores a supported legal Boot Rush")
	perform_choice()
	check(a.state in ["slayer_boot_start","slayer_boot_active"],"Slayer tactical intent starts real Boot Rush")
	var steering := CombatIntent.new()
	brain.threat.position = Vector3(2,0,-8)
	brain.movement.apply(brain,steering,false)
	a.intent = steering
	(a.kit as SlayerKit).steer_boot(1.0/60)
	check(absf((a.kit as SlayerKit).boot_steer_angle) > 0 and absf((a.kit as SlayerKit).boot_steer_angle) <= deg_to_rad((a.tuning as SlayerTuning).boot_turn_rate)/60+.0001,"Slayer AI steering respects real boot turn speed and cone")
	a.kit.deflect_cd = 9
	brain.combat.evaluate(brain)
	check(not brain.combat.ability_scores.has("deflect"),"unavailable Boot Rush is excluded")
	await reset("marshal")
	a.last_hit_age = 0
	decide()
	check(brain.combat.ability_scores.has("secondary_held"),"Marshal responds to pressure with barrier intent")
	perform_choice()
	check(a.state == "marshal_shield","Marshal tactical intent raises real barrier")
	await reset("doctor")
	friend.health = 100
	friend.last_hit_age = 0
	decide()
	check(brain.patient == friend and brain.combat.ability_scores.has("secondary_held"),"Doctor prioritizes injured ally with healing sightline")
	perform_choice()
	check(friend.health > 100,"Doctor tactical intent restores real patient health")
	friend.health = friend.effective_max_health()
	friend.last_hit_age = 99
	brain.decide([a,b,friend],objective)
	check(not brain.combat.ability_scores.has("secondary_held"),"Doctor does not spend beam time on full-health allies")
	a.health = 60
	a.last_hit_age = 0
	friend.health = 60
	b.position = Vector3(0,.01,-3)
	await step(2)
	decide()
	check(str(brain.combat.choice.get("action","")) == "deflect","Doctor prioritizes self-protecting Ward over healing under close pressure")
	perform_choice()
	check(a.health > 60 and not a.intent.secondary_held,"Doctor defensive intent heals self instead of maintaining an unsafe beam")
	await reset("huddle")
	a.health = a.effective_max_health()*.6
	decide()
	check(brain.combat.ability_scores.has("secondary_held"),"Huddle recognizes safe Regroup opportunity")
	perform_choice()
	check(a.state == "huddle_regroup","Huddle tactical intent enters real Regroup")
	await reset("relay")
	friend.health = 100
	decide()
	check(brain.combat.ability_scores.has("secondary_pressed"),"Relay chooses an injured drone recipient")
	perform_choice()
	check((a.kit as RelayKit).recipient == friend,"Relay tactical intent assigns its real drone")
	var relay := a.kit as RelayKit
	relay.recipient = friend
	relay.battery = 10
	brain.combat.evaluate(brain)
	check(str(brain.combat.choice.get("action","")) == "bomb","Relay recalls depleted drone before reassignment")
	await reset("dynamo")
	decide()
	check(brain.combat.ability_scores.has("bomb"),"Dynamo scores Lodestone in its actual range")
	perform_choice()
	check(a.kit.bomb_cd > 0,"Dynamo tactical intent casts a real Lodestone field")
	await reset("wisp")
	var wisp := a.kit as WispKit
	wisp.shells = 1
	for i: int in 3: b.statuses.add_soul(a,4,3)
	decide()
	check(brain.combat.ability_scores.has("secondary_pressed"),"Rogue plans mark-to-explosion follow-up")
	perform_choice()
	check(wisp.shells == 0 and b.statuses.soul_count(a) == 0,"Wisp tactical intent consumes shell and detonates actual marks")
	var rates: Dictionary = brain.diagnostics.summary().ability_casts
	check(rates.has("soulbreaker") and rates.soulbreaker.casts == 1 and rates.soulbreaker.hits == 1,"explosion and mark damage count as one successful ability cast")
	wisp.steps = 1
	wisp.shells = 0
	brain.combat.evaluate(brain)
	check(not brain.combat.ability_scores.has("hover"),"Rogue preserves its last escape dodge during aggression")
	var fallback: BotHeroProfile = BotHeroProfile.for_hero("future_hero")
	check(fallback.hero == "fallback" and fallback.minimum_range > 0,"unknown hero has conservative fallback")

func perform_choice() -> void:
	var point: Vector3 = brain.combat.choice.get("point",b.body_point(1.1))
	if point == Vector3.INF: point = b.body_point(1.1)
	brain.combat.aim = (point-a.body_point(1.45)).normalized()
	brain.combat.aim_error = Vector2.ZERO
	brain.combat.error_goal = Vector2.ZERO
	brain.combat.next_error = resolver.combat_time+10
	var input := CombatIntent.new()
	input.aim_origin = a.body_point(1.45)
	brain.combat.execute(brain,input,1.0/60,true)
	a.intent = input
	a._physics_process(1.0/60)

func nimbus_ultimate() -> void:
	await reset()
	a.kit.ultimate_charge = 100
	a.kit.bomb_cd = 99
	a.motor.hover_cd = 0
	b.tuning.max_health = 5000
	b.health = 500
	b.shields = 1000
	decide()
	var before: int = resolver.events.filter(func(e: Dictionary) -> bool: return e.event == "cast" and e.ability == "ultimate_shot" and e.actor == a.actor_id).size()
	for frame: int in 180:
		if frame%12 == 0: brain.decide([a,b,friend],objective)
		var input := CombatIntent.new()
		input.aim_origin = a.body_point(1.45)
		brain.combat.execute(brain,input,1.0/60,frame%12 == 0)
		a.intent = input
		a._physics_process(1.0/60)
		await step()
	var after: int = resolver.events.filter(func(e: Dictionary) -> bool: return e.event == "cast" and e.ability == "ultimate_shot" and e.actor == a.actor_id).size()
	check(after-before == 3,"Nimbus AI completes all three real Final Notice shots without Hover stealing execution")
	check(a.state != "ultimate","Nimbus returns to ordinary combat after its full ultimate sequence")

func make_bomb(owner: HeroActor, at: Vector3) -> PocketBomb:
	var item := PocketBomb.new()
	item.source = owner
	item.cast_id = resolver.new_cast(owner)
	world.add_child(item)
	item.global_position = at
	item.set_physics_process(false)
	return item

func track(item: PocketBomb) -> void:
	brain.combat.bomb = item
	brain.combat.bomb_cast = item.cast_id
	brain.combat.bomb_life = a.life_serial
	brain.combat.bomb_started = resolver.combat_time-1
	brain.combat.next_bomb_check = 0
	brain.tactical_state = "pressure"
	brain.combat.aim = (item.global_position-a.body_point(1.45)).normalized()
	brain.combat.aim_error = Vector2.ZERO
	brain.combat.error_goal = Vector2.ZERO
	brain.combat.next_error = resolver.combat_time+10

func bomb_intent() -> CombatIntent:
	var input := CombatIntent.new()
	input.aim_origin = a.body_point(1.45)
	brain.combat.update_bomb(brain,input,1.0/60)
	return input

func bombs() -> void:
	await reset()
	decide()
	var item: PocketBomb = make_bomb(b,Vector3(0,1,-11))
	await step()
	track(item)
	check(not bomb_intent().primary and brain.combat.bomb == null,"Nimbus rejects another actor's bomb")
	item.queue_free()
	item = make_bomb(a,Vector3(0,1,-11))
	await step()
	item.airborne = false
	track(item)
	check(not bomb_intent().primary and brain.combat.bomb == null,"first collision cancels bomb shooting")
	item.airborne = true
	item.fuse = 0
	track(item)
	check(not bomb_intent().primary,"expired fuse prevents shot")
	item.fuse = 1
	for reason: String in ["ammo","reload","cooldown","ultimate","reset"]:
		a.kit.ammo = 8
		a.kit.reloading = false
		a.kit.shot_cd = 0
		a.state = "ready"
		track(item)
		match reason:
			"ammo": a.kit.ammo = 0
			"reload": a.kit.reloading = true
			"cooldown": a.kit.shot_cd = 1
			"ultimate": a.state = "ultimate"
			"reset": a.life_serial += 1
		check(not bomb_intent().primary,"bomb shot respects "+reason)
	a.state = "ready"
	a.kit.ammo = 8
	a.kit.reloading = false
	a.kit.shot_cd = 0
	var wall: Node3D = Geometry.box(world,Vector3(5,4,1),Vector3(0,2,-6),Color.GRAY)
	await step(2)
	track(item)
	check(not bomb_intent().primary and brain.combat.bomb == null,"occlusion cancels bomb sequence")
	wall.queue_free()
	brain.diagnostics.bomb_attempts = 1
	item.explode()
	check(brain.diagnostics.early_detonations == 0,"fuse explosion after a failed shot is not counted as early detonation")
	await reset()
	a.motor.hover_cd = 99
	a.kit.deflect_cd = 99
	decide()
	var starting_health: float = b.health
	var thrown: bool = false
	var shot: bool = false
	for frame: int in 70:
		if frame%12 == 0: brain.decide([a,b,friend],objective)
		var input := CombatIntent.new()
		input.aim_origin = a.body_point(1.45)
		brain.combat.execute(brain,input,1.0/60,frame%12 == 0)
		thrown = thrown or input.bomb
		shot = shot or (input.primary and brain.combat.intention == "shoot airborne bomb")
		a.intent = input
		a._physics_process(1.0/60)
		await step()
	check(thrown,"Nimbus throws a real bomb through CombatIntent")
	check(shot,"Nimbus tracks and shoots moving airborne bomb through primary input")
	check(brain.diagnostics.early_detonations == 1,"real rifle ray produces exactly one early detonation")
	check(b.health < starting_health,"airborne detonation applies ordinary splash damage")
	check(a.kit.ammo < a.tuning.magazine,"bomb combo consumes normal rifle ammunition")
	check(not brain.combat.pending_bomb and not is_instance_valid(brain.combat.bomb),"finished bomb sequence releases its reference")
