class_name TrainingWorkshop
extends Node
const BEHAVIORS: Array[String] = ["Stationary","Strafing","Full kit","Melee only","Throw only","Shield defense","Mixed close combat"]
var training: TrainingManager
var selected_hero: String = "nimbus"
var selected_behavior: String = "Stationary"
var selected_allied: bool = false
var selected_dummy: HeroActor
var selected_ability: int = 0
var lab_actor: HeroActor
var lab_ally: HeroActor
var lab_controller: AbilityPracticeController
var repeat_casts: bool = false
var repeat_clock: float = 0
var parkour: TrainingParkour
var parries: int = 0
var misses: int = 0
var parry_active: bool = false
var dummy_picker: OptionButton
var ability_picker: OptionButton
var fixtures: Node3D
func _ready() -> void:
	training.player.resolver.event_logged.connect(on_event)
	training.player.resolver.impact_confirmed.connect(on_impact)
	training.player.resolver.confirmed_heal.connect(on_heal)
	parkour = TrainingParkour.new()
	parkour.training = training
	training.arena.add_child(parkour)
func option(parent: Node, labels: Array, action: Callable) -> OptionButton:
	var picker := OptionButton.new()
	for title: String in labels: picker.add_item(title)
	parent.add_child(picker)
	picker.item_selected.connect(action)
	return picker
func build_controls(parent: Node, hud: TrainingHUD) -> void:
	hud.menu_label(parent,"QUICK TRAINING / SESSION CONTROLS",19)
	var toggles := HBoxContainer.new()
	parent.add_child(toggles)
	hud.check(toggles,"No cooldowns",training.no_cooldowns,func(on: bool) -> void: training.no_cooldowns = on)
	hud.check(toggles,"Prevent death (1 HP)",training.prevent_death,func(on: bool) -> void: training.prevent_death = on)
	hud.check(toggles,"Infinite ammunition",training.infinite_ammo,func(on: bool) -> void: training.infinite_ammo = on)
	var spawn_row := HBoxContainer.new()
	parent.add_child(spawn_row)
	var names: Array[String] = []
	for hero: String in HeroRoster.IDS: names.append(HeroRoster.display_name(hero))
	var hero_picker := option(spawn_row,names,func(index: int) -> void:
		stop_lab()
		selected_hero = HeroRoster.IDS[index]
		refresh_abilities())
	hero_picker.select(HeroRoster.IDS.find(selected_hero))
	var behavior_picker := option(spawn_row,BEHAVIORS,func(index: int) -> void: selected_behavior = BEHAVIORS[index])
	behavior_picker.select(BEHAVIORS.find(selected_behavior))
	var team_picker := option(spawn_row,["Enemy","Ally"],func(index: int) -> void: selected_allied = index == 1)
	team_picker.select(1 if selected_allied else 0)
	hud.button(spawn_row,"Spawn hero",func() -> void:
		selected_dummy = training.spawn_hero(selected_hero,selected_behavior,selected_allied)
		refresh_dummies())
	hud.button(spawn_row,"Spawn 600 HP tank",func() -> void:
		selected_dummy = training.spawn_tank_dummy()
		refresh_dummies())
	var edit_row := HBoxContainer.new()
	parent.add_child(edit_row)
	dummy_picker = option(edit_row,[],func(index: int) -> void:
		var id: int = int(dummy_picker.get_item_metadata(index))
		selected_dummy = instance_from_id(id) as HeroActor)
	hud.button(edit_row,"Apply behavior / team",func() -> void:
		if is_instance_valid(selected_dummy):
			selected_dummy.team = training.player.team if selected_allied else 1-training.player.team
			training.set_behavior(selected_dummy,selected_behavior))
	hud.button(edit_row,"Refresh dummy list",refresh_dummies)
	refresh_dummies()
	hud.menu_label(parent,"ABILITY LAB / choose hero above, then one ability",17)
	ability_picker = option(parent,[],func(index: int) -> void:
		stop_lab()
		selected_ability = index)
	refresh_abilities()
	hud.menu_label(parent,"Live attacks target you. Support actions use an injured ally. Prevent death is optional.",13)
	var actions := HBoxContainer.new()
	parent.add_child(actions)
	hud.button(actions,"Cast once",start_lab.bind(false))
	hud.button(actions,"Repeat",start_lab.bind(true))
	hud.button(actions,"Stop",stop_lab)
	hud.button(actions,"Full kit sparring",start_sparring)
	var drills := HBoxContainer.new()
	parent.add_child(drills)
	hud.button(drills,"Perfect shield parry",start_parry)
	hud.button(drills,"Extended parkour",start_parkour)
	hud.button(drills,"Recover checkpoint",func() -> void: parkour.recover(); resume())
func refresh_abilities() -> void:
	if not is_instance_valid(ability_picker): return
	ability_picker.clear()
	for caption: String in AbilityPracticeController.LABELS[selected_hero]: ability_picker.add_item(caption)
	selected_ability = clampi(selected_ability,0,5)
	ability_picker.select(selected_ability)
