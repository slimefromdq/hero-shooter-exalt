class_name SlayerAudioProfile
extends Resource
## Optional licensed/original replacement assets. Empty slots use cached original synthesis.
@export var blast: AudioStream
@export var mechanism: AudioStream
@export var target_impact: AudioStream
@export var surface_impact: AudioStream
@export_range(-30, 0) var blast_db: float = -7.0
@export_range(-30, 0) var mechanism_db: float = -14.0
@export_range(-30, 0) var impact_db: float = -12.0

@export var ability_cues: Dictionary[String, AudioStream] = {}
