class_name RelayTuning
extends HeroTuning
## Stable resource class for Seeker (legacy hero ID: relay).
@export_category("Seeker · spirit bow")
@export var arrow_speed: float = 90.0
@export var arrow_range: float = 65.0
@export var volley_damage: float = 22.0
@export var volley_min_charge: float = .2
@export var volley_charge: float = 1.0
@export var volley_recovery: float = 1.5
@export_category("Guiding Spirit")
@export var heal_rate: float = 25.0
@export var assign_range: float = 65.0
@export var sight_grace: float = 5.0
@export var transfer_time: float = .25
@export var transfer_cooldown: float = 1.0
@export var wing_heal: float = 60.0
@export var wing_speed: float = .3
@export var wing_duration: float = 2.0
@export var wing_cooldown: float = 8.0
@export_category("Omen / spirit jump")
@export var omen_duration: float = 6.0
@export var omen_cooldown: float = 12.0
@export var omen_damage: float = .2
@export var jump_up: float = 11.0
@export var jump_forward: float = 8.0
@export var jump_cooldown: float = 5.0
@export_category("Murmuration")
@export var murmuration_preparation: float = .35
@export var murmuration_duration: float = 10.0
@export var murmuration_healing: float = .35
@export var swoop_damage: float = 25.0
@export var swoop_range: float = 12.0
