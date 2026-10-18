extends SceneTree
var checks: int = 0
var failures: Array[String] = []
var definition := MuseumMapDefinition.new()

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",description)
	if not ok: failures.append(description)

func fresh() -> MuseumObjective:
	var rules := MuseumObjective.new()
	rules.definition = definition
	rules.reset()
	return rules

func escort() -> MuseumObjective:
	var rules := fresh()
	rules.advance(30,0,0)
	rules.advance(30,1,0)
	return rules

func run() -> void:
	var rules := fresh()
	rules.advance(29,6,0)
	check(rules.phase == "preparation" and rules.capture_progress == 0 and rules.time_remaining == 240,"preparation never captures or consumes round time")
	rules.advance(1,0,0)
	check(rules.phase == "capture","30 seconds of preparation unlocks capture")
	for count: int in [1,2,3,6]:
		rules = fresh()
		rules.advance(30,0,0)
		rules.advance(definition.capture_durations[mini(count,3)-1]/3,count,0)
		check(is_equal_approx(rules.capture_progress,1.0/3) and rules.locked_thirds == 1,"capture speed and first lock with %d attackers" % count)
	rules = fresh()
	rules.advance(30,0,0)
	rules.advance(17,1,0)
	rules.advance(4,0,1)
	check(is_equal_approx(rules.capture_progress,17.0/30),"incomplete capture survives absence delay")
	rules.advance(2,0,1)
	check(is_equal_approx(rules.capture_progress,16.0/30),"decay charges only time after the fifth absent second")
	rules.advance(15,0,1)
	check(is_equal_approx(rules.capture_progress,1.0/3),"defense cannot erase a completed third")
	rules.advance(10,1,1)
	check(rules.contested and is_equal_approx(rules.capture_progress,1.0/3),"living defenders pause contested capture")
	rules.advance(20,1,0)
	check(rules.phase == "escort" and rules.capture_progress == 1 and rules.time_remaining > 240,"full capture releases escort and adds three minutes")
	for count: int in [1,2,3,6]:
		rules = escort()
		rules.advance(1,count,0)
		check(is_equal_approx(rules.payload_distance,definition.escort_speeds[mini(count,3)-1]),"escort speed scales and caps for %d attackers" % count)
	rules = escort()
	rules.advance(10,3,0)
	rules.advance(5,3,1)
	check(rules.payload_distance == 20 and rules.contested,"defender pauses forward payload travel")
	rules.advance(10,0,0)
	check(rules.payload_distance == 20,"rollback has ten-second delay")
	rules.advance(2,0,0)
	check(rules.payload_distance == 19,"unattended cart reverses at half a meter per second")
	rules.advance(2,0,1)
	check(rules.payload_distance == 19,"defender alone also stops rollback")
	rules.advance(100,0,0)
	check(rules.payload_distance == 0,"rollback never precedes its start")
	rules = escort()
	var awarded: Array[int] = []
	rules.checkpoint_reached.connect(func(index: int) -> void: awarded.append(index))
	rules.advance(35,3,0)
	check(rules.checkpoint_index == 1 and awarded == [1],"first checkpoint fires once at seventy meters")
	var after: float = rules.time_remaining
	rules.advance(15,0,0)
	check(rules.payload_distance == 70 and rules.time_remaining == after-15,"checkpoint locks rollback and awards no duplicate bonus")
	rules.advance(35.1,3,0)
	check(rules.checkpoint_index == 2 and awarded == [1,2],"second checkpoint awards once after terrace rise")
	rules.advance(35,3,0)
	check(rules.winner == 0 and rules.phase == "finished" and awarded == [1,2,3],"third checkpoint is the final attacker victory")
	var frozen: float = rules.payload_distance
	rules.advance(99,0,0)
	check(rules.payload_distance == frozen,"finished objectives cannot advance")
	rules = fresh()
	rules.advance(30,0,0)
	rules.advance(240,0,0)
	check(rules.winner == 1,"unattended capture timeout wins for defenders")
	rules = fresh()
	rules.advance(30,0,0)
	rules.time_remaining = .5
	rules.advance(1,1,1)
	check(rules.overtime and rules.winner == -1,"attacker touching at expiry starts overtime even when contested")
	rules.advance(2.9,0,1)
	check(rules.winner == -1,"overtime tolerates less than three absent seconds")
	rules.advance(.1,1,1)
	rules.advance(2.9,0,1)
	check(rules.winner == -1,"returning attacker resets overtime grace")
	rules.advance(.11,0,1)
	check(rules.winner == 1,"three continuous absent overtime seconds end defense win")
	rules = escort()
	rules.payload_distance = 69
	rules.time_remaining = .2
	rules.advance(1,1,0)
	check(rules.checkpoint_index == 1 and not rules.overtime and rules.time_remaining == 90,"checkpoint bonus exits overtime")
	rules.reset()
	check(rules.phase == "preparation" and rules.checkpoint_index == 0 and rules.payload_distance == 0 and rules.capture_progress == 0 and rules.winner == -1 and not rules.overtime,"reset clears every objective lifecycle field")
	var marks := definition.checkpoint_distances()
	check(is_equal_approx(marks[0],70) and absf(marks[1]-140) < .1 and absf(marks[2]-210) < .1,"authored track has three approximately seventy-meter legs")
	for index: int in 3:
		check(definition.path_position(marks[index]).distance_to(definition.payload_path[definition.checkpoint_vertices[index]]) < .001,"distance sampling reaches checkpoint %d" % (index+1))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/museum"))
	var file := FileAccess.open("res://artifacts/museum/rules.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("MUSEUM RULES ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
