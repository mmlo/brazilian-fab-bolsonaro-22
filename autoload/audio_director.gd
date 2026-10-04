extends Node
## Audio director: pooled, throttled SFX cues plus one BGM channel that survives
## scene changes. Cue gains are the absolute base gains for the synthesized set.
const BrowserBgmPlayer = preload("res://scripts/manus/browser_bgm_player.gd")

const MUSIC := {
	"stage": preload("res://assets/audio/music/stage.ogg"),
	"boss": preload("res://assets/audio/music/boss.ogg"),
}
const MUSIC_BASE_DB := 0.0 # template -6 dB + 9.54 dB showcase gain, guarded to <= 0 dB

# cue: [stream, gain_db, voices, min_interval_s, pitch_jitter]
var _cues := {
	"shoot": [preload("res://assets/audio/sfx/shoot.ogg"), -17.0, 2, 0.06, 0.05],
	"enemy_hit": [preload("res://assets/audio/sfx/enemy_hit.ogg"), -9.0, 3, 0.045, 0.12],
	"explode_small": [preload("res://assets/audio/sfx/explode_small.ogg"), -4.0, 4, 0.03, 0.12],
	"explode_big": [preload("res://assets/audio/sfx/explode_big.ogg"), -1.0, 2, 0.1, 0.05],
	"graze": [preload("res://assets/audio/sfx/graze.ogg"), -9.0, 3, 0.035, 0.1],
	"pickup": [preload("res://assets/audio/sfx/pickup.ogg"), -12.0, 3, 0.03, 0.06],
	"energy_full": [preload("res://assets/audio/sfx/energy_full.ogg"), -3.0, 1, 0.5, 0.0],
	"bomb": [preload("res://assets/audio/sfx/bomb.ogg"), 0.0, 1, 0.2, 0.0],
	"player_hit": [preload("res://assets/audio/sfx/player_hit.ogg"), 0.0, 1, 0.2, 0.0],
	"boss_break": [preload("res://assets/audio/sfx/boss_break.ogg"), 0.0, 1, 0.3, 0.0],
	"warning": [preload("res://assets/audio/sfx/warning.ogg"), -3.0, 1, 1.0, 0.0],
	"enemy_fire": [preload("res://assets/audio/sfx/enemy_fire.ogg"), -16.0, 2, 0.09, 0.1],
	"combo_up": [preload("res://assets/audio/sfx/combo_up.ogg"), -4.0, 1, 0.2, 0.0],
	"ui_move": [preload("res://assets/audio/sfx/ui_move.ogg"), -8.0, 2, 0.03, 0.0],
	"ui_confirm": [preload("res://assets/audio/sfx/ui_confirm.ogg"), -5.0, 1, 0.05, 0.0],
	"ui_back": [preload("res://assets/audio/sfx/ui_back.ogg"), -6.0, 1, 0.05, 0.0],
	"charge": [preload("res://assets/audio/sfx/charge.ogg"), -6.0, 1, 0.3, 0.0],
	"victory": [preload("res://assets/audio/sfx/victory.ogg"), -2.0, 1, 0.5, 0.0],
	"defeat": [preload("res://assets/audio/sfx/defeat.ogg"), -2.0, 1, 0.5, 0.0],
}
var _pools := {}
var silent := false # headless tests set this so no playback objects are created
var _last_played := {}
var _music_player: Node
var _music_id := ""
var _music_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Headless runs (CI checks, tests) have no audio output; skip creating playbacks.
	if DisplayServer.get_name() == "headless":
		silent = true
	for id: String in _cues:
		var pool: Array = []
		for i in range(int(_cues[id][2])):
			var p := AudioStreamPlayer.new()
			p.stream = _cues[id][0]
			p.bus = "SFX"
			p.volume_db = _cues[id][1]
			add_child(p)
			pool.append(p)
		_pools[id] = pool
	_music_player = BrowserBgmPlayer.new()
	_music_player.name = "Music"
	_music_player.bus = "Music"
	_music_player.volume_db = MUSIC_BASE_DB
	add_child(_music_player)

func play(id: String, gain_offset := 0.0, pitch := 1.0) -> void:
	if silent:
		return
	if not _cues.has(id):
		return
	var cue: Array = _cues[id]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(id, -10.0)) < float(cue[3]):
		return
	_last_played[id] = now
	var chosen: AudioStreamPlayer = null
	var oldest := -1.0
	for p: AudioStreamPlayer in _pools[id]:
		if not p.playing:
			chosen = p
			break
		if p.get_playback_position() > oldest:
			oldest = p.get_playback_position()
			chosen = p
	chosen.volume_db = float(cue[1]) + gain_offset
	var jitter := float(cue[4])
	chosen.pitch_scale = pitch * (1.0 + randf_range(-jitter, jitter))
	chosen.play()

func play_music(id: String, restart := false) -> void:
	if silent:
		return
	if not MUSIC.has(id):
		return
	if id == _music_id and not restart and _music_player.is_playing():
		return
	_music_id = id
	if _music_tween:
		_music_tween.kill()
	_music_player.stop()
	_music_player.force_loop = true
	_music_player.buffer_key = "starveil-" + id
	_music_player.stream = MUSIC[id]
	_music_player.volume_db = MUSIC_BASE_DB
	_music_player.play()

func fade_music(duration := 1.2) -> void:
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -40.0, duration)
	_music_tween.tween_callback(func() -> void:
		_music_player.stop()
		_music_id = "")

func stop_music() -> void:
	_music_player.stop()
	_music_id = ""

## Stops every voice and releases streams (used on shutdown / by headless tests).
func stop_all() -> void:
	stop_music()
	_music_player.stream = null
	for id in _pools:
		for pl: AudioStreamPlayer in _pools[id]:
			pl.stop()
			pl.stream = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(_music_player):
			stop_all()

func current_music() -> String:
	return _music_id

func set_music_paused(paused: bool) -> void:
	_music_player.stream_paused = paused
