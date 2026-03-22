# ============================================================
# Audio Manager — Procedural sound design
# Autoloaded as "AudioManager"
# Generates all game audio synthetically at runtime.
# ============================================================
extends Node

# ── Audio bus volumes ────────────────────────────────────────
var music_volume := 0.6
var sfx_volume := 0.8
var music_enabled := true
var sfx_enabled := true

# ── Players ──────────────────────────────────────────────────
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS := 6

# ── SFX cache ────────────────────────────────────────────────
var _sfx_cache: Dictionary = {}

# ── Music state ──────────────────────────────────────────────
var _music_playing := false


func _ready() -> void:
	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	music_player.volume_db = linear_to_db(music_volume * 0.4)
	add_child(music_player)

	# SFX player pool
	for i in range(MAX_SFX_PLAYERS):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = linear_to_db(sfx_volume)
		add_child(p)
		sfx_players.append(p)

	# Pre-generate all SFX
	_sfx_cache["build"] = _gen_build_sfx()
	_sfx_cache["evolve"] = _gen_evolve_sfx()
	_sfx_cache["gather_wood"] = _gen_gather_wood_sfx()
	_sfx_cache["gather_stone"] = _gen_gather_stone_sfx()
	_sfx_cache["gather_gold"] = _gen_gather_gold_sfx()
	_sfx_cache["wave_alert"] = _gen_wave_alert_sfx()
	_sfx_cache["hit"] = _gen_hit_sfx()
	_sfx_cache["death"] = _gen_death_sfx()
	_sfx_cache["tower_arrow"] = _gen_arrow_sfx()
	_sfx_cache["ui_click"] = _gen_click_sfx()

	# Generate and start background music
	var bgm := _gen_background_music()
	music_player.stream = bgm
	music_player.play()
	_music_playing = true
	music_player.finished.connect(_on_music_finished)


func _on_music_finished() -> void:
	if _music_playing:
		music_player.play()


# ── Public API ───────────────────────────────────────────────

func play_sfx(sfx_name: String) -> void:
	if not sfx_enabled:
		return
	var stream: AudioStream = _sfx_cache.get(sfx_name)
	if not stream:
		return
	# Find a free player
	for p: AudioStreamPlayer in sfx_players:
		if not p.playing:
			p.stream = stream
			p.volume_db = linear_to_db(sfx_volume)
			p.play()
			return
	# All busy — steal the first one
	sfx_players[0].stream = stream
	sfx_players[0].play()


func play_gather(type: String) -> void:
	match type:
		"wood": play_sfx("gather_wood")
		"stone": play_sfx("gather_stone")
		"gold": play_sfx("gather_gold")


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	if enabled:
		music_player.volume_db = linear_to_db(music_volume * 0.4)
		if not music_player.playing:
			music_player.play()
	else:
		music_player.stop()


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled


# ── Procedural Sound Generation ──────────────────────────────
# All sounds are generated as AudioStreamWAV with raw PCM data.
# We synthesize simple waveforms: sine, square, noise, etc.

const SAMPLE_RATE := 22050
const MIX_RATE := 22050


func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false

	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var s := clampf(samples[i], -1.0, 1.0)
		var v := int(s * 32767.0)
		if v < 0:
			v += 65536
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	wav.data = data
	return wav


func _sine(freq: float, t: float) -> float:
	return sin(t * freq * TAU)


func _square(freq: float, t: float) -> float:
	return 1.0 if fmod(t * freq, 1.0) < 0.5 else -1.0


func _saw(freq: float, t: float) -> float:
	return fmod(t * freq, 1.0) * 2.0 - 1.0


func _noise() -> float:
	return randf_range(-1.0, 1.0)


func _env_decay(t: float, duration: float) -> float:
	return clampf(1.0 - t / duration, 0.0, 1.0)


func _env_attack_decay(t: float, attack: float, decay_end: float) -> float:
	if t < attack:
		return clampf(t / attack, 0.0, 1.0)
	return clampf(1.0 - (t - attack) / (decay_end - attack), 0.0, 1.0)


# ── SFX Generators ───────────────────────────────────────────

func _gen_build_sfx() -> AudioStreamWAV:
	# Hammer-on-wood: short thud + resonance
	var dur := 0.35
	var samples := PackedFloat32Array()
	var count := int(dur * SAMPLE_RATE)
	samples.resize(count)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := _env_decay(t, dur)
		var s := _sine(180.0, t) * 0.5 + _sine(120.0, t) * 0.3 + _noise() * 0.15
		samples[i] = s * env * env * 0.7
	return _make_wav(samples)


