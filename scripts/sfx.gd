extends Node
## Autoload "Sfx": pooled one-shot sounds + looping music with muffle filter.

const SFX_NAMES := [
	"shoot", "hit", "kill", "kill_big", "gem", "coin", "levelup", "chest", "evolve", "dash", "hurt",
	"boss_roar", "explosion", "zap", "swish", "vuvu", "mud", "tweet", "ui_click", "ui_hover", "gameover",
	"win", "heal", "dodge", "magnet", "warning", "pop", "stink", "thud", "reroll", "slot", "milestone",
]
const MUSIC_NAMES := ["menu", "battle", "boss"]
const POOL := 18

var players: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var music_players: Array[AudioStreamPlayer] = []
var music_streams: Dictionary = {}
var cur_music := ""
var last_ms: Dictionary = {}
var next_idx := 0
var lp_sfx := 0
var lp_music := 0
var _fade: Tween

const MIN_GAP_MS := {"hit": 45, "kill": 30, "gem": 20, "zap": 60, "pop": 25, "swish": 80, "tweet": 90, "stink": 120, "thud": 70, "coin": 40}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		add_child(m)
		music_players.append(m)
	for n in SFX_NAMES:
		var path := "res://audio/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for n in MUSIC_NAMES:
		var path := "res://audio/music/%s.wav" % n
		if ResourceLoader.exists(path):
			var ms: AudioStreamWAV = load(path)
			ms.loop_mode = AudioStreamWAV.LOOP_FORWARD
			ms.loop_begin = 0
			ms.loop_end = int(round(ms.get_length() * ms.mix_rate))
			music_streams[n] = ms
	apply_volumes()

func _make_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
			var lp := AudioEffectLowPassFilter.new()
			lp.cutoff_hz = 900.0
			AudioServer.add_bus_effect(idx, lp)
			AudioServer.set_bus_effect_enabled(idx, 0, false)
	lp_sfx = AudioServer.get_bus_index("SFX")
	lp_music = AudioServer.get_bus_index("Music")

func apply_volumes() -> void:
	var s: Dictionary = G.data["settings"]
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(s["master"]))))
	AudioServer.set_bus_volume_db(lp_music, linear_to_db(maxf(0.0001, float(s["music"]))))
	AudioServer.set_bus_volume_db(lp_sfx, linear_to_db(maxf(0.0001, float(s["sfx"]))))

func muffle(on: bool) -> void:
	if lp_sfx < 0:
		return
	AudioServer.set_bus_effect_enabled(lp_music, 0, on)

func play(name: String, vol_db: float = 0.0, pitch: float = 1.0, jitter: float = 0.06) -> void:
	if not streams.has(name):
		return
	var now := Time.get_ticks_msec()
	var gap: int = MIN_GAP_MS.get(name, 0)
	if gap > 0 and now - int(last_ms.get(name, -9999)) < gap:
		return
	last_ms[name] = now
	var p := _free_player()
	p.stream = streams[name]
	p.volume_db = vol_db
	p.pitch_scale = maxf(0.1, pitch * (1.0 + randf_range(-jitter, jitter)))
	p.play()

func _free_player() -> AudioStreamPlayer:
	for i in POOL:
		var p := players[(next_idx + i) % POOL]
		if not p.playing:
			next_idx = (next_idx + i + 1) % POOL
			return p
	var q := players[next_idx]
	next_idx = (next_idx + 1) % POOL
	return q

func music(name: String, fade: float = 0.8) -> void:
	if name == cur_music:
		return
	cur_music = name
	if not music_streams.has(name):
		for m in music_players:
			m.stop()
		return
	var old := music_players[0]
	var nw := music_players[1]
	music_players[0] = nw
	music_players[1] = old
	nw.stream = music_streams[name]
	nw.volume_db = -40.0
	nw.play()
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(nw, "volume_db", 0.0, fade)
	if old.playing:
		_fade.tween_property(old, "volume_db", -40.0, fade)
		_fade.chain().tween_callback(old.stop)

func stop_music(fade: float = 0.5) -> void:
	cur_music = ""
	for m in music_players:
		if m.playing:
			var t := create_tween()
			t.tween_property(m, "volume_db", -40.0, fade)
			t.tween_callback(m.stop)
