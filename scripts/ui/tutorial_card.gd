extends Control
## First-run guided tutorial card (steps are driven by game.gd).
var game: StarveilGame
var step := 0
var t := 0.0
var _skip: PixelButton
const STEPS := 5
const CARD := Rect2(400, 404, 480, 132)

func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	_skip = PixelButton.new("", PixelUI.MUTED, 14)
	_skip.custom_minimum_size = Vector2(150, 34)
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.position = Vector2(CARD.end.x - 150, CARD.end.y + 8)
	_skip.pressed.connect(func() -> void: game.skip_tutorial())
	add_child(_skip)

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
		queue_redraw()

func _draw() -> void:
	var a := clampf(t / 0.25, 0, 1)
	var r := CARD
	r.position.y += (1.0 - a) * 16.0
	PixelUI.draw_panel(self, r, PixelUI.CYAN, Color(0.04, 0.03, 0.1, 0.86 * a))
	var n := step + 1
	var keys := {"move": GameInput.hint("move"), "focus": GameInput.hint("focus"), "bomb": GameInput.hint("bomb")}
	PixelUI.draw_text(self, I18n.t("tut.label", {"n": mini(n, STEPS), "total": STEPS}), Vector2(r.position.x + 20, r.position.y + 30), 13, Color(PixelUI.CYAN, a), "bold")
	PixelUI.draw_text(self, I18n.t("tut.%d.title" % n, keys), Vector2(r.position.x + 20, r.position.y + 62), 24, Color(1, 1, 1, a), "title", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40)
	PixelUI.draw_text(self, I18n.t("tut.%d.body" % n, keys), Vector2(r.position.x + 20, r.position.y + 94), 15, Color(PixelUI.TEXT, a * 0.9), "medium", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40)
	# progress pips
	for i in range(STEPS):
		var col := PixelUI.CYAN if i <= step else Color(1, 1, 1, 0.15)
		draw_rect(Rect2(r.end.x - 20 - (STEPS - i) * 16, r.position.y + 20, 10, 10), Color(col, a))
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
