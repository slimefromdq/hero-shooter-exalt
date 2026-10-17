class_name MatchFeedback
extends Node

## Match-time windows stop with the paused session. Only final blows build streaks.
const MULTI_WINDOW: float = 4.0
const FEED_SECONDS: float = 7.0
var player: HeroActor
var feed: Array[Dictionary] = []
var streaks: Dictionary = {}
var chains: Dictionary = {}
var clock: float = 0.0
var banner: String = ""
var banner_time: float = 0.0
var kills: int = 0
var assists: int = 0
var voices: Array[AudioStreamPlayer] = []
var cue_queue: Array[Dictionary] = []
var cue_delay: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for index: int in 3:
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -9.0
		add_child(voice)
		voices.append(voice)

func _process(delta: float) -> void:
	clock += delta
	banner_time = maxf(0.0, banner_time - delta)
	while not feed.is_empty() and clock - float(feed[0].time) >= FEED_SECONDS:
		feed.pop_front()
	cue_delay -= delta
	if cue_delay <= 0.0 and not cue_queue.is_empty():
		var cue: Dictionary = cue_queue.pop_front()
		var voice: AudioStreamPlayer = voices[int(cue.channel)]
		voice.stream = ProceduralSound.reward_wave(str(cue.kind), int(cue.level))
		if DisplayServer.get_name() != "headless": voice.play()
		cue_delay = .22 if cue.kind == "kill" else .5

func reset() -> void:
	feed.clear()
	streaks.clear()
	chains.clear()
	cue_queue.clear()
	clock = 0.0
	banner = ""
	banner_time = 0.0
	kills = 0
	assists = 0
	cue_delay = 0.0
	for voice: AudioStreamPlayer in voices: voice.stop()

static func multi_name(count: int) -> String:
	var names: Array[String] = ["", "ELIMINATION", "DOUBLE KILL", "TRIPLE KILL", "QUADRUPLE KILL", "QUINTUPLE KILL", "SEXTUPLE KILL"]
	return names[count] if count < names.size() else "%d KILLS IN A ROW" % count

static func streak_name(count: int) -> String:
	if count >= 10: return "UNSTOPPABLE / %d KILL STREAK" % count
	if count >= 7: return "DOMINATING / %d KILL STREAK" % count
	return "KILLING SPREE / %d KILL STREAK" % count

func queue_cue(kind: String, level: int, channel: int) -> void:
	# Keep a burst responsive; older pending celebrations yield to the newest tier.
	if kind != "kill":
		for index: int in range(cue_queue.size() - 1, -1, -1):
			if cue_queue[index].kind == kind: cue_queue.remove_at(index)
	if cue_queue.size() < 8:
		cue_queue.append({"kind": kind, "level": mini(level, 12), "channel": channel})

func on_elimination(killer: HeroActor, victim: HeroActor, helpers: Array[HeroActor], ability: String) -> void:
	streaks.erase(victim.get_instance_id())
	chains.erase(victim.get_instance_id())
	var helper_names: Array[String] = []
	for helper: HeroActor in helpers: helper_names.append(helper.actor_id.to_upper())
	feed.append({"time": clock, "killer": killer.actor_id.to_upper() if is_instance_valid(killer) else "WORLD",
		"killer_team": killer.team if is_instance_valid(killer) else -1, "victim": victim.actor_id.to_upper(),
		"victim_team": victim.team, "assistants": ", ".join(helper_names), "ability": ability.to_upper(),
		"personal": killer == player or victim == player or player in helpers})
	if feed.size() > 5: feed.pop_front()
	if not is_instance_valid(killer): return
	var key: int = killer.get_instance_id()
	var streak: int = int(streaks.get(key, 0)) + 1
	streaks[key] = streak
	var chain: Dictionary = chains.get(key, {"time": -INF, "count": 0})
	var count: int = int(chain.count) + 1 if clock - float(chain.time) <= MULTI_WINDOW else 1
	chains[key] = {"time": clock, "count": count}
	if killer == player:
		kills += 1
		queue_cue("kill", streak, 0)
		banner = multi_name(count) + " / " + victim.actor_id.to_upper()
		if count >= 2: queue_cue("multi", count, 1)
		if streak >= 3:
			banner += "\n" + streak_name(streak)
			queue_cue("streak", streak, 2)
		banner_time = 3.0
	elif player in helpers:
		assists += 1
		queue_cue("assist", 1, 0)
		if banner_time <= 0.0:
			banner = "ASSIST / " + victim.actor_id.to_upper()
			banner_time = 2.0
