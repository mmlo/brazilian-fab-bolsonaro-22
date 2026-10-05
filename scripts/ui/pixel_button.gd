class_name PixelButton
extends Button
## Menu button: chamfered pixel plate, blinking chevron on focus, hover-to-focus,
## focus/confirm sounds. Works with mouse, keyboard, gamepad and touch.

var accent := PixelUI.CYAN
var font_size := 22
var _t := 0.0
var _press := 0.0

func apply_metrics(px: int, min_size: Vector2) -> void:
	font_size = maxi(px, 10)
	custom_minimum_size = min_size
	if is_node_ready():
		add_theme_font_size_override("font_size", font_size)

func _init(label := "", accent_color := PixelUI.CYAN, size := 22) -> void:
	text = label
	accent = accent_color
	font_size = size
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(300, font_size + 26)

func _ready() -> void:
	add_theme_font_override("font", PixelUI.font("bold"))
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", PixelUI.TEXT)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_focus_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", accent)
	add_theme_stylebox_override("normal", PixelUI.box(Color(0.07, 0.06, 0.16, 0.9), PixelUI.LINE))
	add_theme_stylebox_override("hover", PixelUI.box(Color(0.14, 0.11, 0.3, 0.95), accent))
	add_theme_stylebox_override("focus", PixelUI.box(Color(0, 0, 0, 0), accent, 3))
	add_theme_stylebox_override("pressed", PixelUI.box(Color(accent, 0.25), accent, 3))
	add_theme_stylebox_override("disabled", PixelUI.box(Color(0.05, 0.05, 0.1, 0.6), Color(0.2, 0.2, 0.3)))
	mouse_entered.connect(func() -> void:
		if not disabled:
			grab_focus())
	focus_entered.connect(func() -> void:
		AudioDirector.play("ui_move"))
	pressed.connect(func() -> void:
		_press = 1.0
		AudioDirector.play("ui_confirm"))

func _process(delta: float) -> void:
	_t += delta
	_press = maxf(0.0, _press - delta * 5.0)
	if has_focus() or _press > 0.0:
		queue_redraw()

func _draw() -> void:
	if has_focus():
		var bob := 3.0 * sin(_t * 8.0)
		var y := size.y * 0.5
		var x := 12.0 + bob
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - 6), Vector2(x + 7, y), Vector2(x, y + 6)]), accent)
		var x2 := size.x - 12.0 - bob
		draw_colored_polygon(PackedVector2Array([Vector2(x2, y - 6), Vector2(x2 - 7, y), Vector2(x2, y + 6)]), accent)
		draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color(accent, 0.07 + 0.04 * sin(_t * 6.0)))
	if _press > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, _press * 0.25))
