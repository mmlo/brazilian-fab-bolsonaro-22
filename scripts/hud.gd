extends Node2D
## Full-resolution HUD. Draws the two side panels under the upscaled playfield
## and an overlay (boss bar, banners, score pop-ups) above it.
const C = preload("res://scripts/config/game_config.gd")
const U = preload("res://scripts/ui/pixel_ui.gd")

var game: StarveilGame
var overlay: Node2D
var backdrop: Texture2D
var life_icon: Texture2D
var t := 0.0
var deny_t := 0.0

func _ready() -> void:
	backdrop = load("res://assets/art/title_art.png")
	life_icon = load("res://assets/art/player.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func build_overlay(g: Node) -> void:
	overlay = Node2D.new()
	overlay.name = "HudOverlay"
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.draw.connect(_draw_overlay)
	g.add_child(overlay)

func deny_burst() -> void:
	deny_t = 0.5

func _process(delta: float) -> void:
	t += delta
	deny_t = maxf(0.0, deny_t - delta)
	if overlay:
		overlay.queue_redraw()

func _pf(p: Vector2) -> Vector2:
	return C.PF_ORIGIN + game.shake_offset + p * C.PF_SCALE

# ================================================================ side panels
func _draw() -> void:
	if game == null:
		return
	draw_texture_rect(backdrop, Rect2(0, 0, 1280, 720), false, Color(0.42, 0.40, 0.62))
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.015, 0.06, 0.55))
	# playfield frame
	var pr := Rect2(C.PF_ORIGIN - Vector2(6, 0), Vector2(C.PF_W * C.PF_SCALE + 12, 720))
	draw_rect(pr, Color(0.01, 0.01, 0.03))
	draw_rect(Rect2(pr.position.x, 0, 4, 720), U.LINE)
	draw_rect(Rect2(pr.end.x - 4, 0, 4, 720), U.LINE)
	draw_rect(Rect2(pr.position.x + 4, 0, 2, 720), Color(U.CYAN, 0.35))
	draw_rect(Rect2(pr.end.x - 6, 0, 2, 720), Color(U.CYAN, 0.35))
	_draw_left()
	_draw_right()

