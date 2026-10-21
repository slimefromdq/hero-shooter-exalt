extends SceneTree
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",caption)
func run() -> void:
	var arena: Node3D = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	var training: TrainingManager = arena.training
	training.freeze_ai = true
	training.despawn_bots()
	var player: HeroActor = training.player
	player.set_physics_process(false)
	var bot := training.spawn_hero("marshal")
	bot.set_physics_process(false)
	var feedback: CombatFeedback
	for child: Node in training.hud.numbers.get_children():
		if child is CombatFeedback: feedback = child
	check(feedback != null,"training uses shared combat feedback")
	check(CombatFeedback.marker_size(100) > CombatFeedback.marker_size(10),"damage increases X size")
	check(CombatFeedback.marker_size(100000) <= 36,"X size is capped")
	check(CombatFeedback.low_health_strength(25,100) == 0 and CombatFeedback.low_health_strength(1,100) > .9,"low health threshold and strength")
	var resolver: CombatResolver = player.resolver
	resolver.damage(player,bot,10,"shotgun",resolver.new_cast(player))
	resolver.damage(player,bot,15,"shotgun",resolver.new_cast(player),true)
	check(feedback.markers.size() == 1 and feedback.markers.values()[0].amount == 25 and feedback.markers.values()[0].head,"pellets coalesce and retain headshot")
	feedback.clear()
	var a: int = resolver.new_cast(player)
	var b: int = resolver.new_cast(player)
	resolver.damage(player,bot,20,"rifle",a)
	resolver.damage(player,bot,30,"rifle",b)
	check(feedback.markers.size() == 2 and feedback.markers[str(b)].amount == 30,"independent attacks do not accumulate")
	var count: int = feedback.markers.size()
	bot.invulnerable = true
	resolver.damage(player,bot,50,"rifle",resolver.new_cast(player))
	check(feedback.markers.size() == count,"immune hit creates no marker")
	bot.invulnerable = false
	bot.health = 1
	resolver.damage(player,bot,50,"rifle",resolver.new_cast(player))
	check(feedback.skull_left == .6,"confirmed final blow shows skull")
	player.reset_actor()
	check(feedback.markers.is_empty() and feedback.skull_left == 0,"respawn clears outgoing feedback")
	bot.reset_actor()
	resolver.damage(bot,player,10,"rifle",resolver.new_cast(bot),false,false,Vector3(8,1,4))
	resolver.damage(bot,player,10,"rifle",resolver.new_cast(bot),false,false,Vector3(-8,1,-4))
	check(feedback.incoming.size() == 2 and feedback.incoming[0].origin == Vector3(8,1,4),"simultaneous incoming directions retain impact origins")
	resolver.damage(bot,player,1,"bleed",resolver.new_cast(bot))
	check(feedback.incoming.back().origin == Vector3.INF,"periodic damage uses neutral pulse")
	resolver.feedback_cleared.emit(player)
	check(feedback.incoming.is_empty(),"feedback reset clears incoming directions")
	var presenter: HitImpactPresenter
	for child: Node in resolver.get_children():
		if child is HitImpactPresenter: presenter = child
	presenter.pending.clear()
	var contact := Vector3(1,2,3)
	resolver.damage(player,bot,10,"rifle",resolver.new_cast(player),false,false,Vector3.INF,contact)
	check(presenter.pending.size() == 1 and presenter.pending.values()[0].at == contact,"exact contact reaches world burst presenter")
	presenter.pending.clear()
	bot.shields = 20
	resolver.damage(player,bot,10,"rifle",resolver.new_cast(player))
	check(presenter.pending.values()[0].shields == 10,"shield impact carries blue-spark damage")
	presenter.pending.clear()
	feedback.clear()
	bot.state = "guard"
	bot.aim_direction = (player.global_position-bot.global_position).normalized()
	var blocked: String = resolver.damage(player,bot,20,"melee",resolver.new_cast(player))
	check(blocked == "blocked" and feedback.markers.is_empty() and presenter.pending.is_empty(),"blocked attack creates no damage marker or spark burst")
	bot.state = "ready"
	player.reset_actor()
	player.training_prevent_death = true
	player.health = 1
	resolver.damage(bot,player,20,"rifle",resolver.new_cast(bot))
	check(player.alive and player.health == 1 and feedback.incoming.size() == 1,"prevent death still shows incoming attacks at 1 HP")
	resolver.clear_round()
	check(feedback.incoming.is_empty() and feedback.markers.is_empty(),"round reset clears shared combat feedback")
	resolver.damage(bot,player,20,"rifle",resolver.new_cast(bot))
	var camera := player.controller.camera as Camera3D
	var first_origin: Vector3 = feedback.incoming[0].origin
	camera.rotation.y += PI/2
	check(feedback.incoming[0].origin == first_origin,"camera movement preserves the original incoming location")
	print("RESULT: %d checks, %d failures" % [checks,failures])
	arena.queue_free()
	await process_frame
	quit(1 if failures else 0)
