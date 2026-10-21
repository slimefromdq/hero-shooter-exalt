extends "res://tests/care_heroes_test.gd"

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	resolver = CombatResolver.new()
	world.add_child(resolver)
	var target := spawn("dynamo",1,Vector3(20,0,0))
	for id: String in HeroRoster.IDS:
		var source := spawn(id,0,Vector3.ZERO)
		source.kit.ultimate_charge = 0
		source.kit.tick(1.0,CombatIntent.new())
		near(source.kit.ultimate_charge,.8 / 1.4,id + " passive charge uses 40 percent higher cost",.0001)
		source.kit.ultimate_charge = 0
		target.health = target.tuning.max_health
		resolver.damage(source,target,100,"test",resolver.new_cast(source))
		near(source.kit.ultimate_charge,9.0 / 1.4,id + " damage charge uses higher cost",.0001)
		source.health = 10
		source.kit.ultimate_charge = 0
		var support: bool = HeroRoster.role_for(id) == "support"
		var expected: float = 87.5 if support else 100.0
		near(resolver.heal(source,source,100,"test"),expected,id + " healing scales only for supports",.0001)
		near(source.kit.ultimate_charge,expected * .06 / 1.4,id + " charge uses actual restored health",.0001)
		source.kit.ultimate_charge = 99
		source.kit.gain_ultimate_charge(100)
		near(source.kit.ultimate_charge,100,id + " meter caps at full")
	print("RESULT: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