func _draw_left() -> void:
	var x := 18.0
	var w := 334.0
	# Logo
	U.draw_panel(self, Rect2(x, 16, w, 86), U.VIOLET)
	U.draw_text(self, I18n.t("game.title_short"), Vector2(x + 18, 58), 30, U.TEXT, "title")
	var sub_title := I18n.t("brand.sub")
	U.draw_text(self, sub_title, Vector2(x + 20, 86), 13, Color(U.CYAN, 0.8), "display")
	# Score
	U.draw_panel(self, Rect2(x, 112, w, 138))
	U.draw_text(self, I18n.t("hud.hiscore"), Vector2(x + 18, 140), 14, U.MUTED, "bold")
	var hi := maxi(SaveData.best_score, game.score)
	U.draw_text(self, game.format_score(hi), Vector2(x + 18, 140), 20, U.GOLD, "display", HORIZONTAL_ALIGNMENT_RIGHT, w - 36)
	draw_rect(Rect2(x + 16, 152, w - 32, 2), Color(U.LINE, 0.6))
	U.draw_text(self, I18n.t("hud.score"), Vector2(x + 18, 180), 14, U.MUTED, "bold")
	var sc := Color.WHITE.lerp(U.GOLD, game.score_pulse * 0.6)
	U.draw_text(self, game.format_score(int(game.display_score)), Vector2(x + 18, 230), 38, sc, "display", HORIZONTAL_ALIGNMENT_RIGHT, w - 36)
	# Lives
	U.draw_panel(self, Rect2(x, 260, w, 70))
	U.draw_text(self, I18n.t("hud.lives"), Vector2(x + 18, 302), 14, U.MUTED, "bold")
	for i in range(C.PLAYER_LIVES):
		var px := x + 120 + i * 40
		var mod := Color.WHITE if i < game.lives else Color(0.25, 0.25, 0.4, 0.5)
		draw_texture(life_icon, Vector2(px, 280), mod)
	# Burst
	var full: bool = game.energy >= C.ENERGY_MAX
	var bcol := U.CYAN if full else Color(0.3, 0.75, 1.0)
	U.draw_panel(self, Rect2(x, 340, w, 118), U.CYAN if full else U.LINE)
	U.draw_text(self, I18n.t("hud.burst"), Vector2(x + 18, 370), 14, U.MUTED, "bold")
	var pct := int(game.energy / C.ENERGY_MAX * 100.0)
	if full:
		var blink := 0.6 + 0.4 * sin(t * 9.0)
		U.draw_text(self, I18n.t("hud.ready"), Vector2(x + 18, 370), 16, Color(U.CYAN, blink), "bold", HORIZONTAL_ALIGNMENT_RIGHT, w - 36)
	else:
		U.draw_text(self, "%d%%" % pct, Vector2(x + 18, 370), 16, U.TEXT, "display", HORIZONTAL_ALIGNMENT_RIGHT, w - 36)
	var fill := bcol
	if deny_t > 0.0 and fmod(deny_t, 0.12) < 0.06:
		fill = U.RED
	U.draw_meter(self, Rect2(x + 18, 384, w - 36, 22), game.energy / C.ENERGY_MAX, 10, fill)
	var hint_text := I18n.t("hud.burst_hint", {"key": GameInput.hint("bomb")}) if full else I18n.t("hud.graze_hint")
	U.draw_text(self, hint_text, Vector2(x + 18, 438), 14, U.TEXT if full else U.MUTED, "medium", HORIZONTAL_ALIGNMENT_LEFT, w - 36, false)
	# Chain
	var mult: float = game.multiplier()
	var cp: float = game.chain_pulse
	U.draw_panel(self, Rect2(x, 468, w, 150), U.PINK if game.chain >= 25 else U.LINE)
	U.draw_text(self, I18n.t("hud.chain"), Vector2(x + 18, 498), 14, U.MUTED, "bold")
	var mcol := U.TEXT.lerp(U.PINK, clampf((mult - 1.0) / 3.0, 0, 1))
	U.draw_text(self, "×%.1f" % mult, Vector2(x + 18, 552 - cp * 3.0), 46 + int(cp * 6.0), mcol, "display")
	U.draw_text(self, str(game.chain), Vector2(x + 18, 540), 30, Color.WHITE.lerp(U.PINK, cp), "display", HORIZONTAL_ALIGNMENT_RIGHT, w - 36)
	U.draw_text(self, I18n.t("hud.links"), Vector2(x + 18, 562), 12, U.MUTED, "bold", HORIZONTAL_ALIGNMENT_RIGHT, w - 36)
	var ct := clampf(game.chain_t / game.tune("chain_window", C.CHAIN_WINDOW), 0, 1) if game.chain > 0 else 0.0
	draw_rect(Rect2(x + 18, 576, w - 36, 6), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(x + 18, 576, (w - 36) * ct, 6), U.PINK if ct > 0.3 else U.RED)
	U.draw_text(self, I18n.t("hud.graze"), Vector2(x + 18, 606), 13, U.MUTED, "bold")
	var gcol := U.TEXT.lerp(U.CYAN, game.graze_pulse)
	U.draw_text(self, str(game.grazes), Vector2(x + 18, 606), 16, gcol, "display", HORIZONTAL_ALIGNMENT_RIGHT, w - 36)
	# Footer: controls on desktop / drag hint on touch
	if GameInput.device == "touch":
		U.draw_text(self, I18n.t("touch.drag_hint"), Vector2(x + 4, 660), 15, U.MUTED, "medium", HORIZONTAL_ALIGNMENT_LEFT, w, false)
	else:
		U.draw_text(self, I18n.t("hud.pause_hint", {"key": GameInput.hint("pause")}), Vector2(x + 4, 660), 14, U.MUTED, "medium", HORIZONTAL_ALIGNMENT_LEFT, w, false)

