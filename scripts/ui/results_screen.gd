extends Control
## End-of-run results: animated tallies, rank stamp, local best, retry/title.
var game: StarveilGame
var data: Dictionary = {}
var t := 0.0
var _buttons: Array = []
var _stamp_played := false
var _tick_played := 0

const ROWS := [["res.kills", "kills"], ["res.grazes", "grazes"], ["res.max_chain", "max_chain"], ["res.phases", "phases"], ["res.misses", "misses"], ["res.clear_bonus", "clear_bonus"], ["res.life_bonus", "life_bonus"]]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var retry := PixelButton.new("", PixelUI.CYAN, 22)
	var title := PixelButton.new("", PixelUI.PINK, 22)
	for b: PixelButton in [retry, title]:
		b.custom_minimum_size = Vector2(250, 56)
		add_child(b)
		_buttons.append(b)
	retry.pressed.connect(func() -> void: game.restart())
	title.pressed.connect(func() -> void: game.quit_to_title())
	retry.focus_neighbor_right = title.get_path()
	title.focus_neighbor_left = retry.get_path()
	_place_buttons(ScreenFit.capture(self))

func _place_buttons(fit: ScreenFit) -> void:
	if not fit.compact:
		(_buttons[0] as PixelButton).apply_metrics(22, Vector2(250, 56))
		(_buttons[1] as PixelButton).apply_metrics(22, Vector2(250, 56))
		_buttons[0].position = fit.origin + Vector2(640 - 262, 604)
		_buttons[1].position = fit.origin + Vector2(640 + 12, 604)
		return
	var r := _panel_rect(fit)
	var gap := fit.dp(10)
	var bh := fit.dp(50 if fit.portrait else 40)
	var bw := (r.size.x - fit.dp(28) - gap) * 0.5
	var y := r.end.y - bh - fit.dp(14)
	var x := r.position.x + fit.dp(14)
	(_buttons[0] as PixelButton).apply_metrics(int(fit.dp(15)), Vector2(bw, bh))
	(_buttons[1] as PixelButton).apply_metrics(int(fit.dp(15)), Vector2(bw, bh))
	_buttons[0].position = Vector2(x, y)
	_buttons[1].position = Vector2(x + bw + gap, y)

func _panel_rect(fit: ScreenFit) -> Rect2:
	if not fit.compact:
		return Rect2(fit.origin + Vector2(340, 40), Vector2(600, 548))
	var w := minf(fit.safe.size.x - fit.dp(18), fit.safe.size.x)
	var h := minf(fit.safe.size.y - fit.dp(16), fit.dp(640 if fit.portrait else 520))
	h = minf(h, fit.safe.size.y - fit.dp(12))
	var x := fit.safe.position.x + (fit.safe.size.x - w) * 0.5
	var y := fit.safe.position.y + maxf(0.0, (fit.safe.size.y - h) * 0.35)
	return Rect2(x, y, w, h)

func open(d: Dictionary) -> void:
	data = d
	t = 0.0
	_stamp_played = false
	_tick_played = 0
	_buttons[0].text = I18n.t("res.retry")
	_buttons[1].text = I18n.t("res.title")
	for b: Control in _buttons:
		b.modulate.a = 0.0
	show()
	AudioDirector.play_music("stage" if not d["victory"] else "stage", true)

func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	var reveal := 0.9 + ROWS.size() * 0.22
	for i in range(ROWS.size()):
		if t > 0.9 + i * 0.22 and _tick_played <= i:
			_tick_played = i + 1
			AudioDirector.play("ui_move")
	if t > reveal + 0.4 and not _stamp_played:
		_stamp_played = true
		AudioDirector.play("explode_big", -6.0)
		if data.get("new_best", false):
			AudioDirector.play("combo_up")
		_buttons[0].grab_focus()
	var ba := clampf((t - reveal - 0.6) / 0.3, 0, 1)
	for b: Control in _buttons:
		b.modulate.a = ba
	_place_buttons(ScreenFit.capture(self))
	queue_redraw()

