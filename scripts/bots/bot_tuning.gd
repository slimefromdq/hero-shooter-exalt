class_name BotTuning
extends Resource
## Team-wide behaviour weights, evolved offline by self-play (tools/tune_bots.py) and
## shipped as resources/bots/tuning/default.tres. Defaults equal the hand-set values.
## Each TeamDirector holds one, so two weight sets can play each other head to head.

## Query: value of standing on the objective, of avoiding danger, of sight lines and cover.
@export var objective_weight: float = 1.0
@export var danger_weight: float = 1.0
@export var los_weight: float = 1.0
@export var cover_weight: float = 1.0
## Brain: flat biases on aggressive goals and on backing off.
@export var aggression_bias: float = 0.0
@export var retreat_bias: float = 0.0
## Director: fall back when outnumbered by this many; push when this share has gathered.
@export var regroup_margin: float = 2.0
@export var push_fraction: float = .65
## Locomotion: lateral weave while moving, strafe tempo multiplier, dodge eagerness.
@export var weave: float = .55
@export var strafe_tempo: float = 1.0
@export var dodge_eagerness: float = 1.0

const KEYS: Array[String] = ["objective_weight","danger_weight","los_weight","cover_weight","aggression_bias","retreat_bias",
	"regroup_margin","push_fraction","weave","strafe_tempo","dodge_eagerness"]
## Mutation ranges for the evolution strategy: [min, max, step sigma].
const RANGES: Dictionary = {"objective_weight":[.3,2.5,.25],"danger_weight":[0.0,2.5,.25],"los_weight":[.3,2.0,.2],"cover_weight":[.3,2.0,.2],
	"aggression_bias":[-.3,.3,.06],"retreat_bias":[-.3,.3,.06],"regroup_margin":[1.0,3.0,.5],"push_fraction":[.4,.9,.08],
	"weave":[0.0,1.0,.12],"strafe_tempo":[.6,1.6,.15],"dodge_eagerness":[.5,1.3,.1]}

static var default_tuning: BotTuning

static func standard() -> BotTuning:
	if default_tuning == null:
		var path: String = "res://resources/bots/tuning/default.tres"
		default_tuning = load(path) as BotTuning if ResourceLoader.exists(path) else BotTuning.new()
	return default_tuning

static func from_dict(values: Dictionary) -> BotTuning:
	var result := BotTuning.new()
	for key: String in KEYS:
		if values.has(key): result.set(key,float(values[key]))
	return result

func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for key: String in KEYS: result[key] = get(key)
	return result