func _gen_evolve_sfx() -> AudioStreamWAV:
	# Rising shimmer: ascending tones with sparkle
	var dur := 1.0
	var samples := PackedFloat32Array()
	var count := int(dur * SAMPLE_RATE)
	samples.resize(count)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := _env_attack_decay(t, 0.1, dur)
		var freq := 300.0 + t * 500.0  # rising pitch
		var s := _sine(freq, t) * 0.4 + _sine(freq * 1.5, t) * 0.2 + _sine(freq * 2.0, t) * 0.1
		# Sparkle
		if fmod(t, 0.08) < 0.02:
			s += _noise() * 0.15
		samples[i] = s * env * 0.6
	return _make_wav(samples)


func _gen_gather_wood_sfx() -> AudioStreamWAV:
	# Chop sound: sharp attack + wood thud
	var dur := 0.2
	var samples := PackedFloat32Array()
	var count := int(dur * SAMPLE_RATE)
	samples.resize(count)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := _env_decay(t, dur)
		var s := _sine(250.0, t) * 0.3 + _noise() * 0.4 * _env_decay(t, 0.05)
		s += _sine(150.0, t) * 0.3
		samples[i] = s * env * 0.6
	return _make_wav(samples)


func _gen_gather_stone_sfx() -> AudioStreamWAV:
	# Pick-on-rock: higher pitched clink
	var dur := 0.18
	var samples := PackedFloat32Array()
	var count := int(dur * SAMPLE_RATE)
	samples.resize(count)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := _env_decay(t, dur)
		var s := _sine(800.0, t) * 0.3 + _sine(1200.0, t) * 0.2 + _noise() * 0.2 * _env_decay(t, 0.03)
		samples[i] = s * env * env * 0.5
	return _make_wav(samples)


func _gen_gather_gold_sfx() -> AudioStreamWAV:
	# Sparkly coin sound: high sine with shimmering harmonics
	var dur := 0.3
	var samples := PackedFloat32Array()
	var count := int(dur * SAMPLE_RATE)
	samples.resize(count)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := _env_decay(t, dur)
		var s := _sine(1400.0, t) * 0.3 + _sine(2100.0, t) * 0.15 + _sine(700.0, t) * 0.1
		samples[i] = s * env * 0.5
	return _make_wav(samples)


func _gen_wave_alert_sfx() -> AudioStreamWAV:
	# Warning horn: low ominous tone
	var dur := 0.8
	var samples := PackedFloat32Array()
	var count := int(dur * SAMPLE_RATE)
	samples.resize(count)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := _env_attack_decay(t, 0.15, dur)
		var s := _saw(110.0, t) * 0.3 + _sine(110.0, t) * 0.3 + _sine(165.0, t) * 0.15
		samples[i] = s * env * 0.5
	return _make_wav(samples)


func _gen_hit_sfx() -> AudioStreamWAV:
	# Impact thud
	var dur := 0.15
	var samples := PackedFloat32Array()
	var count := int(dur * SAMPLE_RATE)
	samples.resize(count)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := _env_decay(t, dur)
		var s := _sine(200.0, t) * 0.4 + _noise() * 0.3 * _env_decay(t, 0.03)
		samples[i] = s * env * 0.6
	return _make_wav(samples)


func _gen_death_sfx() -> AudioStreamWAV:
	# Descending tone + thud
	var dur := 0.4
	var samples := PackedFloat32Array()
	var count := int(dur * SAMPLE_RATE)
	samples.resize(count)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := _env_decay(t, dur)
		var freq := 400.0 - t * 300.0  # falling pitch
		var s := _sine(freq, t) * 0.4 + _noise() * 0.15
		samples[i] = s * env * 0.5
	return _make_wav(samples)


func _gen_arrow_sfx() -> AudioStreamWAV:
	# Whoosh: filtered noise sweep
	var dur := 0.2
	var samples := PackedFloat32Array()
	var count := int(dur * SAMPLE_RATE)
	samples.resize(count)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := _env_attack_decay(t, 0.02, dur)
		var s := _noise() * 0.3 + _sine(600.0 + t * 800.0, t) * 0.15
		samples[i] = s * env * 0.4
	return _make_wav(samples)


func _gen_click_sfx() -> AudioStreamWAV:
	# UI click: tiny blip
	var dur := 0.06
	var samples := PackedFloat32Array()
	var count := int(dur * SAMPLE_RATE)
	samples.resize(count)
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var env := _env_decay(t, dur)
		var s := _sine(900.0, t) * 0.5
		samples[i] = s * env * 0.4
	return _make_wav(samples)


# ── Background Music Generator ───────────────────────────────
# RuneScape-inspired medieval MIDI music
# Catchy melody (recorder), plucked lute chords, walking bass, light percussion

