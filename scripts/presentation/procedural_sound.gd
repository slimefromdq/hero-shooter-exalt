class_name ProceduralSound
extends AudioStreamPlayer

static var guard_wave: AudioStreamWAV

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
	volume_db = -2.0
	if DisplayServer.get_name() != "headless":
		play()

func _exit_tree() -> void:
	stop()
	stream = null

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
	volume_db = -10.0
	play()
