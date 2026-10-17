class_name HeroRoster
extends RefCounted

const IDS: Array[String] = ["nimbus", "slayer", "marshal", "doctor", "huddle"]
static var selected: String = initial_selection()

static func initial_selection() -> String:
	for id: String in IDS:
		if "--hero=" + id in OS.get_cmdline_user_args(): return id
	return "nimbus"

static func tuning_for(id: String) -> HeroTuning:
	return load("res://resources/%s.tres" % (id if id in IDS else "nimbus")).duplicate() as HeroTuning

static func kit_for(id: String) -> HeroKit:
	match id:
		"slayer": return SlayerKit.new()
		"marshal": return MarshalKit.new()
		"doctor": return DoctorKit.new()
		"huddle": return HuddleKit.new()
	return NimbusKit.new()

static func team_hero(slot: int, player_hero: String) -> String:
	var composition: Array[String] = ["marshal","huddle","doctor","nimbus","slayer","slayer"]
	var player_slot: int = maxi(0,composition.find(player_hero))
	var first: String = composition[0]
	composition[0] = composition[player_slot]
	composition[player_slot] = first
	return composition[slot]

static func bot_role(slot: int, player_hero: String) -> String:
	var hero: String = team_hero(slot,player_hero)
	if hero in ["marshal","doctor"]: return "frontline"
	if hero == "huddle": return "flank_left"
	# Prefer Nimbus; when Nimbus is the player, a Slayer covers the same route.
	var runner: int = -1
	for candidate: int in range(1,6):
		if team_hero(candidate,player_hero) == "nimbus":
			runner = candidate
			break
	if runner < 0:
		for candidate: int in range(1,6):
			if team_hero(candidate,player_hero) == "slayer":
				runner = candidate
				break
	if slot == runner: return "frontline_subway"
	return ["frontline","frontline","frontline","flank_left","flank_right","high_ground"][slot]
