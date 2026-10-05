extends Control
## On-screen controls. Drag anywhere outside the buttons to steer 1:1.
## FOCUS is held, BURST is a tap, PAUSE sits clear of the thumbs.
## Portrait puts the buttons under the playfield. Landscape keeps them
## on the right, including the original desktop plate.
var game: StarveilGame
var _fingers := {} # index -> role ("drag" | "focus" | "burst" | "pause")
var _t := 0.0
var _burst_flash := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detect_coarse_pointer()

func _detect_coarse_pointer() -> void:
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
		GameInput.device = "touch"
		GameInput.touch_seen = true
		return
	if OS.has_feature("web"):
		var coarse = JavaScriptBridge.eval("!!(window.matchMedia && window.matchMedia('(pointer: coarse)').matches)", true)
		if coarse == true:
			GameInput.device = "touch"

func _fit() -> ScreenFit:
	if game != null and game.layout != null:
		return game.layout
	return ScreenFit.capture(self)

func _shown() -> bool:
	if game == null:
		return false
	var fit := game.layout
	return GameInput.device == "touch" or (fit != null and fit.compact)

func _active() -> bool:
	return game != null and not game.paused and game.state != "results"

func _input(event: InputEvent) -> void:
	if not _shown():
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_pointer(st.index, st.position, st.pressed, Vector2.ZERO, false)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_pointer(sd.index, sd.position, true, sd.relative, true)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if GameInput.touch_seen and event.device == -1:
			return
		var mb := event as InputEventMouseButton
		_pointer(80, mb.position, mb.pressed, Vector2.ZERO, false)
		if _fingers.get(80, "") != "drag":
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _fingers.has(80):
		if GameInput.touch_seen and event.device == -1:
			return
		var mm := event as InputEventMouseMotion
		_pointer(80, mm.position, true, mm.relative, true)
		if _fingers.get(80, "") != "drag":
			get_viewport().set_input_as_handled()

func _pointer(index: int, pos: Vector2, pressed: bool, relative: Vector2, dragging: bool) -> void:
	var fit := _fit()
	if dragging:
		var role := str(_fingers.get(index, ""))
		if role == "drag" and _active():
			game.add_touch_drag(relative)
		elif role == "focus" and pos.distance_to(fit.focus_c) > fit.focus_r * 1.8:
			_fingers[index] = "drag"
			GameInput.virtual_focus = _fingers.values().has("focus")
		return
	if pressed:
		if not _active():
			return
		var role := "drag"
		var slop := fit.dp(10) if fit.compact else 12.0
		if pos.distance_to(fit.burst_c) < fit.burst_r + slop:
			role = "burst"
			GameInput.virtual_bomb = true
			_burst_flash = 0.3
		elif pos.distance_to(fit.focus_c) < fit.focus_r + slop:
			role = "focus"
		elif pos.distance_to(fit.pause_c) < fit.pause_r + slop:
			role = "pause"
			game.set_paused(true)
		_fingers[index] = role
	else:
		_fingers.erase(index)
	GameInput.virtual_focus = _fingers.values().has("focus")

func _process(delta: float) -> void:
	_t += delta
	_burst_flash = maxf(0.0, _burst_flash - delta)
	visible = _shown()
	if not _active():
		_fingers.clear()
		GameInput.virtual_focus = false
	if visible:
		queue_redraw()

func _draw() -> void:
	if game == null or game.state == "results":
		return
	var fit := _fit()
	var full: bool = game.energy >= GameConfig.ENERGY_MAX
	var bc := PixelUI.CYAN if full else Color(0.35, 0.4, 0.6)
	var pulse := (0.5 + 0.5 * sin(_t * 8.0)) if full else 0.0
	_pad(fit.burst_c, fit.burst_r, bc, full, pulse)
	var k: float = clampf(game.energy / GameConfig.ENERGY_MAX, 0, 1)
	draw_arc(fit.burst_c, fit.burst_r - fit.dp(6), -PI * 0.5, -PI * 0.5 + TAU * k, 40, Color(bc, 0.8), maxf(4.0, fit.dp(3)))
	if _burst_flash > 0.0:
		draw_circle(fit.burst_c, fit.burst_r, Color(1, 1, 1, _burst_flash))
	var label := int(fit.dp(13) if fit.compact else 20)
	PixelUI.draw_text(self, I18n.t("touch.burst"), fit.burst_c + Vector2(-fit.burst_r, fit.dp(6)), label, Color.WHITE if full else PixelUI.MUTED, "bold", HORIZONTAL_ALIGNMENT_CENTER, fit.burst_r * 2.0)
	var held := GameInput.virtual_focus
	draw_circle(fit.focus_c, fit.focus_r, Color(0.03, 0.02, 0.08, 0.72) if not held else Color(PixelUI.PINK, 0.35))
	draw_arc(fit.focus_c, fit.focus_r, 0, TAU, 36, Color(PixelUI.PINK, 0.9), maxf(2.0, fit.dp(2)))
	draw_circle(fit.focus_c + Vector2(0, -fit.focus_r * 0.28), fit.dp(4), Color.WHITE)
	draw_arc(fit.focus_c + Vector2(0, -fit.focus_r * 0.28), fit.dp(7), 0, TAU, 20, PixelUI.PINK, maxf(1.5, fit.dp(1.4)))
	PixelUI.draw_text(self, I18n.t("touch.focus"), fit.focus_c + Vector2(-fit.focus_r, fit.focus_r * 0.32), int(fit.dp(12) if fit.compact else 17), Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER, fit.focus_r * 2.0)
	draw_circle(fit.pause_c, fit.pause_r, Color(0.03, 0.02, 0.08, 0.72))
	draw_arc(fit.pause_c, fit.pause_r, 0, TAU, 28, Color(PixelUI.TEXT, 0.7), maxf(1.5, fit.dp(1.5)))
	var bar_w := maxf(4.0, fit.pause_r * 0.18)
	var bar_h := fit.pause_r * 0.62
	draw_rect(Rect2(fit.pause_c + Vector2(-bar_w * 1.6, -bar_h * 0.5), Vector2(bar_w, bar_h)), PixelUI.TEXT)
	draw_rect(Rect2(fit.pause_c + Vector2(bar_w * 0.55, -bar_h * 0.5), Vector2(bar_w, bar_h)), PixelUI.TEXT)
	if fit.compact and fit.portrait:
		PixelUI.draw_text(self, I18n.t("touch.drag_hint"), Vector2(fit.safe.position.x, fit.safe.end.y - fit.dp(16)), int(fit.dp(12)), Color(PixelUI.TEXT, 0.7), "medium", HORIZONTAL_ALIGNMENT_CENTER, fit.safe.size.x)

func _pad(center: Vector2, radius: float, color: Color, full: bool, pulse: float) -> void:
	draw_circle(center, radius, Color(0.03, 0.02, 0.08, 0.72))
	draw_arc(center, radius, 0, TAU, 40, Color(color, 0.9), maxf(3.0, radius * 0.055))
	if full:
		draw_circle(center, radius * 0.78, Color(color, 0.15 + pulse * 0.2))
