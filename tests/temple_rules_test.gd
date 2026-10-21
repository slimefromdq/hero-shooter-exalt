extends SceneTree
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures.append(message)

func empty() -> Array:
	return [[0,0],[0,0],[0,0],[0,0],[0,0]]

func fresh() -> TempleObjective:
	var rules := TempleObjective.new()
	rules.preparation_remaining = 0
	return rules

func _initialize() -> void:
	var rules := TempleObjective.new()
	var people: Array = empty()
	people[2] = [1,0]
	rules.advance(20,people)
	check(rules.owners == [0,0,-1,1,1] and rules.time_remaining == 600,"preparation consumes no capture or round clock")
	check(rules.eligible(2,0) and rules.eligible(2,1) and not rules.eligible(3,0),"only neutral mid starts attackable")
	for count: int in [1,2,3,6]:
		rules = fresh()
		people[2] = [count,0]
		var rate: float = [1.0,1.5,2.0][mini(count,3)-1]
		rules.advance(12/rate,people)
		check(is_equal_approx(rules.progress[2],.5),"capture multiplier with %d actors" % count)
		people[2] = [count,1]
		rules.advance(10,people)
		check(is_equal_approx(rules.progress[2],.5) and rules.contested[2],"one enemy contests %d attackers" % count)
	rules = fresh()
	people = empty()
	people[2] = [1,0]
	rules.advance(12,people)
	people = empty()
	rules.advance(5,people)
	check(is_equal_approx(rules.progress[2],.5),"five-second absence grace")
	rules.advance(6,people)
	check(is_equal_approx(rules.progress[2],.25),"abandoned progress decays at solo capture rate")
	for team: int in 2:
		rules = fresh()
		for index: int in ([2,3,4] if team == 0 else [2,1,0]):
			people = empty()
			people[index][team] = 1
			rules.advance(TempleObjective.DURATIONS[index],people)
			check(rules.owners[index] == team,"team %d captures %d" % [team,index])
		check(rules.finished and rules.winner == team,"team %d wins all five" % team)
	rules = fresh()
	people = empty()
	people[2] = [1,0]
	rules.advance(24,people)
	check(rules.spawn_stage(0) == 1 and rules.spawn_stage(1) == 0,"mid activates own-second forward spawn")
	people = empty()
	people[3] = [1,0]
	rules.advance(18,people)
	check(rules.spawn_stage(0) == 2,"enemy second activates mid forward spawn")
	people = empty()
	people[3] = [0,1]
	rules.advance(18,people)
	check(rules.spawn_stage(0) == 1,"recapture rolls forward spawn back")
	people = empty()
	people[2] = [0,1]
	rules.advance(24,people)
	check(rules.spawn_stage(0) == 0 and rules.eligible(1,1),"mid reversal restores base and changes front")
	rules = fresh()
	rules.time_remaining = 1
	people = empty()
	people[2] = [1,1]
	rules.advance(2,people)
	check(rules.overtime and not rules.finished,"contested eligible activity sustains overtime")
	rules.advance(2,empty())
	check(not rules.finished,"overtime has three-second departure grace")
	rules.advance(1.1,empty())
	check(rules.finished and rules.winner == -1,"overtime expiry stalemates")
	rules = fresh()
	rules.time_remaining = .1
	people = empty()
	people[0] = [0,1]
	rules.advance(1,people)
	check(rules.finished,"players on locked points cannot force overtime")
	rules = fresh()
	rules.time_remaining = 1
	people = empty()
	people[2] = [1,0]
	rules.advance(24,people)
	check(not rules.finished and rules.time_remaining > 119 and not rules.overtime,"overtime capture restores clock")
	rules.reset()
	check(rules.owners == [0,0,-1,1,1] and rules.preparation_remaining == 20 and not rules.finished,"restart clears all match state")
	rules = fresh()
	rules.owners = [0,0,0,1,1]
	rules.progress = [0,0,.9999,.9999,0]
	rules.capturing = [-1,-1,1,0,-1]
	people = [[0,0],[0,0],[0,1],[1,0],[0,0]]
	rules.advance(.05,people)
	check(rules.owners[2] == 1 and rules.owners[3] == 0,"simultaneous captures commit against the same ownership snapshot")
	rules = fresh()
	rules.owners[2] = 0
	rules.capturing[3] = 0
	rules.progress[3] = .5
	rules.owners[2] = 1
	rules.advance(.05,empty())
	check(rules.progress[3] == 0 and rules.capturing[3] == -1,"losing prerequisite territory clears locked capture progress")
	var definition := TempleMapDefinition.new()
	check(definition.district_size.x >= 288 and definition.district_size.y >= 264,"twice each existing map dimension")
	check(definition.contains_point(2,Vector3(19,16,17)) and not definition.contains_point(2,Vector3(0,20,0)) and not definition.contains_point(2,Vector3(0,8,0)),"large capture court excludes roofs and lower passages")
	check(definition.small_pack_positions.size() == 12 and definition.large_pack_positions.size() == 6,"symmetric 12 small and six large pickups")
	for team: int in 2:
		for stage: int in 3:
			for at: Vector3 in definition.spawns(team,stage): check(definition.room_bounds(team,stage).has_point(at),"spawn fits its staged protected room")
	print("TEMPLE RULES: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
