extends Node3D
var definition: MuseumMapDefinition
var builder: MuseumBuilder
var navigation_region: NavigationRegion3D
var resolver: CombatResolver
var player: HeroActor
var match_controller: MuseumMatch
var objective_marker: MuseumObjectiveMarker

func _ready() -> void:
	HeroRoster.consume_direct_entry()
	TrainingInputs.install()
	definition = load("res://resources/maps/meridian_museum.tres").duplicate() as MuseumMapDefinition
	resolver = CombatResolver.new()
	add_child(resolver)
	builder = MuseumBuilder.new()
	builder.definition = definition
	add_child(builder)
	navigation_region = builder.navigation_region
	player = preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
	player.team = 1 if "--defend" in OS.get_cmdline_user_args() else MuseumMatch.selected_side
	player.tuning = HeroRoster.tuning_for(HeroRoster.selected)
	player.actor_id = HeroRoster.display_name(HeroRoster.selected)
	player.position = definition.team_spawns(player.team)[0]
	add_child(player)
	var controller := PlayerController.new()
	controller.actor = player
	player.add_child(controller)
	player.controller = controller
	if "--explore" in OS.get_cmdline_user_args(): MuseumMatch.start_exploring = true
	match_controller = MuseumMatch.new()
	match_controller.arena = self
	match_controller.definition = definition
	match_controller.player = player
	add_child(match_controller)
	objective_marker = MuseumObjectiveMarker.new()
	objective_marker.session = match_controller
	add_child(objective_marker)

func _exit_tree() -> void:
	get_tree().paused = false
