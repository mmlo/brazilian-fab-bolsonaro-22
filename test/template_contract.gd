extends SceneTree

var failed := false

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, detail: String) -> void:
	if not ok:
		failed = true
		push_error("[BULLET_HELL_CONTRACT_FAIL] " + detail)

func _run() -> void:
	_check(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "fixed aspect")
	_check(ProjectSettings.get_setting("display/window/size/viewport_width") == 1280, "canvas width")
	_check(ProjectSettings.get_setting("display/window/size/viewport_height") == 720, "canvas height")
	var font_path := "res://assets/template/fonts/ui_regular.tres"
	var label := Label.new()
	root.add_child(label)
	var font := label.get_theme_font("font") as FontVariation
	label.free()
	_check(font != null and font.resource_path == font_path, "runtime inherited project font")
	_check(font != null, "bundled font")
	if font:
		_check(font.get_font_name().begins_with("Exo 2"), "Exo 2 primary")
		_check(font.base_font is FontFile and not font.base_font.allow_system_fallback, "no primary system fallback")
		var cjk := font.fallbacks[0] as FontVariation if font.fallbacks.size() == 1 else null
		_check(cjk != null and cjk.base_font is FontFile and cjk.base_font.get_font_name().begins_with("Noto Sans SC") and not cjk.base_font.allow_system_fallback, "bundled Noto Sans SC fallback without system fallback")
		for char in "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz !%+-/.:,()":
			_check(font.has_char(char.unicode_at(0)), "English glyph: " + char)
		for char in "↑↓←→×·":
			_check(font.has_char(char.unicode_at(0)), "UI glyph: " + char)

	# Native checks inspect every string; compiled packs also verify the font above.
	var string_pattern := RegEx.new()
	string_pattern.compile('"([^"\\n]*)"')
	for script_path in ["res://scripts/game.gd", "res://scripts/title_screen.gd"]:
		var source: String = load(script_path).source_code
		for match_result in string_pattern.search_all(source):
			for char in match_result.get_string(1):
				if char.unicode_at(0) >= 32:
					_check(font.has_char(char.unicode_at(0)), "Runtime glyph: " + char)
	var scene := load("res://scenes/game.tscn") as PackedScene
	var game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var outside := InputEventScreenTouch.new()
	outside.pressed = true
	outside.position = Vector2(-12, 360)
	game._unhandled_input(outside)
	_check(game.touch_id == -1, "letterbox input ignored")
	for layer in [game.far_sprites, game.mid_sprites, game.near_sprites]:
		_check(layer[0].texture.get_width() >= 1280 and layer[0].texture.get_height() >= 720, "background covers canvas")
	_check(game.bgm_player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM, "streamed music")
	var player_count := 0
	for child in game.get_children():
		if child is AudioStreamPlayer or child == game.bgm_player:
			player_count += 1
		_check(not (child is HTTPRequest), "no old session endpoint")
	_check(player_count == 4, "bounded audio players")
	game.phase = game.Phase.PLAYING
	var writes_before: int = game.audio_pause_writes
	for i in 10000:
		game._sync_audio_pause()
	_check(game.audio_pause_writes == writes_before, "idle does not rewrite pause state")
	game.phase = game.Phase.PAUSED
	game._sync_audio_pause()
	var paused_writes: int = game.audio_pause_writes
	for i in 10000:
		game._sync_audio_pause()
	_check(game.bgm_player.stream_paused, "music pauses")
	_check(game.audio_pause_writes == paused_writes, "pause is idempotent")
	game.phase = game.Phase.PLAYING
	game._sync_audio_pause()
	_check(not game.bgm_player.stream_paused, "music resumes")
	_check(root.get_node("TuningStore").descriptors.size() == 12, "twelve tuning values")
	_check(root.get_node("TuningStore").enabled() == OS.is_debug_build(), "release/debug gate")
	var pause := InputEventKey.new()
	pause.keycode = KEY_ESCAPE
	pause.pressed = true
	game._unhandled_input(pause)
	_check(game.phase == game.Phase.PAUSED, "pause control")
	game._unhandled_input(pause)
	_check(game.phase == game.Phase.PLAYING, "resume control")
	for child in game.get_children():
		if child is AudioStreamPlayer or child == game.bgm_player:
			child.stop()
	game.queue_free()
	# Let the streamed BGM playback release before quit (0.25 s raced on slower loads).
	await create_timer(1.0).timeout
	await process_frame
	await process_frame
	if not failed:
		print("[BULLET_HELL_CONTRACT_PASS] font, fixed aspect, streamed bounded audio, pause and tuning")
	quit(1 if failed else 0)
