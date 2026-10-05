class_name FactionMarks
extends RefCounted
## Original pixel flags for the Brazilian left organisations named in the game.
## Cloth sits on a short pole. Each emblem follows the public composition:
## PT white star, CUT white wordmark with a gold bar, MST couple and facão
## over a green map inside a white disc, MTST white house on red over black,
## PSOL red star on yellow, PCdoB gold star with hammer and sickle, UNE white
## wordmark, PSTU raised fist, PCB gold star.

const RED := Color(0.82, 0.06, 0.10)
const GOLD := Color(0.98, 0.78, 0.10)
const WHITE := Color(0.96, 0.96, 0.94)
const BLACK := Color(0.07, 0.04, 0.05)
const YELLOW := Color(1.0, 0.82, 0.05)
const BLUE := Color(0.02, 0.14, 0.48)
const GREEN := Color(0.10, 0.52, 0.22)
const WOOD := Color(0.40, 0.26, 0.12)
const BLADE := Color(0.93, 0.94, 0.90)

const ALL: Array = [
	["pt", "PT"], ["cut", "CUT"], ["mst", "MST"], ["mtst", "MTST"], ["psol", "PSOL"],
	["pcdob", "PCdoB"], ["une", "UNE"], ["pstu", "PSTU"], ["pcb", "PCB"],
]

## 5x7 wordmarks. Rows are left to right, '#' is ink.
const _WORD := {
	"C": ["#####", "#....", "#....", "#....", "#....", "#....", "#####"],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", "#####"],
}

static func for_kind(kind: String, salt: int) -> String:
	match kind:
		"lancer":
			return "cut"
		"frigate":
			return "mst"
		"carrier":
			return "pt"
		_:
			var pool := ["psol", "pcdob", "mtst", "pstu", "une", "pcb"]
			return pool[posmod(salt, pool.size())]

static func for_context(boss: bool, wave_idx: int) -> Array:
	if boss:
		return ["pt", "cut", "mst", "mtst"]
	match wave_idx:
		0:
			return ["psol", "pcdob", "mtst", "pstu", "une", "pcb"]
		1:
			return ["cut"]
		2:
			return ["mst", "pt", "mtst"]
		_:
			return ["pt", "cut", "mst"]

static func label_of(id: String) -> String:
	for row: Array in ALL:
		if row[0] == id:
			return str(row[1])
	return id.to_upper()

static func draw(ci: CanvasItem, id: String, rect: Rect2) -> void:
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	var u := minf(rect.size.x / 18.0, rect.size.y / 12.0)
	var o := rect.position + (rect.size - Vector2(18, 12) * u) * 0.5
	ci.draw_rect(Rect2(o, Vector2(u * 1.15, 12.0 * u)), WOOD)
	ci.draw_rect(Rect2(o + Vector2(0, 11.1 * u), Vector2(2.2 * u, u * 0.9)), GOLD)
	var cloth := Rect2(o + Vector2(1.5 * u, 0.35 * u), Vector2(16.0 * u, 10.0 * u))
	ci.draw_rect(cloth.grow(maxf(u * 0.35, 0.45)), Color(0.02, 0.01, 0.02, 0.92))
	match id:
		"pt":
			_fill(ci, cloth, RED)
			_star(ci, cloth.position + cloth.size * Vector2(0.50, 0.50), cloth.size.y * 0.40, WHITE)
		"cut":
			_fill(ci, cloth, RED)
			_wordmark(ci, cloth, "CUT", WHITE, GOLD)
		"mst":
			_mst(ci, cloth)
		"mtst":
			_mtst(ci, cloth)
		"psol":
			_fill(ci, cloth, YELLOW)
			ci.draw_rect(cloth, RED, false, maxf(cloth.size.y * 0.045, 0.7))
			_star(ci, cloth.position + cloth.size * Vector2(0.50, 0.52), cloth.size.y * 0.36, RED)
		"pcdob":
			_pcdob(ci, cloth)
		"une":
			_fill(ci, cloth, BLUE)
			_wordmark(ci, cloth, "UNE", WHITE, WHITE)
		"pstu":
			_fill(ci, cloth, RED)
			_fist(ci, cloth)
		"pcb":
			_fill(ci, cloth, RED)
			_star(ci, cloth.position + cloth.size * Vector2(0.50, 0.50), cloth.size.y * 0.40, GOLD)
		_:
			_fill(ci, cloth, RED)
			_star(ci, cloth.position + cloth.size * 0.5, cloth.size.y * 0.32, GOLD)

static func _fill(ci: CanvasItem, cloth: Rect2, color: Color) -> void:
	ci.draw_rect(cloth, color)

