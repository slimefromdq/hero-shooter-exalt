extends AudioStreamPlayer
## Original, quiet city bed: filtered storm wind and distant electric transit.
## The finite cached waveform loops without a continuously running audio generator.

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var rate: int = 16000
	var seconds: int = 24
	var frames: int = rate * seconds
	var pcm := PackedByteArray()
	pcm.resize(frames * 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 34176
	var filtered: float = 0.0
	for index: int in frames:
		var time: float = float(index) / rate
		filtered = lerpf(filtered, rng.randf_range(-1, 1), .035)
		var loop_envelope: float = minf(1, minf(time * 2, (seconds - time) * 2))
		var gust: float = .5 + .5 * sin(time * TAU / 12.0)
		var wind: float = filtered * (.38 + gust * .22)
		var transit: float = pow(maxf(0, sin((time - 4) * PI / 16.0)), 8) * .035
		var hum: float = sin(time * TAU * 76.0) + .3 * sin(time * TAU * 152.0)
		var left: float = (wind + transit * hum) * loop_envelope
		var right: float = (wind * .87 + transit * hum * (.65 + .25 * sin(time * .4))) * loop_envelope
		pcm.encode_s16(index * 4, int(clampf(left, -1, 1) * 32767))
		pcm.encode_s16(index * 4 + 2, int(clampf(right, -1, 1) * 32767))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = rate
	wave.stereo = true
	wave.data = pcm
	wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wave.loop_begin = 0
	wave.loop_end = frames
	stream = wave
	volume_db = -24
	play()

func _exit_tree() -> void:
	stop()
	stream = null