func _pluck(freq: float, t: float, dur: float) -> float:
	## Karplus-Strong inspired plucked string (lute) timbre
	var env := _env_decay(t, dur) * _env_decay(t, dur)  # fast exponential decay
	var brightness := maxf(1.0 - t / dur, 0.0)
	var s := _sine(freq, t) * 0.5 + _sine(freq * 2.0, t) * 0.25 * brightness
	s += _sine(freq * 3.0, t) * 0.12 * brightness * brightness
	return s * env

func _flute(freq: float, t: float, dur: float) -> float:
	## Recorder/flute timbre — soft sine with gentle harmonics and breath
	var env := _env_attack_decay(t, 0.06, dur * 0.95)
	var vibrato := sin(t * 5.5) * 3.0 * minf(t / 0.2, 1.0)
	var f := freq + vibrato
	var s := _sine(f, t) * 0.55 + _sine(f * 2.0, t) * 0.15 + _sine(f * 3.0, t) * 0.05
	# Gentle breath noise
	s += _noise() * 0.015 * env
	return s * env

func _bass_tone(freq: float, t: float, dur: float) -> float:
	## Soft bass tone — like a viola da gamba
	var env := _env_attack_decay(t, 0.04, dur * 0.9)
	var s := _sine(freq, t) * 0.6 + _saw(freq, t) * 0.1 + _sine(freq * 2.0, t) * 0.15
	return s * env

func _perc_tick(t: float) -> float:
	## Short percussion tick (tambourine-like)
	var env := _env_decay(t, 0.06)
	return _noise() * env * env

