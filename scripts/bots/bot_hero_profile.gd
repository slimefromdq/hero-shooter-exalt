class_name BotHeroProfile
extends Resource
@export var hero: String = "fallback"
@export var minimum_range: float = 10.0
@export var maximum_range: float = 20.0
@export var aggression: float = .5
@export var mobility: float = .5
@export var vulnerable_bias: float = .2
@export var escape_reserve: int = 1

@export_category("Peel support decisions")
@export var rescue_health: float = .65
@export var emergency_health: float = .4
@export var pressure_window: float = 1.5
@export var diver_range: float = 6.0
@export var threat_range: float = 10.0
@export var court_offset: float = 4.0

static func for_hero(id: String) -> BotHeroProfile:
	var path: String = "res://resources/bots/heroes/%s.tres" % id
	return load(path) as BotHeroProfile if ResourceLoader.exists(path) else BotHeroProfile.new()
