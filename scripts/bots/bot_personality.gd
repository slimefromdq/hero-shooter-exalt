class_name BotPersonality
extends Resource
## A player archetype. Offsets (-0.5..0.5) bias decisions; flair, chattiness and tilt
## (0..1) shape movement flourish, callouts and how badly repeated deaths rattle the bot.
## Each bot takes a seeded archetype plus small jitter, so a lobby feels like people.
const ARCHETYPES: Array[String] = ["hothead","anchor","lurker","guardian","showoff","turtle","shotcaller","wildcard"]
const NAMES: Array[String] = ["Ash","Bramble","Cinder","Dove","Ember","Fennel","Gale","Hazel","Iris","Juniper","Kestrel","Lark",
	"Moss","Nettle","Onyx","Pike","Quill","Rook","Sable","Thistle","Umber","Vesper","Wren","Yarrow"]

@export var archetype: String = "neutral"
@export var aggression: float = 0.0
@export var caution: float = 0.0
@export var teamplay: float = 0.0
@export var flank: float = 0.0
@export var patience: float = 0.0
@export_range(0,1) var flair: float = .3
@export_range(0,1) var chattiness: float = .4
@export_range(0,1) var tilt_prone: float = .4

static func archetype_resource(id: String) -> BotPersonality:
	var path: String = "res://resources/bots/personalities/%s.tres" % id
	return load(path) as BotPersonality if ResourceLoader.exists(path) else BotPersonality.new()

## Seeded archetype with per-bot jitter, returned as plain traits.
static func roll(rng: RandomNumberGenerator) -> Dictionary:
	var base: BotPersonality = archetype_resource(ARCHETYPES[rng.randi_range(0,ARCHETYPES.size()-1)])
	var jitter := func(value: float, low: float, high: float) -> float: return clampf(value+rng.randf_range(-.1,.1),low,high)
	return {"archetype":base.archetype,"aggression":jitter.call(base.aggression,-.5,.5),"caution":jitter.call(base.caution,-.5,.5),
		"teamplay":jitter.call(base.teamplay,-.5,.5),"flank":jitter.call(base.flank,-.5,.5),"patience":jitter.call(base.patience,-.5,.5),
		"flair":jitter.call(base.flair,0,1),"chattiness":jitter.call(base.chattiness,0,1),"tilt_prone":jitter.call(base.tilt_prone,0,1)}