func _draw_right() -> void:
	var x := 928.0
	var w := 334.0
	# Stage
	U.draw_panel(self, Rect2(x, 16, w, 132), U.VIOLET)
	U.draw_text(self, I18n.t("hud.stage"), Vector2(x + 18, 46), 14, U.MUTED, "bold")
	U.draw_text(self, I18n.t("stage.name"), Vector2(x + 18, 78), 22, U.TEXT, "title")
	var nodes := StageData.WAVES.size() + 1
	var rx := x + 30.0
	var rw := w - 60.0
	var ry := 118.0
	var prog: float = game.stage_progress()
	draw_rect(Rect2(rx, ry - 2, rw, 4), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(rx, ry - 2, rw * prog, 4), U.CYAN)
	for i in range(nodes):
		var nx := rx + rw * float(i) / float(nodes - 1) if i < nodes - 1 else rx + rw
		nx = rx + rw * (float(i) + 0.0) / float(nodes - 1) if nodes > 1 else rx
		var reached := prog >= float(i) / float(nodes)
		var is_boss := i == nodes - 1
		var col := (U.PINK if is_boss else U.CYAN) if reached else Color(0.3, 0.3, 0.5)
		var s := 7.0 if is_boss else 5.0
		draw_colored_polygon(PackedVector2Array([Vector2(nx, ry - s), Vector2(nx + s, ry), Vector2(nx, ry + s), Vector2(nx - s, ry)]), col)
		var lbl := "B" if is_boss else str(i + 1)
		U.draw_text(self, lbl, Vector2(nx - 20, ry + 24), 12, col, "display", HORIZONTAL_ALIGNMENT_CENTER, 40, false)
	# Current section
	U.draw_panel(self, Rect2(x, 158, w, 150))
	var head := ""
	var sub := ""
	var extra := ""
	if game.boss_active or game.state == "victory":
		head = I18n.t("boss.name")
		if game.boss_phase >= 0:
			var ph: Dictionary = StageData.BOSS["phases"][game.boss_phase]
			sub = I18n.t("hud.phase", {"n": game.boss_phase + 1}) + "  " + I18n.t(ph["name_key"])
			extra = I18n.t("hud.phase_bonus", {"v": game.format_score(C.BOSS_PHASE_BONUS + int(maxf(game.boss_phase_time, 0) * C.BOSS_TIME_BONUS_PER_SEC))})
		else:
			sub = I18n.t("boss.title")
	elif game.state == "warning":
		head = I18n.t("hud.warning")
		sub = I18n.t("warning.sub")
	elif game.tutorial_active:
		head = I18n.t("hud.training")
		sub = I18n.t("hud.training_sub")
	elif game.wave_idx >= 0:
		head = I18n.t("hud.wave", {"n": game.wave_idx + 1})
		sub = I18n.t(StageData.WAVES[game.wave_idx]["name_key"])
	else:
		head = I18n.t("hud.launch")
	U.draw_text(self, head, Vector2(x + 18, 196), 22, U.PINK if game.boss_active else U.TEXT, "title", HORIZONTAL_ALIGNMENT_LEFT, w - 36)
	U.draw_text(self, sub, Vector2(x + 18, 232), 16, U.CYAN, "bold", HORIZONTAL_ALIGNMENT_LEFT, w - 36)
	if extra != "":
		U.draw_text(self, extra, Vector2(x + 18, 268), 14, U.GOLD, "bold", HORIZONTAL_ALIGNMENT_LEFT, w - 36)
	U.draw_text(self, I18n.t("hud.time", {"t": _fmt_time(game.run_time)}), Vector2(x + 18, 292), 13, U.MUTED, "bold", HORIZONTAL_ALIGNMENT_LEFT, w - 36, false)
	# Controls legend (hidden on touch, where on-screen buttons live here)
	if GameInput.device != "touch":
		U.draw_panel(self, Rect2(x, 318, w, 296))
		U.draw_text(self, I18n.t("hud.controls"), Vector2(x + 18, 348), 14, U.MUTED, "bold")
		var rows := [["move", "ctl.move"], ["focus", "ctl.focus"], ["bomb", "ctl.burst"], ["pause", "ctl.pause"]]
		var yy := 386.0
		for r: Array in rows:
			U.draw_text(self, I18n.t(r[1]), Vector2(x + 18, yy), 16, U.TEXT, "medium", HORIZONTAL_ALIGNMENT_LEFT, -1, false)
			var key := GameInput.hint(r[0])
			var kw := U.text_width(key, 14) + 14
			U.key_cap(self, key, Vector2(x + w - 18 - kw, yy), 14, U.PINK if r[0] == "bomb" else U.CYAN)
			yy += 40
		U.draw_wrapped(self, I18n.t("hud.tip"), Vector2(x + 18, yy + 2), w - 36, 13, U.MUTED, "medium", 3)

func _fmt_time(s: float) -> String:
	return "%d:%02d" % [int(s) / 60, int(s) % 60]

