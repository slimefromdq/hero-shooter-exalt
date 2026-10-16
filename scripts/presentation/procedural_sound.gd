class_name ProceduralSound
extends AudioStreamPlayer

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