func _draw() -> void:
	if data.is_empty():
		return
	var fit := ScreenFit.capture(self)
	var a := clampf(t / 0.4, 0, 1)
	draw_rect(Rect2(Vector2.ZERO, fit.view), Color(0.02, 0.01, 0.06, 0.82 * a))
	if fit.compact:
		_draw_compact(fit, a)
		return
	draw_set_transform(fit.origin, 0, Vector2.ONE)
	var r := Rect2(340, 40, 600, 548)
	PixelUI.draw_panel(self, r, PixelUI.GOLD if data["victory"] else PixelUI.RED)
	var head := I18n.t("res.victory") if data["victory"] else I18n.t("res.defeat")
	PixelUI.draw_text(self, head, Vector2(r.position.x, 100), 38, PixelUI.GOLD if data["victory"] else PixelUI.RED, "title", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	PixelUI.draw_text(self, I18n.t("stage.name"), Vector2(r.position.x, 132), 16, PixelUI.MUTED, "bold", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var y := 186.0
	for i in range(ROWS.size()):
		var row: Array = ROWS[i]
		var k := clampf((t - 0.9 - i * 0.22) / 0.3, 0, 1)
		if k <= 0.0:
			break
		var val := int(data.get(row[1], 0))
		var shown := int(val * k)
		var s := game.format_score(shown)
		if row[1] in ["clear_bonus", "life_bonus"]:
			s = "+" + s
		var col := Color(1, 1, 1, k)
		PixelUI.draw_text(self, I18n.t(row[0]), Vector2(r.position.x + 48, y), 18, Color(PixelUI.MUTED, k), "bold")
		PixelUI.draw_text(self, s, Vector2(r.position.x + 48, y), 20, col, "display", HORIZONTAL_ALIGNMENT_RIGHT, 330)
		y += 36
	draw_rect(Rect2(r.position.x + 40, y - 14, 340, 2), Color(PixelUI.LINE, a))
	var tk := clampf((t - 0.9 - ROWS.size() * 0.22) / 0.4, 0, 1)
	if tk > 0.0:
		PixelUI.draw_text(self, I18n.t("res.total"), Vector2(r.position.x + 48, y + 26), 20, Color(PixelUI.GOLD, tk), "bold")
		PixelUI.draw_text(self, game.format_score(int(int(data["total"]) * tk)), Vector2(r.position.x + 48, y + 30), 34, Color(1, 1, 1, tk), "display", HORIZONTAL_ALIGNMENT_RIGHT, 330)
		PixelUI.draw_text(self, I18n.t("res.best", {"v": game.format_score(SaveData.best_score)}), Vector2(r.position.x + 48, y + 66), 15, Color(PixelUI.MUTED, tk), "bold")
	# Rank stamp
	var sk := clampf((t - 0.9 - ROWS.size() * 0.22 - 0.4) / 0.18, 0, 1)
	if sk > 0.0:
		var c := fit.origin + Vector2(r.position.x + 480, 300)
		var sc := lerpf(2.6, 1.0, sk)
		draw_set_transform(c, -0.12, Vector2(sc, sc))
		var rank := str(data["rank"])
		var rcol := {"S": PixelUI.GOLD, "A": PixelUI.PINK, "B": PixelUI.CYAN, "C": PixelUI.VIOLET}.get(rank, PixelUI.MUTED) as Color
		var box := Rect2(-70, -80, 140, 160)
		draw_rect(box, Color(rcol, 0.12 * sk))
		draw_rect(box, Color(rcol, sk), false, 4.0)
		PixelUI.draw_text(self, I18n.t("res.rank"), Vector2(-70, -52), 16, Color(rcol, sk), "bold", HORIZONTAL_ALIGNMENT_CENTER, 140)
		PixelUI.draw_text(self, rank, Vector2(-70, 50), 96, Color(1, 1, 1, sk), "title", HORIZONTAL_ALIGNMENT_CENTER, 140)
		draw_set_transform(fit.origin, 0, Vector2.ONE)
		if data.get("new_best", false) and sk >= 1.0:
			var blink := 0.6 + 0.4 * sin(t * 8.0)
			var nb := Rect2(r.position.x + 400, 400, 160, 34)
			draw_rect(nb, Color(PixelUI.GOLD, 0.2 * blink))
			draw_rect(nb, Color(PixelUI.GOLD, blink), false, 2.0)
			PixelUI.draw_text(self, I18n.t("res.new_best"), Vector2(nb.position.x, nb.position.y + 24), 18, Color(PixelUI.GOLD, blink), "bold", HORIZONTAL_ALIGNMENT_CENTER, nb.size.x)
		PixelUI.draw_text(self, I18n.t("res.time", {"t": "%d:%02d" % [int(data["time"]) / 60, int(data["time"]) % 60]}), Vector2(r.position.x + 400, 470), 14, PixelUI.MUTED, "bold", HORIZONTAL_ALIGNMENT_CENTER, 160)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_compact(fit: ScreenFit, a: float) -> void:
	var r := _panel_rect(fit)
	PixelUI.draw_panel(self, r, PixelUI.GOLD if data["victory"] else PixelUI.RED)
	var px := int(fit.dp(15 if fit.portrait else 13))
	PixelUI.draw_text(self, I18n.t("res.victory") if data["victory"] else I18n.t("res.defeat"), Vector2(r.position.x, r.position.y + fit.dp(36)), int(px * 1.6), PixelUI.GOLD if data["victory"] else PixelUI.RED, "title", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	PixelUI.draw_text(self, I18n.t("stage.name"), Vector2(r.position.x, r.position.y + fit.dp(58)), px, PixelUI.MUTED, "bold", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_flag_line(fit, Vector2(r.position.x, r.position.y + fit.dp(68)), r.size.x, fit.dp(22))
	var top := r.position.y + fit.dp(108)
	var bottom := r.end.y - fit.dp(78)
	var row_h := maxf(fit.dp(22), (bottom - top) / (ROWS.size() + 1.6))
	var y := top
	for i in range(ROWS.size()):
		var row: Array = ROWS[i]
		var k := clampf((t - 0.9 - i * 0.22) / 0.3, 0, 1)
		if k <= 0.0:
			break
		var val := int(data.get(row[1], 0))
		var shown := int(val * k)
		var s := game.format_score(shown)
		if row[1] in ["clear_bonus", "life_bonus"]:
			s = "+" + s
		PixelUI.draw_text(self, I18n.t(row[0]), Vector2(r.position.x + fit.dp(16), y), px, Color(PixelUI.MUTED, k), "bold", HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.48)
		PixelUI.draw_text(self, s, Vector2(r.position.x + fit.dp(16), y), int(px * 1.05), Color(1, 1, 1, k), "display", HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - fit.dp(32))
		y += row_h
	var tk := clampf((t - 0.9 - ROWS.size() * 0.22) / 0.4, 0, 1)
	if tk > 0.0:
		PixelUI.draw_text(self, I18n.t("res.total"), Vector2(r.position.x + fit.dp(16), y + fit.dp(8)), int(px * 1.1), Color(PixelUI.GOLD, tk), "bold")
		PixelUI.draw_text(self, game.format_score(int(int(data["total"]) * tk)), Vector2(r.position.x + fit.dp(16), y + fit.dp(10)), int(px * 1.5), Color(1, 1, 1, tk), "display", HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - fit.dp(32))
	var sk := clampf((t - 0.9 - ROWS.size() * 0.22 - 0.4) / 0.18, 0, 1)
	if sk > 0.0:
		var rank := str(data["rank"])
		var rcol := {"S": PixelUI.GOLD, "A": PixelUI.PINK, "B": PixelUI.CYAN, "C": PixelUI.VIOLET}.get(rank, PixelUI.MUTED) as Color
		PixelUI.draw_text(self, I18n.t("res.rank") + "  " + rank, Vector2(r.position.x, r.position.y + fit.dp(78)), int(px * 1.3), Color(rcol, sk), "title", HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - fit.dp(16))
		if data.get("new_best", false):
			var blink := 0.6 + 0.4 * sin(t * 8.0)
			PixelUI.draw_text(self, I18n.t("res.new_best"), Vector2(r.position.x, y + fit.dp(36)), int(px), Color(PixelUI.GOLD, blink * sk), "bold", HORIZONTAL_ALIGNMENT_CENTER, r.size.x)

func _flag_line(fit: ScreenFit, at: Vector2, width: float, h: float) -> void:
	var ids := FactionMarks.for_context(true, 0)
	var gap := h * 0.2
	var fw := h * 1.5
	var total := ids.size() * (fw + gap) - gap
	if total > width - fit.dp(12):
		fw = (width - fit.dp(12)) / ids.size() / 1.2
		h = fw / 1.5
		gap = h * 0.2
		total = ids.size() * (fw + gap) - gap
	var x := at.x + (width - total) * 0.5
	for id: String in ids:
		FactionMarks.draw(self, id, Rect2(x, at.y, fw, h))
		x += fw + gap
