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
var _layout_sig := ""
var _view := Vector2(1280, 720)

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
	_layout_ui(ScreenFit.capture(self))
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
	var fit := ScreenFit.capture(self)
	_view = fit.view
	_layout_ui(fit)
	for i in range(stars.size()):
		var s: Vector3 = stars[i]
		s.y += (10.0 + s.z * s.z * 60.0) * delta
		if s.y > _view.y + 2.0:
			s.y = -2
			s.x = randf() * _view.x
		stars[i] = s
	if leaving >= 0.0:
		leaving += delta
		if leaving > 0.75:
			get_tree().change_scene_to_file("res://scenes/game.tscn")
			leaving = -10.0
	queue_redraw()

func _layout_ui(fit: ScreenFit) -> void:
	var sig := "%s|%s|%s|%s" % [fit.view, fit.compact, fit.portrait, fit.safe]
	if sig == _layout_sig:
		return
	_layout_sig = sig
	if settings != null and settings.visible:
		settings.apply_fit(fit)
	if not fit.compact:
		menu.position = fit.origin + Vector2(92, 318)
		menu.add_theme_constant_override("separation", 12)
		for id: String in buttons:
			var h := 60.0 if id == "start" else 50.0
			(buttons[id] as PixelButton).apply_metrics(24 if id == "start" else 20, Vector2(340, h))
		lang_btn.position = fit.origin + Vector2(1110, 22)
		lang_btn.apply_metrics(16, Vector2(150, 42))
		return
	var gap := fit.dp(8)
	var start_h := fit.dp(58 if fit.portrait else 46)
	var row_h := fit.dp(50 if fit.portrait else 40)
	var bw := minf(fit.safe.size.x - fit.dp(28), fit.dp(420))
	if not fit.portrait:
		var px_btn := int(fit.dp(15))
		var label_w := 0.0
		for id: String in buttons:
			label_w = maxf(label_w, U.text_width((buttons[id] as PixelButton).text, px_btn, "bold"))
		bw = clampf(label_w + fit.dp(56), fit.dp(210), fit.safe.size.x * 0.44)
	menu.add_theme_constant_override("separation", int(gap))
	for id: String in buttons:
		var h := start_h if id == "start" else row_h
		var btn := buttons[id] as PixelButton
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.clip_text = true
		btn.apply_metrics(int(fit.dp(18 if fit.portrait and id == "start" else 15)), Vector2(bw, h))
		btn.size = Vector2(bw, h)
	menu.size = Vector2(bw, start_h + row_h * 3.0 + gap * 3.0)
	if fit.portrait:
		var block := menu.size.y
		menu.position = Vector2(fit.safe.position.x + (fit.safe.size.x - bw) * 0.5, fit.safe.position.y + fit.safe.size.y * 0.40)
		if menu.position.y + block > fit.safe.end.y - fit.dp(90):
			menu.position.y = fit.safe.end.y - fit.dp(90) - block
	else:
		var below_lang := fit.safe.position.y + fit.dp(8) + fit.dp(40) + fit.dp(14)
		menu.position = Vector2(fit.safe.end.x - bw - fit.dp(16), below_lang)
	lang_btn.apply_metrics(int(fit.dp(14)), Vector2(fit.dp(118), fit.dp(40)))
	lang_btn.position = Vector2(fit.safe.end.x - fit.dp(130), fit.safe.position.y + fit.dp(8))

func _draw() -> void:
	var fit := ScreenFit.capture(self)
	draw_rect(Rect2(Vector2.ZERO, fit.view), Color(0.012, 0.03, 0.016))
	if fit.compact:
		_draw_compact(fit)
		return
	draw_set_transform(fit.origin, 0, Vector2.ONE)
	_draw_plate()
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if leaving > 0.0:
		draw_rect(Rect2(Vector2.ZERO, fit.view), Color(1, 1, 1, clampf(leaving / 0.6, 0, 1) * 0.9))

func _draw_plate() -> void:
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
	_faction_strip(Rect2(480, 566, 740, 92), 12)

