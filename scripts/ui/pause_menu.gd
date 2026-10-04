extends Control
## Pause overlay. The game keeps its own `paused` flag, so this UI runs normally.
var game: StarveilGame
var _panel: PanelContainer
var _box: VBoxContainer
var _title: Label
var _buttons := {}
var _settings: SettingsPanel

func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.06, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", PixelUI.box(PixelUI.PANEL, PixelUI.VIOLET, 3, 10, 28))
	center.add_child(_panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_panel.add_child(_box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", PixelUI.font("title"))
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", PixelUI.TEXT)
	_box.add_child(_title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	_box.add_child(gap)
	for id: String in ["resume", "restart", "skip", "settings", "title_btn"]:
		var b := PixelButton.new("", PixelUI.PINK if id == "title_btn" else PixelUI.CYAN, 22)
		b.custom_minimum_size = Vector2(380, 54)
		b.name = id
		_box.add_child(b)
		_buttons[id] = b
	_buttons["resume"].pressed.connect(func() -> void: game.set_paused(false))
	_buttons["restart"].pressed.connect(func() -> void: game.restart())
	_buttons["skip"].pressed.connect(func() -> void:
		game.set_paused(false)
		game.skip_tutorial())
	_buttons["settings"].pressed.connect(_open_settings)
	_buttons["title_btn"].pressed.connect(func() -> void: game.quit_to_title())
	_settings = SettingsPanel.new()
	_settings.hide()
	center.add_child(_settings)
	_settings.closed.connect(func() -> void:
		_panel.show()
		_buttons["settings"].grab_focus())
	I18n.locale_changed.connect(func(_l: String) -> void: _refresh())
	_refresh()

func _refresh() -> void:
	_title.text = I18n.t("pause.title")
	for id: String in _buttons:
		_buttons[id].text = I18n.t("pause." + id)

func open() -> void:
	_refresh()
	_buttons["skip"].visible = game.tutorial_active
	show()
	_panel.show()
	_settings.hide()
	_buttons["resume"].grab_focus.call_deferred()

func close() -> void:
	hide()

func _open_settings() -> void:
	_panel.hide()
	_settings.open()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _settings.visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		game.set_paused(false)
