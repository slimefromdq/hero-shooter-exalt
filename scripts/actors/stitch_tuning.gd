class_name StitchTuning
extends HeroTuning

@export_category("Stitch · Needlepoint / Loose Ends")
@export var needle_range: float = 45.0
@export var needle_speed: float = 65.0
@export var shears_damage: float = 60.0
@export var shears_interval: float = .42
@export var shears_range: float = 2.6
@export var shears_exit_range: float = 3.1
@export var shears_angle: float = 40.0
@export var shears_exit_angle: float = 50.0
@export var switch_grace: float = .15
@export var mark_limit: int = 3
@export var mark_duration: float = 4.0
@export var mark_damage: float = 12.0
@export_category("Stitch · Red Thread")
@export var thread_range: float = 22.0
@export var thread_duration: float = 5.0
@export var thread_leash: float = 10.0
@export var thread_break_range: float = 28.0
@export var thread_pull_speed: float = 12.0
@export var thread_spring: float = 4.0
@export var thread_obstruction: float = .3
@export var thread_cooldown: float = 12.0
@export var pursuit_bonus: float = .2
@export_category("Stitch · Play Dead")
@export var collapse_duration: float = .25
@export var conceal_duration: float = 20.0
@export var conceal_cooldown: float = 12.0
@export var conceal_speed: float = 1.1
@export var detection_range: float = 5.0
@export var opening_range: float = 10.0
@export var opening_lunge: float = 10.0
@export var opening_damage: float = 45.0
@export var opening_speed: float = 35.0
@export var opening_bleed: float = 20.0
@export var opening_bleed_duration: float = 3.0
@export_category("Stitch · Spoolstep")
@export var hook_range: float = 45.0
@export var hook_speed: float = 40.0
@export var reel_speed: float = 28.0
@export var hook_cooldown: float = 13.0
@export var reel_timeout: float = 2.0
@export_category("Stitch · Curtain Call")
@export var seam_range: float = 26.0
@export var seam_width: float = 2.0
@export var seam_preparation: float = .65
@export var seam_speed: float = 65.0
@export var seam_damage: float = 140.0
