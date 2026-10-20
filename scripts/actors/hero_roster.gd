class_name HeroRoster
extends RefCounted

const IDS: Array[String] = ["nimbus", "slayer", "marshal", "doctor", "huddle", "relay", "dynamo", "wisp", "samson", "stitch"]
const ROLES: Dictionary = {"nimbus":"dps","slayer":"dps","marshal":"tank","doctor":"support","huddle":"tank","relay":"support","dynamo":"tank","wisp":"dps","samson":"support","stitch":"dps"}
static var composition_seed: int = 76
static var selected: String = initial_selection()
static var direct_entry_pending: bool = OS.get_cmdline_user_args().has("--direct")

static func consume_direct_entry() -> bool:
	var requested: bool = direct_entry_pending
	direct_entry_pending = false
	return requested

static func initial_selection() -> String:
	for id: String in IDS:
		if "--hero=" + id in OS.get_cmdline_user_args(): return id
	return "nimbus"

static func tuning_for(id: String) -> HeroTuning:
	return load("res://resources/%s.tres" % (id if id in IDS else "nimbus")).duplicate() as HeroTuning

static func kit_for(id: String) -> HeroKit:
	match id:
		"stitch": return StitchKit.new()
		"slayer": return SlayerKit.new()
		"marshal": return MarshalKit.new()
		"doctor": return DoctorKit.new()
		"huddle": return HuddleKit.new()
		"relay": return RelayKit.new()
		"dynamo": return DynamoKit.new()
		"wisp": return WispKit.new()
		"samson": return SamsonKit.new()
	return NimbusKit.new()

static func team_hero(slot: int, player_hero: String) -> String:
	var composition: Array[String] = composition_for(player_hero)
	return composition[clampi(slot,0,5)]

static func role_for(id: String) -> String:
	return str(ROLES.get(id,"dps"))

static func composition_for(player_hero: String, seed_value: int = -1) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = composition_seed if seed_value < 0 else seed_value
	var composition: Array[String] = []
	for role: String in ["tank","support","dps"]:
		var pool: Array[String] = []
		for id: String in IDS:
			if role_for(id) == role: pool.append(id)
		# Seeded Fisher-Yates; no changes to the global combat RNG.
		for index: int in range(pool.size()-1,0,-1):
			var other: int = rng.randi_range(0,index)
			var held: String = pool[index]
			pool[index] = pool[other]
			pool[other] = held
		if role_for(player_hero) == role and player_hero not in pool.slice(0,2): pool[0] = player_hero
		composition.append_array(pool.slice(0,2))
	var player_slot: int = maxi(0,composition.find(player_hero))
	var first: String = composition[0]
	composition[0] = composition[player_slot]
	composition[player_slot] = first
	return composition

static func bot_role(slot: int, player_hero: String) -> String:
	var hero: String = team_hero(slot,player_hero)
	var runner: int = -1
	for candidate: int in range(1,6):
		if role_for(team_hero(candidate,player_hero)) == "dps":
			runner = candidate
			break
	if slot == runner: return "frontline_subway"
	var high: int = -1
	for candidate: int in range(1,6):
		if candidate != runner and role_for(team_hero(candidate,player_hero)) == "dps":
			high = candidate
			break
	if high < 0:
		for preferred: String in ["huddle","relay","dynamo"]:
			for candidate: int in range(1,6):
				if team_hero(candidate,player_hero) == preferred:
					high = candidate
					break
			if high >= 0: break
	if slot == high: return "high_ground"
	if hero in ["marshal","dynamo","doctor","relay","samson"]: return "frontline"
	if hero == "huddle": return "flank_left"
	return ["frontline","frontline","frontline","flank_left","flank_right","high_ground"][slot]