func _gen_background_music() -> AudioStreamWAV:
	var bpm := 100.0
	var beat := 60.0 / bpm  # seconds per beat
	var bar := beat * 4.0   # 4/4 time
	var bars := 8           # 8 bars = ~19.2 seconds
	var dur := bar * float(bars)
	var count := int(dur * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)

	# Note frequencies (D Dorian / medieval scale)
	# D3=146.8 E3=164.8 F3=174.6 G3=196.0 A3=220.0 Bb3=233.1 C4=261.6 D4=293.7
	# D4=293.7 E4=329.6 F4=349.2 G4=392.0 A4=440.0 Bb4=466.2 C5=523.3 D5=587.3
	var N: Dictionary = {
		"D3": 146.8, "E3": 164.8, "F3": 174.6, "G3": 196.0,
		"A3": 220.0, "Bb3": 233.1, "C4": 261.6, "D4": 293.7,
		"E4": 329.6, "F4": 349.2, "G4": 392.0, "A4": 440.0,
		"Bb4": 466.2, "C5": 523.3, "D5": 587.3, "E5": 659.3,
		"D2": 73.4, "G2": 98.0, "A2": 110.0, "C3": 130.8,
		"F2": 87.3, "Bb2": 116.5,
	}

	# ── Melody (recorder) — 8 bars, each bar = 4 beats ──
	# Format: [bar, beat_offset, duration_in_beats, note_name]
	# Catchy, upbeat medieval tune
	var melody: Array = [
		# Bar 1: Opening phrase
		[0, 0.0, 0.5, "D4"], [0, 0.5, 0.5, "E4"], [0, 1.0, 1.0, "F4"],
		[0, 2.0, 0.5, "G4"], [0, 2.5, 0.5, "A4"], [0, 3.0, 1.0, "G4"],
		# Bar 2: Continuation
		[1, 0.0, 0.75, "F4"], [1, 0.75, 0.75, "E4"], [1, 1.5, 0.5, "D4"],
		[1, 2.0, 1.5, "E4"], [1, 3.5, 0.5, "D4"],
		# Bar 3: Rising phrase
		[2, 0.0, 1.0, "A4"], [2, 1.0, 0.5, "G4"], [2, 1.5, 0.5, "A4"],
		[2, 2.0, 0.5, "Bb4"], [2, 2.5, 0.5, "A4"], [2, 3.0, 1.0, "G4"],
		# Bar 4: Resolution
		[3, 0.0, 0.5, "F4"], [3, 0.5, 0.5, "G4"], [3, 1.0, 1.0, "A4"],
		[3, 2.0, 2.0, "D4"],
		# Bar 5: Second phrase (variation)
		[4, 0.0, 0.5, "D5"], [4, 0.5, 0.5, "C5"], [4, 1.0, 1.0, "Bb4"],
		[4, 2.0, 0.5, "A4"], [4, 2.5, 0.5, "G4"], [4, 3.0, 1.0, "A4"],
		# Bar 6: Answering phrase
		[5, 0.0, 0.75, "G4"], [5, 0.75, 0.75, "F4"], [5, 1.5, 0.5, "E4"],
		[5, 2.0, 1.0, "F4"], [5, 3.0, 0.5, "E4"], [5, 3.5, 0.5, "D4"],
		# Bar 7: Climax
		[6, 0.0, 0.5, "D4"], [6, 0.5, 0.5, "F4"], [6, 1.0, 0.5, "A4"],
		[6, 1.5, 0.5, "D5"], [6, 2.0, 1.5, "C5"], [6, 3.5, 0.5, "Bb4"],
		# Bar 8: Ending (loops back nicely)
		[7, 0.0, 1.0, "A4"], [7, 1.0, 0.5, "G4"], [7, 1.5, 0.5, "F4"],
		[7, 2.0, 1.0, "E4"], [7, 3.0, 1.0, "D4"],
	]

	# ── Chord progression (lute arpeggios) ──
	# Dm | Am | Bb | F | Dm | Gm | Dm | A (Dm)
	var chord_roots: Array = [
		[N["D3"], N["F3"], N["A3"]],   # Dm
		[N["A3"], N["C4"], N["E4"]],   # Am
		[N["Bb3"], N["D4"], N["F4"]],  # Bb
		[N["F3"], N["A3"], N["C4"]],   # F
		[N["D3"], N["F3"], N["A3"]],   # Dm
		[N["G3"], N["Bb3"], N["D4"]],  # Gm
		[N["D3"], N["F3"], N["A3"]],   # Dm
		[N["A3"], N["C4"], N["E4"]],   # Am → back to Dm
	]

	# ── Bass line ──
	var bass_notes: Array = [
		N["D2"], N["A2"], N["Bb2"], N["F2"],
		N["D2"], N["G2"], N["D2"], N["A2"],
	]

	# Render all layers
	for i in range(count):
		var t := float(i) / SAMPLE_RATE
		var current_bar := int(t / bar)
		if current_bar >= bars:
			current_bar = bars - 1
		var bar_t := fmod(t, bar)
		var beat_in_bar := bar_t / beat
		var s := 0.0

		# ─── Layer 1: Melody (recorder/flute) ───
		for note: Array in melody:
			var note_bar: int = int(note[0])
			var note_beat: float = float(note[1])
			var note_dur_beats: float = float(note[2])
			var note_name: String = note[3]
			var note_start := float(note_bar) * bar + note_beat * beat
			var note_end := note_start + note_dur_beats * beat
			if t >= note_start and t < note_end:
				var nt := t - note_start
				var nd := note_dur_beats * beat
				s += _flute(N[note_name], nt, nd) * 0.30

		# ─── Layer 2: Lute arpeggios (plucked chords) ───
		var chord: Array = chord_roots[current_bar]
		# Arpeggio pattern: root, third, fifth, third — on 8th notes
		var arp_pattern: Array = [0, 1, 2, 1, 0, 2, 1, 2]  # indices into chord
		var eighth := beat * 0.5
		var arp_idx := int(bar_t / eighth) % 8
		var arp_t := fmod(bar_t, eighth)
		var arp_freq: float = chord[int(arp_pattern[arp_idx])]
		s += _pluck(arp_freq, arp_t, eighth * 1.8) * 0.14

		# ─── Layer 3: Bass ───
		var bass_freq: float = bass_notes[current_bar]
		# Bass plays on beats 1 and 3
		var bass_beat := int(beat_in_bar)
		if bass_beat == 0 or bass_beat == 2:
			var bass_t := fmod(bar_t, beat * 2.0)
			s += _bass_tone(bass_freq, bass_t, beat * 1.8) * 0.18
		# Walking note on beat 4
		if bass_beat == 3:
			var walk_freq := bass_freq * 1.25  # up a third for movement
			var walk_t := bar_t - beat * 3.0
			s += _bass_tone(walk_freq, walk_t, beat * 0.9) * 0.12

		# ─── Layer 4: Light percussion ───
		# Soft tambourine on every beat, accent on 1 and 3
		var perc_t := fmod(bar_t, beat)
		var perc_vol := 0.08
		if bass_beat == 0 or bass_beat == 2:
			perc_vol = 0.12
		if perc_t < 0.06:
			s += _perc_tick(perc_t) * perc_vol
		# Off-beat shaker (very subtle)
		var offbeat_t := fmod(bar_t + beat * 0.5, beat)
		if offbeat_t < 0.04:
			s += _perc_tick(offbeat_t) * 0.04

		samples[i] = clampf(s * 0.65, -1.0, 1.0)

	var wav := _make_wav(samples)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = count
	return wav
