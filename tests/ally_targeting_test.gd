extends "res://tests/care_heroes_test.gd"
## Real-physics support acquisition regressions, independent of Wave 1 kits.

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	doctor = spawn("doctor",0,Vector3.ZERO)
	friend = spawn("nimbus",0,Vector3(0,0,-8))
	second = spawn("nimbus",0,Vector3(0,0,-12))
	enemy = spawn("marshal",1,Vector3(20,0,0))
	var relay: HeroActor = spawn("relay",0,Vector3(20,0,10))
	aim(doctor,friend)
	await step()
	var k := doctor.kit as DoctorKit
	check(AllyTargeting.aimed(doctor,20) == friend,"aligned allies retain actor-order tie break")
	check(k.targeted(20) == friend,"Doctor wrapper uses shared acquisition")
	check(AllyTargeting.aimed(doctor,8) == friend,"feet range includes exact boundary")
	check(AllyTargeting.aimed(doctor,7.99) == null,"feet range excludes just-outside target")
	check(not AllyTargeting.sight(doctor,doctor),"self excluded; kit owns self fallback")
	check(not AllyTargeting.sight(doctor,enemy),"enemy excluded")
	check(not AllyTargeting.sight(doctor,null),"null target safely excluded")
	check(AllyTargeting.aimed(null,20) == null,"null source safely excluded")
	friend.alive = false
	check(AllyTargeting.aimed(doctor,20) == second,"dead ally excluded")
	friend.alive = true
	friend.spawn_protected = true
	check(AllyTargeting.aimed(doctor,20) == second,"protected ally excluded")
	friend.spawn_protected = false
	second.position.x = 6
	friend.position.x = 3
	aim(doctor,second)
	check(AllyTargeting.aimed(doctor,20) == second,"closest angle wins over closest distance")
	second.position = Vector3(0,0,-12)
	friend.position = Vector3(0,0,-8)
	doctor.aim_direction = Vector3.RIGHT
	check(AllyTargeting.aimed(doctor,20) == null,"outside cone rejected")
	doctor.intent.aim_origin = Vector3(4,3,2)
	doctor.aim_direction = (friend.body_point(1.2)-doctor.intent.aim_origin).normalized()
	check(AllyTargeting.aimed(doctor,20,2) == friend,"acquisition uses camera aim origin")
	doctor.intent.aim_origin = Vector3.ZERO
	doctor.aim_direction = (friend.body_point(1.2)-doctor.body_point(1.4)).normalized()
	check(AllyTargeting.aimed(doctor,20,2) == friend,"missing camera falls back to source body")
	friend.motor.set_crouched(true)
	aim(doctor,friend)
	doctor.aim_direction = (friend.body_point(1.2)-doctor.intent.aim_origin).normalized()
	check(AllyTargeting.aimed(doctor,20,1) == friend,"target point follows crouched posture")
	friend.motor.set_crouched(false)
	aim(doctor,second)
	check(AllyTargeting.sight(doctor,second),"intervening teammate does not occlude sight")
	var wall: Node3D = Geometry.box(world,Vector3(6,4,.3),Vector3(0,1.8,-4),Color.GRAY)
	await step()
	check(not AllyTargeting.sight(doctor,friend),"solid world cover blocks sight")
	check(k.targeted(20) == null,"covered allies cannot be acquired")
	wall.queue_free()
	await step()
	enemy.position = Vector3(0,0,-4)
	enemy.aim_direction = Vector3.BACK
	enemy.state = "marshal_shield"
	(enemy.kit as MarshalKit).barrier_hp = 1200
	await step()
	check(not AllyTargeting.sight(doctor,friend),"analytic hostile shield blocks support sight")
	enemy.team = doctor.team
	check(AllyTargeting.sight(doctor,friend),"friendly analytic shield allows support sight")
	enemy.state = "ready"
	enemy.team = 1
	enemy.position.x = 20
	doctor.spawn_protected = true
	check(not k.sight(friend) and k.targeted(20) == null,"Doctor retains source-room policy")
	doctor.spawn_protected = false
	relay.position = Vector3.ZERO
	aim(relay,friend)
	var r := relay.kit as RelayKit
	check(r.aimed_ally() == AllyTargeting.aimed(relay,r.data().assign_range),"Relay wrapper uses shared acquisition")
	check(r.assign(friend),"Relay still assigns a visible ally")
	r.transfer_left = 0
	friend.health = 100
	wall = Geometry.box(world,Vector3(6,4,.3),Vector3(0,1.8,-4),Color.GRAY)
	await step()
	check(r.aimed_ally() == null,"Relay cannot acquire through new cover")
	r.tick_drone(.1)
	check(friend.health > 100,"existing Relay companion keeps healing behind cover")
	friend.health = 100
	k.patient = friend
	aim(doctor,friend)
	k.update_beam(.01)
	check(k.patient == friend and not k.beam_healing and friend.health == 100,"Doctor grace retains target without healing through cover")
	k.update_beam(k.data().beam_grace+.01)
	check(k.patient == null,"Doctor obstruction grace still disconnects expired channel")
	wall.queue_free()
	await step()
	friend.queue_free()
	await step()
	aim(doctor,second)
	check(AllyTargeting.aimed(doctor,20) == second,"removed target cannot remain in stateless acquisition")
	world.queue_free()
	await step()
	print("RESULT: %d checks, %d failures" % [checks,failures.size()])
	var file := FileAccess.open("res://artifacts/ally-targeting-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	quit(0 if failures.is_empty() else 1)