# ================================================================ overlay
func _draw_overlay() -> void:
	if game == null:
		return
	var o: CanvasItem = overlay
	var pf_x := C.PF_ORIGIN.x
	var pf_w := C.PF_W * C.PF_SCALE
	var cx := pf_x + pf_w * 0.5
	# Popups
	for pp in game.popups:
		var k: float = clampf(pp.life / pp.max_life, 0, 1)
		var a := minf(1.0, k * 2.5)
		var sz := 22 if pp.big else 14
		var p := _pf(pp.pos)
		var col: Color = pp.color
		col.a = a
		var tw := U.text_width(pp.text, sz, "display")
		var pop := 1.0 + maxf(0.0, (k - 0.8) * 2.0)
		o.draw_set_transform(p, 0, Vector2(pop, pop))
		U.draw_text(o, pp.text, Vector2(-tw * 0.5, 0), sz, col, "display")
		o.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# Boss HP
	if game.boss_active and game.boss_phase >= 0 and game.boss_dead_t <= 0.0:
		var r := Rect2(pf_x + 14, 10, pf_w - 110, 14)
		o.draw_rect(r.grow(3), Color(0.02, 0.01, 0.05, 0.85))
		var k: float = clampf(game.boss_hp / game.boss_max_hp, 0, 1)
		var col := U.PINK.lerp(U.GOLD, 0.5 + 0.5 * sin(t * 6.0)) if k < 0.25 else U.PINK
		o.draw_rect(Rect2(r.position, Vector2(r.size.x * k, r.size.y)), col)
		o.draw_rect(Rect2(r.position, Vector2(r.size.x * k, 3)), Color(1, 1, 1, 0.45))
		o.draw_rect(r.grow(3), U.LINE, false, 2.0)
		# phase pips
		var phases: int = StageData.BOSS["phases"].size()
		for i in range(phases):
			var left := phases - 1 - game.boss_phase
			var pc := U.PINK if i < left else Color(0.25, 0.22, 0.4)
			var px := r.end.x + 16 + i * 14
			o.draw_colored_polygon(PackedVector2Array([Vector2(px, 11), Vector2(px + 6, 17), Vector2(px, 23), Vector2(px - 6, 17)]), pc)
		var secs := maxf(0.0, game.boss_phase_time)
		var tcol := U.RED if secs < 10.0 else U.TEXT
		U.draw_text(o, "%d" % int(ceil(secs)), Vector2(pf_x + pf_w - 50, 50), 22, tcol, "display", HORIZONTAL_ALIGNMENT_RIGHT, 40)
		# Phase card (spell-card style)
		if game.boss_phase >= 0:
			var ph: Dictionary = StageData.BOSS["phases"][game.boss_phase]
			var name := I18n.t(ph["name_key"])
			var slide := clampf((2.6 - game.boss_card_t) / 0.35, 0, 1) if game.boss_card_t > 0.0 else 1.0
			var yy := 58.0 if game.boss_card_t <= 0.0 else lerpf(420.0, 58.0, _ease(clampf((2.6 - game.boss_card_t - 1.2) / 0.6, 0, 1)))
			var label := "%02d  %s" % [game.boss_phase + 1, name]
			var tw := U.text_width(label, 18, "bold")
			var bx := pf_x + pf_w - 64 - tw
			bx = lerpf(pf_x + pf_w + 10, bx, _ease(slide))
			o.draw_rect(Rect2(bx - 14, yy - 22, tw + 28, 30), Color(0.05, 0.02, 0.12, 0.75))
			o.draw_rect(Rect2(bx - 14, yy + 6, tw + 28, 2), U.PINK)
			U.draw_text(o, label, Vector2(bx, yy), 18, U.TEXT, "bold")
	# Boss entry title card
	if game.boss_active and game.boss_entering:
		var a := clampf(game.boss_t / 0.4, 0, 1) * clampf((C.BOSS_ENTRY_TIME - game.boss_t) / 0.4, 0, 1)
		_banner(o, cx, 420, I18n.t("boss.title"), I18n.t("boss.name"), U.PINK, a)
	# Wave banner
	if game.state == "wave" and game.wave_banner_t > 0.0:
		var bt: float = 2.4 - game.wave_banner_t
		var a := clampf(bt / 0.25, 0, 1) * clampf(game.wave_banner_t / 0.4, 0, 1)
		_banner(o, cx, 300, I18n.t("hud.wave", {"n": game.wave_idx + 1}), I18n.t(StageData.WAVES[game.wave_idx]["name_key"]), U.CYAN, a)
	# Intro banner
	if game.state == "intro":
		var a := clampf(game.state_t / 0.3, 0, 1)
		_banner(o, cx, 300, I18n.t("hud.stage"), I18n.t("stage.name"), U.VIOLET, a)
	# Interlude
	if game.state == "interlude" and game.state_t > 0.2:
		var a := clampf((game.state_t - 0.2) / 0.3, 0, 1) * clampf((1.6 - game.state_t) / 0.3, 0, 1)
		U.draw_text(o, I18n.t("hud.wave_clear"), Vector2(pf_x, 320), 26, Color(U.GOLD, a), "title", HORIZONTAL_ALIGNMENT_CENTER, pf_w)
	# Warning
	if game.state == "warning":
		_warning(o, pf_x, pf_w)
	# End banners
	if game.state == "gameover":
		var a := clampf(game.state_t / 0.5, 0, 1)
		o.draw_rect(Rect2(pf_x, 0, pf_w, 720), Color(0.1, 0.0, 0.05, a * 0.45))
		_banner(o, cx, 330, I18n.t("end.fail"), I18n.t("end.fail_sub"), U.RED, a)
	if game.state == "victory" and game.boss_dead_t > 2.8:
		var a := clampf((game.boss_dead_t - 2.8) / 0.5, 0, 1)
		_banner(o, cx, 330, I18n.t("end.clear"), I18n.t("end.clear_sub"), U.GOLD, a)
	# Burst deny hint near the player
	if deny_t > 0.3 and game.player_alive:
		var p := _pf(game.player_pos + Vector2(0, -26))
		var s := I18n.t("pop.burst_charging")
		U.draw_text(o, s, Vector2(p.x - 150, p.y), 14, Color(U.RED, 0.9), "bold", HORIZONTAL_ALIGNMENT_CENTER, 300)

