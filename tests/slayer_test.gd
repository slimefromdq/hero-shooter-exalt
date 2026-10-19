extends SceneTree

var world: Node3D
var resolver: CombatResolver
var a: HeroActor
var b: HeroActor
var c: HeroActor
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	if ok: print("PASS  ",caption)
	else:
		failures.append(caption)
		push_error("FAIL  " + caption)

func step(frames: int = 1) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame

func spawn(id: String, team: int, at: Vector3, hero: String = "nimbus") -> HeroActor:
	var actor := preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
	actor.actor_id = id
	actor.team = team
	actor.tuning = HeroRoster.tuning_for(hero)
	actor.position = at
	world.add_child(actor)
	return actor

func reset(at_b: Vector3 = Vector3(0,.01,-6)) -> void:
	CombatEffect.clear_transients(self)
	a.reset_actor(Vector3(0,.01,0))
	a.intent.aim_origin = a.global_position + Vector3.UP * 1.05
	b.reset_actor(at_b)
	c.reset_actor(Vector3(8,.01,-6))
	b.intent.aim = Vector3.BACK
	c.intent.aim = Vector3.BACK
	resolver.clear_round()
	await step(2)

func kit() -> SlayerKit:
	return a.kit as SlayerKit

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(150,1,150),Vector3(0,-.5,0),Color.GRAY)
	a = spawn("slayer",0,Vector3(0,.01,0),"slayer")
	b = spawn("target",1,Vector3(0,.01,-6))
	c = spawn("ally",0,Vector3(8,.01,-6))
	await step(4)
	await shotgun_tests()
	await knife_tests()
	await boot_tests()
	await trap_tests()
	await axe_tests()
	await edge_tests()
	await integration_tests()
	print("RESULT: %d checks, %d failures" % [checks,failures.size()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file := FileAccess.open("res://artifacts/slayer-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"checks":checks,"failures":failures},"\t"))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func shotgun_tests() -> void:
	await reset()
	check(a.tuning.max_health == 275 and a.health == 275 and a.tuning.ground_speed == b.tuning.ground_speed,"Slayer starts with 275 HP and standard ground speed")
	check(kit().ammo == 6,"Street Sweeper starts with six shells")
	kit().fire(false)
	check(is_equal_approx(b.health,160.0),"ten close body pellets resolve exactly 90 damage")
	check(kit().last_shot_pellets == 10 and is_equal_approx(kit().last_shot_damage,90),"shot report sums actual pellet damage")
	check(kit().ammo == 5,"one shot consumes exactly one shell")
	kit().fire(false)
	check(b.health == 160 and kit().ammo == 5,"pump cooldown rejects repeated direct fire")
	check(b.statuses.marked_for(a) and not b.statuses.marked_for(c),"Hunter's Instinct records attacker-specific information")
	await reset(Vector3(0,.01,-3))
	a.intent.aim_origin = a.global_position + Vector3(0,1.73,0)
	kit().fire(false)
	check(b.health < 150 and b.health >= 50,"shotgun uses global height-based headshot multiplier")
	await reset(Vector3(0,.01,-18))
	kit().fire(false)
	check(kit().last_shot_damage >= 55 and kit().last_shot_damage <= 80,"tighter shotgun retains useful midrange damage at eighteen metres")
	check(is_equal_approx(kit().damage_scale(12),1) and is_equal_approx(kit().damage_scale(24),.4),"falloff endpoints match stronger midrange tuning")
	await reset()
	b.team = 0
	kit().fire(false)
	check(b.health == 250,"pellets cannot damage teammates")
	b.team = 1
	await reset()
	var wall: Node3D = Geometry.box(world,Vector3(3,3,.1),Vector3(0,1.5,-.4),Color.GRAY)
	await step(2)
	kit().fire(false)
	check(b.health == 250,"thin wall between shoulder and muzzle blocks all pellets")
	wall.queue_free()
	await reset()
	kit().ammo = 2
	a.intent.reload = true
	await step()
	a.intent.reload = false
	await step(24)
	check(kit().ammo == 3 and kit().reloading,"reload inserts first shell after fast startup")
	kit().fire(false)
	check(a.state == "ready" and kit().ammo == 3 and kit().reloading,"fire cannot cancel concurrent shell loading")
	await step(100)
	check(kit().ammo == 6 and a.state == "ready" and not kit().reloading,"shell reload completes and restores firing")
	await reset()
	kit().fire(false)
	a.intent.hover = true
	await step()
	a.intent.hover = false
	check(kit().knives == 3,"knife cancel is rejected during shotgun's initial recovery")
	await step(16)
	a.intent.hover = true
	await step()
	a.intent.hover = false
	check(kit().knives == 2 and kit().shot_cd > .7,"valid knife cancel retains pump recovery")

func knife_tests() -> void:
	await reset(Vector3(0,.01,-10))
	a.intent.hover = true
	await step()
	a.intent.hover = false
	await step(25)
	check(b.health <= 220 and b.statuses.effects.has("bleed"),"swept knife hits moving-time target and applies bleed")
	var health: float = b.health
	b.statuses.cleanse()
	b.health = 250
	b.statuses.apply("bleed",a,4,8)
	b.statuses.tick(1.25)
	check(b.health == 242,"bleed catches up deterministic half-second ticks")
	b.statuses.apply("bleed",a,4,8)
	b.statuses.tick(.25)
	check(b.health == 238,"bleed refresh retains partial tick progress")
	check(b.statuses.effects.size() == 1,"repeated knife bleed refreshes a single status")
	b.invulnerable = true
	b.statuses.tick(.5)
	check(b.health == 238,"invulnerability prevents bleed tick damage")
	b.invulnerable = false
	b.statuses.cleanse()
	b.statuses.tick(5)
	check(b.health == 238 and b.statuses.effects.is_empty(),"cleanse removes bleed without deferred damage")
	b.statuses.apply("bleed",a,4,8)
	b.health = 2
	b.statuses.tick(.5)
	check(not b.alive and b.statuses.effects.is_empty(),"lethal bleed uses shared death and clears statuses")
	b.reset_actor()
	check(b.health == 250 and b.statuses.effects.is_empty(),"respawn clears damage-over-time effects")
	await reset()
	b.statuses.apply("bleed",a,4,8)
	b.statuses.tick(4.5)
	check(b.health == 218 and not b.statuses.effects.has("bleed"),"exact four-second bleed deals 32 damage once")
	kit().knives = 0
	kit().knife_timer = .1
	await step(8)
	check(kit().knives == 1 and kit().knife_timer > 5,"knife charges regenerate sequentially")
	await reset(Vector3(0,.01,-6))
	var wall: Node3D = Geometry.box(world,Vector3(3,3,.05),Vector3(0,1.5,-3),Color.GRAY)
	await step(2)
	kit().throw_knife()
	await step(25)
	check(b.health == 250,"fast knife cannot tunnel through a thin wall")
	wall.queue_free()
	await reset(Vector3(0,.01,-60))
	kit().throw_knife()
	await step(65)
	check(b.health == 250 and get_nodes_in_group("owned_attacks").is_empty(),"knife expires at its limited range")

func boot_tests() -> void:
	await reset(Vector3(0,.01,-6))
	a.motor.dash_charges = 1
	a.motor.dash_cd = 3
	kit().start_boot()
	await step(2)
	check(b.health == 250 and a.global_position.z > -.1,"Boot Rush has a damage-free readable startup")
	await step(42)
	check(b.health == 195 and b.position.z < -6,"boot connects once and displaces its target")
	check(a.motor.dash_cd > 2 and kit().deflect_cd > 7,"boot does not reset universal dash or its own cooldown")
	check(a.state == "ready","successful kick finishes its short recovery")
	await reset(Vector3(10,.01,-6))
	kit().start_boot()
	await step(13)
	a.intent.aim = Vector3.BACK
	await step(25)
	check(a.state == "ready" and a.position.z < -11.9,"miss travels twelve metres with fixed commitment")
	check(a.permits("primary") and a.permits("dash") and kit().movement_scale() < 1,"miss applies a decaying slow while retaining actions")
	await step(45)
	check(a.state == "ready" and kit().movement_scale() == 1,"miss slow expires without an additional lock")
	await reset(Vector3(0,.01,-6))
	var wall: Node3D = Geometry.box(world,Vector3(3,3,.08),Vector3(0,1.5,-2),Color.GRAY)
	await step(2)
	kit().start_boot()
	await step(45)
	check(a.position.z > -1.6 and b.health == 250,"boot capsule stops at thin world geometry")
	wall.queue_free()
	await reset(Vector3(0,.01,-2))
	b.state = "guard"
	b.intent.guard = true
	kit().start_boot()
	await step(15)
	check(b.health == 250 and a.state == "stagger","frontal guard blocks boot using shared attacker stagger")
	await reset()
	a.velocity = Vector3(0,0,-6)
	a.motor.transition("slide")
	a.intent.slide = true
	kit().throw_knife()
	await step(2)
	check(a.motor.mode == "slide","knife supports existing momentum slide")
	await reset()
	a.global_position.y = 3
	a.motor.mode = "air"
	a.intent.hover = true
	await step()
	a.intent.hover = false
	check(kit().knives == 2 and a.motor.mode == "air","aerial knife does not grant Nimbus Hover")

func trap_tests() -> void:
	await reset(Vector3(10,.01,-6))
	check(kit().deploy_trap(),"snare toss accepts a clear release without a ground query")
	check(kit().traps.is_empty(),"snare waits for the hand's release frame")
	await step(10)
	var trap: HunterSnare = kit().traps.back()
	check(trap.flying and not trap.armed,"snare flies from the hand before its arming delay")
	await step(55)
	check(trap.armed,"snare arms after configured delay")
	b.global_position = trap.global_position + Vector3(0,0,-.8)
	await step(3)
	check(b.statuses.effects.has("root") and b.health == 225,"armed snare applies damage and root once")
	check(not b.permits("dash") and not b.permits("hover") and not b.permits("jump"),"root disables shared movement actions")
	check(b.permits("primary"),"root preserves aim and primary fire agency")
	var at: Vector3 = b.position
	b.intent.move = Vector3.RIGHT
	await step(20)
	check(b.position.distance_to(at) < .05,"root prevents ordinary movement")
	await step(80)
	check(not b.statuses.movement_disabled(),"root expires and returns mobility")
	await reset(Vector3(10,.01,-5))
	a.intent.aim_held = true
	check(kit().deploy_trap(),"aiming uses the same timed trap toss")
	await step(65)
	var landed: HunterSnare = kit().traps.back()
	check(is_instance_valid(landed) and not landed.flying and landed.armed and absf(landed.position.z) > 4,"single snare toss travels farther and settles armed")
	await reset()
	kit().deploy_trap()
	await step(12)
	trap = kit().traps.back()
	trap.receive_damage(c,100,resolver.new_cast())
	check(not trap.is_queued_for_deletion(),"friendly damage cannot destroy an owned snare")
	trap.receive_damage(b,25,resolver.new_cast())
	check(trap.is_queued_for_deletion(),"enemy damage destroys a trap through its health")
	await reset()
	kit().deploy_trap()
	await step(12)
	trap = kit().traps.back()
	trap.age = 15
	await step()
	check(not is_instance_valid(trap) or trap.is_queued_for_deletion(),"snare lifetime expires cleanly")
	await reset()
	a.global_position.y = 6
	check(kit().deploy_trap() and kit().snares == 1,"airborne snare toss does not require nearby ground")
	await reset()
	kit().deploy_trap()
	await step(12)
	trap = kit().traps.back()
	a.die()
	await step(2)
	check(not is_instance_valid(trap),"owner death removes persistent snares")

func axe_tests() -> void:
	await reset(Vector3(0,.01,-7))
	a.intent.ultimate = true
	await step()
	a.intent.ultimate = false
	check(kit().ultimate_charge < 1 and a.state == "slayer_axe_windup","ultimate uses established charge economy on commitment")
	await step(30)
	check(b.health == 250 and not a.permits("primary"),"axe has a telegraphed committed windup")
	await step(35)
	check(b.health == 125 and b.effective_max_health() == 125,"axe inflicts direct damage then clamps to half base maximum")
	check(b.tuning.max_health == 250,"maximum-health wound never edits base-stat resource")
	check(b.statuses.effects.has("max_health"),"maximum-health wound is an inspectable status")
	check(a.state == "slayer_axe_recovery","axe maintains recovery after release")
	await step(30)
	check(a.state == "ready","axe returns to ordinary shotgun stance")
	b.statuses.apply("max_health",a,8,.5)
	check(b.effective_max_health() == 125,"repeated maximum-health hits refresh without recursive reduction")
	b.statuses.tick(8.1)
	check(b.effective_max_health() == 250 and b.health == 125,"wound expiry restores maximum without free healing")
	b.reset_actor()
	check(b.health == 250 and b.effective_max_health() == 250,"respawn restores both current and effective maximum HP")
	await reset(Vector3(0,.01,-4))
	b.state = "deflect"
	b.state_time = 5
	kit().release_axe()
	await step(20)
	check(b.health == 250 and b.effective_max_health() == 250,"frontal Nimbus Deflect stops axe damage and wound")
	await reset(Vector3(0,.01,-4))
	b.invulnerable = true
	kit().release_axe()
	await step(20)
	check(b.health == 250 and b.effective_max_health() == 250,"invulnerability rejects axe and maximum-health status")
	await reset(Vector3(0,.01,-4))
	b.shields = 200
	kit().release_axe()
	await step(20)
	check(b.health == 250 and b.shields == 90 and b.effective_max_health() == 250,"remaining shields prevent maximum-health wound")
	await reset(Vector3(0,.01,-7))
	var wall: Node3D = Geometry.box(world,Vector3(3,3,.06),Vector3(0,1.5,-3),Color.GRAY)
	await step(2)
	kit().release_axe()
	await step(35)
	check(b.health == 250,"large swept axe does not pass through thin walls")
	wall.queue_free()
	await reset(Vector3(0,.01,-4))
	c.team = 1
	c.position = Vector3(0,.01,-7)
	kit().release_axe()
	await step(35)
	check(b.health == 125 and c.health == 125,"spinning axe pierces multiple enemies once each")
	c.team = 0
	await reset(Vector3(0,.01,-7))
	a.intent.ultimate = true
	await step()
	a.intent.ultimate = false
	a.close.stagger()
	await step(80)
	check(b.health == 250 and kit().ultimate_charge < 5,"windup interruption cancels axe without refund")

func integration_tests() -> void:
	await reset()
	b.statuses.mark(a,.1)
	b.statuses.tick(.2)
	check(not b.statuses.marked_for(a),"passive mark expires")
	b.statuses.mark(a,4)
	b.die()
	check(not b.statuses.marked_for(a),"passive mark clears on target death")
	b.reset_actor()
	b.statuses.mark(a,4)
	a.die()
	a.reset_actor()
	check(not b.statuses.marked_for(a),"attacker death and immediate respawn cannot retain pursuit marks")
	a.motor.dash_charges = 1
	a.motor.dash_cd = 3
	a.statuses.apply("root",b,1.5)
	check(a.motor.dash_cd == 3,"snare mobility interruption preserves universal cooldown")
	a.reset_actor()
	check(a.statuses.effects.is_empty() and a.motor.mode == "ground","reset clears statuses and movement overrides")
	a.select_hero("nimbus")
	check(a.kit is NimbusKit and a.health == 250,"hero selection restores complete Nimbus kit")
	a.select_hero("slayer")
	check(a.kit is SlayerKit and a.kit.ammo == 6,"hero selection installs full Slayer kit")
	check(a.presentation.slayer_axe != null and a.presentation.rifle.get_child_count() >= 5,"Slayer has distinct carried axe and shotgun geometry")
	var pack := CityHealthPack.new()
	world.add_child(pack)
	a.statuses.apply("max_health",b,8,.5)
	a.health = 100
	check(pack.try_collect(a) and a.health == 137.5,"shared healing respects Slayer's temporary effective maximum")
	check(not pack.try_collect(a),"health pack cannot bypass maximum-health wound")
	var wave: AudioStreamWAV = ProceduralSound.slayer_wave("shotgun")
	check(wave.data.size() > 1000 and wave.mix_rate == 22050,"shotgun has a finite original synthesized audio cue")

func edge_tests() -> void:
	await reset(Vector3(0,.01,-6))
	b.state = "deflect"
	b.state_time = 2
	kit().fire(false)
	check(b.health == 250 and kit().last_shot_pellets == 0,"Deflect rejects every frontal shotgun pellet")
	await reset(Vector3(0,.01,-6))
	kit().start_boot()
	await step(11)
	a.statuses.apply("root",b,1.5)
	var entry: Vector3 = a.position
	await step(15)
	check(a.position.distance_to(entry) < .03 and a.state == "ready","snare interrupts an active Boot Rush without continuing travel")
	check(kit().deflect_cd > 7 and a.motor.dash_cd == 0,"interrupted boot retains its spent cooldown")
	await reset()
	kit().ammo = 2
	kit().start_reload()
	a.statuses.apply("root",b,1.5)
	check(kit().reloading,"root preserves a concurrent shell reload")
	await reset()
	a.intent.ultimate = true
	await step()
	a.intent.ultimate = false
	a.statuses.apply("root",b,1.5)
	check(a.state == "slayer_axe_windup","root preserves committed offensive axe windup")
	await reset(Vector3(0,.01,-6))
	kit().start_boot()
	await step(10)
	a.reset_actor()
	await step(30)
	check(a.state == "ready" and kit().boot_remaining == 0 and b.health == 250,"reset during boot clears pending damage and travel")
	await reset(Vector3(1.2,.01,-8))
	b.intent.move = Vector3.RIGHT
	kit().start_boot()
	await step(50)
	check(b.health == 250,"moving target can evade the committed boot path")
	await reset(Vector3(0,1.6,-4))
	b.velocity.y = 2
	kit().start_boot()
	await step(25)
	check(b.health >= 195,"boot handles airborne target without repeated hits")
	await reset(Vector3(8,.01,-6))
	a.position.y = 6
	a.velocity.y = -8
	a.motor.mode = "air"
	kit().start_boot()
	await step(13)
	check(a.velocity.y < -8 and a.position.y < 5,"horizontal aerial boot preserves falling momentum instead of granting a hover reset")
	await reset(Vector3(8,.01,-6))
	var doorway: Node3D = Geometry.box(world,Vector3(.2,3,2),Vector3(.6,1.5,-3),Color.GRAY)
	var doorway2: Node3D = Geometry.box(world,Vector3(.2,3,2),Vector3(-.6,1.5,-3),Color.GRAY)
	await step(2)
	kit().start_boot()
	await step(50)
	check(a.position.z < -7.9 and absf(a.position.x) < .05,"boot sweeps through a capsule-width doorway")
	doorway.queue_free()
	doorway2.queue_free()
	await reset(Vector3(8,.01,-6))
	var ramp: Node3D = Geometry.box(world,Vector3(4,.4,10),Vector3(20,1,0),Color.GRAY)
	ramp.rotation.x = -.15
	a.reset_actor(Vector3(20,1.8,3))
	await step(20)
	kit().start_boot()
	await step(55)
	check(a.position.is_finite() and a.position.z < -2 and a.position.y > 0,"boot follows a walkable slope without tunnelling")
	ramp.queue_free()
	await reset()
	var small_platform: Node3D = Geometry.box(world,Vector3(3,2,3),Vector3(30,1,0),Color.GRAY)
	a.reset_actor(Vector3(30,2.01,0))
	await step(3)
	kit().start_boot()
	await step(38)
	check(a.position.z < -7 and a.position.y < 1.9,"boot crossing a ledge falls under shared gravity")
	small_platform.queue_free()
	await reset()
	var blocked: Node3D = Geometry.box(world,Vector3(2,2,.3),Vector3(0,1,-.8),Color.GRAY)
	await step(2)
	check(not kit().deploy_trap() and kit().snares == 2,"snare rejects obstructed hand space without charging")
	blocked.position.z = -2
	await step(2)
	check(kit().deploy_trap(),"snare can be tossed toward nearby cover")
	await step(12)
	check(kit().traps.size() == 1 and kit().traps[0].position.z > -1.7,"swept snare release cannot spawn through a nearby wall")
	blocked.queue_free()
	await reset()
	kit().deploy_trap()
	await step(24)
	var first: WeakRef = weakref(kit().traps[0])
	a.position.x += 2
	kit().deploy_trap()
	await step(24)
	a.position.x += 2
	kit().snares = 1
	kit().deploy_trap()
	await step(24)
	check(first.get_ref() == null and get_nodes_in_group("traps").size() == 2,"deploying above active limit retires the oldest trap")
	await reset()
	kit().deploy_trap()
	await step(12)
	var trap: HunterSnare = kit().traps.back()
	c.position = trap.position + Vector3(0,0,-.5)
	await step(35)
	check(is_instance_valid(trap) and not c.statuses.movement_disabled(),"allies do not activate armed snares")
	var id: int = resolver.new_cast()
	trap.receive_damage(b,10,id)
	trap.receive_damage(b,10,id)
	check(trap.health == 15,"trap damage deduplicates each attack cast")
	kit().snares = 0
	kit().snare_timer = .1
	await step(8)
	check(kit().snares == 1 and kit().snare_timer > 11,"snare charges regenerate sequentially")
	await reset(Vector3(0,.01,-4))
	b.tuning.max_health = 500
	b.health = 500
	kit().release_axe()
	await step(25)
	check(b.health == 250 and b.effective_max_health() == 250,"axe reduction uses a tank's base 500 HP rather than current HP")
	b.tuning.max_health = 250
	await reset(Vector3(0,.01,-4))
	b.health = 120
	kit().release_axe()
	await step(25)
	check(b.alive and b.health == 10 and b.effective_max_health() == 125,"maximum-health clamp does not inflict a hidden second damage packet")
	await reset(Vector3(0,.01,-4))
	b.state = "captured"
	kit().release_axe()
	await step(25)
	check(b.health == 239 and b.effective_max_health() == 250,"paired throw mitigation also prevents full maximum-health wound")
	await reset(Vector3(0,.01,-4))
	b.intent.move = Vector3.RIGHT
	kit().release_axe()
	await step(35)
	check(b.health >= 125,"axe remains a physical projectile against moving targets")
	await reset()
	b.spawn_protected = true
	check(not b.statuses.apply("max_health",a,8,.5) and not b.statuses.apply("root",a,1.5),"protected-room immunity covers wound and snare statuses")
	b.spawn_protected = false
	b.statuses.apply("bleed",a,4,8)
	a.die()
	b.statuses.tick(.5)
	check(b.health == 246,"existing bleed keeps originating attribution after attacker death")
	await reset()
	resolver.events.clear()
	b.statuses.apply("bleed",a,4,8)
	b.statuses.tick(4)
	var ticks: int = 0
	for event: Dictionary in resolver.events:
		if event.event == "damage" and event.ability == "bleed" and event.actor == a.actor_id: ticks += 1
	check(ticks == 8,"bleed emits eight correctly attributed shared damage events")