func _draw_compact(fit: ScreenFit) -> void:
	var drift := Vector2(sin(t * 0.2) * 4.0, cos(t * 0.17) * 3.0)
	draw_texture_rect(art, Rect2(drift, fit.view), false, Color(0.55, 0.6, 0.7, 0.55))
	draw_rect(Rect2(Vector2.ZERO, fit.view), Color(0.01, 0.03, 0.02, 0.72))
	for s: Vector3 in stars:
		if s.x > fit.view.x or s.y > fit.view.y:
			continue
		draw_rect(Rect2(Vector2(s.x, s.y).floor(), Vector2(2, 2)), Color(0.8, 0.9, 0.75, 0.35 + s.z * 0.4))
	var appear := clampf(t / 0.8, 0, 1)
	if fit.portrait:
		# The language button owns the top-right corner. The title starts under it.
		var ly := fit.safe.position.y + fit.dp(86)
		var title_px := int(fit.dp(30))
		U.draw_text(self, I18n.t("game.title_short"), Vector2(fit.safe.position.x, ly), title_px, Color(1, 1, 1, appear), "title", HORIZONTAL_ALIGNMENT_CENTER, fit.safe.size.x)
		U.draw_text(self, I18n.t("brand.sub"), Vector2(fit.safe.position.x, ly + fit.dp(28)), int(fit.dp(13)), Color(U.CYAN, appear), "display", HORIZONTAL_ALIGNMENT_CENTER, fit.safe.size.x)
		U.draw_text(self, I18n.t("title.tagline"), Vector2(fit.safe.position.x + fit.dp(16), ly + fit.dp(52)), int(fit.dp(13)), Color(U.TEXT, appear * 0.9), "medium", HORIZONTAL_ALIGNMENT_CENTER, fit.safe.size.x - fit.dp(32))
		_faction_strip(Rect2(fit.safe.position.x + fit.dp(8), ly + fit.dp(68), fit.safe.size.x - fit.dp(16), fit.dp(236)), int(fit.dp(12)))
		var br := Rect2(fit.safe.position.x + fit.dp(16), fit.safe.end.y - fit.dp(78), fit.safe.size.x - fit.dp(32), fit.dp(64))
		_best_plate(br, int(fit.dp(13)), int(fit.dp(22)))
	else:
		var ly := fit.safe.position.y + fit.dp(28)
		var left_w := fit.safe.size.x * 0.50
		U.draw_text(self, I18n.t("game.title_short"), Vector2(fit.safe.position.x + fit.dp(12), ly), int(fit.dp(26)), Color(1, 1, 1, appear), "title", HORIZONTAL_ALIGNMENT_LEFT, left_w)
		U.draw_text(self, I18n.t("brand.sub"), Vector2(fit.safe.position.x + fit.dp(12), ly + fit.dp(24)), int(fit.dp(12)), Color(U.CYAN, appear), "display")
		U.draw_text(self, I18n.t("title.tagline"), Vector2(fit.safe.position.x + fit.dp(12), ly + fit.dp(46)), int(fit.dp(12)), Color(U.TEXT, appear * 0.9), "medium", HORIZONTAL_ALIGNMENT_LEFT, left_w - fit.dp(16))
		_faction_strip(Rect2(fit.safe.position.x + fit.dp(12), ly + fit.dp(56), left_w - fit.dp(24), fit.dp(156)), int(fit.dp(11)))
		var br := Rect2(fit.safe.position.x + fit.dp(12), fit.safe.end.y - fit.dp(62), left_w - fit.dp(24), fit.dp(52))
		_best_plate(br, int(fit.dp(12)), int(fit.dp(18)))
	if leaving > 0.0:
		draw_rect(Rect2(Vector2.ZERO, fit.view), Color(1, 1, 1, clampf(leaving / 0.6, 0, 1) * 0.9))

func _best_plate(br: Rect2, label_px: int, value_px: int) -> void:
	U.draw_panel(self, br, U.GOLD, Color(0.05, 0.04, 0.12, 0.85))
	U.draw_text(self, I18n.t("title.best"), Vector2(br.position.x + 14, br.position.y + label_px + 8), label_px, U.MUTED, "bold")
	var best := SaveData.best_score
	U.draw_text(self, "—" if best <= 0 else _fmt(best), Vector2(br.position.x + 14, br.end.y - 12), value_px, U.GOLD, "display")
	if SaveData.best_rank != "":
		U.draw_text(self, I18n.t("res.rank") + " " + SaveData.best_rank, Vector2(br.position.x + 14, br.position.y + label_px + 8), label_px, U.TEXT, "bold", HORIZONTAL_ALIGNMENT_RIGHT, br.size.x - 28)

func _faction_strip(area: Rect2, label_px := 11) -> void:
	var rows: Array = FactionMarks.ALL
	var n := rows.size()
	if n == 0 or area.size.x < 12.0 or area.size.y < 12.0:
		return
	var gap := maxf(4.0, float(label_px) * 0.45)
	var label_h := float(label_px) + 4.0
	var per_row := n
	var row_count := 1
	var h1 := _flag_row_height(area.size, n, 1, gap, label_h)
	var per2 := int(ceil(float(n) / 2.0))
	var h2 := _flag_row_height(area.size, per2, 2, gap, label_h)
	if h2 > h1 * 1.12:
		row_count = 2
		per_row = per2
	var fh := h2 if row_count == 2 else h1
	if fh < 8.0:
		return
	var fw := fh * 1.5
	var y := area.position.y
	var index := 0
	for _r in row_count:
		var count := mini(per_row, n - index)
		var total := float(count) * fw + float(maxi(count - 1, 0)) * gap
		var x := area.position.x + (area.size.x - total) * 0.5
		for _i in count:
			var row: Array = rows[index]
			FactionMarks.draw(self, str(row[0]), Rect2(x, y, fw, fh))
			U.draw_text(self, str(row[1]), Vector2(x - 8, y + fh + label_h - 1.0), label_px, U.TEXT, "bold", HORIZONTAL_ALIGNMENT_CENTER, fw + 16)
			x += fw + gap
			index += 1
		y += fh + label_h + gap * 0.35

func _flag_row_height(area: Vector2, per_row: int, rows: int, gap: float, label_h: float) -> float:
	if per_row < 1 or rows < 1:
		return 0.0
	var cell := (area.x - gap * float(per_row - 1)) / float(per_row)
	var fh := cell / 1.5
	var band := (area.y - gap * 0.35 * float(rows - 1)) / float(rows)
	return minf(fh, band - label_h)

func _fmt(v: int) -> String:
	var s := str(v)
	var out := ""
	for i in range(s.length()):
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return out
