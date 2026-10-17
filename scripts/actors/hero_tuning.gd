class_name HeroTuning
extends Resource

@export_category("Movement · meters / seconds")
@export var ground_speed: float = 6.0
@export var acceleration: float = 30.0
@export var braking: float = 24.0
@export var air_steering: float = 7.5
@export var gravity: float = 22.0
@export var jump_impulse: float = 8.0
@export var dash_buildup: float = 0.16
@export var dash_speed: float = 22.0
@export var dash_duration: float = 0.38
@export var dash_decay: float = 26.0
@export var dash_cooldown: float = 4.5
@export var slide_entry_speed: float = 5.0
@export var slide_friction: float = 3.6
@export var slide_slope: float = 8.0
@export var speed_limit: float = 26.0
@export_category("Nimbus")
@export var max_health: float = 250.0
@export var rifle_damage: float = 45.0
@export var head_multiplier: float = 2.0
@export var shot_interval: float = 0.6
@export var magazine: int = 8
@export var reload_time: float = 1.6
@export_range(0.0, 1.0) var reload_move_multiplier: float = 0.85
@export var hover_ascent: float = 8.5
@export var hover_ascent_time: float = 0.3
@export var hover_duration: float = 2.5
@export var hover_descent: float = 1.6
@export var hover_cooldown: float = 8.0
@export var deflect_duration: float = 0.65
@export var deflect_cooldown: float = 10.0
@export var bomb_damage: float = 80.0
@export var bomb_radius: float = 3.0
@export var bomb_fuse: float = 1.1
@export var bomb_cooldown: float = 9.0
@export var ultimate_damage: float = 150.0
@export var execute_threshold: float = 0.2
@export var ultimate_preparation: float = 0.6
@export var ultimate_duration: float = 5.0
@export_category("Close combat · prototype values")
@export var melee_damage: float = 75.0
@export var melee_range: float = 2.6
@export var melee_windup: float = 0.24
@export var melee_active: float = 0.2
@export var melee_recovery: float = 0.4
@export var melee_lunge_distance: float = 4.8
@export var melee_lunge_delay: float = 0.06
@export var melee_lunge_duration: float = 0.36
@export var guard_drain: float = 24.0
@export var guard_regen: float = 35.0
@export var guard_cost: float = 28.0
@export var guard_cooldown: float = 2.0
@export var bullet_guard_reduction: float = 0.0
@export var stagger_duration: float = 0.55
@export var throw_range: float = 2.8
@export var throw_startup: float = 0.3
@export var throw_recovery: float = 0.65
@export var counter_window: float = 0.24
@export var throw_duration: float = 1.1
@export var throw_impact_progress: float = 0.72
@export var throw_lift_height: float = 1.05
@export var throw_damage: float = 95.0
@export var throw_outside_multiplier: float = 0.1
@export var throw_grace: float = 0.8
