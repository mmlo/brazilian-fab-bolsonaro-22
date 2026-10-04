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
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()
	var retry := PixelButton.new("", PixelUI.CYAN, 22)
	var title := PixelButton.new("", PixelUI.PINK, 22)
	for b: PixelButton in [retry, title]:
		b.custom_minimum_size = Vector2(250, 56)
		add_child(b)
		_buttons.append(b)
	retry.position = Vector2(640 - 262, 604)
	title.position = Vector2(640 + 12, 604)
	retry.pressed.connect(func() -> void: game.restart())
	title.pressed.connect(func() -> void: game.quit_to_title())
	retry.focus_neighbor_right = title.get_path()
	title.focus_neighbor_left = retry.get_path()

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
	queue_redraw()

func _draw() -> void:
	if data.is_empty():
		return
	var a := clampf(t / 0.4, 0, 1)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.01, 0.06, 0.82 * a))
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
		var c := Vector2(r.position.x + 480, 300)
		var sc := lerpf(2.6, 1.0, sk)
		draw_set_transform(c, -0.12, Vector2(sc, sc))
		var rank := str(data["rank"])
		var rcol := {"S": PixelUI.GOLD, "A": PixelUI.PINK, "B": PixelUI.CYAN, "C": PixelUI.VIOLET}.get(rank, PixelUI.MUTED) as Color
		var box := Rect2(-70, -80, 140, 160)
		draw_rect(box, Color(rcol, 0.12 * sk))
		draw_rect(box, Color(rcol, sk), false, 4.0)
		PixelUI.draw_text(self, I18n.t("res.rank"), Vector2(-70, -52), 16, Color(rcol, sk), "bold", HORIZONTAL_ALIGNMENT_CENTER, 140)
		PixelUI.draw_text(self, rank, Vector2(-70, 50), 96, Color(1, 1, 1, sk), "title", HORIZONTAL_ALIGNMENT_CENTER, 140)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		if data.get("new_best", false) and sk >= 1.0:
			var blink := 0.6 + 0.4 * sin(t * 8.0)
			var nb := Rect2(r.position.x + 400, 400, 160, 34)
			draw_rect(nb, Color(PixelUI.GOLD, 0.2 * blink))
			draw_rect(nb, Color(PixelUI.GOLD, blink), false, 2.0)
			PixelUI.draw_text(self, I18n.t("res.new_best"), Vector2(nb.position.x, nb.position.y + 24), 18, Color(PixelUI.GOLD, blink), "bold", HORIZONTAL_ALIGNMENT_CENTER, nb.size.x)
		PixelUI.draw_text(self, I18n.t("res.time", {"t": "%d:%02d" % [int(data["time"]) / 60, int(data["time"]) % 60]}), Vector2(r.position.x + 400, 470), 14, PixelUI.MUTED, "bold", HORIZONTAL_ALIGNMENT_CENTER, 160)
