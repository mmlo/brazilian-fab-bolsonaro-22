extends RefCounted
## Holographic cockpit UI kit for Stargrave: chamfered glass plates, corner brackets, scanlines,
## segmented meters, keycap prompts, glow/chromatic text and a CRT overlay. Everything is drawn
## in code (no textures) so it stays crisp at any resolution and costs a handful of draw calls.

const CYAN := Color(0.38, 0.91, 0.96)
const ORANGE := Color(1.0, 0.49, 0.27)
const AMBER := Color(1.0, 0.78, 0.40)
const MAGENTA := Color(1.0, 0.36, 0.70)
const RED := Color(1.0, 0.24, 0.20)
const INK := Color(0.93, 0.98, 1.0)
const MUTED := Color(0.62, 0.70, 0.82)
const GLASS_TOP := Color(0.040, 0.085, 0.150, 0.80)
const GLASS_BOTTOM := Color(0.010, 0.018, 0.048, 0.88)
const SHADOW := Color(0.0, 0.005, 0.03, 0.85)

const CRT_SHADER := """
shader_type canvas_item;
uniform float scan_alpha = 0.055;
uniform float vignette = 0.62;
uniform float flicker = 0.0;
void fragment() {
	float scan = 0.5 + 0.5 * sin(FRAGCOORD.y * 2.0943951);
	vec2 d = (UV - 0.5) * vec2(1.0, 0.82);
	float v = smoothstep(0.30, 0.78, length(d));
	COLOR = vec4(0.0, 0.004, 0.02, scan * scan_alpha + v * vignette + flicker);
}
"""

const SHINE_SHADER := """
shader_type canvas_item;
uniform float sweep = -2000.0;
varying vec2 local_pos;
void vertex() {
	local_pos = VERTEX;
}
void fragment() {
	float d = local_pos.x + local_pos.y * 0.5 - sweep;
	float band = exp(-d * d / 1100.0);
	float lum = max(COLOR.r, max(COLOR.g, COLOR.b));
	COLOR.rgb += vec3(band * 0.9 * smoothstep(0.4, 0.85, lum));
}
"""

static var _key_styles: Dictionary = {}


## Full-screen scanline + vignette overlay drawn above the scene (never receives input).
static func add_crt_overlay(parent: Node, size: Vector2, z: int = -1, vignette: float = 0.62) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = "CrtOverlay"
	overlay.size = size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = z
	var shader := Shader.new()
	shader.code = CRT_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("vignette", vignette)
	overlay.material = material
	parent.add_child(overlay)
	return overlay


static func shine_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SHINE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func ease_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3.0)


static func ease_back(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	var c := 1.9
	return 1.0 + (c + 1.0) * pow(k - 1.0, 3.0) + c * pow(k - 1.0, 2.0)


static func chamfer_points(rect: Rect2, cut: float) -> PackedVector2Array:
	var p := rect.position
	var e := rect.end
	return PackedVector2Array([
		Vector2(p.x + cut, p.y), Vector2(e.x, p.y), Vector2(e.x, e.y - cut),
		Vector2(e.x - cut, e.y), Vector2(p.x, e.y), Vector2(p.x, p.y + cut),
	])


## Glass plate: vertical gradient, rim light, scanlines, thin outline and bright corner brackets.
static func panel(ci: CanvasItem, rect: Rect2, accent: Color = CYAN, alpha: float = 1.0, cut: float = 12.0, scan: bool = true, bracket_len: float = 12.0) -> void:
	if rect.size.x < 8.0 or rect.size.y < 8.0 or alpha <= 0.0:
		if rect.size.x >= 1.0 and rect.size.y >= 1.0 and alpha > 0.0:
			ci.draw_rect(rect, Color(accent, 0.8 * alpha))
		return
	cut = maxf(1.0, minf(cut, minf(rect.size.x, rect.size.y) * 0.5 - 2.0))
	var pts := chamfer_points(rect, cut)
	var cols := PackedColorArray()
	for pt: Vector2 in pts:
		var k := clampf((pt.y - rect.position.y) / rect.size.y, 0.0, 1.0)
		var c := GLASS_TOP.lerp(GLASS_BOTTOM, k)
		c.a *= alpha
		cols.append(c)
	ci.draw_polygon(pts, cols)
	if scan:
		var y := rect.position.y + 3.0
		var line := Color(accent, 0.045 * alpha)
		while y < rect.end.y - 1.0:
			var lx := rect.position.x + maxf(0.0, cut - (y - rect.position.y)) + 1.0
			var rx := rect.end.x - maxf(0.0, cut - (rect.end.y - y)) - 1.0
			ci.draw_line(Vector2(lx, y), Vector2(rx, y), line, 1.0)
			y += 3.0
	ci.draw_line(Vector2(rect.position.x + cut + 1.0, rect.position.y + 1.5), Vector2(rect.end.x - 1.0, rect.position.y + 1.5), Color(accent, 0.30 * alpha), 1.0)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, Color(accent, 0.40 * alpha), 1.0)
	if bracket_len > 0.0:
		brackets(ci, rect.grow(3.0), bracket_len, Color(accent, 0.85 * alpha), 2.0)


