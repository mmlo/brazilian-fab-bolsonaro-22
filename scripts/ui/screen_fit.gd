class_name ScreenFit
extends RefCounted
## Live layout for the 1280x720 plate.
## Desktop keeps that plate exactly. Phones (and short windows) get a portrait
## or landscape arrangement where the playfield fills the screen and buttons
## stay large enough to hit with a thumb.
##
## `dp(css)` converts a CSS-pixel size into the current logical pixels, so a
## 48px target stays finger-sized after Godot stretches the canvas.

const BASE := Vector2(1280, 720)
const PF := Vector2(270, 360)

var view := BASE
var origin := Vector2.ZERO
var compact := false
var portrait := false
var css_per_logical := 1.0
var safe := Rect2(Vector2.ZERO, BASE)
var playfield := Rect2(370, 0, 540, 720)
var scale := 2.0
var top_bar := Rect2()
var left_col := Rect2()
var right_col := Rect2()
var burst_c := Vector2(1172, 606)
var burst_r := 76.0
var focus_c := Vector2(1002, 634)
var focus_r := 60.0
var pause_c := Vector2(1214, 356)
var pause_r := 34.0

static func capture(node: Node) -> ScreenFit:
	var fit := ScreenFit.new()
	fit._build(node)
	return fit

func dp(css_px: float) -> float:
	return css_px / maxf(css_per_logical, 0.05)

func _build(node: Node) -> void:
	var vp := node.get_viewport()
	if vp != null:
		view = vp.get_visible_rect().size
	if view.x < 8.0 or view.y < 8.0:
		view = BASE
	var win := Vector2(DisplayServer.window_get_size())
	if win.x < 8.0 or win.y < 8.0:
		win = view
	css_per_logical = win.x / view.x
	var short_css := minf(win.x, win.y)
	# Native mobile reports physical pixels; the web export reports CSS pixels.
	if OS.has_feature("mobile") and not OS.has_feature("web"):
		var dpr := maxf(DisplayServer.screen_get_scale(), 1.0)
		css_per_logical /= dpr
		short_css /= dpr
	portrait = view.y > view.x * 1.02
	# 720 is the desktop plate height, so the phone cutoff stays under that.
	compact = portrait or short_css < 680.0
	safe = Rect2(Vector2.ZERO, view)
	if compact:
		_apply_safe_insets()
		_layout_compact()
	else:
		origin = Vector2(maxf(0.0, (view.x - BASE.x) * 0.5), maxf(0.0, (view.y - BASE.y) * 0.5))
		playfield = Rect2(origin + Vector2(370, 0), Vector2(PF.x * 2.0, PF.y * 2.0))
		scale = 2.0
		burst_c = origin + Vector2(1172, 606)
		burst_r = 76.0
		focus_c = origin + Vector2(1002, 634)
		focus_r = 60.0
		pause_c = origin + Vector2(1214, 356)
		pause_r = 34.0

func _apply_safe_insets() -> void:
	var screen := Vector2(DisplayServer.screen_get_size())
	var area := DisplayServer.get_display_safe_area()
	if screen.x < 8.0 or screen.y < 8.0 or area.size.x < 8.0:
		_fallback_insets()
		return
	var left := float(area.position.x) / screen.x * view.x
	var top := float(area.position.y) / screen.y * view.y
	var right := float(screen.x - area.end.x) / screen.x * view.x
	var bottom := float(screen.y - area.end.y) / screen.y * view.y
	if left > view.x * 0.18 or top > view.y * 0.18 or right > view.x * 0.18 or bottom > view.y * 0.22:
		_fallback_insets()
		return
	if portrait and bottom < dp(16):
		bottom = dp(18)
	if top < dp(8):
		top = dp(8)
	left = maxf(left, dp(6))
	right = maxf(right, dp(6))
	safe = Rect2(left, top, maxf(32.0, view.x - left - right), maxf(32.0, view.y - top - bottom))

func _fallback_insets() -> void:
	var top := dp(10)
	var side := dp(8)
	var bottom := dp(18 if portrait else 10)
	safe = Rect2(side, top, maxf(32.0, view.x - side * 2.0), maxf(32.0, view.y - top - bottom))

func _layout_compact() -> void:
	if portrait:
		_layout_portrait()
	else:
		_layout_landscape()

func _layout_portrait() -> void:
	var top_h := dp(92)
	var bot_h := dp(128)
	top_bar = Rect2(safe.position.x, safe.position.y, safe.size.x, top_h)
	var avail := Rect2(safe.position.x + dp(4), safe.position.y + top_h, safe.size.x - dp(8), safe.size.y - top_h - bot_h)
	_place_playfield(avail, true)
	var cy := safe.end.y - bot_h * 0.50
	focus_r = dp(46)
	burst_r = dp(52)
	focus_c = Vector2(safe.position.x + dp(64), cy)
	burst_c = Vector2(safe.end.x - dp(64), cy)
	pause_r = dp(22)
	pause_c = Vector2(safe.end.x - dp(30), safe.position.y + dp(24))

func _layout_landscape() -> void:
	var col := dp(156)
	var margin := dp(4)
	var avail_h := safe.size.y - margin * 2.0
	var ideal := avail_h / PF.y
	var play_w := PF.x * ideal
	var room := safe.size.x - play_w - dp(12)
	col = clampf(room * 0.5, dp(112), dp(210))
	var avail := Rect2(safe.position.x + col, safe.position.y + margin, safe.size.x - col * 2.0, avail_h)
	_place_playfield(avail, false)
	left_col = Rect2(safe.position.x, safe.position.y, maxf(8.0, playfield.position.x - safe.position.x - dp(4)), safe.size.y)
	right_col = Rect2(playfield.end.x + dp(4), safe.position.y, maxf(8.0, safe.end.x - playfield.end.x - dp(4)), safe.size.y)
	var cx := right_col.position.x + right_col.size.x * 0.5
	burst_r = minf(dp(42), right_col.size.x * 0.36)
	focus_r = burst_r * 0.84
	burst_c = Vector2(cx, right_col.end.y - burst_r - dp(6))
	focus_c = Vector2(cx, burst_c.y - burst_r - focus_r - dp(12))
	pause_r = dp(18)
	pause_c = Vector2(right_col.end.x - pause_r - dp(4), right_col.position.y + pause_r + dp(4))

func _place_playfield(avail: Rect2, pin_top: bool) -> void:
	var raw := minf(avail.size.x / PF.x, avail.size.y / PF.y)
	raw = maxf(raw, 0.5)
	var snapped := floorf(raw)
	if snapped >= 2.0 and snapped >= raw * 0.94:
		raw = snapped
	scale = raw
	var sz := PF * scale
	var x := avail.position.x + (avail.size.x - sz.x) * 0.5
	var y := avail.position.y if pin_top else avail.position.y + (avail.size.y - sz.y) * 0.5
	playfield = Rect2(x, y, sz.x, sz.y)
