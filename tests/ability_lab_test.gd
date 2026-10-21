extends SceneTree
var failures: int = 0
var checks: int = 0
var arena: Node3D
var training: TrainingManager
var healed: float = 0
func _initialize() -> void: call_deferred("run")
func step(frames: int = 1) -> void:
	for index: int in frames:
		await physics_frame
		await process_frame
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",caption)
func run() -> void:
	arena = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	training = arena.training
	training.despawn_bots()
	training.prevent_death = true
	training.player.training_prevent_death = true
	training.player.controller.active = false
	training.player.set_physics_process(false)
	training.player.resolver.confirmed_heal.connect(func(_source: HeroActor,_target: HeroActor,amount: float) -> void: healed += amount)
	var workshop: TrainingWorkshop = training.workshop
	await step(3)
	for hero: String in HeroRoster.IDS:
		for slot: int in 6:
			workshop.selected_hero = hero
			workshop.selected_ability = slot
			healed = 0
			workshop.start_lab(false)
			var steps: int = 0
			while workshop.lab_controller.requested and steps < 900:
				await step()
				steps += 1
			var controller: AbilityPracticeController = workshop.lab_controller
			var is_passive: bool = slot == 1 and hero in ["nimbus","slayer","samson","dynamo"]
			check(controller.cast_count > 0 or controller.observed_effect or healed > 0 or is_passive,"real lab sequence / %s / %s / events %d / healing %.1f" % [hero,AbilityPracticeController.LABELS[hero][slot],controller.cast_count,healed])
			check(is_instance_valid(workshop.lab_actor) and workshop.lab_actor.alive,"lab caster survives / %s %d" % [hero,slot])
			workshop.stop_lab()
			await step(2)
			check(workshop.lab_actor == null and workshop.lab_ally == null and training.bots.is_empty(),"lab fixtures cleaned / %s %d" % [hero,slot])
	print("RESULT: %d checks, %d failures" % [checks,failures])
	arena.queue_free()
	await step(3)
	quit(1 if failures else 0)
