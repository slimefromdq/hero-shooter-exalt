class_name SlayerTuning
extends HeroTuning

@export_category("Street Sweeper")
@export_range(1,64,1) var pellets: int = 10
@export var pellet_damage: float = 7.0
@export var spread_degrees: float = 2.2
@export var falloff_start: float = 8.0
@export var falloff_end: float = 14.0
@export_range(0,1) var minimum_damage: float = 0.15
@export var weapon_range: float = 35.0
@export var shell_time: float = 0.55
@export var reload_start: float = 0.3
@export var shotgun_cancel_after: float = 0.25
@export var recoil_degrees: float = 2.4
@export_category("Silver Knives")
@export var knife_damage: float = 30.0
@export var knife_speed: float = 35.0
@export var knife_range: float = 25.0
@export_range(1,8,1) var knife_charges: int = 2
@export var knife_recharge: float = 7.0
@export var knife_recovery: float = 0.22
@export var bleed_dps: float = 8.0
@export var bleed_duration: float = 4.0
@export_category("Boot Rush")
@export var boot_distance: float = 8.0
@export var boot_speed: float = 25.0
@export var boot_startup: float = 0.12
@export var boot_damage: float = 55.0
@export var boot_reach: float = 1.25
@export var boot_knockback: float = 8.0
@export var boot_miss_recovery: float = 0.35
@export var boot_hit_recovery: float = 0.18
@export var boot_cooldown: float = 9.0
@export_range(0,1) var boot_momentum: float = 0.3
@export_category("Hunter's Snare")
@export_range(1,8,1) var trap_limit: int = 2
@export var trap_arm_time: float = 0.5
@export var trap_radius: float = 1.4
@export var trap_root: float = 1.5
@export var trap_lifetime: float = 15.0
@export var trap_recharge: float = 12.0
@export var trap_health: float = 25.0
@export var trap_damage: float = 25.0
@export var trap_direct_damage: float = 12.0
@export var trap_slow_duration: float = 1.5
@export_range(0,1) var trap_slow_multiplier: float = 0.5
@export var trap_throw_speed: float = 13.0
@export var trap_recovery: float = 0.25
@export_category("Hunter's Instinct")
@export var mark_duration: float = 4.0
@export var mark_range: float = 32.0
@export_range(0,1) var wounded_threshold: float = 0.3
@export_category("Heads Will Roll")
@export var axe_damage: float = 110.0
@export_range(0,0.9) var axe_max_reduction: float = 0.5
@export var axe_debuff_duration: float = 8.0
@export var axe_windup: float = 0.65
@export var axe_release: float = 0.2
@export var axe_recovery: float = 0.55
@export var axe_speed: float = 20.0
@export var axe_range: float = 30.0
@export var axe_radius: float = 0.55
