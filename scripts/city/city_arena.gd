extends Node3D

var definition: CityMapDefinition
var builder: MeridianCityBuilder
var navigation_region: NavigationRegion3D
var resolver: CombatResolver
var player: HeroActor
var match_controller: CityMatch

func _ready() -> void:
	TrainingInputs.install()
	definition = load("res://resources/maps/meridian_gardens.tres") as CityMapDefinition
	resolver = CombatResolver.new()
	add_child(resolver)
	builder = MeridianCityBuilder.new()
	builder.name = "MeridianDistrict"
	builder.definition = definition
	add_child(builder)
	var ambience := preload("res://scripts/city/city_ambience.gd").new()
	ambience.name = "MeridianCityAmbience"
	add_child(ambience)
	navigation_region = builder.navigation_region
	player = preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
	player.actor_id = "Nimbus"
	player.position = definition.team_spawns(0)[0]
	add_child(player)
	var controller := PlayerController.new()
	controller.actor = player
	player.add_child(controller)
	player.controller = controller
	match_controller = CityMatch.new()
	match_controller.name = "CityMatch"
	match_controller.arena = self
	match_controller.definition = definition
	match_controller.player = player
	add_child(match_controller)

func _exit_tree() -> void:
	get_tree().paused = false