static func _wordmark(ci: CanvasItem, cloth: Rect2, text: String, ink: Color, bar: Color) -> void:
	var cols := 5
	var rows := 7
	var gap := 1
	var units := text.length() * cols + maxi(text.length() - 1, 0) * gap
	var unit := minf(cloth.size.x * 0.86 / float(units), cloth.size.y * 0.60 / float(rows))
	if unit < 0.4:
		return
	var total_w := float(units) * unit
	var total_h := float(rows) * unit
	var origin := cloth.position + Vector2((cloth.size.x - total_w) * 0.5, cloth.size.y * 0.14)
	var x := origin.x
	for i in text.length():
		var ch := text.substr(i, 1)
		var glyph: Array = _WORD["C"]
		if _WORD.has(ch):
			glyph = _WORD[ch]
		for ry in glyph.size():
			var row: String = glyph[ry]
			for rx in row.length():
				if row[rx] == "#":
					ci.draw_rect(Rect2(Vector2(x + float(rx) * unit, origin.y + float(ry) * unit), Vector2(unit, unit)), ink)
		x += float(cols + gap) * unit
	var bar_h := maxf(unit * 0.95, 1.0)
	var bar_y := origin.y + total_h + unit * 0.45
	var limit := cloth.end.y - bar_h - unit * 0.15
	if bar_y > limit:
		bar_y = limit
	ci.draw_rect(Rect2(Vector2(origin.x - unit * 0.3, bar_y), Vector2(total_w + unit * 0.6, bar_h)), bar)

