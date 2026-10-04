extends Node
## Player settings (volumes, effects quality, screen shake). Language lives in I18n.
## Persisted to user://starveil_settings.cfg and applied to the audio buses.
signal changed

const PATH := "user://starveil_settings.cfg"

var master := 0.8
var music := 0.7
var sfx := 0.8
var effects_high := true
var screen_shake := true

func _ready() -> void:
	_ensure_buses()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		master = clampf(float(cfg.get_value("audio", "master", master)), 0.0, 1.0)
		music = clampf(float(cfg.get_value("audio", "music", music)), 0.0, 1.0)
		sfx = clampf(float(cfg.get_value("audio", "sfx", sfx)), 0.0, 1.0)
		effects_high = bool(cfg.get_value("video", "effects_high", effects_high))
		screen_shake = bool(cfg.get_value("video", "screen_shake", screen_shake))
	apply()

func set_value(key: String, value: Variant) -> void:
	match key:
		"master": master = clampf(float(value), 0.0, 1.0)
		"music": music = clampf(float(value), 0.0, 1.0)
		"sfx": sfx = clampf(float(value), 0.0, 1.0)
		"effects_high": effects_high = bool(value)
		"screen_shake": screen_shake = bool(value)
	apply()
	save()
	changed.emit()

func apply() -> void:
	_set_bus("Master", master)
	_set_bus("Music", music)
	_set_bus("SFX", sfx)

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("video", "effects_high", effects_high)
	cfg.set_value("video", "screen_shake", screen_shake)
	cfg.save(PATH)

func _set_bus(bus_name: String, level: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, level <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(level, 0.001)))

func _ensure_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
