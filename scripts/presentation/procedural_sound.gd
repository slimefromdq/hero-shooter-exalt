class_name ProceduralSound
extends AudioStreamPlayer

static var guard_wave: AudioStreamWAV
static var slayer_waves: Dictionary = {}
var spatial_owner: Node3D
static var reward_waves: Dictionary = {}

static func reward_wave(kind: String, level: int) -> AudioStreamWAV:
	level = clampi(level, 1, 12)
	var key: String = "%s_%d" % [kind, level]
	if reward_waves.has(key): return reward_waves[key]
	var notes: int = 1 if kind in ["kill", "assist"] else mini(6, level)
	var step: float = .075 if kind == "multi" else .105
	var seconds: float = .22 + step * (notes - 1)
	var base: float = 440.0 * pow(2.0, float(level - 1) / 24.0)
	if kind == "assist": base = 330.0
	if kind == "streak": base *= .75
	if kind == "multi": base *= 1.5
	var rate: int = 22050
	var bytes := PackedByteArray()
	bytes.resize(int(seconds * rate) * 2)
	for index: int in bytes.size() / 2:
		var time: float = float(index) / rate
		var sample: float = 0.0
		for note: int in notes:
			var age: float = time - note * step
			if age < 0.0 or age > .22: continue
			var hz: float = base * pow(2.0, float(note * 3) / 12.0)
			var envelope: float = minf(1.0, age / .004) * exp(-age * 22.0) * clampf((.22 - age) / .02, 0, 1)
			sample += (sin(TAU * hz * age) + .22 * sin(TAU * hz * 2 * age)) * envelope * .42
		bytes.encode_s16(index * 2, int(clampf(sample, -.9, .9) * 32767))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = rate
	wave.data = bytes
	reward_waves[key] = wave
	return wave

func distance_gain() -> float:
	if not is_instance_valid(spatial_owner):
		return 0.0
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return 0.0
	var distance: float = camera.global_position.distance_to(spatial_owner.global_position)
	return -minf(45.0, maxf(0.0, distance - 6.0) * 1.1)

# A sharp contact transient, low body hit and decaying inharmonic metal partials.
# Cached PCM uses local noise so presentation never changes gameplay's random seed.
static func guard_clang() -> AudioStreamWAV:
	if guard_wave != null:
		return guard_wave
	var rate: int = 44100
	var frames: int = int(.36 * rate)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 7419
	for index: int in frames:
		var time: float = float(index) / rate
		var transient: float = noise.randf_range(-1,1) * .3 * exp(-time * 150)
		var thump: float = sin(TAU * 135 * time) * .23 * exp(-time * 35)
		var metal: float = (sin(TAU * 740 * time) * .23 + sin(TAU * 1193 * time) * .15 + sin(TAU * 1927 * time) * .1 + sin(TAU * 3137 * time) * .065) * exp(-time * 17)
		var tail: float = clampf((.36 - time) / .025,0,1)
		var sample: float = clampf((transient + thump + metal) * tail, -.95, .95)
		bytes.encode_s16(index * 2, int(sample * 32767))
	guard_wave = AudioStreamWAV.new()
	guard_wave.format = AudioStreamWAV.FORMAT_16_BITS
	guard_wave.mix_rate = rate
	guard_wave.data = bytes
	return guard_wave

func play_guard_clang() -> void:
	stream = guard_clang()
	volume_db = -2.0 + distance_gain()
	if DisplayServer.get_name() != "headless":
		play()

func _exit_tree() -> void:
	stop()
	stream = null

func play_slayer(cue: String) -> void:
	stop()
	stream = null
	stream = slayer_wave(cue)
	volume_db = -5.0 + distance_gain()
	if DisplayServer.get_name() != "headless": play()

static func slayer_wave(cue: String) -> AudioStreamWAV:
	if slayer_waves.has(cue): return slayer_waves[cue]
	var seconds: float = .28 if cue == "shotgun" else (.45 if cue.begins_with("axe") else .16)
	var hz: float = 85.0 if cue in ["shotgun","boot_hit","axe_hit"] else (460.0 if cue in ["shell","knife_hit","snare_hit"] else 210.0)
	var rate: int = 22050
	var frames: int = int(seconds * rate)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = cue.hash()
	for index: int in frames:
		var time: float = float(index) / rate
		var envelope: float = exp(-time * (17.0 if cue == "shotgun" else 12.0)) * minf(1.0,(seconds - time) / .015)
		var transient: float = noise.randf_range(-1,1) * (.55 if cue == "shotgun" else .22) * exp(-time * 38)
		var sample: float = (sin(TAU * hz * time) * .5 + sin(TAU * hz * 2.7 * time) * .15) * envelope + transient
		bytes.encode_s16(index * 2,int(clampf(sample,-.95,.95) * 32767))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = rate
	wave.data = bytes
	slayer_waves[cue] = wave
	return wave

# Short original synth cues. Finite WAV streams avoid an always-running generator.
func play_tone(hz: float, seconds: float, loudness: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var rate: int = 22050
	var frames: int = int(seconds * rate)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var phase: float = 0.0
	for index: int in frames:
		var progress: float = float(index) / frames
		phase += hz * (1.0 - progress * 0.55) / rate
		var sample: float = (sin(phase * TAU) * 0.7 + randf_range(-0.3,0.3)) * loudness * (1.0 - progress)
		bytes.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = rate
	wave.data = bytes
	stream = wave
	volume_db = -10.0 + distance_gain()
	play()