static func brackets(ci: CanvasItem, rect: Rect2, length: float, color: Color, width: float = 2.0) -> void:
	var p := rect.position
	var e := rect.end
	for corner: Array in [[p, Vector2(1, 1)], [Vector2(e.x, p.y), Vector2(-1, 1)], [e, Vector2(-1, -1)], [Vector2(p.x, e.y), Vector2(1, -1)]]:
		var o: Vector2 = corner[0]
		var s: Vector2 = corner[1]
		ci.draw_polyline(PackedVector2Array([o + Vector2(0, s.y * length), o, o + Vector2(s.x * length, 0)]), color, width)


## Skewed segmented meter; the last partially-filled segment fades in proportionally.
static func seg_bar(ci: CanvasItem, rect: Rect2, value: float, segments: int, color: Color, skew: float = 4.0, gap: float = 3.0, pulse: float = 0.0) -> void:
	var sw := (rect.size.x - skew - gap * (segments - 1)) / segments
	var filled := clampf(value, 0.0, 1.0) * segments
	for i in segments:
		var x := rect.position.x + i * (sw + gap)
		var poly := PackedVector2Array([
			Vector2(x + skew, rect.position.y), Vector2(x + sw + skew, rect.position.y),
			Vector2(x + sw, rect.end.y), Vector2(x, rect.end.y),
		])
		var amount := clampf(filled - i, 0.0, 1.0)
		ci.draw_colored_polygon(poly, Color(0.07, 0.10, 0.17, 0.85))
		if amount > 0.0:
			var c := color.lightened(pulse * 0.35)
			c.a = (0.35 + amount * 0.65) * color.a
			ci.draw_colored_polygon(poly, c)
			ci.draw_line(poly[0], poly[1], Color(1, 1, 1, 0.45 * amount * color.a), 1.0)
		else:
			var closed := poly.duplicate()
			closed.append(poly[0])
			ci.draw_polyline(closed, Color(color, 0.18 * color.a), 1.0)


## A small 3D keycap ("[ENTER]" prompt chip). Returns the drawn width.
static func keycap(ci: CanvasItem, font: Font, pos: Vector2, label: String, size: int, color: Color = INK, alpha: float = 1.0) -> float:
	var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var h := float(size) + 10.0
	var w := maxf(h, text_w + 12.0)
	var face := Rect2(pos, Vector2(w, h))
	var base := _key_style(Color(0.0, 0.02, 0.05, 0.9 * alpha), Color(color, 0.0))
	var top := _key_style(Color(0.10, 0.17, 0.26, 0.96 * alpha), Color(color, 0.55 * alpha))
	ci.draw_style_box(base, Rect2(face.position + Vector2(0, 3), face.size))
	ci.draw_style_box(top, face)
	ci.draw_line(face.position + Vector2(3, 1.5), Vector2(face.end.x - 3, face.position.y + 1.5), Color(1, 1, 1, 0.22 * alpha), 1.0)
	ci.draw_string(font, Vector2(pos.x, pos.y + h * 0.5 + float(size) * 0.36), label, HORIZONTAL_ALIGNMENT_CENTER, w, size, Color(color, alpha))
	return w


