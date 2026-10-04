extends Node2D
## Title screen: key art, animated logo, menu, local best, language toggle.
const OpenSourceLicenses = preload("res://scripts/manus/open_source_licenses.gd")
const U = preload("res://scripts/ui/pixel_ui.gd")

var t := 0.0
var art: Texture2D
var ship: Texture2D
var stars: Array = []
var ui: CanvasLayer
var menu: VBoxContainer
var buttons := {}
var settings: SettingsPanel
var lang_btn: PixelButton
var leaving := -1.0
var leave_target := ""

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art = load("res://assets/art/title_art.png")
	ship = load("res://assets/art/player.png")
	for i in range(90):
		stars.append(Vector3(randf() * 1280, randf() * 720, randf_range(0.2, 1.0)))
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	menu = VBoxContainer.new()
	menu.position = Vector2(92, 318)
	menu.add_theme_constant_override("separation", 12)
	root.add_child(menu)
	for id: String in ["start", "training", "settings", "credits"]:
		var b := PixelButton.new("", U.PINK if id == "start" else U.CYAN, 24 if id == "start" else 20)
		b.custom_minimum_size = Vector2(340, 60 if id == "start" else 50)
		menu.add_child(b)
		buttons[id] = b
	buttons["start"].pressed.connect(func() -> void: _leave(false))
	buttons["training"].pressed.connect(func() -> void: _leave(true))
	buttons["settings"].pressed.connect(_open_settings)
	buttons["credits"].pressed.connect(func() -> void: OpenSourceLicenses.open(root))
	lang_btn = PixelButton.new("", U.VIOLET, 16)
	lang_btn.custom_minimum_size = Vector2(150, 42)
	lang_btn.position = Vector2(1110, 22)
	lang_btn.focus_mode = Control.FOCUS_NONE
	lang_btn.pressed.connect(func() -> void: I18n.set_locale("en" if I18n.get_locale() == "zh-CN" else "zh-CN"))
	root.add_child(lang_btn)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	settings = SettingsPanel.new()
	settings.hide()
	center.add_child(settings)
	settings.closed.connect(func() -> void:
		menu.show()
		buttons["settings"].grab_focus())
	I18n.locale_changed.connect(func(_l: String) -> void: _refresh())
	_refresh()
	buttons["start"].grab_focus.call_deferred()
	AudioDirector.play_music("stage")
	if OS.is_debug_build() and OS.has_feature("web"):
		var q := str(JavaScriptBridge.eval("location.search", true))
		if q.contains("autoplay") or q.contains("start="):
			SaveData.tutorial_done = true
			get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")

func _refresh() -> void:
	buttons["start"].text = I18n.t("menu.start")
	buttons["training"].text = I18n.t("menu.training")
	buttons["settings"].text = I18n.t("menu.settings")
	buttons["credits"].text = I18n.t("menu.credits")
	lang_btn.text = I18n.t("lang.toggle")

func _open_settings() -> void:
	menu.hide()
	settings.open()

func _leave(training: bool) -> void:
	if leaving >= 0.0:
		return
	leaving = 0.0
	get_tree().set_meta("force_tutorial", training)
	AudioDirector.play("charge")

func _process(delta: float) -> void:
	t += delta
	for i in range(stars.size()):
		var s: Vector3 = stars[i]
		s.y += (10.0 + s.z * s.z * 60.0) * delta
		if s.y > 722:
			s.y = -2
			s.x = randf() * 1280
		stars[i] = s
	if leaving >= 0.0:
		leaving += delta
		if leaving > 0.75:
			get_tree().change_scene_to_file("res://scenes/game.tscn")
			leaving = -10.0
	queue_redraw()

