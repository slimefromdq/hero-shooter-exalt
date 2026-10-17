class_name HeroRoster
extends RefCounted

static var selected: String = "slayer" if "--hero=slayer" in OS.get_cmdline_user_args() else "nimbus"

static func tuning_for(id: String) -> HeroTuning:
	return load("res://resources/slayer.tres" if id == "slayer" else "res://resources/nimbus.tres").duplicate() as HeroTuning

static func kit_for(id: String) -> HeroKit:
	return SlayerKit.new() if id == "slayer" else NimbusKit.new()