func refresh_dummies() -> void:
	if not is_instance_valid(dummy_picker): return
	dummy_picker.clear()
	for bot: HeroActor in training.bots:
		if not is_instance_valid(bot): continue
		dummy_picker.add_item(bot.actor_id)
		var index: int = dummy_picker.item_count-1
		dummy_picker.set_item_metadata(index,bot.get_instance_id())
		if bot == selected_dummy: dummy_picker.select(index)
	if (not is_instance_valid(selected_dummy) or not training.bots.has(selected_dummy)) and dummy_picker.item_count > 0:
		selected_dummy = instance_from_id(int(dummy_picker.get_item_metadata(0))) as HeroActor
		dummy_picker.select(0)
	if dummy_picker.item_count == 0: selected_dummy = null
func resume() -> void:
	if training.menu_open: training.toggle_menu()
func stop_all() -> void:
	stop_lab()
	parry_active = false
	if is_instance_valid(parkour): parkour.running = false
func stop_lab() -> void:
	repeat_casts = false
	for bot: HeroActor in [lab_actor,lab_ally]:
		if not is_instance_valid(bot): continue
		bot.close.cancel()
		bot.kit.cancel(true)
		# Hero reset clears owned benefits, status links, structures and projectiles.
		bot.reset_actor()
		training.bots.erase(bot)
		training.death_timers.erase(bot.get_instance_id())
		bot.queue_free()
	lab_actor = null
	lab_ally = null
	lab_controller = null
	if is_instance_valid(fixtures): fixtures.queue_free()
	fixtures = null
func start_lab(repeat: bool) -> void:
	stop_lab()
	parry_active = false
	parkour.running = false
	training.freeze_ai = false
	# An isolated west annex avoids existing range cover and keeps fixtures separate.
	training.player.reset_actor(Vector3(-58,.1,0))
	fixtures = Node3D.new()
	training.arena.add_child(fixtures)
	Geometry.box(fixtures,Vector3(1,8,12),Vector3(-58,4,-12),Color("526d78"))
	Geometry.text3d(fixtures,"ABILITY LAB / REAL KIT CASTS",Vector3(-58,5,-12),28,Color("c8eee0"))
	Geometry.text3d(fixtures,AbilityPracticeController.LABELS[selected_hero][selected_ability],Vector3(-58,3.8,-12),22,Color("ffc7bc"))
	var distance: float = 9.0
	if selected_hero in ["marshal","huddle","stitch"]: distance = 5.0
	lab_actor = training.spawn_hero(selected_hero,"Stationary",false,Vector3(-58,.1,distance),true)
	lab_ally = training.spawn_hero("nimbus","Stationary",false,Vector3(-55,.1,distance-3),true)
	lab_ally.team = lab_actor.team
	lab_ally.health = lab_ally.tuning.max_health*.3
	if selected_hero == "doctor" and selected_ability == 4: lab_ally.statuses.apply("slow",training.player,10,.3)
	lab_actor.remove_child(lab_actor.controller)
	lab_actor.controller.queue_free()
	lab_controller = AbilityPracticeController.new()
	lab_controller.actor = lab_actor
	lab_controller.target = training.player
	lab_controller.ally = lab_ally
	lab_actor.controller = lab_controller
	lab_actor.add_child(lab_controller)
	repeat_casts = repeat
	repeat_clock = 0
	lab_controller.begin(selected_ability)
	training.show_notice("ABILITY LAB / "+AbilityPracticeController.LABELS[selected_hero][selected_ability])
	resume()
func start_sparring() -> void:
	stop_all()
	training.player.reset_actor(Vector3(0,.1,11))
	training.freeze_ai = false
	selected_dummy = training.spawn_hero(selected_hero,"Full kit",false,Vector3(0,.1,-5))
	resume()
func start_parry() -> void:
	training.scenario = 18
	training.freeze_ai = false
	training.reset_scenario()
	parry_active = true
	parries = 0
	misses = 0
	resume()
func start_parkour() -> void:
	stop_lab()
	parry_active = false
	parkour.start()
	resume()
func status() -> String:
	if parry_active: return "PARRY PRACTICE / %d PERFECT / %d HITS TAKEN" % [parries,misses]
	if is_instance_valid(lab_controller): return "ABILITY LAB / "+lab_controller.outcome
	if parkour.running: return "PARKOUR / CHECKPOINT %d/6 / %.1fs / BEST %.1fs" % [parkour.checkpoint,parkour.elapsed,parkour.best]
	return ""
func _process(delta: float) -> void:
	if training.menu_open: return
	if is_instance_valid(lab_controller) and repeat_casts:
		repeat_clock += delta
		if repeat_clock >= 9:
			repeat_clock = 0
			start_lab(true)
func on_event(entry: Dictionary) -> void:
	if parry_active and entry.actor == training.player.actor_id and entry.event == "parry": parries += 1
	if is_instance_valid(lab_actor) and is_instance_valid(lab_controller) and entry.actor == lab_actor.actor_id and entry.event in ["cast","buff","heal","complete"]:
		lab_controller.cast_count += 1
		lab_controller.outcome = str(entry.event).to_upper()+" / "+str(entry.get("ability","kit"))
func on_impact(_source: HeroActor, target: HeroActor, _amount: float, _head: bool, _executed: bool, _origin: Vector3, _shield: float, _cast: int, _tag: String) -> void:
	if parry_active and target == training.player and _tag == "knife": misses += 1

func on_heal(source: HeroActor, _target: HeroActor, amount: float) -> void:
	if source == lab_actor and is_instance_valid(lab_controller) and amount > 0:
		lab_controller.outcome = "HEALING / %.1f HP" % amount
