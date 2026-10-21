extends "res://tests/full_roster_soak.gd"
## Separate, staged live combat at every payload leg; not a natural route win.
func run() -> void:
	await step(3)
	memory_baseline = counts()
	for stage: int in 3:
		await open_map("museum",stage+4)
		var museum := session as MuseumMatch
		museum.freeze_ai = true
		museum.objective.phase = "escort"
		museum.objective.preparation_remaining = 0
		museum.objective.checkpoint_index = stage
		var distance: float = museum.museum_definition().checkpoint_distances()[stage-1] if stage > 0 else 0.0
		museum.objective.payload_distance = distance
		museum.objective.time_remaining = maxf(180,seconds+30)
		museum._relocate(stage+1,mini(2,stage+1))
		museum.payload.move_to_distance(distance)
		for actor: HeroActor in museum.actors: museum.respawn_actor(actor)
		museum.freeze_ai = false
		await play("museum",seconds)
		reports[-1].scenario = "staged_escort_leg_%d" % (stage+1)
		reports[-1].start_payload_distance = distance
		save_report()
	await finish()
