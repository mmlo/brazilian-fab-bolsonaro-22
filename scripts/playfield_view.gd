extends Node2D
## Draws the 270x360 pixel playfield (inside a SubViewport, upscaled 2x).
## Layers: base (background, ships, items, debris) -> glow (additive sparks)
## -> top (enemy bullets, player, hitbox, burst ring, flashes). Enemy bullets
## are always drawn above effects so they stay readable.
const C = preload("res://scripts/config/game_config.gd")

var game: StarveilGame
var tex := {}
var bullet_tex := [] # [shape_idx][color_idx]
var stars: Array = []
var glow: Node2D
var top: Node2D
var bg_scroll := 0.0

func _ready() -> void:
	for id in ["bg_nebula", "stargate", "player", "player_flash", "enemy_drone", "enemy_drone_flash", "enemy_lancer", "enemy_lancer_flash",
			"enemy_frigate", "enemy_frigate_flash", "enemy_carrier", "enemy_carrier_flash", "boss_p1", "boss_p1_flash", "boss_p2", "boss_p2_flash",
			"boss_p3", "boss_p3_flash", "item_star", "item_gem", "item_energy", "shot_player"]:
		tex[id] = load("res://assets/art/%s.png" % id)
	for shape: String in Bullet.SHAPES:
		var row := []
		for color: String in Bullet.COLORS:
			row.append(load("res://assets/art/%s_%s.png" % [shape, color]))
		bullet_tex.append(row)
	for i in range(70):
		stars.append(Vector3(randf() * C.PF_W, randf() * C.PF_H, randf_range(0.25, 1.0)))
	glow = Node2D.new()
	glow.z_index = 1
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	glow.draw.connect(_draw_glow)
	add_child(glow)
	top = Node2D.new()
	top.z_index = 2
	top.draw.connect(_draw_top)
	add_child(top)

func _process(delta: float) -> void:
	if game == null or game.paused:
		return
	var speed := 8.0 if game.boss_active else 20.0
	bg_scroll = fmod(bg_scroll + speed * delta, 960.0)
	for i in range(stars.size()):
		var s: Vector3 = stars[i]
		s.y += (14.0 + s.z * s.z * 70.0) * delta * (0.6 if game.boss_active else 1.0)
		if s.y > C.PF_H + 2:
			s.y = -2
			s.x = randf() * C.PF_W
		stars[i] = s
	glow.queue_redraw()
	top.queue_redraw()

func _centered(t: Texture2D, p: Vector2, mod := Color.WHITE) -> void:
	draw_texture(t, (p - t.get_size() * 0.5).round(), mod)

# ------------------------------------------------------------------ base layer
func _draw() -> void:
	if game == null:
		return
	# Nebula (seamless mirrored loop)
	var bg: Texture2D = tex["bg_nebula"]
	var y := bg_scroll
	draw_texture(bg, Vector2(0, round(y) - 960))
	draw_texture(bg, Vector2(0, round(y)))
	# Stars
	for s: Vector3 in stars:
		var c := Color(0.75, 0.8, 1.0, 0.25 + s.z * 0.6)
		var h := 1.0 if s.z < 0.8 else 2.0
		draw_rect(Rect2(Vector2(s.x, s.y).floor(), Vector2(1, h)), c)
	# Stargate set piece
	if game.stargate_y > -290.0:
		var gate: Texture2D = tex["stargate"]
		var gp := Vector2(C.PF_W * 0.5, game.stargate_y + 60.0)
		draw_texture(gate, (gp - gate.get_size() * 0.5).round(), Color(0.62, 0.58, 0.75, 0.9))
	# Items
	var t: float = game.sim_time
	for it in game.items:
		match it.kind:
			"star": _centered(tex["item_star"], it.pos, Color(1, 1, 1, 0.8 + 0.2 * sin(t * 12.0 + it.pos.x)))
			"gem": _centered(tex["item_gem"], it.pos)
			"energy": _centered(tex["item_energy"], it.pos)
			"shard":
				var col := Color(1.0, 0.86, 0.35)
				draw_rect(Rect2(it.pos.round() - Vector2(1, 1), Vector2(2, 2)), col)
				draw_rect(Rect2(it.pos.round() + Vector2(-2, 0), Vector2(4, 1)).grow(0), Color(col, 0.55))
	# Enemies
	for e in game.enemies:
		var sprite: String = e.data["sprite"]
		var et: Texture2D = tex[sprite]
		if e.data.get("face_motion", false):
			draw_set_transform(e.pos.round(), e.heading - PI * 0.5, Vector2.ONE)
			draw_texture(et, -(et.get_size() * 0.5).round())
			if e.flash > 0.0:
				draw_texture(tex[sprite + "_flash"], -(et.get_size() * 0.5).round(), Color(1, 1, 1, 0.85))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			_centered(et, e.pos)
			if e.flash > 0.0:
				_centered(tex[sprite + "_flash"], e.pos, Color(1, 1, 1, 0.85))
		# damage smoke on heavy units
		if e.max_hp >= 60.0 and e.hp < e.max_hp * 0.5 and randf() < 0.3:
			game._spawn_particle(e.pos + Vector2(randf_range(-10, 10), randf_range(-8, 8)), Vector2(0, -20), 0.5, Color(0.3, 0.28, 0.35, 0.7), 3, 2.0, 4.0, false, 1.0)
	# Boss
	if game.boss_active:
		var bt: Texture2D = tex[game.boss_sprite]
		var bp: Vector2 = game.boss_pos
		if game.boss_dead_t > 0.0:
			bp += Vector2(randf_range(-2, 2), randf_range(-2, 2))
		var visible := true
		if game.boss_breaking > 0.0 and fmod(game.boss_breaking, 0.16) < 0.05:
			visible = false
		if visible:
			_centered(bt, bp)
			if game.boss_flash > 0.0:
				_centered(tex[game.boss_sprite + "_flash"], bp, Color(1, 1, 1, 0.42))
	# Player shots
	var st: Texture2D = tex["shot_player"]
	for s in game.shots:
		var mod := Color(0.55, 1.0, 1.0, 0.9) if s.option else Color.WHITE
		if s.vel.x == 0.0:
			draw_texture(st, (s.pos - st.get_size() * 0.5).round(), mod)
		else:
			draw_set_transform(s.pos.round(), s.vel.angle() + PI * 0.5, Vector2.ONE)
			draw_texture(st, -st.get_size() * 0.5, mod)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Solid particles (debris, smoke)
	for pt in game.particles:
		if not pt.add:
			_draw_particle(self, pt)

