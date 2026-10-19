class_name BotHeroProfile
extends Resource
@export var hero: String = "fallback"
@export var minimum_range: float = 10.0
@export var maximum_range: float = 20.0
@export var aggression: float = .5
@export var mobility: float = .5
@export var vulnerable_bias: float = .2
@export var escape_reserve: int = 1

static func for_hero(id: String) -> BotHeroProfile:
	var path: String = "res://resources/bots/heroes/%s.tres" % id
	return load(path) as BotHeroProfile if ResourceLoader.exists(path) else BotHeroProfile.new()