static func _star(ci: CanvasItem, c: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + float(i) * PI / 5.0
		var rad := radius if i % 2 == 0 else radius * 0.40
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	ci.draw_colored_polygon(pts, color)

static func _fan(ci: CanvasItem, pts: PackedVector2Array, color: Color) -> void:
	if pts.size() < 3:
		return
	var c := Vector2.ZERO
	for i in pts.size():
		c += pts[i]
	c /= float(pts.size())
	for i in pts.size():
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		ci.draw_colored_polygon(PackedVector2Array([c, a, b]), color)

static func _quad(ci: CanvasItem, a: Vector2, b: Vector2, thickness: float, color: Color) -> void:
	var dir := b - a
	var span := dir.length()
	if span < 0.001:
		return
	var n := Vector2(-dir.y, dir.x) / span * thickness * 0.5
	ci.draw_colored_polygon(PackedVector2Array([a + n, b + n, b - n, a - n]), color)

static func _stroke_arc(ci: CanvasItem, center: Vector2, radius: float, a0: float, a1: float, width: float, color: Color, steps: int) -> void:
	var d0 := Vector2(cos(a0), sin(a0))
	var prev_o := center + d0 * (radius + width * 0.5)
	var prev_i := center + d0 * maxf(0.4, radius - width * 0.5)
	for s in steps:
		var a := lerpf(a0, a1, float(s + 1) / float(steps))
		var d := Vector2(cos(a), sin(a))
		var outer := center + d * (radius + width * 0.5)
		var inner := center + d * maxf(0.4, radius - width * 0.5)
		ci.draw_colored_polygon(PackedVector2Array([prev_o, outer, inner]), color)
		ci.draw_colored_polygon(PackedVector2Array([prev_o, inner, prev_i]), color)
		prev_o = outer
		prev_i = inner

static func _mst(ci: CanvasItem, cloth: Rect2) -> void:
	_fill(ci, cloth, RED)
	var c := cloth.position + cloth.size * Vector2(0.50, 0.50)
	var rad := minf(cloth.size.x, cloth.size.y) * 0.46
	ci.draw_circle(c, rad, WHITE)
	# Wide north, northeast horn, narrow south. Reads as the map even when small.
	var shape: Array[Vector2] = [
		Vector2(-0.20, -0.70), Vector2(0.22, -0.78), Vector2(0.48, -0.58), Vector2(0.95, -0.15),
		Vector2(0.72, 0.10), Vector2(0.50, 0.32), Vector2(0.36, 0.55), Vector2(0.16, 0.82),
		Vector2(0.02, 1.0), Vector2(-0.14, 0.78), Vector2(-0.22, 0.48), Vector2(-0.38, 0.22),
		Vector2(-0.78, 0.05), Vector2(-0.62, -0.22), Vector2(-0.50, -0.48), Vector2(-0.28, -0.62),
	]
	var map := PackedVector2Array()
	for p in shape:
		map.append(c + p * rad * 0.90)
	_fan(ci, map, GREEN)
	# Man and woman, joined hat-head-body so the pair stays a silhouette when tiny.
	var hx := -0.10
	ci.draw_rect(Rect2(c + Vector2(hx - 0.15, 0.02) * rad, Vector2(0.30, 0.46) * rad), BLACK)
	ci.draw_circle(c + Vector2(hx, -0.16) * rad, rad * 0.15, BLACK)
	ci.draw_rect(Rect2(c + Vector2(hx - 0.32, -0.28) * rad, Vector2(0.54, 0.10) * rad), BLACK)
	ci.draw_rect(Rect2(c + Vector2(hx - 0.12, -0.44) * rad, Vector2(0.24, 0.18) * rad), BLACK)
	var wx := 0.28
	ci.draw_rect(Rect2(c + Vector2(wx - 0.13, 0.08) * rad, Vector2(0.26, 0.40) * rad), Color(0.75, 0.05, 0.08))
	ci.draw_circle(c + Vector2(wx, -0.08) * rad, rad * 0.13, BLACK)
	var hand := c + Vector2(hx + 0.14, -0.22) * rad
	var tip := c + Vector2(0.78, -0.84) * rad
	var dir := (tip - hand).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var bw := rad * 0.09
	ci.draw_colored_polygon(PackedVector2Array([
		hand - nrm * bw * 0.7,
		tip - nrm * bw * 0.2,
		tip + nrm * bw * 0.85,
		hand + nrm * bw * 0.15,
	]), BLACK)
	ci.draw_colored_polygon(PackedVector2Array([
		hand - nrm * bw * 0.28,
		tip - nrm * bw * 0.05,
		tip + nrm * bw * 0.48,
		hand + nrm * bw * 0.02,
	]), BLADE)
	ci.draw_arc(c, rad, 0.0, TAU, 40, BLACK, maxf(1.0, rad * 0.07))

static func _mtst(ci: CanvasItem, cloth: Rect2) -> void:
	_fill(ci, cloth, RED)
	var o := cloth.position
	var w := cloth.size.x
	var h := cloth.size.y
	ci.draw_rect(Rect2(o + Vector2(0, h * 0.50), Vector2(w, h * 0.50)), BLACK)
	var roof := PackedVector2Array([
		o + Vector2(w * 0.16, h * 0.60),
		o + Vector2(w * 0.50, h * 0.16),
		o + Vector2(w * 0.84, h * 0.60),
	])
	ci.draw_colored_polygon(roof, WHITE)
	ci.draw_rect(Rect2(o + Vector2(w * 0.28, h * 0.58), Vector2(w * 0.44, h * 0.30)), WHITE)
	ci.draw_rect(Rect2(o + Vector2(w * 0.44, h * 0.70), Vector2(w * 0.12, h * 0.18)), BLACK)

static func _pcdob(ci: CanvasItem, cloth: Rect2) -> void:
	_fill(ci, cloth, RED)
	var o := cloth.position
	var w := cloth.size.x
	var h := cloth.size.y
	_star(ci, o + Vector2(w * 0.50, h * 0.24), h * 0.16, GOLD)
	var sc := o + Vector2(w * 0.58, h * 0.64)
	var sr := h * 0.22
	var sw := maxf(h * 0.072, 1.0)
	var a0 := -1.70
	var a1 := 1.05
	_stroke_arc(ci, sc, sr, a0, a1, sw, GOLD, 12)
	var tip := sc + Vector2(cos(a0), sin(a0)) * sr
	ci.draw_colored_polygon(PackedVector2Array([
		tip + Vector2(-sw * 0.2, sw * 0.55),
		tip + Vector2(sw * 0.7, -sw * 0.1),
		tip + Vector2(-sr * 0.05, -sr * 0.42),
	]), GOLD)
	var butt := sc + Vector2(cos(a1), sin(a1)) * sr
	_quad(ci, butt, butt + Vector2(h * 0.02, h * 0.10), sw * 0.75, GOLD)
	var h0 := o + Vector2(w * 0.26, h * 0.82)
	var h1 := o + Vector2(w * 0.52, h * 0.52)
	_quad(ci, h0, h1, h * 0.065, GOLD)
	var dir := (h1 - h0).normalized()
	var n := Vector2(-dir.y, dir.x)
	var head := h1 + dir * h * 0.01
	_quad(ci, head - n * h * 0.15, head + n * h * 0.15, h * 0.085, GOLD)

static func _fist(ci: CanvasItem, cloth: Rect2) -> void:
	var u := minf(cloth.size.x, cloth.size.y)
	var c := cloth.position + cloth.size * Vector2(0.50, 0.60)
	ci.draw_rect(Rect2(c + Vector2(-u * 0.08, u * 0.04), Vector2(u * 0.16, u * 0.28)), GOLD)
	ci.draw_circle(c + Vector2(0.0, -u * 0.04), u * 0.18, GOLD)
	for i in 4:
		var kx := -0.12 + float(i) * 0.080
		ci.draw_circle(c + Vector2(u * kx, -u * 0.16), u * 0.048, GOLD)
	_quad(ci, c + Vector2(-u * 0.16, u * 0.06), c + Vector2(-u * 0.02, -u * 0.08), u * 0.07, GOLD)
	ci.draw_circle(c + Vector2(-u * 0.02, -u * 0.09), u * 0.045, GOLD)
