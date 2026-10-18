class_name MuseumObjective
extends RefCounted
## Pure authoritative progression; occupancy/visibility belongs to the session.
signal phase_changed(phase: String)
signal checkpoint_reached(index: int)
signal round_ended(team: int)
var definition: MuseumMapDefinition
var phase: String = "preparation"
var capture_progress: float = 0
var payload_distance: float = 0
var checkpoint_index: int = 0
var time_remaining: float = 240
var preparation_remaining: float = 30
var overtime: bool = false
var overtime_empty: float = 0
var winner: int = -1
var absence: float = 0
var locked_thirds: int = 0
var contested: bool = false

func reset() -> void:
	phase = "preparation"
	capture_progress = 0
	payload_distance = 0
	checkpoint_index = 0
	time_remaining = definition.round_seconds
	preparation_remaining = definition.preparation_seconds
	overtime = false
	overtime_empty = 0
	winner = -1
	absence = 0
	locked_thirds = 0
	contested = false

func advance(delta: float, attackers: int, defenders: int) -> void:
	if winner >= 0: return
	if phase == "preparation":
		preparation_remaining = maxf(0,preparation_remaining-delta)
		if preparation_remaining <= 0:
			phase = "capture"
			phase_changed.emit(phase)
		return
	contested = defenders > 0 and (attackers > 0 or phase == "escort")
	absence = absence+delta if attackers == 0 and (phase == "capture" or defenders == 0) else 0.0
	# Timeout is decided against occupancy before this tick's progress. A late
	# checkpoint cannot resurrect an already expired, unattended objective.
	if not overtime:
		time_remaining = maxf(0,time_remaining-delta)
		if time_remaining <= 0:
			if attackers > 0: overtime = true
			else:
				finish(1)
				return
	if overtime:
		overtime_empty = overtime_empty+delta if attackers == 0 else 0.0
		if overtime_empty >= definition.overtime_grace:
			finish(1)
			return
	if phase == "capture":
		if attackers > 0 and defenders == 0:
			capture_progress = minf(1,capture_progress+delta/definition.capture_durations[mini(attackers,3)-1])
			locked_thirds = maxi(locked_thirds,mini(3,int(floor(capture_progress*3+.00001))))
		elif attackers == 0 and absence > definition.decay_delay:
			var decay_delta: float = minf(delta,absence-definition.decay_delay)
			capture_progress = maxf(locked_thirds/3.0,capture_progress-decay_delta/definition.capture_durations[0])
		if capture_progress >= 1:
			phase = "escort"
			absence = 0
			add_time(definition.unlock_bonus)
			phase_changed.emit(phase)
	else:
		var marks := definition.checkpoint_distances()
		if defenders == 0 and attackers > 0:
			payload_distance = minf(marks[-1],payload_distance+delta*definition.escort_speeds[mini(attackers,3)-1])
		elif absence > definition.rollback_delay and defenders == 0:
			var floor_distance: float = marks[checkpoint_index-1] if checkpoint_index > 0 else 0.0
			payload_distance = maxf(floor_distance,payload_distance-definition.rollback_speed*minf(delta,absence-definition.rollback_delay))
		while checkpoint_index < marks.size() and payload_distance+.00001 >= marks[checkpoint_index]:
			checkpoint_index += 1
			if checkpoint_index < marks.size(): add_time(definition.checkpoint_bonus)
			checkpoint_reached.emit(checkpoint_index)
			if checkpoint_index == marks.size(): finish(0)

func add_time(seconds: float) -> void:
	time_remaining += seconds
	overtime = false
	overtime_empty = 0

func finish(team: int) -> void:
	winner = team
	phase = "finished"
	phase_changed.emit(phase)
	round_ended.emit(team)
