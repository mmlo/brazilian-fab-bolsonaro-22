class_name OptionRow
extends PixelButton
## A settings row: "LABEL        < value >". Left/right (keys, d-pad, stick)
## change the value; clicking the left/right half steps down/up; accept steps up.
signal value_changed(index: int)

var label_key := ""
var choices: Array = [] # for choice rows: localization keys or literal strings
var steps := 0 # >0 means a slider with this many steps
var index := 0
var _box: HBoxContainer
var _label: Label
var _value: Label

func _init(key: String, slider_steps := 0, choice_list: Array = []) -> void:
	super._init("", PixelUI.CYAN, 18)
	label_key = key
	steps = slider_steps
	choices = choice_list
	custom_minimum_size = Vector2(540, 46)

func _ready() -> void:
	super._ready()
	_box = HBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box.offset_left = 34
	_box.offset_right = -34
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", PixelUI.font("bold"))
	_label.add_theme_font_size_override("font_size", 18)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_label)
	_value = Label.new()
	_value.custom_minimum_size = Vector2(230, 0)
	_value.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value.add_theme_font_override("font", PixelUI.font("bold"))
	_value.add_theme_font_size_override("font_size", 18)
	_value.add_theme_color_override("font_color", PixelUI.CYAN)
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_value)
	refresh()

func refresh() -> void:
	if _label == null:
		return
	_label.text = I18n.t(label_key)
	if steps > 0:
		_value.text = ""
	else:
		var c: String = str(choices[index]) if index < choices.size() else ""
		_value.text = I18n.t(c) if c.contains(".") else c
	queue_redraw()

func _draw() -> void:
	super._draw()
	if _value == null:
		return
	var vr := Rect2(_box.position + _value.position, _value.size)
	var cy := vr.position.y + vr.size.y * 0.5
	var col := PixelUI.CYAN if has_focus() else Color(PixelUI.CYAN, 0.7)
	var lx := vr.position.x + 4.0
	draw_colored_polygon(PackedVector2Array([Vector2(lx + 8, cy - 7), Vector2(lx, cy), Vector2(lx + 8, cy + 7)]), col)
	var rx := vr.end.x - 4.0
	draw_colored_polygon(PackedVector2Array([Vector2(rx - 8, cy - 7), Vector2(rx, cy), Vector2(rx - 8, cy + 7)]), col)
	if steps <= 0:
		return
	var bx := lx + 18.0
	var bw := (rx - 18.0 - bx) / steps
	for i in range(steps):
		var r := Rect2(bx + i * bw + 1, cy - 7, bw - 3, 14)
		if i < index:
			draw_rect(r, col)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), Color(1, 1, 1, 0.4))
		else:
			draw_rect(r, Color(1, 1, 1, 0.1))

func set_index(i: int, emit := false) -> void:
	var count := steps + 1 if steps > 0 else choices.size()
	if steps > 0:
		i = clampi(i, 0, steps)
	else:
		i = posmod(i, count)
	if i == index and not emit:
		refresh()
		return
	var changed := i != index
	index = i
	refresh()
	if emit and changed:
		AudioDirector.play("ui_move")
		value_changed.emit(index)

func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		set_index(index - 1, true)
		accept_event()
	elif event.is_action_pressed("ui_right"):
		set_index(index + 1, true)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mid := _box.position.x + _value.position.x + _value.size.x * 0.5
		if event.position.x >= mid:
			set_index(index + 1 if steps > 0 or true else index, true)
		elif event.position.x > _box.position.x + _value.position.x:
			set_index(index - 1, true)
		else:
			set_index(index + 1, true)
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		set_index(index + 1 if steps == 0 or index < steps else 0, true)
		accept_event()