static func _key_style(fill: Color, border: Color) -> StyleBoxFlat:
	var key := "%s|%s" % [fill.to_html(), border.to_html()]
	if _key_styles.has(key):
		return _key_styles[key]
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(3)
	if _key_styles.size() > 96:
		_key_styles.clear()
	_key_styles[key] = style
	return style


## Text with a soft coloured glow and a dark keyline for legibility over busy art.
static func glow_text(ci: CanvasItem, font: Font, pos: Vector2, text: String, size: int, color: Color, glow: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, strength: float = 1.0) -> void:
	if strength > 0.0:
		ci.draw_string_outline(font, pos, text, align, width, size, maxi(4, size / 3), Color(glow, glow.a * 0.09 * strength))
		ci.draw_string_outline(font, pos, text, align, width, size, maxi(3, size / 6), Color(glow, glow.a * 0.20 * strength))
	ci.draw_string_outline(font, pos, text, align, width, size, maxi(2, size / 14), Color(SHADOW, SHADOW.a * color.a))
	ci.draw_string(font, pos, text, align, width, size, color)


## Holographic RGB split behind the main glyphs; `jitter` offsets the ghosts on glitch frames.
static func chroma_text(ci: CanvasItem, font: Font, pos: Vector2, text: String, size: int, color: Color, glow: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, split: float = 2.0) -> void:
	ci.draw_string(font, pos + Vector2(-split, 0), text, align, width, size, Color(1.0, 0.22, 0.55, 0.34 * color.a))
	ci.draw_string(font, pos + Vector2(split, 0), text, align, width, size, Color(0.2, 0.9, 1.0, 0.34 * color.a))
	glow_text(ci, font, pos, text, size, color, glow, align, width)


static func chevron(ci: CanvasItem, center: Vector2, size: float, color: Color, width: float = 2.5) -> void:
	ci.draw_polyline(PackedVector2Array([center + Vector2(-size * 0.5, -size), center + Vector2(size * 0.5, 0), center + Vector2(-size * 0.5, size)]), color, width)


## Diagonal hazard stripes clipped exactly to `rect`.
static func stripes(ci: CanvasItem, rect: Rect2, color: Color, spacing: float = 22.0, thickness: float = 10.0, offset: float = 0.0) -> void:
	var clip := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var h := rect.size.y
	var x := rect.position.x - h + fposmod(offset, spacing) - spacing
	while x < rect.end.x:
		var stripe := PackedVector2Array([
			Vector2(x + h, rect.position.y), Vector2(x + h + thickness, rect.position.y),
			Vector2(x + thickness, rect.end.y), Vector2(x, rect.end.y),
		])
		for part: PackedVector2Array in Geometry2D.intersect_polygons(stripe, clip):
			if part.size() >= 3 and _area(part) > 2.0:
				ci.draw_colored_polygon(part, color)
		x += spacing


## Hull heart used by the HUD and results (kept from the original art direction).
static func heart(ci: CanvasItem, center: Vector2, r: float, color: Color, outline_only: bool = false) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var hx := 16.0 * pow(sin(a), 3.0)
		var hy := -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
		pts.append(center + Vector2(hx, hy) * (r / 16.0))
	if outline_only:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, color, 1.5)
	else:
		ci.draw_colored_polygon(pts, color)


static func _area(poly: PackedVector2Array) -> float:
	var total := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		total += a.x * b.y - b.x * a.y
	return absf(total) * 0.5
