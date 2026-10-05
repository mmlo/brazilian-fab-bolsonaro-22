class_name FactionMarks
extends RefCounted
## Original pixel flags for the Brazilian left organisations named in the game.
## Cloth is a 16x10 grid on a short pole. Symbols follow the public colours of
## each group: PT white star on red, CUT white sigla, MST rural worker in a
## white disc, MTST roof, PSOL red star on yellow, PCdoB hammer and sickle,
## UNE blue sigla, PSTU raised fist, PCB yellow star.

const RED := Color(0.86, 0.07, 0.10)
const RED_DEEP := Color(0.62, 0.02, 0.06)
const GOLD := Color(0.98, 0.82, 0.12)
const WHITE := Color(0.96, 0.96, 0.94)
const BLACK := Color(0.08, 0.05, 0.06)
const YELLOW := Color(1.0, 0.84, 0.08)
const BLUE := Color(0.02, 0.16, 0.52)
const GREEN := Color(0.12, 0.48, 0.20)
const WOOD := Color(0.40, 0.26, 0.12)

const ALL: Array = [
	["pt", "PT"], ["cut", "CUT"], ["mst", "MST"], ["mtst", "MTST"], ["psol", "PSOL"],
	["pcdob", "PCdoB"], ["une", "UNE"], ["pstu", "PSTU"], ["pcb", "PCB"],
]