func _banner(o: CanvasItem, cx: float, y: float, head: String, sub: String, col: Color, a: float) -> void:
	if a <= 0.0:
		return
	var w := 540.0 * _ease(a)
	o.draw_rect(Rect2(cx - w * 0.5, y - 46, w, 84), Color(0.03, 0.02, 0.08, 0.72 * a))
	o.draw_rect(Rect2(cx - w * 0.5, y - 46, w, 2), Color(col, a))
	o.draw_rect(Rect2(cx - w * 0.5, y + 36, w, 2), Color(col, a))
	U.draw_text(o, head, Vector2(cx - 270, y - 12), 16, Color(col, a), "bold", HORIZONTAL_ALIGNMENT_CENTER, 540)
	U.draw_text(o, sub, Vector2(cx - 270, y + 22), 28, Color(1, 1, 1, a), "title", HORIZONTAL_ALIGNMENT_CENTER, 540)

func _warning(o: CanvasItem, pf_x: float, pf_w: float) -> void:
	var st: float = game.state_t
	var a := clampf(st / 0.3, 0, 1) * clampf((3.6 - st) / 0.4, 0, 1)
	var y := 300.0
	o.draw_rect(Rect2(pf_x, y - 60, pf_w, 120), Color(0.25, 0.0, 0.06, 0.55 * a))
	# moving hazard stripes
	var off := fmod(st * 80.0, 40.0)
	for band_y: float in [y - 60.0, y + 44.0]:
		o.draw_rect(Rect2(pf_x, band_y, pf_w, 16), Color(0.1, 0, 0.02, 0.8 * a))
		var sx := pf_x - 40.0 + off
		while sx < pf_x + pf_w:
			var pts := PackedVector2Array([Vector2(sx, band_y + 16), Vector2(sx + 16, band_y), Vector2(sx + 28, band_y), Vector2(sx + 12, band_y + 16)])
			var clipped := PackedVector2Array()
			for p: Vector2 in pts:
				clipped.append(Vector2(clampf(p.x, pf_x, pf_x + pf_w), p.y))
			o.draw_colored_polygon(clipped, Color(1.0, 0.25, 0.35, 0.85 * a))
			sx += 40.0
	var blink := 0.55 + 0.45 * sin(st * 12.0)
	U.draw_text(o, "WARNING", Vector2(pf_x, y + 16), 46, Color(1.0, 0.3, 0.38, a * blink), "title", HORIZONTAL_ALIGNMENT_CENTER, pf_w)
	U.draw_text(o, I18n.t("warning.sub"), Vector2(pf_x, y + 38), 15, Color(1, 0.85, 0.88, a), "bold", HORIZONTAL_ALIGNMENT_CENTER, pf_w)

func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0, 1), 3.0)
