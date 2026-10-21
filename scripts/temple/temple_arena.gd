extends Node3D
var definition: TempleMapDefinition
var builder: TempleBuilder
var navigation_region: NavigationRegion3D
var resolver: CombatResolver
var player: HeroActor
var match_controller: TempleMatch
var navigation_map: RID
var previous_cell_size: float = .25

func _ready() -> void:
	navigation_map = get_world_3d().navigation_map
	previous_cell_size = NavigationServer3D.map_get_cell_size(navigation_map)
	NavigationServer3D.map_set_cell_size(navigation_map,.4)
	HeroRoster.consume_direct_entry()
	TrainingInputs.install()
	definition = load("res://resources/maps/sakura_veil.tres") as TempleMapDefinition
	resolver = CombatResolver.new()
	add_child(resolver)
	builder = TempleBuilder.new()
	builder.definition = definition
	add_child(builder)
	navigation_region = builder.navigation_region
	player = preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
	player.team = 1 if "--temple-team=1" in OS.get_cmdline_user_args() else TempleMatch.selected_side
	player.tuning = HeroRoster.tuning_for(HeroRoster.selected)
	player.actor_id = HeroRoster.display_name(HeroRoster.selected)
	player.position = definition.team_spawns(player.team)[0]
	add_child(player)
	var controller := PlayerController.new()
	controller.actor = player
	player.add_child(controller)
	player.controller = controller
	match_controller = TempleMatch.new()
	match_controller.arena = self
	match_controller.definition = definition
	match_controller.player = player
	add_child(match_controller)

func _exit_tree() -> void:
	if navigation_map.is_valid(): NavigationServer3D.map_set_cell_size(navigation_map,previous_cell_size)
	get_tree().paused = false
