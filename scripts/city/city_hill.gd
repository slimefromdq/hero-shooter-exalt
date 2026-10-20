class_name CityHill
extends Node

signal ownership_changed(team: int)
signal round_won(team: int)

var definition: CityMapDefinition
var elapsed: float = 0.0
var unlock_remaining: float = 20.0
var unlocked: bool = false
var owner_team: int = -1
var capture_team: int = -1
var capturing_team: int:
	get: return capture_team
	set(value): capture_team = value
var capture_progress: float = 0.0
var scores: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])
var contested: bool = false
var occupancy: Array[int] = [0, 0]
var winner: int = -1
var captures: Array[int] = [0, 0]
var contested_seconds: float = 0.0

func reset() -> void:
	elapsed = 0.0
	unlock_remaining = definition.unlock_seconds if definition != null else 20.0
	unlocked = false
	owner_team = -1
	capture_team = -1
	capture_progress = 0.0
	scores = PackedFloat64Array([0.0, 0.0])
	contested = false
	occupancy = [0, 0]
	winner = -1
	captures = [0, 0]
	contested_seconds = 0.0

func contains(position: Vector3) -> bool:
	var local: Vector3 = position - definition.hill_center
	return absf(local.x) <= definition.hill_half_extents.x and absf(local.z) <= definition.hill_half_extents.z and local.y >= definition.hill_min_height and local.y <= definition.hill_max_height

func tick(delta: float, participants: Array[HeroActor]) -> void:
	advance(delta, participants)

func advance(delta: float, participants: Array[HeroActor]) -> void:
	if winner >= 0:
		return
	var previous_elapsed: float = elapsed
	elapsed += delta
	unlock_remaining = maxf(0.0, definition.unlock_seconds - elapsed)
	unlocked = unlock_remaining <= 0.0
	occupancy = [0, 0]
	for actor: HeroActor in participants:
		if is_instance_valid(actor) and actor.objective_eligible() and actor.team in [0, 1] and contains(actor.global_position):
			occupancy[actor.team] += 1
	contested = occupancy[0] > 0 and occupancy[1] > 0
	if not unlocked:
		return
	# Only time after the unlock can contribute when a simulation crosses it in one step.
	var active_delta: float = minf(delta, maxf(0.0, elapsed - maxf(previous_elapsed, definition.unlock_seconds)))
	var score_delta: float = active_delta
	if contested:
		contested_seconds += active_delta
	else:
		var occupying_team: int = 0 if occupancy[0] > 0 else (1 if occupancy[1] > 0 else -1)
		if occupying_team >= 0 and occupying_team != owner_team:
			var progress_before: float = capture_progress
			if capture_team >= 0 and capture_team != occupying_team:
				capture_progress = maxf(0.0, capture_progress - active_delta / definition.capture_seconds)
				if capture_progress <= 0.0:
					capture_team = occupying_team
			else:
				capture_team = occupying_team
				capture_progress = minf(1.0, capture_progress + active_delta / definition.capture_seconds)
			if capture_progress >= 1.0 - 0.000001:
				owner_team = occupying_team
				score_delta = maxf(0.0, active_delta - (1.0 - progress_before) * definition.capture_seconds)
				captures[owner_team] += 1
				capture_team = -1
				capture_progress = 0.0
				ownership_changed.emit(owner_team)
		elif capture_progress > 0.0:
			capture_progress = maxf(0.0, capture_progress - active_delta / definition.capture_seconds)
			if capture_progress <= 0.0:
				capture_team = -1
	# An enemy in an owned hill stops the clock, including a lone attacker recapturing it.
	if owner_team >= 0 and occupancy[1 - owner_team] == 0:
		scores[owner_team] = minf(definition.score_to_win, scores[owner_team] + score_delta * definition.score_per_second)
		if scores[owner_team] >= definition.score_to_win:
			winner = owner_team
			round_won.emit(winner)
