class_name SettingsPanel
extends PanelContainer
## Shared settings panel (title screen + pause). Emits `closed` on Back / cancel.
signal closed

var _rows: Array = []
var _title: Label
var _legend: Label
var _back: PixelButton

func _ready() -> void:
	add_theme_stylebox_override("panel", PixelUI.box(PixelUI.PANEL, PixelUI.CYAN, 3, 10, 26))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", PixelUI.font("title"))
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", PixelUI.CYAN)
	v.add_child(_title)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)
	var master := OptionRow.new("settings.master", 10)
	var music := OptionRow.new("settings.music", 10)
	var sfx := OptionRow.new("settings.sfx", 10)
	var fx := OptionRow.new("settings.effects", 0, ["opt.high", "opt.low"])
	var shake := OptionRow.new("settings.shake", 0, ["opt.on", "opt.off"])
	var lang := OptionRow.new("settings.language", 0, ["English", "简体中文"])
	_rows = [master, music, sfx, fx, shake, lang]
	for r: OptionRow in _rows:
		v.add_child(r)
	master.index = int(round(Settings.master * 10))
	music.index = int(round(Settings.music * 10))
	sfx.index = int(round(Settings.sfx * 10))
	fx.index = 0 if Settings.effects_high else 1
	shake.index = 0 if Settings.screen_shake else 1
	lang.index = 1 if I18n.get_locale() == "zh-CN" else 0
	master.value_changed.connect(func(i: int) -> void: Settings.set_value("master", i / 10.0))
	music.value_changed.connect(func(i: int) -> void: Settings.set_value("music", i / 10.0))
	sfx.value_changed.connect(func(i: int) -> void:
		Settings.set_value("sfx", i / 10.0)
		AudioDirector.play("pickup"))
	fx.value_changed.connect(func(i: int) -> void: Settings.set_value("effects_high", i == 0))
	shake.value_changed.connect(func(i: int) -> void: Settings.set_value("screen_shake", i == 0))
	lang.value_changed.connect(func(i: int) -> void: I18n.set_locale("zh-CN" if i == 1 else "en"))
	_legend = Label.new()
	_legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legend.custom_minimum_size = Vector2(540, 0)
	_legend.add_theme_font_override("font", PixelUI.font("medium"))
	_legend.add_theme_font_size_override("font_size", 14)
	_legend.add_theme_color_override("font_color", PixelUI.MUTED)
	v.add_child(_legend)
	_back = PixelButton.new("", PixelUI.PINK, 20)
	_back.custom_minimum_size = Vector2(540, 50)
	_back.pressed.connect(close)
	v.add_child(_back)
	I18n.locale_changed.connect(func(_l: String) -> void: _refresh_text())
	_refresh_text()

func _refresh_text() -> void:
	_title.text = I18n.t("settings.title")
	_legend.text = I18n.t("settings.legend")
	_back.text = I18n.t("menu.back")
	for r: OptionRow in _rows:
		r.refresh()

func apply_fit(fit: ScreenFit) -> void:
	var px := 18
	var h := 46.0
	var w := 540.0
	if fit.compact:
		px = int(fit.dp(15 if fit.portrait else 14))
		h = fit.dp(44 if fit.portrait else 34)
		w = minf(fit.safe.size.x - fit.dp(28), fit.dp(480))
	_title.add_theme_font_size_override("font_size", int(px * 1.45))
	for r: OptionRow in _rows:
		r.apply_row_metrics(px, h, w)
	_legend.visible = not fit.compact or fit.portrait
	_legend.custom_minimum_size = Vector2(w, 0)
	_back.apply_metrics(px, Vector2(w, h + 4.0))

func open() -> void:
	apply_fit(ScreenFit.capture(self))
	show()
	for r: OptionRow in _rows:
		r.refresh()
	(_rows[0] as Control).grab_focus.call_deferred()

func close() -> void:
	AudioDirector.play("ui_back")
	hide()
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()
