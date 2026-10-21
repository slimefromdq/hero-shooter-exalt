extends SceneTree
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok:
		failures.append(caption)
		print("FAIL ",caption)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arena = load("res://scenes/temple/sakura_veil.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.match_controller.freeze_ai = true
	arena.match_controller.set_physics_process(false)
	arena.player.controller.active = false
	for actor: HeroActor in arena.match_controller.actors:
		actor.set_physics_process(false)
		actor.collision_layer = 0
	for pad: TempleJumpPad in arena.builder.pads: pad.set_physics_process(false)
	await physics_frame
	for hero: String in HeroRoster.IDS:
		var p := preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
		p.tuning = HeroRoster.tuning_for(hero)
		arena.add_child(p)
		p.set_physics_process(false)
		p.collision_layer = 0
		for pad: TempleJumpPad in arena.builder.pads:
			for speed: float in [0,20]:
				p.reset_actor(pad.global_position+Vector3(.8,.05,-.8))
				p.velocity = Vector3(speed,0,-speed)
				p.motor.dash_charges = 1
				pad.contacts.clear()
				pad._physics_process(1.0/60)
				check(p.motor.pad_flight_left>0,hero+" activates "+pad.spec.id)
				check(p.motor.dash_charges==1,"launch preserves charges")
				var landed: bool = false
				for frame: int in int((pad.spec.flight_time+1)*60):
					p.motor.tick(1.0/60,CombatIntent.new())
					if frame>12 and p.motor.grounded() and p.velocity.y<=0:
						landed = true
						break
				var offset: Vector3 = p.global_position-Vector3(pad.spec.destination)
				check(landed and absf(offset.x)<3.5 and absf(offset.z)<3.5 and absf(offset.y)<.3,hero+" lands "+pad.spec.id+" at "+str(p.global_position))
				p.motor.tick(1.0/60,CombatIntent.new())
				check(p.motor.pad_speed_limit==0,"landing clears scoped speed allowance")
		p.queue_free()
		await process_frame
	var p: HeroActor = arena.player
	var pad: TempleJumpPad = arena.builder.pads[0]
	for state: String in ["captured","throw_pair","boot_attached","boot_captured","stagger","melee_active"]:
		p.reset_actor(pad.global_position)
		p.state = state
		check(not p.motor.launch_from_pad(Vector3(10,30,0),2),"respects "+state)
	p.reset_actor(pad.global_position+Vector3(0,-1,0))
	pad.contacts.clear()
	pad._physics_process(1.0/60)
	check(p.motor.pad_flight_left==0,"underside contact does not launch")
	p.reset_actor(pad.global_position+Vector3(3,0,0))
	pad._physics_process(1.0/60)
	check(p.motor.pad_flight_left==0,"side contact does not launch")
	p.reset_actor(pad.global_position)
	pad.contacts.clear()
	pad._physics_process(1.0/60)
	var count: int = pad.launch_count
	p.velocity = Vector3.ZERO
	pad._physics_process(1.0/60)
	check(pad.launch_count==count,"contact does not repeatedly launch")
	p.position.x += 6
	pad._physics_process(1.1)
	p.position = pad.global_position
	pad._physics_process(1.0/60)
	check(pad.launch_count==count+1,"exit and debounce rearm platform")
	p.motor.interrupt_mobility()
	check(p.motor.pad_speed_limit==0,"interruption clears launch allowance")
	p.reset_actor(pad.global_position)
	check(p.motor.pad_speed_limit==0,"reset clears launch allowance")
	p.reset_actor(pad.global_position)
	p.statuses.effects["root"] = {}
	pad.contacts.clear()
	pad._physics_process(1.0/60)
	check(p.motor.pad_flight_left==0,"rooted actor stays on platform")
	p.statuses.effects.erase("root")
	pad._physics_process(1.0/60)
	check(p.motor.pad_flight_left>0,"root expiry while on platform becomes eligible")
	p.motor.tick(1.0/60,CombatIntent.new())
	var held := CombatIntent.new()
	held.jump_held = true
	p.motor.tick(1.0/60,held)
	check(p.motor.pad_speed_limit>0,"holding jump without a traversal action preserves launch")
	p.motor.dash_charges = 0
	p.motor.dash_cd = 3
	held.dash = true
	p.motor.tick(1.0/60,held)
	check(p.motor.pad_speed_limit>0,"unavailable dash does not cancel launch")
	p.motor.dash_charges = 1
	var redirect := CombatIntent.new()
	redirect.move = Vector3.RIGHT
	redirect.aim = Vector3.RIGHT
	redirect.dash = true
	p.motor.tick(1.0/60,redirect)
	check(p.motor.pad_speed_limit==0 and p.motor.mode=="dash_windup","player can redirect launch with dash")
	p.reset_actor(pad.global_position)
	pad.contacts.clear()
	var partner: HeroActor = arena.match_controller.bots[0]
	partner.reset_actor(pad.global_position+Vector3(.8,0,.8))
	pad._physics_process(1.0/60)
	check(p.motor.pad_flight_left>0 and partner.motor.pad_flight_left>0,"simultaneous users launch independently")
	partner.controller.selected_pad = pad
	partner.controller.pad_phase = "approach"
	partner.reset_actor()
	check(partner.controller.selected_pad==null and partner.controller.pad_phase=="","bot respawn clears stale pad approach")
	p.die()
	check(p.motor.pad_speed_limit==0,"death clears scoped flight state")
	var file := FileAccess.open("res://artifacts/temple/jump-pads.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("TEMPLE PADS ",checks," checks / ",failures.size()," failures")
	for platform: TempleJumpPad in arena.builder.pads: platform.sound.stop()
	arena.queue_free()
	await process_frame
	# Manual motor ticks can queue many sounds inside one rendered frame.
	OS.delay_msec(100)
	await process_frame
	quit(0 if failures.is_empty() else 1)
