extends Control
## On-screen touch controls for phones (landscape). Drag anywhere outside the
## buttons for relative steering; hold FOCUS; tap BURST; PAUSE top-right.
var game: StarveilGame
var _fingers := {} # index -> role ("drag" | "focus" | "burst" | "pause")
var _t := 0.0
var _burst_flash := 0.0

const BURST_C := Vector2(1172, 606)
const BURST_R := 76.0
const FOCUS_C := Vector2(1002, 634)
const FOCUS_R := 60.0
const PAUSE_C := Vector2(1214, 356)
const PAUSE_R := 34.0

func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
		GameInput.device = "touch"
		GameInput.touch_seen = true

func _active() -> bool:
	return game != null and not game.paused and game.state != "results"

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			if not _active():
				return
			var role := "drag"
			if st.position.distance_to(BURST_C) < BURST_R + 10:
				role = "burst"
				GameInput.virtual_bomb = true
				_burst_flash = 0.3
			elif st.position.distance_to(FOCUS_C) < FOCUS_R + 10:
				role = "focus"
			elif st.position.distance_to(PAUSE_C) < PAUSE_R + 12:
				role = "pause"
				game.set_paused(true)
			_fingers[st.index] = role
		else:
			_fingers.erase(st.index)
		GameInput.virtual_focus = _fingers.values().has("focus")
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _fingers.get(sd.index, "") == "drag" and _active():
			game.add_touch_drag(sd.relative)
		elif _fingers.get(sd.index, "") == "focus" and sd.position.distance_to(FOCUS_C) > FOCUS_R * 1.8:
			# sliding off the focus pad turns it into a steering finger
			_fingers[sd.index] = "drag"
			GameInput.virtual_focus = false

func _process(delta: float) -> void:
	_t += delta
	_burst_flash = maxf(0.0, _burst_flash - delta)
	visible = GameInput.device == "touch"
	if not _active():
		_fingers.clear()
		GameInput.virtual_focus = false
	if visible:
		queue_redraw()

func _draw() -> void:
	if game == null or game.state == "results":
		return
	var full: bool = game.energy >= GameConfig.ENERGY_MAX
	# BURST
	var bc := PixelUI.CYAN if full else Color(0.35, 0.4, 0.6)
	var pulse := (0.5 + 0.5 * sin(_t * 8.0)) if full else 0.0
	draw_circle(BURST_C, BURST_R, Color(0.03, 0.02, 0.08, 0.72))
	draw_arc(BURST_C, BURST_R, 0, TAU, 40, Color(bc, 0.9), 4.0)
	var k: float = clampf(game.energy / GameConfig.ENERGY_MAX, 0, 1)
	draw_arc(BURST_C, BURST_R - 9, -PI * 0.5, -PI * 0.5 + TAU * k, 40, Color(bc, 0.8), 6.0)
	if full:
		draw_circle(BURST_C, BURST_R - 16, Color(bc, 0.15 + pulse * 0.2))
	if _burst_flash > 0.0:
		draw_circle(BURST_C, BURST_R, Color(1, 1, 1, _burst_flash))
	PixelUI.draw_text(self, I18n.t("touch.burst"), BURST_C + Vector2(-70, 8), 20, Color.WHITE if full else PixelUI.MUTED, "bold", HORIZONTAL_ALIGNMENT_CENTER, 140)
	# FOCUS
	var held := GameInput.virtual_focus
	draw_circle(FOCUS_C, FOCUS_R, Color(0.03, 0.02, 0.08, 0.72) if not held else Color(PixelUI.PINK, 0.35))
	draw_arc(FOCUS_C, FOCUS_R, 0, TAU, 36, Color(PixelUI.PINK, 0.9), 3.0)
	draw_circle(FOCUS_C + Vector2(0, -16), 5.0, Color.WHITE)
	draw_arc(FOCUS_C + Vector2(0, -16), 9.0, 0, TAU, 20, PixelUI.PINK, 2.0)
	PixelUI.draw_text(self, I18n.t("touch.focus"), FOCUS_C + Vector2(-60, 22), 17, Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER, 120)
	# PAUSE
	draw_circle(PAUSE_C, PAUSE_R, Color(0.03, 0.02, 0.08, 0.72))
	draw_arc(PAUSE_C, PAUSE_R, 0, TAU, 28, Color(PixelUI.TEXT, 0.7), 2.0)
	draw_rect(Rect2(PAUSE_C + Vector2(-9, -11), Vector2(6, 22)), PixelUI.TEXT)
	draw_rect(Rect2(PAUSE_C + Vector2(3, -11), Vector2(6, 22)), PixelUI.TEXT)
