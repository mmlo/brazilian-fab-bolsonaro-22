extends Control
## First-run guided tutorial card (steps are driven by game.gd).
var game: StarveilGame
var step := 0
var t := 0.0
var _skip: PixelButton
const STEPS := 5

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	_skip = PixelButton.new("", PixelUI.MUTED, 14)
	_skip.custom_minimum_size = Vector2(150, 34)
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.pressed.connect(func() -> void: game.skip_tutorial())
	add_child(_skip)

func _card_rect() -> Rect2:
	var fit := ScreenFit.capture(self)
	if game != null and game.layout != null:
		fit = game.layout
	if not fit.compact:
		return Rect2(fit.origin + Vector2(400, 404), Vector2(480, 132))
	var w := minf(fit.playfield.size.x - fit.dp(16), fit.dp(440))
	var h := fit.dp(148)
	var x := fit.playfield.position.x + (fit.playfield.size.x - w) * 0.5
	# Upper playfield, so the card stays off the ship and off the thumb buttons.
	var y := fit.playfield.position.y + fit.playfield.size.y * 0.08
	return Rect2(x, y, w, h)

func show_step(i: int) -> void:
	step = i
	t = 0.0
	_refresh_skip()
	_skip.visible = i < STEPS - 1
	show()

var _skip_device := ""
func _refresh_skip() -> void:
	_skip_device = GameInput.device + I18n.get_locale()
	var key := {"kb": "ENTER", "pad": "SELECT"}.get(GameInput.device, "") as String
	_skip.text = I18n.t("tut.skip") + (("  [" + key + "]") if key != "" else "")

func hide_card() -> void:
	hide()

func _process(delta: float) -> void:
	if visible and _skip_device != GameInput.device + I18n.get_locale():
		_refresh_skip()
	if visible:
		t += delta
		if game and game.paused:
			modulate.a = 0.0
		else:
			modulate.a = 1.0
		var fit := ScreenFit.capture(self)
		if game != null and game.layout != null:
			fit = game.layout
		var r := _card_rect()
		var skip_w := 150.0 if not fit.compact else fit.dp(120)
		var skip_h := 34.0 if not fit.compact else fit.dp(36)
		_skip.apply_metrics(int(14 if not fit.compact else fit.dp(13)), Vector2(skip_w, skip_h))
		_skip.position = Vector2(r.end.x - skip_w, r.end.y + (8.0 if not fit.compact else fit.dp(6)))
		queue_redraw()

func _draw() -> void:
	var a := clampf(t / 0.25, 0, 1)
	var fit := ScreenFit.capture(self)
	if game != null and game.layout != null:
		fit = game.layout
	var ui := 1.0 if not fit.compact else clampf(fit.dp(15) / 15.0, 1.0, 2.4)
	var r := _card_rect()
	r.position.y += (1.0 - a) * 16.0 * ui
	PixelUI.draw_panel(self, r, PixelUI.CYAN, Color(0.04, 0.03, 0.1, 0.86 * a))
	var n := step + 1
	var keys := {"move": GameInput.hint("move"), "focus": GameInput.hint("focus"), "bomb": GameInput.hint("bomb")}
	var pad := 20.0 * minf(ui, 1.6) if not fit.compact else fit.dp(14)
	var label_px := int(13.0 * ui) if not fit.compact else int(fit.dp(12))
	var title_px := int(22.0 * minf(ui, 1.7)) if not fit.compact else int(fit.dp(18))
	var body_px := int(14.0 * minf(ui, 1.5)) if not fit.compact else int(fit.dp(14))
	var label_y := r.position.y + (30.0 * ui if not fit.compact else fit.dp(22))
	var title_y := r.position.y + (58.0 * ui if not fit.compact else fit.dp(50))
	var body_y := r.position.y + (86.0 * ui if not fit.compact else fit.dp(80))
	PixelUI.draw_text(self, I18n.t("tut.label", {"n": mini(n, STEPS), "total": STEPS}), Vector2(r.position.x + pad, label_y), label_px, Color(PixelUI.CYAN, a), "bold")
	PixelUI.draw_text(self, I18n.t("tut.%d.title" % n, keys), Vector2(r.position.x + pad, title_y), title_px, Color(1, 1, 1, a), "title", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2.0)
	if fit.compact:
		PixelUI.draw_wrapped(self, I18n.t("tut.%d.body" % n, keys), Vector2(r.position.x + pad, body_y), r.size.x - pad * 2.0, body_px, Color(PixelUI.TEXT, a * 0.95), "medium", 3)
	else:
		PixelUI.draw_text(self, I18n.t("tut.%d.body" % n, keys), Vector2(r.position.x + pad, body_y), body_px, Color(PixelUI.TEXT, a * 0.9), "medium", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - pad * 2.0)
	# progress pips
	var pip := fit.dp(8) if fit.compact else 10.0
	var pip_y := r.position.y + (fit.dp(10) if fit.compact else 20.0)
	for i in range(STEPS):
		var col := PixelUI.CYAN if i <= step else Color(1, 1, 1, 0.15)
		draw_rect(Rect2(r.end.x - pad - (STEPS - i) * (pip + 4.0), pip_y, pip, pip), Color(col, a))
	# live objective meter
	var k := 0.0
	match step:
		0: k = clampf(game.tut_moved / 90.0, 0, 1)
		1: k = clampf(game.tut_focus_time / 1.1, 0, 1)
		2: k = clampf(game.tut_grazes / 8.0, 0, 1)
		3: k = 0.0
		4: k = 1.0
	draw_rect(Rect2(r.position.x + 20, r.end.y - 18, r.size.x - 40, 5), Color(1, 1, 1, 0.1 * a))
	draw_rect(Rect2(r.position.x + 20, r.end.y - 18, (r.size.x - 40) * k, 5), Color(PixelUI.CYAN, a))
