class_name TempleObjective
extends RefCounted
signal point_captured(index: int, team: int)
signal round_ended(team: int)
var owners: Array[int] = [0,0,-1,1,1]
var progress: Array[float] = [0.0,0.0,0.0,0.0,0.0]
var capturing: Array[int] = [-1,-1,-1,-1,-1]
var absent: Array[float] = [0.0,0.0,0.0,0.0,0.0]
var contested: Array[bool] = [false,false,false,false,false]
var preparation_remaining: float = 20.0
var time_remaining: float = 600.0
var overtime: bool = false
var grace: float = 3.0
var finished: bool = false
var winner: int = -1
const DURATIONS: Array[float] = [10,18,24,18,10]

func reset() -> void:
	owners = [0,0,-1,1,1]
	progress = [0.0,0.0,0.0,0.0,0.0]
	capturing = [-1,-1,-1,-1,-1]
	absent = [0.0,0.0,0.0,0.0,0.0]
	contested = [false,false,false,false,false]
	preparation_remaining = 20
	time_remaining = 600
	overtime = false
	grace = 3
	finished = false
	winner = -1

func eligible(index: int, team: int, ownership: Array[int] = []) -> bool:
	var state: Array[int] = owners if ownership.is_empty() else ownership
	if state[index] == team: return false
	var behind: int = index-1 if team == 0 else index+1
	return behind < 0 or behind > 4 or state[behind] == team

func target(team: int) -> int:
	for index: int in (range(5) if team == 0 else range(4,-1,-1)):
		if eligible(index,team): return index
	return 4 if team == 0 else 0

func spawn_stage(team: int) -> int:
	if owners[2] != team: return 0
	return 2 if owners[3 if team == 0 else 1] == team else 1

func advance(delta: float, occupancy: Array) -> void:
	if finished: return
	if preparation_remaining > 0:
		var used: float = minf(delta,preparation_remaining)
		preparation_remaining -= used
		delta -= used
		if delta <= 0: return
	# Process small deterministic slices: large test deltas cannot bypass locks,
	# overtime boundaries, absence delays or simultaneous capture decisions.
	while delta > .000001 and not finished:
		var step: float = minf(delta,.05)
		_tick(step,occupancy)
		delta -= step

func _tick(delta: float, occupancy: Array) -> void:
	var snapshot: Array[int] = owners.duplicate()
	var completed: Array[Vector2i] = []
	var activity: bool = false
	time_remaining = maxf(0,time_remaining-delta)
	for index: int in 5:
		var counts: Array = occupancy[index]
		contested[index] = counts[0] > 0 and counts[1] > 0
		for team: int in 2:
			if eligible(index,team,snapshot) and counts[team] > 0: activity = true
		if capturing[index] >= 0 and not eligible(index,capturing[index],snapshot):
			progress[index] = 0
			capturing[index] = -1
		if contested[index]: continue
		var team: int = 0 if counts[0] > 0 else (1 if counts[1] > 0 else -1)
		if team >= 0 and eligible(index,team,snapshot):
			if capturing[index] != team:
				progress[index] = 0
				capturing[index] = team
			absent[index] = 0
			var rate: float = [1.0,1.5,2.0][mini(3,int(counts[team]))-1]
			progress[index] = minf(1,progress[index]+delta*rate/DURATIONS[index])
			if progress[index] >= .999999: completed.append(Vector2i(index,team))
		else:
			var previous: float = absent[index]
			absent[index] += delta
			var decay: float = maxf(0,absent[index]-5)-maxf(0,previous-5)
			progress[index] = maxf(0,progress[index]-decay/DURATIONS[index])
	for capture: Vector2i in completed:
		owners[capture.x] = capture.y
		progress[capture.x] = 0
		capturing[capture.x] = -1
		time_remaining = minf(600,time_remaining+120)
	# Publish only after the entire simultaneous ownership transaction commits.
	for capture: Vector2i in completed: point_captured.emit(capture.x,capture.y)
	for index: int in 5:
		if capturing[index] >= 0 and not eligible(index,capturing[index]):
			progress[index] = 0
			capturing[index] = -1
	for team: int in 2:
		if owners.count(team) == 5:
			_finish(team)
			return
	if time_remaining > 0:
		overtime = false
		grace = 3
	elif activity:
		overtime = true
		grace = 3
	elif overtime:
		grace -= delta
		if grace <= .000001: _finish(-1)
	else: _finish(-1)

func _finish(team: int) -> void:
	finished = true
	winner = team
	round_ended.emit(team)