const _GLYPHS := {
	"A": [".#.", "#.#", "###", "#.#", "#.#"],
	"B": ["##.", "#.#", "##.", "#.#", "###"],
	"C": ["###", "#..", "#..", "#..", "###"],
	"D": ["##.", "#.#", "#.#", "#.#", "##."],
	"E": ["###", "#..", "##.", "#..", "###"],
	"M": ["#.#", "###", "#.#", "#.#", "#.#"],
	"N": ["#.#", "##.", "#.#", "#.#", "#.#"],
	"O": ["###", "#.#", "#.#", "#.#", "###"],
	"P": ["##.", "#.#", "##.", "#..", "#.."],
	"S": [".##", "#..", ".#.", "..#", "##."],
	"T": ["###", ".#.", ".#.", ".#.", ".#."],
	"U": ["#.#", "#.#", "#.#", "#.#", "###"],
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
			_star(ci, cloth.position + cloth.size * Vector2(0.50, 0.48), cloth.size.y * 0.40, WHITE)
		"cut":
			_fill(ci, cloth, RED_DEEP)
			_cell(ci, cloth, 1, 8, 14, 1, GOLD)
			_letters(ci, cloth, "CUT", 2, WHITE)
		"mst":
			_fill(ci, cloth, RED)
			ci.draw_circle(cloth.position + cloth.size * Vector2(0.46, 0.52), cloth.size.y * 0.40, WHITE)
			_cell(ci, cloth, 3, 7, 7, 2, GREEN)
			_cell(ci, cloth, 5, 2, 3, 1, BLACK)
			_cell(ci, cloth, 6, 1, 1, 1, BLACK)
			_cell(ci, cloth, 6, 3, 1, 1, BLACK)
			_cell(ci, cloth, 5, 4, 2, 3, BLACK)
			_cell(ci, cloth, 8, 2, 2, 1, Color(0.82, 0.84, 0.86))
			_cell(ci, cloth, 8, 3, 1, 4, Color(0.28, 0.18, 0.10))
		"mtst":
			_fill(ci, cloth, RED)
			_cell(ci, cloth, 0, 6, 16, 4, BLACK)
			_tri(ci, cloth, Vector2(3, 6), Vector2(8, 1), Vector2(13, 6), WHITE)
			_cell(ci, cloth, 6, 6, 3, 3, WHITE)
			_cell(ci, cloth, 7, 7, 1, 2, BLACK)
		"psol":
			_fill(ci, cloth, YELLOW)
			ci.draw_rect(cloth, RED, false, maxf(u * 0.45, 0.6))
			_star(ci, cloth.position + cloth.size * Vector2(0.50, 0.52), cloth.size.y * 0.34, RED)
		"pcdob":
			_fill(ci, cloth, RED)
			_star(ci, cloth.position + cloth.size * Vector2(0.50, 0.18), cloth.size.y * 0.14, GOLD)
			_cell(ci, cloth, 1, 4, 5, 2, GOLD)
			_cell(ci, cloth, 3, 6, 1, 3, GOLD)
			_cell(ci, cloth, 10, 4, 4, 1, GOLD)
			_cell(ci, cloth, 9, 5, 1, 2, GOLD)
			_cell(ci, cloth, 13, 5, 1, 1, GOLD)
			_cell(ci, cloth, 10, 7, 1, 3, GOLD)
		"une":
			_fill(ci, cloth, BLUE)
			_cell(ci, cloth, 1, 8, 14, 1, WHITE)
			_letters(ci, cloth, "UNE", 2, WHITE)
		"pstu":
			_fill(ci, cloth, RED)
			_fist(ci, cloth)
		"pcb":
			_fill(ci, cloth, RED)
			_star(ci, cloth.position + cloth.size * Vector2(0.50, 0.50), cloth.size.y * 0.38, GOLD)
		_:
			_fill(ci, cloth, RED)
			_star(ci, cloth.position + cloth.size * 0.5, cloth.size.y * 0.32, GOLD)

static func _fill(ci: CanvasItem, cloth: Rect2, color: Color) -> void:
	ci.draw_rect(cloth, color)

static func _cell(ci: CanvasItem, cloth: Rect2, x: float, y: float, w: float, h: float, color: Color) -> void:
	var sx := cloth.size.x / 16.0
	var sy := cloth.size.y / 10.0
	ci.draw_rect(Rect2(cloth.position + Vector2(x * sx, y * sy), Vector2(w * sx, h * sy)), color)

static func _letters(ci: CanvasItem, cloth: Rect2, text: String, y: int, color: Color) -> void:
	var gw := 3
	var gap := 1
	var width := text.length() * gw + maxi(text.length() - 1, 0) * gap
	var x := int((16 - width) / 2.0)
	for i in text.length():
		var rows: Array = _GLYPHS.get(text[i], _GLYPHS["O"])
		for ry in rows.size():
			var row: String = rows[ry]
			for rx in row.length():
				if row[rx] == "#":
					_cell(ci, cloth, x + rx, y + ry, 1, 1, color)
		x += gw + gap

static func _star(ci: CanvasItem, c: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + float(i) * PI / 5.0
		var rad := radius if i % 2 == 0 else radius * 0.42
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	ci.draw_colored_polygon(pts, color)

static func _tri(ci: CanvasItem, cloth: Rect2, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var sx := cloth.size.x / 16.0
	var sy := cloth.size.y / 10.0
	var p := cloth.position
	ci.draw_colored_polygon(PackedVector2Array([
		p + Vector2(a.x * sx, a.y * sy),
		p + Vector2(b.x * sx, b.y * sy),
		p + Vector2(c.x * sx, c.y * sy),
	]), color)

static func _fist(ci: CanvasItem, cloth: Rect2) -> void:
	var c := cloth.position + cloth.size * Vector2(0.48, 0.58)
	var u := cloth.size.y / 10.0
	ci.draw_circle(c + Vector2(0, -u), u * 2.1, GOLD)
	_cell(ci, cloth, 5, 3, 4, 3, GOLD)
	_cell(ci, cloth, 6, 6, 2, 3, GOLD)
	_cell(ci, cloth, 4, 2, 1, 2, GOLD)
	_cell(ci, cloth, 6, 1, 1, 2, GOLD)
	_cell(ci, cloth, 8, 2, 1, 2, GOLD)
	_cell(ci, cloth, 9, 3, 1, 2, GOLD)