func _draw_particle(ci: CanvasItem, pt) -> void:
	var k: float = clampf(pt.life / pt.max_life, 0.0, 1.0)
	var col: Color = pt.color
	col.a *= k if pt.kind != 0 else minf(1.0, k * 1.6)
	match pt.kind:
		0:
			var s := maxf(1.0, round(pt.size))
			ci.draw_rect(Rect2((pt.pos - Vector2(s, s) * 0.5).round(), Vector2(s, s)), col)
		1:
			ci.draw_line(pt.pos.round(), (pt.pos - pt.vel * 0.035).round(), col, 1.0)
		2:
			if pt.size >= 1.0:
				ci.draw_arc(pt.pos.round(), round(pt.size), 0.0, TAU, clampi(int(pt.size * 1.5), 12, 64), col, 1.0 if pt.size < 60.0 else 2.0)
		3:
			ci.draw_circle(pt.pos.round(), maxf(1.0, pt.size), col)

# ------------------------------------------------------------------ glow layer (additive)
func _draw_glow() -> void:
	if game == null:
		return
	# Stargate inner light
	if game.stargate_y > -290.0:
		var gp := Vector2(C.PF_W * 0.5, game.stargate_y + 60.0)
		var pulse := 0.5 + 0.5 * sin(game.sim_time * 1.3)
		var g: float = 0.10 + 0.05 * pulse + game.stargate_glow * 0.5
		glow.draw_circle(gp, 96.0, Color(0.55, 0.2, 0.7, g * 0.5))
		glow.draw_circle(gp, 70.0, Color(0.8, 0.3, 0.9, g * 0.5))
		if game.stargate_glow > 0.0:
			glow.draw_circle(gp, 50.0, Color(1, 0.9, 1, game.stargate_glow * 0.5))
	for pt in game.particles:
		if pt.add:
			_draw_particle(glow, pt)
	# Player engine glow
	if game.player_alive:
		var fl := 0.7 + 0.3 * sin(game.sim_time * 50.0)
		glow.draw_circle(game.player_pos + Vector2(-4, 15), 2.0 * fl, Color(0.3, 0.9, 1.0, 0.6))
		glow.draw_circle(game.player_pos + Vector2(4, 15), 2.0 * fl, Color(0.3, 0.9, 1.0, 0.6))
	# Boss core glow
	if game.boss_active and game.boss_phase >= 0:
		var core := game.boss_pos + Vector2(0, 2)
		var p := 0.5 + 0.5 * sin(game.sim_time * (3.0 + game.boss_phase * 2.0))
		var col := Color(1.0, 0.3, 0.7, 0.10 + 0.10 * p + game.boss_phase * 0.05)
		glow.draw_circle(core, 12.0 + game.boss_phase * 4.0 + p * 3.0, col)

