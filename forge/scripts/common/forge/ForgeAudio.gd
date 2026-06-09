extends Node
class_name ForgeAudio
# AUDIO du FORGE : SFX synthétisés (carré/bruit/sinus) + boucle musicale.
# Autonome : ForgeApp l'instancie comme enfant et appelle play()/toggle_music().

const SFX_DB := -16.0   # atténuation globale des effets sonores

var sfx := {}
var music_on := false
var music_player: AudioStreamPlayer


func _ready() -> void:
	sfx["jump"] = _mk_player(_tone([520.0, 760.0], 0.10, 0.35, "square"))
	sfx["coin"] = _mk_player(_tone([900.0, 1300.0], 0.09, 0.30, "square"))
	sfx["death"] = _mk_player(_tone([400.0, 120.0], 0.35, 0.40, "square"))
	sfx["win"] = _mk_player(_tone([660.0, 880.0, 1180.0], 0.40, 0.35, "square"))
	sfx["spring"] = _mk_player(_tone([300.0, 1000.0], 0.16, 0.40, "square"))
	sfx["break"] = _mk_player(_tone([220.0, 90.0], 0.12, 0.35, "noise"))
	sfx["stomp"] = _mk_player(_tone([700.0, 300.0], 0.10, 0.35, "square"))
	sfx["key"] = _mk_player(_tone([800.0, 1200.0, 1000.0], 0.16, 0.30, "square"))
	music_player = AudioStreamPlayer.new()
	music_player.stream = _music_loop()
	music_player.volume_db = -14.0
	add_child(music_player)


func play(sname: String) -> void:
	if sfx.has(sname): sfx[sname].play()


func toggle_music() -> bool:
	music_on = not music_on
	if music_on: music_player.play()
	else: music_player.stop()
	return music_on


func _mk_player(stream: AudioStreamWAV) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = SFX_DB
	add_child(p)
	return p


func _tone(freqs: Array, dur: float, vol := 0.4, kind := "square") -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var prog := float(i) / n
		var f: float = freqs[clampi(int(prog * freqs.size()), 0, freqs.size() - 1)]
		ph += f / rate
		var s: float
		if kind == "square": s = 1.0 if fmod(ph, 1.0) < 0.5 else -1.0
		elif kind == "noise": s = randf() * 2.0 - 1.0
		else: s = sin(ph * TAU)
		var env := 1.0 - prog
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func _music_loop() -> AudioStreamWAV:
	var rate := 22050
	var notes := [392.0, 523.0, 392.0, 659.0]
	var nlen := 0.4
	var n := int(rate * nlen * notes.size())
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		var ni := int(t / nlen) % notes.size()
		ph += notes[ni] / rate
		var s := sin(ph * TAU) * 0.5 + sin(ph * TAU * 0.5) * 0.3
		data.encode_s16(i * 2, int(clampf(s * 0.5, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w
