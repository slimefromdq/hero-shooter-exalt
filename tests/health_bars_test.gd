extends SceneTree
var checks: int = 0
var failures: int = 0

class SlotProbe extends CityHUD:
	var captions: Array[String] = []
	var rectangles: Array[Rect2] = []
	var panel_size: Vector2
	func box(at: Vector2, size: Vector2, _color: Color) -> void: rectangles.append(Rect2(at,size))
	func panel(_at: Vector2, size: Vector2, _light: bool = false) -> void: panel_size = size
	func centered(caption: String, _at: Vector2, _size: int = 16, _color: Color = Color.WHITE, _heavy: bool = false) -> void: captions.append(caption)
	func text(caption: String, _at: Vector2, _size: int = 16, _color: Color = Color.WHITE, _heavy: bool = false) -> void: captions.append(caption)

class RespawnProbe extends Node:
	func respawn_remaining(_actor: HeroActor) -> float: return 3.2

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",caption)

func frames(count: int = 4) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func run() -> void:
	var arena: Node = load("res://scenes/training/combat_sandbox.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.training.freeze_ai = true
	arena.player.controller.active = false
	await frames()
	var enemy: HeroActor = arena.training.practice_range.groups.aoe[0]
	var ally: HeroActor = arena.training.practice_range.groups.allies[0]
	var bar: ActorHealthBar = enemy.presentation.health_bar
	check(bar.visible and not bar.friendly,"enemy has a visible overhead health bar")
	check(ally.presentation.health_bar.visible and ally.presentation.health_bar.friendly,"training ally also has a visible overhead health bar")
	check(not arena.player.presentation.health_bar.visible,"local hero uses the player HUD without an overhead bar")
	enemy.health = 125
	await frames()
	check(is_equal_approx(bar.health_fraction,.5) and is_equal_approx(bar.fill.scale.x,.5),"enemy bar tracks half health")
	check(bar.caption.text == "125 / 250","overhead bar exposes current and maximum HP")
	check((bar.fill.material_override as StandardMaterial3D).albedo_color == Color("ff4f65"),"enemy health fill is red")
	check((ally.presentation.health_bar.fill.material_override as StandardMaterial3D).albedo_color == Color("80f54e"),"ally health fill is green")
	enemy.resolver.heal(enemy,enemy,25,"test")
	await frames()
	check(is_equal_approx(bar.health_fraction,.6),"healing immediately updates the bar")
	enemy.shields = 75
	await frames()
	check(bar.shield_fill.visible and bar.caption.text.contains("+75"),"overhead shield strip and amount are visible")
	enemy.statuses.apply("max_health",arena.player,8,.5)
	await frames()
	check(bar.caption.text.begins_with("125 / 125") and is_equal_approx(bar.health_fraction,1),"wounds use the current effective health maximum")
	var probe := SlotProbe.new()
	var respawn := RespawnProbe.new()
	probe.match_controller = respawn
	enemy.statuses.cleanse()
	enemy.health = 125
	probe.draw_team_slot(enemy,Vector2.ZERO,false,Color("ff4f65"),false)
	check(probe.captions.has("125 HP") and probe.panel_size.y == 112,"enemy top roster slot includes numeric health")
	check(probe.rectangles.has(Rect2(4,85,31.5,7)),"enemy top roster slot includes proportional health fill")
	check(not probe.captions.any(func(caption: String) -> bool: return caption.begins_with("ULT")),"enemy health does not reveal enemy ultimate charge")
	probe.captions.clear()
	probe.draw_team_slot(ally,Vector2.ZERO,true,Color("38dfff"),false)
	check(probe.captions.any(func(caption: String) -> bool: return caption.begins_with("ULT")),"ally top roster keeps ultimate information")
	enemy.die()
	await frames()
	check(not bar.visible,"overhead bar hides on death")
	probe.captions.clear()
	probe.draw_team_slot(enemy,Vector2.ZERO,false,Color("ff4f65"),false)
	check(probe.captions.has("0 HP") and probe.captions.has("RESPAWN"),"enemy death shows zero health and respawn state in roster")
	enemy.reset_actor()
	await frames()
	check(bar.visible and bar.health_fraction == 1,"overhead bar returns full on respawn")
	var camera: Camera3D = (arena.player.controller as PlayerController).camera
	enemy.global_position = camera.global_position+camera.global_basis.z*5
	await frames()
	check(not bar.visible,"bars behind the camera are hidden")
	enemy.global_position = camera.global_position-camera.global_basis.z*70
	await frames()
	check(not bar.visible,"distant overhead bars are culled")
	check(not (bar.fill.material_override as StandardMaterial3D).no_depth_test and not bar.caption.no_depth_test,"world health bars respect cover depth")
	probe.free()
	respawn.free()
	arena.queue_free()
	await frames()
	print("HEALTH BARS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