# ------------------------------------------------------------------ top layer
func _draw_top() -> void:
	if game == null:
		return
	# Enemy bullets
	var warm := C.BULLET_WARMUP
	for b: Bullet in game.bullets:
		var bt: Texture2D = bullet_tex[b.shape_idx][b.color_idx]
		var half := bt.get_size() * 0.5
		if b.age < warm:
			var k := b.age / warm
			var sc := 1.0 + (1.0 - k) * 1.2
			top.draw_set_transform(b.pos, b.angle + PI * 0.5 if b.shape_idx == 1 else 0.0, Vector2(sc, sc))
			top.draw_texture(bt, -half, Color(1, 1, 1, 0.35 + 0.65 * k))
			top.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		elif b.shape_idx == 1:
			top.draw_set_transform(b.pos.round(), b.angle + PI * 0.5, Vector2.ONE)
			top.draw_texture(bt, -half)
			top.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			top.draw_texture(bt, (b.pos - half).round())
	# Player
	if game.player_alive:
		var pp: Vector2 = game.player_pos
		var blink: bool = game.player_invuln > 0.0 and fmod(game.player_invuln, 0.16) < 0.07 and not game.burst_active
		# thruster pixels
		var fl := int(game.sim_time * 30.0) % 3
		for sx: float in [-4.0, 3.0]:
			top.draw_rect(Rect2((pp + Vector2(sx, 14)).round(), Vector2(2, 2 + fl)), Color(0.6, 1.0, 1.0, 0.9))
			top.draw_rect(Rect2((pp + Vector2(sx, 16 + fl)).round(), Vector2(2, 2)), Color(0.2, 0.6, 1.0, 0.6))
		if not blink:
			var ptex: Texture2D = tex["player"]
			var sq := 1.0 - absf(game.bank) * 0.12
			top.draw_set_transform(pp.round(), 0.0, Vector2(sq, 1.0))
			top.draw_texture(ptex, -(ptex.get_size() * 0.5).round())
			top.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# option pods
		var off: Vector2 = C.OPTION_FOCUS_OFFSET if game.focus else C.OPTION_OFFSET
		for side: float in [-1.0, 1.0]:
			var op := pp + Vector2(off.x * side, off.y + sin(game.sim_time * 5.0 + side) * 1.0)
			top.draw_texture(tex["item_energy"], (op - Vector2(5, 6)).round(), Color(1, 1, 1, 0.9))
		# Focus: hitbox + graze ring
		if game.focus:
			var gr: float = game.tune("graze_radius", C.PLAYER_GRAZE_RADIUS)
			var ring_a := 0.25 + game.graze_pulse * 0.5
			var n := 20
			for i in range(n):
				var a := game.sim_time * 1.8 + TAU * i / n
				top.draw_rect(Rect2((pp + Vector2.from_angle(a) * gr).round(), Vector2(1, 1)), Color(0.5, 1.0, 1.0, ring_a))
			var hr: float = maxf(2.0, game.tune("hit_radius", C.PLAYER_HIT_RADIUS) + 0.6)
			top.draw_circle(pp.round(), hr + 1.5, Color(1.0, 0.25, 0.55, 0.95))
			top.draw_circle(pp.round(), hr, Color(1, 1, 1))
		elif game.graze_pulse > 0.0:
			top.draw_arc(pp.round(), game.tune("graze_radius", C.PLAYER_GRAZE_RADIUS), 0, TAU, 24, Color(0.5, 1, 1, game.graze_pulse * 0.4), 1.0)
	# Burst shock ring
	if game.burst_active:
		var k: float = clampf(game.burst_t / C.BURST_DURATION, 0, 1)
		var r := (1.0 - pow(1.0 - k, 3.0)) * C.BURST_RADIUS
		var a := 1.0 - k
		top.draw_arc(game.burst_origin, r, 0, TAU, 72, Color(0.7, 1.0, 1.0, a), 3.0)
		top.draw_arc(game.burst_origin, maxf(1.0, r - 6.0), 0, TAU, 72, Color(1, 1, 1, a * 0.6), 1.0)
		top.draw_arc(game.burst_origin, r * 0.7, 0, TAU, 60, Color(0.5, 0.9, 1.0, a * 0.35), 1.0)
	# Screen flash
	if game.flash_t > 0.0 and Settings.effects_high:
		var fc: Color = game.flash_color
		fc.a = clampf(game.flash_t * 1.4, 0.0, 0.55)
		top.draw_rect(Rect2(0, 0, C.PF_W, C.PF_H), fc)
	elif game.flash_t > 0.0:
		var fc2: Color = game.flash_color
		fc2.a = clampf(game.flash_t * 0.6, 0.0, 0.2)
		top.draw_rect(Rect2(0, 0, C.PF_W, C.PF_H), fc2)
