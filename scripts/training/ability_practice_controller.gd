class_name AbilityPracticeController
extends BotController
## One real kit input sequence per request, never synthetic damage.
var ability: int = 0
var age: float = 0
var requested: bool = false
var sent: bool = false
var ally: HeroActor
var cast_count: int = 0
var outcome: String = "Ready"
var secondary_sent: bool = false
var observed_effect: bool = false
const LABELS: Dictionary = {
	"nimbus":["Rifle / damage","Shoulder aim / aim only","Hover / movement","Deflect / defense","Pocket Bomb / damage","Final Notice / damage"],
	"slayer":["Sweeper / damage","Shoulder aim / aim only","Silver Knives / damage + bleed","Boot Rush / movement + damage","Snare / trap","Heads Will Roll / damage"],
	"marshal":["Cannon / damage","Shield / defense","Forward March / movement + damage","Rally / ally overhealth","Orbital Barrage / area damage","Marshal's Verdict / movement + damage"],
	"doctor":["Sidearm / damage","Healing beam / ally healing","House Call / ally movement","Ward Round / healing + defense","Prescription / cleanse + healing","Exemplary Condition / ally buff"],
	"huddle":["Seeds / damage","Regroup / self healing","Scatterbound / movement","We've Got You / ally shield","Personal Space / push","Nobody Gets Squished / movement + push"],
	"relay":["Spirit arrow / damage","Charged volley / damage","Omen / enemy mark","Guiding Wing / defense","Guiding Spirit / ally healing","Murmuration / healing + piercing"],
	"dynamo":["Minigun / damage","Prespin / preparation","Stormcharge / weapon buff","Raise the Line / terrain defense","Lodestone / pull","Storm Dominion / area damage"],
	"wisp":["Pistols / damage + marks","Explosive burst / damage","Phantom Dodge / movement","Vanishing Act / movement + defense","Majestic Leap / movement + dive","Grand Heist / suction + damage"],
	"samson":["Deposition / damage","Evidence / passive, earned by Q and E","Intervene / ally rescue","Cross-examination / stun + silence","Cease and Desist / area control","Roach Court / ally defense"],
	"stitch":["Needles or shears / damage","Hidden opening / conceal then lunge","Spoolstep / terrain hook","Play Dead / concealment","Red Thread / enemy tether","Curtain Call / piercing damage"]}
static func friendly_test(hero: String, slot: int) -> bool:
	return (hero == "doctor" and slot in [1,2,3,4,5]) or (hero == "huddle" and slot == 3) or (hero == "relay" and slot in [3,4,5]) or (hero == "marshal" and slot == 3) or (hero == "samson" and slot in [2,5])
func begin(slot: int) -> void:
	ability = slot
	age = 0
	sent = false
	secondary_sent = false
	requested = true
	observed_effect = false
	cast_count = 0
	outcome = "Telegraph / cast in 0.8s"
func gather_intent(delta: float) -> CombatIntent:
	var input := CombatIntent.new()
	if frozen or not actor.alive or not requested or not is_instance_valid(target): return input
	age += delta
	input.aim_origin = actor.body_point(1.4)
	var hero: String = actor.tuning.hero_id
	var recipient: HeroActor = ally if friendly_test(hero,ability) and is_instance_valid(ally) else target
	input.aim = (recipient.body_point(1.0)-input.aim_origin).normalized()
	# Placement spells target ground at the participant; hooks target the lab wall.
	if (hero == "dynamo" and ability in [3,4,5]) or (hero == "samson" and ability in [4,5]):
		var ground: Vector3 = recipient.global_position
		if hero == "samson" and ability == 5: ground += Vector3(4,0,-3)
		input.aim = (ground-input.aim_origin).normalized()
	if hero == "stitch" and ability == 2:
		input.aim = (home+Vector3(0,4,-10)-input.aim_origin).normalized()
	if hero == "samson" and ability == 1:
		outcome = "Passive: successful Intervene / Cross-examination earns Evidence"
		requested = false
		return input
	if actor.state == "marshal_shield": observed_effect = true
	if age < .8: return input
	var first: bool = not sent
	if first:
		sent = true
		outcome = "Executing real kit sequence"
		actor.kit.refill()
		TrainingResources.restore(actor)
		if hero == "huddle" and ability == 1: actor.health = actor.effective_max_health()*.45
		if hero == "samson" and ability == 4: actor.kit.evidence = 2
	if ability == 0:
		input.primary = age < 2.8
		input.primary_held = age < 2.8
	elif ability == 1:
		input.secondary_pressed = first
		input.secondary_held = age < 2.5
		input.aim_held = age < 2.5
		if hero == "wisp": actor.kit.shells = actor.tuning.shell_limit
		if hero == "stitch":
			input.secondary_pressed = false
			input.secondary_held = false
			input.deflect = first
			if age > 1.8 and not secondary_sent:
				input.primary = true
				secondary_sent = true
	elif first:
		input.set(["hover","deflect","bomb","ultimate"][ability-2],true)
	if hero == "relay" and ability == 3:
		input.deflect = false
		input.bomb = first
		if age > 2 and not secondary_sent:
			input.deflect = true
			secondary_sent = true
	if hero == "nimbus" and ability == 5 and age > 2:
		input.primary = true
	if hero == "dynamo" and ability == 3 and age > 1.1 and actor.kit.previewing:
		input.primary = true
	if hero == "wisp" and ability == 4 and age > 1.6 and not secondary_sent:
		input.bomb = true
		secondary_sent = true
	if hero == "dynamo" and ability == 2 and age > 1.0 and age < 3.5:
		input.primary = true
		input.primary_held = true
	if age > 7:
		requested = false
		if cast_count == 0 and not observed_effect and ability not in [1,2]: outcome = "No cast: check range / placement / target prerequisites"
		else: outcome = "Complete / %d kit events" % cast_count
	return input
