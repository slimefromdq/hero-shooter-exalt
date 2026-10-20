class_name StitchTuning
extends HeroTuning

@export_category("Stitch · Needlepoint / Loose Ends")
@export var needle_range: float = 45.0
@export var needle_speed: float = 65.0
@export var shears_damage: float = 48.0
@export var shears_interval: float = .32
@export var shears_range: float = 2.6
@export var shears_exit_range: float = 3.1
@export var shears_angle: float = 40.0
@export var shears_exit_angle: float = 50.0
@export var switch_grace: float = .15
@export var mark_limit: int = 3
@export var mark_duration: float = 4.0
@export var mark_damage: float = 12.0
@export_category("Stitch · Red Thread")
@export var thread_range: float = 14.0
@export var thread_duration: float = 5.0
@export var thread_leash: float = 16.0
@export var thread_break_range: float = 20.0
@export var thread_obstruction: float = .3
@export var thread_cooldown: float = 12.0
@export var pursuit_bonus: float = .2
@export_category("Stitch · Play Dead")
@export var collapse_duration: float = .25
@export var conceal_duration: float = 20.0
@export var conceal_cooldown: float = 12.0
@export var conceal_speed: float = .65
@export var detection_range: float = 5.0
@export var opening_range: float = 4.0
@export var opening_lunge: float = 1.5
@export var opening_damage: float = 15.0
@export_category("Stitch · Spoolstep")
@export var hook_range: float = 20.0
@export var hook_speed: float = 40.0
@export var reel_speed: float = 28.0
@export var hook_cooldown: float = 13.0
@export var reel_timeout: float = 1.0
@export_category("Stitch · Curtain Call")
@export var seam_range: float = 18.0
@export var seam_width: float = 1.2
@export var seam_preparation: float = .65
@export var seam_speed: float = 45.0
@export var seam_damage: float = 140.0
