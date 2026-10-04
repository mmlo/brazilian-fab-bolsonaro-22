class_name PixelUI
extends RefCounted
## Starveil pixel UI kit: one palette, hard-edged chamfered panels and text helpers
## shared by the HUD, menus and title screen.

const INK := Color(0.035, 0.03, 0.09)
const PANEL := Color(0.06, 0.05, 0.14, 0.94)
const PANEL_HI := Color(0.12, 0.10, 0.26, 0.96)
const LINE := Color(0.33, 0.28, 0.58)
const CYAN := Color(0.37, 0.95, 1.0)
const GOLD := Color(1.0, 0.81, 0.35)
const PINK := Color(1.0, 0.31, 0.64)
const VIOLET := Color(0.62, 0.45, 1.0)
const RED := Color(1.0, 0.33, 0.38)
const TEXT := Color(0.93, 0.95, 1.0)
const MUTED := Color(0.56, 0.57, 0.76)

static var _fonts := {}

static func font(kind := "regular") -> Font:
	if not _fonts.has(kind):
		var path: String = {
			"regular": "res://assets/template/fonts/ui_regular.tres",
			"medium": "res://assets/template/fonts/ui_medium.tres",
			"bold": "res://assets/template/fonts/ui_bold.tres",
			"title": "res://assets/template/fonts/display/display_title.tres",
			"display": "res://assets/template/fonts/display/display_bold.tres",
		}.get(kind, "res://assets/template/fonts/ui_regular.tres")
		_fonts[kind] = load(path)
	return _fonts[kind]

## Chamfered pixel StyleBox (corner_detail 1 turns radii into 45-degree notches).
static func box(bg: Color, border: Color, bw := 2, notch := 6, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(notch)
	s.corner_detail = 1
	s.anti_aliasing = false
	s.set_content_margin_all(pad)
	return s

## Immediate-mode pixel panel for _draw(): fill, 2px frame, notched corners, top glint.
static func draw_panel(ci: CanvasItem, r: Rect2, border := LINE, bg := PANEL, glint := true) -> void:
	var n := 6.0
	var pts := PackedVector2Array([
		r.position + Vector2(n, 0), Vector2(r.end.x - n, r.position.y), Vector2(r.end.x, r.position.y + n),
		Vector2(r.end.x, r.end.y - n), Vector2(r.end.x - n, r.end.y), Vector2(r.position.x + n, r.end.y),
		Vector2(r.position.x, r.end.y - n), Vector2(r.position.x, r.position.y + n)])
	ci.draw_colored_polygon(pts, bg)
	var loop := pts.duplicate()
	loop.append(pts[0])
	ci.draw_polyline(loop, border, 2.0)
	if glint:
		ci.draw_line(r.position + Vector2(n + 4, 4), Vector2(r.end.x - n - 4, r.position.y + 4), Color(border, 0.35), 1.0)

static func draw_text(ci: CanvasItem, text: String, pos: Vector2, size: int, color := TEXT, kind := "bold", align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, shadow := true) -> void:
	var f := font(kind)
	if shadow:
		ci.draw_string(f, pos + Vector2(2, 2), text, align, width, size, Color(0, 0, 0.05, 0.75 * color.a))
	ci.draw_string(f, pos, text, align, width, size, color)

## Word-wrapped text (CJK wraps per glyph). `pos` is the first baseline.
static func draw_wrapped(ci: CanvasItem, text: String, pos: Vector2, width: float, size: int, color := TEXT, kind := "medium", max_lines := -1) -> void:
	var f := font(kind)
	ci.draw_multiline_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, color, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND)

static func text_width(text: String, size: int, kind := "bold") -> float:
	return font(kind).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

## Segmented meter (pixel blocks).
static func draw_meter(ci: CanvasItem, r: Rect2, value: float, segments: int, fill: Color, empty := Color(1, 1, 1, 0.08)) -> void:
	var gap := 3.0
	var w := (r.size.x - gap * (segments - 1)) / segments
	for i in range(segments):
		var seg := Rect2(r.position.x + i * (w + gap), r.position.y, w, r.size.y)
		var k := clampf(value * segments - i, 0.0, 1.0)
		ci.draw_rect(seg, empty)
		if k > 0.0:
			ci.draw_rect(Rect2(seg.position, Vector2(seg.size.x * k, seg.size.y)), fill)
			ci.draw_rect(Rect2(seg.position, Vector2(seg.size.x * k, 2)), Color(1, 1, 1, 0.35))

static func key_cap(ci: CanvasItem, text: String, pos: Vector2, size := 14, accent := CYAN) -> float:
	var w := text_width(text, size, "bold") + 14.0
	var r := Rect2(pos + Vector2(0, -size - 4), Vector2(w, size + 10))
	ci.draw_rect(r, Color(accent, 0.14))
	ci.draw_rect(r, Color(accent, 0.8), false, 2.0)
	draw_text(ci, text, pos + Vector2(7, 1), size, TEXT, "bold", HORIZONTAL_ALIGNMENT_LEFT, -1, false)
	return w