func _draw() -> void:
	# Key art with a slow breathing drift
	var drift := Vector2(sin(t * 0.2) * 6.0, cos(t * 0.17) * 4.0).round()
	draw_texture_rect(art, Rect2(Vector2(-8, -8) + drift, Vector2(1296, 736)), false)
	# Left vignette so the logo/menu read clearly
	for i in range(24):
		var a := 0.62 * (1.0 - i / 24.0)
		draw_rect(Rect2(i * 24, 0, 24, 720), Color(0.02, 0.01, 0.06, a))
	for s: Vector3 in stars:
		var tw := 0.5 + 0.5 * sin(t * 3.0 + s.x)
		draw_rect(Rect2(Vector2(s.x, s.y).floor(), Vector2(2, 2 if s.z < 0.8 else 4)), Color(0.8, 0.85, 1.0, (0.2 + s.z * 0.5) * tw))
	# Logo
	var zh := I18n.get_locale() == "zh-CN"
	var appear := clampf(t / 0.8, 0, 1)
	var ly := 150.0 - (1.0 - appear) * 20.0
	var main := I18n.t("brand.zh") if zh else I18n.t("game.title_short")
	var sub := I18n.t("brand.sub")
	var glow := 0.5 + 0.5 * sin(t * 2.0)
	var main_size := 48 if main.length() > 8 else 84
	for k in range(3):
		U.draw_text(self, main, Vector2(86 + k * 2, ly + 4 + k * 2), main_size, Color(U.PINK, 0.25 * appear), "title", HORIZONTAL_ALIGNMENT_LEFT, -1, false)
	U.draw_text(self, main, Vector2(86, ly), main_size, Color(1, 1, 1, appear), "title", HORIZONTAL_ALIGNMENT_LEFT, -1, false)
	draw_rect(Rect2(90, ly + 22, 440 * appear, 4), Color(U.CYAN, appear))
	draw_rect(Rect2(90, ly + 28, 300 * appear, 2), Color(U.PINK, appear * 0.8))
	U.draw_text(self, sub, Vector2(92, ly + 66), 26, Color(U.CYAN, appear * (0.75 + 0.25 * glow)), "display")
	U.draw_text(self, I18n.t("title.tagline"), Vector2(92, ly + 104), 17, Color(U.TEXT, appear * 0.85), "medium")
	# Best score plate
	var br := Rect2(92, 590, 340, 84)
	U.draw_panel(self, br, U.GOLD, Color(0.05, 0.04, 0.12, 0.85))
	U.draw_text(self, I18n.t("title.best"), Vector2(br.position.x + 18, br.position.y + 30), 14, U.MUTED, "bold")
	var best := SaveData.best_score
	U.draw_text(self, "—" if best <= 0 else _fmt(best), Vector2(br.position.x + 18, br.position.y + 68), 30, U.GOLD, "display")
	if SaveData.best_rank != "":
		U.draw_text(self, I18n.t("res.rank") + " " + SaveData.best_rank, Vector2(br.position.x + 18, br.position.y + 30), 14, U.TEXT, "bold", HORIZONTAL_ALIGNMENT_RIGHT, br.size.x - 36)
	if SaveData.clears > 0:
		U.draw_text(self, I18n.t("title.clears", {"n": SaveData.clears}), Vector2(br.position.x + 18, br.position.y + 68), 13, U.MUTED, "bold", HORIZONTAL_ALIGNMENT_RIGHT, br.size.x - 36)
	# Footer
	var hint := I18n.t("title.hint", {"confirm": GameInput.hint("confirm")})
	U.draw_text(self, hint, Vector2(0, 700), 14, Color(U.TEXT, 0.55 + 0.25 * sin(t * 3.0)), "medium", HORIZONTAL_ALIGNMENT_RIGHT, 1256)
	U.draw_text(self, "v1.0 · " + I18n.t("title.original"), Vector2(1256 - 400, 676), 12, Color(U.MUTED, 0.8), "medium", HORIZONTAL_ALIGNMENT_RIGHT, 400)
	# Launch flash
	if leaving > 0.0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(1, 1, 1, clampf(leaving / 0.6, 0, 1) * 0.9))

func _fmt(v: int) -> String:
	var s := str(v)
	var out := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out
