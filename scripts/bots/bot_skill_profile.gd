class_name BotSkillProfile
extends Resource
const NAMES: Array[String] = ["Beginner", "Normal", "Hard", "Expert"]
@export var title: String = "Normal"
@export var acquisition_delay: float = .38
@export var turn_speed: float = 180.0
@export var tracking_acceleration: float = 540.0
@export var error_degrees: float = 1.0
@export var prediction: float = .65
@export var consistency: float = .7
@export var coordination: float = .6
@export var tactical_interval: float = .2
@export var path_interval: float = .5
@export var perception_budget: int = 6
@export_category("Human senses")
## Half-angle of the focused view cone and of the motion-only peripheral band.
@export var cone_degrees: float = 50.0
@export var peripheral_degrees: float = 100.0
## Seconds a moving/firing enemy must stay in peripheral vision before it registers.
@export var peripheral_delay: float = .35
@export var hearing_scale: float = .85
## Mean seconds between flank/"check six" glances while not engaged; 0 disables.
@export var glance_interval: float = 5.0

static func for_level(level: int) -> BotSkillProfile:
	return load("res://resources/bots/skills/%s.tres" % NAMES[clampi(level,0,3)].to_lower()) as BotSkillProfile
