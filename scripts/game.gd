class_name StarveilGame
extends Node2D
## ------------------------------------------------------------------------
## STARVEIL BARRAGE — aerospace defense controller (simulation + flow).
## Rendering lives in PlayfieldView (low-res pixel playfield) and Hud (full-res
## panels/text); menus in scripts/ui. Tunables: GameConfig. Content: StageData.
## ------------------------------------------------------------------------
signal run_finished(victory: bool)

const PlayfieldView = preload("res://scripts/playfield_view.gd")
const Hud = preload("res://scripts/hud.gd")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const ResultsScreen = preload("res://scripts/ui/results_screen.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")
const TutorialCard = preload("res://scripts/ui/tutorial_card.gd")

const C = preload("res://scripts/config/game_config.gd")

# ---------------------------------------------------------------- entities
class Enemy:
	var kind := ""
	var data: Dictionary
	var ev: Dictionary
	var pos := Vector2.ZERO
	var origin_x := 0.0
	var heading := PI * 0.5
	var speed := 60.0
	var age := 0.0
	var hp := 1.0
	var max_hp := 1.0
	var flash := 0.0
	var fires: Array = [] # [{spec, timer, left, state}]
	var burst_hit := false
	var dead := false

class Shot:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var damage := 1.0
	var option := false
	var dead := false

class Item:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var kind := "star" # star | gem | energy | shard
	var age := 0.0
	var magnet := false
	var dead := false

class Particle:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.5
	var max_life := 0.5
	var size := 1.0
	var grow := 0.0
	var color := Color.WHITE
	var kind := 0 # 0 pixel square, 1 streak, 2 ring, 3 glow dot
	var drag := 0.0
	var add := false

class ScorePopup:
	var pos := Vector2.ZERO # playfield coords
	var text := ""
	var color := Color.WHITE
	var life := 1.0
	var max_life := 1.0
	var big := false

# ---------------------------------------------------------------- run state
var state := "intro" # intro | tutorial | wave | interlude | warning | boss | victory | gameover | results
var state_t := 0.0
var sim_time := 0.0
var run_time := 0.0
var paused := false
var hitstop := 0.0
var slowmo_t := 0.0

var player_pos := Vector2(C.PLAYER_START.x, C.PF_H + 30)
var player_alive := true
var player_invuln := 0.0
var respawn_t := 0.0
var focus := false
var fire_t := 0.0
var shoot_sfx_toggle := false
var bank := 0.0 # -1..1 visual tilt for the sprite
var lives := C.PLAYER_LIVES
var energy := C.ENERGY_START
var energy_full_announced := false

var score := 0
var display_score := 0.0
var chain := 0
var chain_t := 0.0
var max_chain := 0
var grazes := 0
var kills := 0
var misses := 0
var bursts_used := 0
var phases_broken := 0
var last_milestone := 0
var graze_pulse := 0.0
var chain_pulse := 0.0
var score_pulse := 0.0

var wave_idx := -1
var wave_t := 0.0
var wave_queue: Array = []
var wave_banner_t := 0.0
var interlude_next := ""

var enemies: Array = []
var bullets: Array = []
var shots: Array = []
var items: Array = []
var particles: Array = []
var popups: Array = []

var burst_active := false
var burst_t := 0.0
var burst_origin := Vector2.ZERO
var flash_t := 0.0
var flash_color := Color.WHITE
var shake := 0.0
var shake_offset := Vector2.ZERO

# Boss
var boss_active := false
var boss_pos := Vector2(C.PF_W * 0.5, -90)
var boss_phase := -1
var boss_hp := 1.0
var boss_max_hp := 1.0
var boss_phase_time := 0.0
var boss_emitters: Array = []
var boss_entering := false
var boss_breaking := 0.0
var boss_flash := 0.0
var boss_t := 0.0
var boss_card_t := 0.0
var boss_dead_t := 0.0
var boss_sprite := "boss_p1"
var stargate_y := -300.0
var stargate_glow := 0.0

# Tutorial
var tutorial_active := false
var tut_step := 0
var tut_t := 0.0
var tut_moved := 0.0
var tut_focus_time := 0.0
var tut_grazes := 0
var tut_emit_t := 0.0

# Mouse / touch steering
var drag_active := false
var drag_delta := Vector2.ZERO

# Nodes
var view: Node2D
var viewport: SubViewport
var pf_rect: TextureRect
var hud: Node2D
var ui_layer: CanvasLayer
var pause_menu: Control
var results: Control
var touch: Control
var tutorial_card: Control

var force_tutorial := false
var autoplay := false # test bot steering
var god_mode := false # test only
var god_hits := 0 # would-be hits absorbed in god mode (difficulty metric)
var debug_start := "" # debug builds only: "boss" | "wave2" | "wave3" via ?start=...
var debug_phase := 0 # debug builds only: ?phase=2|3 starts the boss at that phase

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	force_tutorial = bool(get_tree().get_meta("force_tutorial", false))
	if get_tree().has_meta("force_tutorial"):
		get_tree().remove_meta("force_tutorial")
	TuningStore.begin_run()
	_read_debug_flags()
	_build_nodes()
	AudioDirector.play_music("stage", true)
	_set_state("intro")

func _build_nodes() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(C.PF_W, C.PF_H)
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.snap_2d_transforms_to_pixel = true
	add_child(viewport)
	view = PlayfieldView.new()
	view.game = self
	viewport.add_child(view)

	hud = Hud.new()
	hud.game = self
	hud.name = "Hud"
	add_child(hud)

	pf_rect = TextureRect.new()
	pf_rect.texture = viewport.get_texture()
	pf_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pf_rect.position = C.PF_ORIGIN
	pf_rect.size = Vector2(C.PF_W * C.PF_SCALE, C.PF_H * C.PF_SCALE)
	pf_rect.stretch_mode = TextureRect.STRETCH_SCALE
	pf_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pf_rect)
	hud.build_overlay(self)

	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	touch = TouchControls.new()
	touch.game = self
	ui_layer.add_child(touch)
	tutorial_card = TutorialCard.new()
	tutorial_card.game = self
	ui_layer.add_child(tutorial_card)
	pause_menu = PauseMenu.new()
	pause_menu.game = self
	ui_layer.add_child(pause_menu)
	results = ResultsScreen.new()
	results.game = self
	ui_layer.add_child(results)

## Debug builds on the web accept ?autoplay (bot + god mode) and ?start=wave2|wave3|boss
## so reviewers can jump to any section. Release exports ignore these flags.
func _read_debug_flags() -> void:
	if not OS.is_debug_build() or not OS.has_feature("web"):
		return
	var q := str(JavaScriptBridge.eval("location.search", true))
	if q.contains("autoplay"):
		autoplay = true
		god_mode = true
	for s: String in ["boss", "wave2", "wave3"]:
		if q.contains("start=" + s):
			debug_start = s
	for n in [2, 3]:
		if q.contains("phase=%d" % n):
			debug_phase = n - 1

# ---------------------------------------------------------------- tuning
func tune(id: String, fallback: float) -> float:
	var d: Dictionary = TuningStore.active
	return float(d[id]) if d.has(id) else fallback

# ---------------------------------------------------------------- main loop
func _physics_process(delta: float) -> void:
	if paused:
		return
	var dt := delta
	if hitstop > 0.0:
		hitstop -= delta
		_update_fx(delta * 0.25)
		return
	if slowmo_t > 0.0:
		slowmo_t -= delta
		dt *= 0.35
	sim_time += dt
	state_t += dt
	if state in ["tutorial", "wave", "interlude", "warning", "boss"]:
		run_time += dt
	_update_state(dt)
	_update_player(dt)
	_update_shots(dt)
	_update_enemies(dt)
	_update_boss(dt)
	_update_bullets(dt)
	_update_items(dt)
	_update_burst(dt)
	_update_scoring(dt)
	_update_fx(dt)

func _process(delta: float) -> void:
	display_score = move_toward(display_score, score, maxf(40.0, absf(score - display_score) * 10.0) * delta)
	if shake > 0.0 and Settings.screen_shake:
		shake = maxf(0.0, shake - C.SHAKE_DECAY * delta)
		shake_offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * minf(shake, 10.0)
		shake_offset = (shake_offset / 2.0).round() * 2.0 # stay on the 2x pixel grid
	else:
		shake = 0.0
		shake_offset = Vector2.ZERO
	pf_rect.position = C.PF_ORIGIN + shake_offset
	flash_t = maxf(0.0, flash_t - delta)
	view.queue_redraw()
	hud.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and state != "results":
		set_paused(not paused)
		get_viewport().set_input_as_handled()
		return
	if paused:
		return
	if tutorial_active and event.is_action_pressed("skip_tutorial"):
		skip_tutorial()
		get_viewport().set_input_as_handled()
		return
	if GameInput.touch_seen:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			drag_active = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			GameInput.virtual_bomb = true
	elif event is InputEventMouseMotion and drag_active:
		drag_delta += (event as InputEventMouseMotion).relative * 0.5

func add_touch_drag(screen_delta: Vector2) -> void:
	drag_delta += screen_delta * C.TOUCH_DRAG_GAIN

func set_paused(value: bool) -> void:
	if state == "results":
		return
	paused = value
	if paused:
		AudioDirector.play("ui_back")
		pause_menu.open()
	else:
		pause_menu.close()

# ---------------------------------------------------------------- flow
func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	match s:
		"intro":
			player_pos = Vector2(C.PLAYER_START.x, C.PF_H + 30)
			player_invuln = 3.0
		"tutorial":
			tutorial_active = true
			tut_step = 0
			tut_t = 0.0
			tutorial_card.show_step(0)
		"warning":
			AudioDirector.fade_music(2.4)
			AudioDirector.play("warning")
			shake = 3.0
		"victory":
			AudioDirector.fade_music(2.5)
		"gameover":
			AudioDirector.fade_music(1.6)

func _update_state(dt: float) -> void:
	match state:
		"intro":
			player_pos.y = lerpf(C.PF_H + 30, C.PLAYER_START.y, _ease_out(clampf(state_t / 1.2, 0, 1)))
			if state_t >= 1.3:
				if debug_start == "boss":
					wave_idx = StageData.WAVES.size() - 1
					_set_state("warning")
				elif debug_start.begins_with("wave"):
					_begin_wave(int(debug_start.substr(4)) - 1)
				elif force_tutorial or not SaveData.tutorial_done:
					_set_state("tutorial")
				else:
					_begin_wave(0)
		"tutorial":
			_update_tutorial(dt)
		"wave":
			_update_wave(dt)
		"interlude":
			if state_t >= 1.6:
				if interlude_next == "boss":
					_set_state("warning")
				else:
					_begin_wave(wave_idx + 1)
		"warning":
			stargate_y = lerpf(-300.0, -40.0, _ease_out(clampf(state_t / 4.0, 0, 1)))
			if state_t >= 3.6:
				_start_boss()
		"boss":
			stargate_y = lerpf(stargate_y, -40.0, dt * 0.5)
		"victory":
			if state_t >= 4.6 and not results.visible:
				_finish_run(true)
		"gameover":
			if state_t >= 2.2 and not results.visible:
				_finish_run(false)

func _begin_wave(idx: int) -> void:
	wave_idx = idx
	wave_t = 0.0
	wave_banner_t = 2.4
	TuningStore.apply_boundary("NEXT_SPAWN")
	TuningStore.apply_boundary("NEXT_ATTACK")
	wave_queue = _expand_wave(StageData.WAVES[idx])
	_set_state("wave")
	AudioDirector.play("ui_confirm")

func _expand_wave(wave: Dictionary) -> Array:
	var q: Array = []
	for ev: Dictionary in wave["events"]:
		var copies: Array = [ev]
		if ev.get("mirror", false):
			copies.append(_mirror_event(ev))
		for e: Dictionary in copies:
			for i in range(int(e.get("count", 1))):
				q.append({"at": float(e["at"]) + i * float(e.get("gap", 0.3)), "x": float(e.get("x", 0.5)) + i * float(e.get("dx", 0.0)), "ev": e})
	q.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	return q

func _mirror_event(ev: Dictionary) -> Dictionary:
	var m := ev.duplicate(true)
	m["x"] = 1.0 - float(ev.get("x", 0.5))
	m["dx"] = -float(ev.get("dx", 0.0))
	if ev.has("angle"):
		m["angle"] = 180.0 - float(ev["angle"])
	if ev.has("turn"):
		m["turn"] = -float(ev["turn"])
	if ev.has("side"):
		m["side"] = "right" if ev["side"] == "left" else "left"
	m.erase("mirror")
	return m

func _update_wave(dt: float) -> void:
	wave_t += dt
	wave_banner_t = maxf(0.0, wave_banner_t - dt)
	while not wave_queue.is_empty() and float(wave_queue[0]["at"]) <= wave_t:
		var entry: Dictionary = wave_queue.pop_front()
		_spawn_enemy(entry["ev"], entry["x"])
	var wave: Dictionary = StageData.WAVES[wave_idx]
	var cleared := wave_queue.is_empty() and enemies.is_empty()
	if cleared or wave_t >= float(wave.get("max_time", 60.0)):
		interlude_next = "boss" if wave_idx >= StageData.WAVES.size() - 1 else "wave"
		for e: Enemy in enemies:
			e.speed = maxf(e.speed, 60.0) # stragglers leave
		_set_state("interlude")

func _finish_run(victory: bool) -> void:
	var breakdown := compute_results(victory)
	var is_best := SaveData.record_run(int(breakdown["total"]), str(breakdown["rank"]), max_chain, victory)
	breakdown["new_best"] = is_best
	state = "results"
	results.open(breakdown)
	run_finished.emit(victory)

func compute_results(victory: bool) -> Dictionary:
	var clear_bonus := C.CLEAR_BONUS if victory else 0
	var life_bonus := lives * C.LIFE_BONUS if victory else 0
	score += clear_bonus + life_bonus
	var total := score
	var rank := "D"
	for r: Array in C.RANKS:
		if total >= int(r[0]):
			rank = str(r[1])
			break
	return {"victory": victory, "total": total, "clear_bonus": clear_bonus, "life_bonus": life_bonus, "rank": rank,
		"max_chain": max_chain, "grazes": grazes, "kills": kills, "misses": misses, "time": run_time, "phases": phases_broken}

func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func quit_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")

# ---------------------------------------------------------------- tutorial
func _update_tutorial(dt: float) -> void:
	tut_t += dt
	match tut_step:
		0:
			if tut_moved > 90.0 and tut_t > 1.0:
				_tut_next()
		1:
			if focus:
				tut_focus_time += dt
			if tut_focus_time > 1.1:
				_tut_next()
		2:
			tut_emit_t -= dt
			if tut_emit_t <= 0.0:
				tut_emit_t = 1.25
				var spec := {"pattern": "ring", "count": 14, "speed": 44, "rot_step": 7, "shape": "orb", "color": "cyan"}
				BulletPatterns.fire(self, Vector2(C.PF_W * 0.5, 56), spec, {"fired": int(tut_t * 3)})
			if tut_grazes >= 8 or tut_t > 16.0:
				_tut_next()
		3:
			if energy < C.ENERGY_MAX and not burst_active:
				energy = C.ENERGY_MAX
			if burst_active:
				_tut_next()
		4:
			if tut_t > 2.0:
				_end_tutorial()

func _tut_next() -> void:
	tut_step += 1
	tut_t = 0.0
	AudioDirector.play("ui_confirm")
	tutorial_card.show_step(tut_step)

func skip_tutorial() -> void:
	if not tutorial_active:
		return
	for b: Bullet in bullets:
		_pop_bullet(b)
	bullets.clear()
	_end_tutorial()

func _end_tutorial() -> void:
	tutorial_active = false
	tutorial_card.hide_card()
	SaveData.mark_tutorial_done()
	energy = C.ENERGY_START
	energy_full_announced = false
	chain = 0
	score = 0
	display_score = 0
	grazes = 0
	_begin_wave(0)

# ---------------------------------------------------------------- player
func _update_player(dt: float) -> void:
	player_invuln = maxf(0.0, player_invuln - dt)
	if not player_alive:
		respawn_t -= dt
		if respawn_t <= 0.0 and lives > 0:
			player_alive = true
			player_pos = Vector2(C.PLAYER_START.x, C.PF_H + 16)
			player_invuln = C.RESPAWN_INVULN
		return
	if state == "intro":
		return
	focus = GameInput.focus_held()
	var move := GameInput.move_vector()
	if autoplay:
		move = _bot_move()
	var speed := tune("focus_speed", C.PLAYER_FOCUS_SPEED) if focus else tune("player_speed", C.PLAYER_SPEED)
	var before := player_pos
	player_pos += move * speed * dt
	if drag_delta != Vector2.ZERO:
		player_pos += drag_delta
		drag_delta = Vector2.ZERO
	# Respawn glide back into the play area.
	if player_pos.y > C.PLAYER_BOUNDS.end.y:
		player_pos.y = move_toward(player_pos.y, C.PLAYER_BOUNDS.end.y - 20, 120 * dt)
		player_pos.x = clampf(player_pos.x, C.PLAYER_BOUNDS.position.x, C.PLAYER_BOUNDS.end.x)
	else:
		player_pos = player_pos.clamp(C.PLAYER_BOUNDS.position, C.PLAYER_BOUNDS.end)
	var moved := player_pos - before
	bank = move_toward(bank, clampf(moved.x / maxf(dt, 0.001) / 120.0, -1, 1), dt * 6.0)
	if tutorial_active:
		tut_moved += moved.length()
	# Weapon
	if state not in ["results", "gameover", "victory"]:
		fire_t -= dt
		if fire_t <= 0.0:
			fire_t = C.FIRE_INTERVAL
			_fire_player()
	# Burst
	if GameInput.consume_bomb():
		try_burst()
	elif autoplay and energy >= C.ENERGY_MAX and bullets.size() > 70:
		try_burst()

func _fire_player() -> void:
	var p := player_pos + Vector2(0, -10)
	if focus:
		for ox: float in C.FOCUS_OFFSETS:
			_add_shot(p + Vector2(ox, 0), Vector2(0, -C.SHOT_SPEED), C.SHOT_DAMAGE * C.FOCUS_DAMAGE_MULT, false)
	else:
		for a: float in C.SPREAD_ANGLES:
			_add_shot(p, Vector2(0, -C.SHOT_SPEED).rotated(a), C.SHOT_DAMAGE, false)
	for side: float in [-1.0, 1.0]:
		var off: Vector2 = C.OPTION_FOCUS_OFFSET if focus else C.OPTION_OFFSET
		var op := player_pos + Vector2(off.x * side, off.y)
		var dir := Vector2(0, -C.SHOT_SPEED * 0.9)
		if not focus:
			dir = dir.rotated(0.1 * side)
		_add_shot(op, dir, C.OPTION_DAMAGE, true)
	shoot_sfx_toggle = not shoot_sfx_toggle
	if shoot_sfx_toggle:
		AudioDirector.play("shoot")

func _add_shot(p: Vector2, v: Vector2, dmg: float, option: bool) -> void:
	var s := Shot.new()
	s.pos = p
	s.vel = v
	s.damage = dmg
	s.option = option
	shots.append(s)

func try_burst() -> bool:
	if state in ["results", "gameover", "victory", "intro"]:
		return false
	if not player_alive or burst_active:
		return false
	if energy < C.ENERGY_MAX:
		hud.deny_burst()
		return false
	energy = 0.0
	energy_full_announced = false
	burst_active = true
	burst_t = 0.0
	burst_origin = player_pos
	player_invuln = maxf(player_invuln, C.BURST_INVULN)
	bursts_used += 1
	for e: Enemy in enemies:
		e.burst_hit = false
	flash_t = 0.35
	flash_color = Color(0.7, 0.95, 1.0)
	shake = 8.0
	hitstop = 0.05
	AudioDirector.play("bomb")
	_spawn_ring(player_pos, Color(0.6, 1.0, 1.0), 0.5, 4.0, 180.0, true)
	for i in range(40 if Settings.effects_high else 16):
		var a := randf() * TAU
		_spawn_particle(player_pos, Vector2.from_angle(a) * randf_range(80, 260), randf_range(0.4, 0.9), Color(0.7, 1, 1), 1, 2.0, 1.5, true)
	return true

func _player_hit() -> void:
	if tutorial_active:
		return
	if god_mode:
		god_hits += 1
		player_invuln = 1.0
		return
	player_alive = false
	lives -= 1
	misses += 1
	respawn_t = C.DEATH_RESPAWN_DELAY
	hitstop = C.HITSTOP_PLAYER_HIT
	shake = 10.0
	flash_t = 0.25
	flash_color = Color(1.0, 0.35, 0.45)
	AudioDirector.play("player_hit")
	_explode(player_pos, 2, Color(0.6, 0.95, 1.0))
	if chain >= 10:
		_popup(player_pos + Vector2(0, -20), I18n.t("pop.chain_lost"), Color(1, 0.4, 0.5), true)
	chain = 0
	chain_t = 0.0
	last_milestone = 0
	# Fairness: clear the field on a miss.
	for b: Bullet in bullets:
		_pop_bullet(b)
	bullets.clear()
	if lives <= 0:
		_set_state("gameover")
		AudioDirector.play("defeat")

# ---------------------------------------------------------------- shots
func _update_shots(dt: float) -> void:
	for s: Shot in shots:
		s.pos += s.vel * dt
		if s.pos.y < -12 or s.pos.x < -12 or s.pos.x > C.PF_W + 12:
			s.dead = true
			continue
		for e: Enemy in enemies:
			if e.dead:
				continue
			if s.pos.distance_squared_to(e.pos) < pow(float(e.data["radius"]) + 3.0, 2):
				s.dead = true
				_damage_enemy(e, s.damage, s.pos)
				break
		if not s.dead and _boss_hittable() and _boss_contains(s.pos):
			s.dead = true
			_damage_boss(s.damage, s.pos)
	shots = shots.filter(func(s: Shot) -> bool: return not s.dead)

# ---------------------------------------------------------------- enemies
func _spawn_enemy(ev: Dictionary, x_frac: float) -> void:
	var e := Enemy.new()
	e.kind = ev["enemy"]
	e.data = EnemyTypes.get_type(e.kind)
	e.ev = ev
	e.hp = float(e.data["hp"]) * tune("enemy_health", 1.0)
	e.max_hp = e.hp
	e.speed = float(ev.get("speed", 60.0))
	var path: String = ev.get("path", "dive")
	match path:
		"sweep":
			var left: bool = ev.get("side", "left") == "left"
			e.pos = Vector2(-20.0 if left else C.PF_W + 20.0, float(ev.get("y", 60.0)))
			e.heading = 0.0 if left else PI
		"curve":
			e.pos = Vector2(x_frac * C.PF_W, -20)
			e.heading = deg_to_rad(float(ev.get("angle", 90.0)))
		_:
			e.pos = Vector2(x_frac * C.PF_W, -24)
			e.heading = PI * 0.5
	e.origin_x = e.pos.x
	for key: String in ["fire", "fire2"]:
		if ev.has(key):
			var spec: Dictionary = ev[key]
			e.fires.append({"spec": spec, "timer": float(spec.get("delay", 1.0)), "left": int(spec.get("shots", 1)), "state": {}})
	enemies.append(e)

func _update_enemies(dt: float) -> void:
	var hit_r := tune("hit_radius", C.PLAYER_HIT_RADIUS)
	for e: Enemy in enemies:
		if e.dead:
			continue
		e.age += dt
		e.flash = maxf(0.0, e.flash - dt)
		var ev := e.ev
		match String(ev.get("path", "dive")):
			"dive":
				e.pos.y += e.speed * dt
				var drift := float(ev.get("drift", 0.0))
				if drift != 0.0:
					e.pos.x = e.origin_x + sin(e.age * 1.7) * drift
			"curve":
				var turn_at := float(ev.get("turn_at", 0.8))
				if e.age > turn_at and e.age < turn_at + float(ev.get("turn_for", 2.6)):
					e.heading += deg_to_rad(float(ev.get("turn", 30.0))) * dt
				e.pos += Vector2.from_angle(e.heading) * e.speed * dt
			"stop":
				var enter := 1.4
				var hold := float(ev.get("hold", 5.0))
				if e.age < enter:
					e.pos.y = lerpf(-28.0, float(ev.get("stop_y", 70.0)), _ease_out(e.age / enter))
				elif e.age < enter + hold and state == "wave":
					e.pos.x = lerpf(e.pos.x, e.origin_x + sin((e.age - enter) * 0.9) * 10.0, dt * 2.0)
				else:
					var t := maxf(0.0, e.age - enter - hold)
					e.pos.y -= (20.0 + t * 90.0) * dt
			"sweep":
				e.pos += Vector2.from_angle(e.heading) * e.speed * dt
				e.pos.y += cos(e.age * 2.4) * 16.0 * dt
		# Fire
		var can_fire := e.pos.y > C.ENEMY_FIRE_MIN_Y and e.pos.y < C.ENEMY_FIRE_MAX_Y and e.pos.x > 4 and e.pos.x < C.PF_W - 4 and state == "wave"
		for f: Dictionary in e.fires:
			f["timer"] = float(f["timer"]) - dt
			if float(f["timer"]) <= 0.0 and int(f["left"]) > 0:
				if can_fire:
					f["left"] = int(f["left"]) - 1
					f["timer"] = float(f["spec"].get("interval", 1.5))
					BulletPatterns.fire(self, e.pos + Vector2(0, 4), f["spec"], f["state"])
					AudioDirector.play("enemy_fire")
				else:
					f["timer"] = 0.1
		# Body contact
		if player_alive and player_invuln <= 0.0 and e.pos.distance_to(player_pos) < float(e.data["radius"]) * 0.6 + hit_r:
			_player_hit()
		# Cull
		if e.age > 1.0 and (e.pos.y > C.PF_H + 40 or e.pos.y < -60 or e.pos.x < -50 or e.pos.x > C.PF_W + 50):
			e.dead = true
	enemies = enemies.filter(func(e: Enemy) -> bool: return not e.dead)

func _damage_enemy(e: Enemy, dmg: float, at: Vector2) -> void:
	e.hp -= dmg
	e.flash = 0.06
	if randf() < 0.5:
		_spawn_particle(at, Vector2(randf_range(-40, 40), randf_range(-90, -30)), 0.18, Color(1, 0.9, 0.6), 0, 1.0, 0.0, true)
	AudioDirector.play("enemy_hit")
	if e.hp <= 0.0:
		_kill_enemy(e)

func _kill_enemy(e: Enemy) -> void:
	if e.dead:
		return
	e.dead = true
	kills += 1
	var blast := int(e.data["blast"])
	_bump_chain(1 + blast * 2)
	var gained := add_score(int(e.data["score"]))
	_popup(e.pos, _fmt(gained), Color(1.0, 0.86, 0.4), blast >= 1)
	energy_add(C.KILL_ENERGY * (1 + blast * 2))
	_explode(e.pos, blast, Color(1.0, 0.55, 0.3))
	if blast == 0:
		AudioDirector.play("explode_small")
		shake = maxf(shake, 1.5)
	else:
		AudioDirector.play("explode_big")
		shake = maxf(shake, 4.0 + blast * 3.0)
		hitstop = maxf(hitstop, 0.03 * blast)
	var shards := int(e.data["shards"])
	for i in range(shards):
		_spawn_item(e.pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), "gem" if i % 6 == 5 else "star")
	for i in range(int(e.data["energy"])):
		_spawn_item(e.pos, "energy")

# ---------------------------------------------------------------- boss
func _start_boss() -> void:
	boss_active = true
	boss_entering = true
	boss_pos = Vector2(C.PF_W * 0.5, -90)
	boss_t = 0.0
	boss_phase = -1
	boss_card_t = 3.2
	boss_sprite = "boss_p1"
	_set_state("boss")
	AudioDirector.play_music("boss", true)
	AudioDirector.play("charge")

func _boss_phase_data() -> Dictionary:
	return StageData.BOSS["phases"][boss_phase]

func _begin_boss_phase(idx: int) -> void:
	boss_phase = idx
	TuningStore.apply_boundary("NEXT_BOSS")
	TuningStore.apply_boundary("NEXT_ATTACK")
	var ph := _boss_phase_data()
	boss_max_hp = float(ph["hp"]) * tune("boss_health", 1.0)
	boss_hp = boss_max_hp
	boss_phase_time = float(ph["time"])
	boss_sprite = str(ph["sprite"])
	boss_card_t = 2.6
	boss_emitters.clear()
	for em: Dictionary in ph["emitters"]:
		boss_emitters.append({"def": em, "timer": float(em.get("delay", 1.0)), "state": {}})

func _boss_hittable() -> bool:
	return boss_active and not boss_entering and boss_breaking <= 0.0 and boss_dead_t <= 0.0 and boss_phase >= 0

func _boss_contains(p: Vector2) -> bool:
	var d := p - boss_pos
	if absf(d.x) < 34 and d.y > -44 and d.y < 44:
		return true
	if absf(d.x) < 88 and d.y > -30 and d.y < 22:
		return true
	return false

func _update_boss(dt: float) -> void:
	if not boss_active:
		return
	boss_t += dt
	boss_flash = maxf(-0.2, boss_flash - dt)
	boss_card_t = maxf(0.0, boss_card_t - dt)
	if boss_dead_t > 0.0:
		_update_boss_death(dt)
		return
	if boss_entering:
		boss_pos.y = lerpf(-90.0, 76.0, _ease_out(clampf(boss_t / C.BOSS_ENTRY_TIME, 0, 1)))
		if boss_t >= C.BOSS_ENTRY_TIME:
			boss_entering = false
			boss_t = 0.0
			_begin_boss_phase(debug_phase)
		return
	if boss_breaking > 0.0:
		boss_breaking -= dt
		boss_pos = boss_pos.lerp(Vector2(C.PF_W * 0.5, 72), dt * 2.0)
		if randf() < 0.25:
			_explode(boss_pos + Vector2(randf_range(-80, 80), randf_range(-40, 40)), 0, Color(1, 0.6, 0.3))
		if boss_breaking <= 0.0:
			boss_t = 0.0
			_begin_boss_phase(boss_phase + 1)
		return
	var ph := _boss_phase_data()
	# Movement
	var target := boss_pos
	match String(ph.get("move", "sway")):
		"sway":
			target = Vector2(C.PF_W * 0.5 + sin(boss_t * 0.7) * 52.0, 74.0 + sin(boss_t * 1.4) * 6.0)
		"hover":
			target = Vector2(C.PF_W * 0.5 + sin(boss_t * 0.45) * 16.0, 80.0 + sin(boss_t * 0.9) * 5.0)
		"figure8":
			target = Vector2(C.PF_W * 0.5 + sin(boss_t * 0.6) * 58.0, 82.0 + sin(boss_t * 1.2) * 14.0)
	boss_pos = boss_pos.lerp(target, clampf(dt * 3.0, 0, 1))
	# Emitters
	var rage := float(ph.get("rage", 1.0)) if boss_hp / boss_max_hp < float(ph.get("rage_at", 0.0)) else 1.0
	for em: Dictionary in boss_emitters:
		em["timer"] = float(em["timer"]) - dt
		if float(em["timer"]) <= 0.0:
			var def: Dictionary = em["def"]
			em["timer"] = float(def.get("interval", 1.0)) * rage
			BulletPatterns.fire(self, boss_pos + def.get("origin", Vector2.ZERO), def["fire"], em["state"])
			AudioDirector.play("enemy_fire", -2.0)
	boss_phase_time -= dt
	if boss_phase_time <= 0.0:
		_break_boss_phase(false)

func _damage_boss(dmg: float, at: Vector2) -> void:
	boss_hp -= dmg
	if boss_flash < -0.07:
		boss_flash = 0.045
	if randf() < 0.35:
		_spawn_particle(at, Vector2(randf_range(-50, 50), randf_range(-110, -40)), 0.2, Color(1, 0.85, 0.5), 0, 1.0, 0.0, true)
	AudioDirector.play("enemy_hit", -3.0)
	if boss_hp <= 0.0:
		_break_boss_phase(true)

func _break_boss_phase(killed: bool) -> void:
	if not _boss_hittable():
		return
	phases_broken += 1 if killed else 0
	var bonus := 0
	if killed:
		bonus = add_score(C.BOSS_PHASE_BONUS + int(maxf(boss_phase_time, 0.0) * C.BOSS_TIME_BONUS_PER_SEC))
	var label := (I18n.t("pop.phase_break") + "  +" + _fmt(bonus)) if killed else I18n.t("pop.phase_timeout")
	_popup(boss_pos + Vector2(0, 50), label, Color(1, 0.9, 0.45) if killed else Color(0.7, 0.75, 0.9), true)
	_convert_all_bullets()
	for em: Dictionary in boss_emitters:
		em["timer"] = 99.0
	hitstop = C.HITSTOP_BOSS_BREAK
	shake = 12.0
	flash_t = 0.3
	flash_color = Color(1.0, 0.85, 0.6)
	AudioDirector.play("boss_break")
	for i in range(5):
		_explode(boss_pos + Vector2(randf_range(-70, 70), randf_range(-30, 30)), 1, Color(1, 0.55, 0.3))
	for i in range(12):
		_spawn_item(boss_pos + Vector2(randf_range(-40, 40), randf_range(-20, 20)), "gem")
	for i in range(2):
		_spawn_item(boss_pos, "energy")
	for it: Item in items:
		it.magnet = true
	if boss_phase >= StageData.BOSS["phases"].size() - 1:
		boss_dead_t = 0.001
		slowmo_t = 1.2
		_set_state("victory")
	else:
		boss_breaking = C.BOSS_PHASE_BREAK_TIME

func _update_boss_death(dt: float) -> void:
	boss_dead_t += dt
	boss_pos += Vector2(sin(boss_dead_t * 40.0) * 0.6, 6.0 * dt)
	stargate_glow = minf(1.0, stargate_glow + dt * 0.4)
	if boss_active and randf() < 0.45:
		_explode(boss_pos + Vector2(randf_range(-90, 90), randf_range(-45, 45)), 1 if randf() < 0.3 else 0, Color(1, 0.6, 0.3))
		AudioDirector.play("explode_small")
		shake = maxf(shake, 4.0)
	if boss_dead_t > 2.6 and boss_active:
		boss_active = false
		hitstop = 0.2
		flash_t = 0.6
		flash_color = Color(1, 0.95, 0.85)
		shake = 16.0
		AudioDirector.play("explode_big")
		AudioDirector.play("victory")
		for i in range(4):
			_explode(boss_pos + Vector2(randf_range(-50, 50), randf_range(-30, 30)), 2, Color(1, 0.7, 0.35))
		_spawn_ring(boss_pos, Color(1, 0.9, 0.7), 0.9, 6.0, 260.0, true)
		for it: Item in items:
			it.magnet = true

# ---------------------------------------------------------------- bullets
## BulletPatterns sink API.
func spawn_bullet(p: Vector2, angle: float, speed: float, shape: String, color: String, spec: Dictionary) -> void:
	if bullets.size() >= 1400:
		return
	var mult := tune("enemy_bullet_speed", 1.0)
	var b := Bullet.new().setup(p, angle, speed * mult, shape, color)
	b.accel = float(spec.get("accel", 0.0)) * mult
	b.max_speed = float(spec.get("max_speed", 9999.0)) * mult
	b.min_speed = float(spec.get("min_speed", 0.0))
	b.curve = float(spec.get("curve_rad", 0.0))
	b.redirect_at = float(spec.get("redirect_at", -1.0))
	b.redirect_speed = float(spec.get("redirect_speed", 90.0)) * mult
	bullets.append(b)

func aim_angle(from: Vector2) -> float:
	var target := player_pos if player_alive else Vector2(C.PF_W * 0.5, C.PF_H - 40)
	return (target - from).angle()

func _update_bullets(dt: float) -> void:
	var hit_r := tune("hit_radius", C.PLAYER_HIT_RADIUS)
	var graze_r := tune("graze_radius", C.PLAYER_GRAZE_RADIUS)
	var can_hit := player_alive and player_invuln <= 0.0 and state != "intro" and not tutorial_active
	var can_graze := player_alive and state != "intro"
	var m := C.PF_MARGIN
	for b: Bullet in bullets:
		b.age += dt
		if b.accel != 0.0:
			b.speed = clampf(b.speed + b.accel * dt, b.min_speed, b.max_speed)
		if b.curve != 0.0:
			b.angle += b.curve * dt
		if b.redirect_at > 0.0 and b.age >= b.redirect_at:
			b.redirect_at = -1.0
			b.angle = aim_angle(b.pos)
			b.speed = b.redirect_speed
			b.accel = 0.0
			if Settings.effects_high:
				_spawn_particle(b.pos, Vector2.ZERO, 0.2, Color(0.8, 0.6, 1.0), 2, 1.0, 16.0, true)
		b.pos += Vector2.from_angle(b.angle) * b.speed * dt
		if b.pos.x < -m or b.pos.x > C.PF_W + m or b.pos.y < -m - 10 or b.pos.y > C.PF_H + m:
			b.dead = true
			continue
		if b.age < C.BULLET_WARMUP:
			continue
		var d2 := b.pos.distance_squared_to(player_pos)
		if can_graze and not b.grazed and d2 < pow(graze_r + b.radius, 2):
			b.grazed = true
			_graze(b)
		if can_hit and d2 < pow(hit_r + b.radius, 2):
			b.dead = true
			_player_hit()
			break
	bullets = bullets.filter(func(b: Bullet) -> bool: return not b.dead)

func _graze(b: Bullet) -> void:
	grazes += 1
	graze_pulse = 1.0
	if tutorial_active:
		tut_grazes += 1
	_bump_chain(1)
	add_score(C.GRAZE_SCORE)
	energy_add(tune("graze_energy", C.GRAZE_ENERGY))
	AudioDirector.play("graze", 0.0, 1.0 + minf(chain, 200) * 0.002)
	var dir := (b.pos - player_pos).normalized()
	for i in range(3 if Settings.effects_high else 1):
		_spawn_particle(player_pos + dir * 6.0, dir.rotated(randf_range(-0.6, 0.6)) * randf_range(60, 130), 0.22, Color(0.55, 1.0, 1.0), 1, 1.0, 0.0, true)

func _pop_bullet(b: Bullet) -> void:
	if Settings.effects_high or randf() < 0.3:
		_spawn_particle(b.pos, Vector2(0, -10), 0.25, bullet_color(b.color), 2, 1.0, 14.0, true)

func _convert_all_bullets() -> void:
	for b: Bullet in bullets:
		_convert_bullet(b)
	bullets.clear()

func _convert_bullet(b: Bullet) -> void:
	b.dead = true
	var it := _spawn_item(b.pos, "shard")
	it.vel = Vector2(randf_range(-10, 10), randf_range(-30, -10))
	it.magnet = true
	if Settings.effects_high or randf() < 0.35:
		_spawn_particle(b.pos, Vector2.ZERO, 0.28, bullet_color(b.color), 2, 1.0, 18.0, true)

static func bullet_color(c: String) -> Color:
	match c:
		"pink": return Color(1.0, 0.35, 0.7)
		"orange": return Color(1.0, 0.6, 0.25)
		"violet": return Color(0.7, 0.45, 1.0)
		_: return Color(0.4, 0.95, 1.0)

# ---------------------------------------------------------------- burst
func _update_burst(dt: float) -> void:
	if not burst_active:
		return
	var prev := burst_t
	burst_t += dt
	var k := clampf(burst_t / C.BURST_DURATION, 0, 1)
	var radius := _ease_out(k) * C.BURST_RADIUS
	var r2 := radius * radius
	var converted := 0
	for b: Bullet in bullets:
		if b.pos.distance_squared_to(burst_origin) < r2:
			_convert_bullet(b)
			converted += 1
	if converted > 0:
		bullets = bullets.filter(func(b: Bullet) -> bool: return not b.dead)
		_bump_chain(int(ceil(converted / 6.0)))
	for e: Enemy in enemies:
		if not e.burst_hit and not e.dead and e.pos.distance_to(burst_origin) < radius:
			e.burst_hit = true
			_damage_enemy(e, C.BURST_ENEMY_DAMAGE, e.pos)
	if _boss_hittable() and burst_t >= 0.25 and prev < 0.25:
		_damage_boss(C.BURST_BOSS_DAMAGE, boss_pos)
		boss_flash = 0.2
	if burst_t >= C.BURST_DURATION:
		burst_active = false

# ---------------------------------------------------------------- items & score
func _spawn_item(p: Vector2, kind: String) -> Item:
	var it := Item.new()
	it.pos = p
	it.kind = kind
	it.vel = Vector2(randf_range(-40, 40), randf_range(-110, -50))
	items.append(it)
	return it

func _update_items(dt: float) -> void:
	var magnet_r := C.ITEM_FOCUS_MAGNET_RADIUS if focus else C.ITEM_MAGNET_RADIUS
	var vacuum := player_alive and player_pos.y < C.ITEM_AUTOCOLLECT_Y
	for it: Item in items:
		it.age += dt
		var to_player := player_pos - it.pos
		var dist := to_player.length()
		if player_alive and (it.magnet or vacuum or dist < magnet_r) and it.age > 0.25:
			var spd := 300.0 + it.age * 120.0
			it.vel = it.vel.lerp(to_player.normalized() * spd, clampf(dt * 10.0, 0, 1))
		else:
			it.vel.y = move_toward(it.vel.y, C.ITEM_FALL_SPEED, 160.0 * dt)
			it.vel.x = move_toward(it.vel.x, 0.0, 60.0 * dt)
		it.pos += it.vel * dt
		if player_alive and dist < 9.0:
			it.dead = true
			_collect(it)
		elif it.pos.y > C.PF_H + 16:
			it.dead = true
	items = items.filter(func(i: Item) -> bool: return not i.dead)

func _collect(it: Item) -> void:
	match it.kind:
		"star":
			var v := add_score(C.SHARD_VALUE)
			if Settings.effects_high and randf() < 0.3:
				_popup(it.pos + Vector2(0, -6), _fmt(v), Color(1, 0.85, 0.35), false)
			AudioDirector.play("pickup")
		"gem":
			var v := add_score(C.SHARD_VALUE * 5)
			_popup(it.pos + Vector2(0, -6), _fmt(v), Color(1, 0.9, 0.5), false)
			AudioDirector.play("pickup", 2.0, 1.15)
		"energy":
			energy_add(C.ENERGY_ITEM)
			AudioDirector.play("pickup", 0.0, 0.8)
		"shard":
			add_score(C.CONVERTED_SHARD_VALUE)
			AudioDirector.play("pickup", -4.0, 1.3)
	score_pulse = 1.0

func multiplier() -> float:
	return minf(1.0 + float(chain) / C.CHAIN_PER_MULT, C.CHAIN_MULT_MAX)

func add_score(base: int) -> int:
	var v := int(round(base * multiplier() / 10.0)) * 10
	if tutorial_active:
		return v
	score += v
	return v

func energy_add(amount: float) -> void:
	if burst_active:
		return
	energy = minf(C.ENERGY_MAX, energy + amount)
	if energy >= C.ENERGY_MAX and not energy_full_announced and not tutorial_active:
		energy_full_announced = true
		AudioDirector.play("energy_full")
		_popup(player_pos + Vector2(0, -22), I18n.t("pop.burst_ready"), Color(0.5, 1, 1), true)

func _bump_chain(n: int) -> void:
	chain += n
	chain_t = tune("chain_window", C.CHAIN_WINDOW)
	chain_pulse = 1.0
	max_chain = maxi(max_chain, chain)
	for ms: int in C.CHAIN_MILESTONES:
		if chain >= ms and last_milestone < ms:
			last_milestone = ms
			AudioDirector.play("combo_up")
			_popup(player_pos + Vector2(0, -30), I18n.t("pop.chain", {"n": ms}), Color(1.0, 0.5, 0.85), true)
			if Settings.effects_high:
				_spawn_ring(player_pos, Color(1.0, 0.5, 0.85), 0.35, 1.0, 50.0, true)

func _update_scoring(dt: float) -> void:
	graze_pulse = maxf(0.0, graze_pulse - dt * 4.0)
	chain_pulse = maxf(0.0, chain_pulse - dt * 5.0)
	score_pulse = maxf(0.0, score_pulse - dt * 6.0)
	if chain > 0 and not burst_active:
		chain_t -= dt
		if chain_t <= 0.0:
			if chain >= 20:
				_popup(player_pos + Vector2(0, -24), I18n.t("pop.chain_end", {"n": chain}), Color(0.8, 0.8, 1.0), false)
			chain = 0
			last_milestone = 0

# ---------------------------------------------------------------- fx
func _spawn_particle(p: Vector2, v: Vector2, life: float, color: Color, kind := 0, size := 1.0, grow := 0.0, add := false, drag := 3.0) -> void:
	var cap := C.MAX_PARTICLES_HIGH if Settings.effects_high else C.MAX_PARTICLES_LOW
	if particles.size() >= cap:
		return
	var pt := Particle.new()
	pt.pos = p
	pt.vel = v
	pt.life = life
	pt.max_life = life
	pt.color = color
	pt.kind = kind
	pt.size = size
	pt.grow = grow
	pt.add = add
	pt.drag = drag
	particles.append(pt)

func _spawn_ring(p: Vector2, color: Color, life: float, size: float, grow: float, add := true) -> void:
	_spawn_particle(p, Vector2.ZERO, life, color, 2, size, grow, add, 0.0)

func _explode(p: Vector2, size: int, tint: Color) -> void:
	var q := 1.0 if Settings.effects_high else 0.45
	var n := int((10 + size * 18) * q)
	_spawn_particle(p, Vector2.ZERO, 0.12 + size * 0.06, Color(1, 1, 0.9), 3, 6.0 + size * 6.0, 30.0, true, 0.0)
	_spawn_ring(p, Color(1.0, 0.8, 0.5), 0.3 + size * 0.12, 2.0, 70.0 + size * 60.0)
	for i in range(n):
		var a := randf() * TAU
		var sp := randf_range(30, 110 + size * 70)
		var col := Color(1, 0.95, 0.7).lerp(tint, randf())
		_spawn_particle(p, Vector2.from_angle(a) * sp, randf_range(0.25, 0.6 + size * 0.25), col, 0, randf_range(1.0, 2.0 + size), -1.5, randf() < 0.5)
	for i in range(int((4 + size * 6) * q)):
		var a := randf() * TAU
		_spawn_particle(p, Vector2.from_angle(a) * randf_range(90, 200 + size * 80), randf_range(0.2, 0.45), Color(1, 0.9, 0.6), 1, 1.0, 0.0, true, 2.0)
	if size >= 1:
		for i in range(int(6 * q * size)):
			_spawn_particle(p + Vector2(randf_range(-8, 8), randf_range(-8, 8)), Vector2(randf_range(-30, 30), randf_range(-30, 30)), randf_range(0.5, 0.9), Color(0.35, 0.3, 0.4, 0.8), 3, randf_range(3, 6), 8.0, false, 1.0)

func _popup(p: Vector2, text: String, color: Color, big: bool) -> void:
	if popups.size() > 40:
		popups.pop_front()
	var pp := ScorePopup.new()
	pp.pos = p
	pp.text = text
	pp.color = color
	pp.big = big
	pp.life = 1.2 if big else 0.8
	pp.max_life = pp.life
	popups.append(pp)

func _update_fx(dt: float) -> void:
	for pt: Particle in particles:
		pt.life -= dt
		pt.pos += pt.vel * dt
		if pt.drag > 0.0:
			pt.vel *= maxf(0.0, 1.0 - pt.drag * dt)
		pt.size = maxf(0.0, pt.size + pt.grow * dt)
	particles = particles.filter(func(pt: Particle) -> bool: return pt.life > 0.0)
	for pp: ScorePopup in popups:
		pp.life -= dt
		pp.pos.y -= (22.0 if pp.big else 16.0) * dt
	popups = popups.filter(func(pp: ScorePopup) -> bool: return pp.life > 0.0)

# ---------------------------------------------------------------- helpers
func _ease_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)

func _fmt(v: int) -> String:
	return format_score(v)

static func format_score(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	var n := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		n += 1
		if n % 3 == 0 and i > 0:
			out = "," + out
	return out

func stage_progress() -> float:
	## 0..1 across the three waves and the boss, for the HUD progress rail.
	var segs := float(StageData.WAVES.size() + 1)
	if boss_active or state in ["warning", "victory", "results"]:
		var bp := 0.0
		if boss_phase >= 0:
			bp = (boss_phase + (1.0 - clampf(boss_hp / maxf(boss_max_hp, 1.0), 0, 1))) / 3.0
		return (StageData.WAVES.size() + bp) / segs
	if wave_idx < 0:
		return 0.0
	var w: Dictionary = StageData.WAVES[wave_idx]
	return (wave_idx + clampf(wave_t / float(w.get("max_time", 40.0)) * 1.4, 0, 1)) / segs

# ---------------------------------------------------------------- test bot
## A simple dodging bot used by automated playthrough tests (never in play).
func _bot_move() -> Vector2:
	var threat := Vector2.ZERO
	for b: Bullet in bullets:
		var fut := b.pos + Vector2.from_angle(b.angle) * b.speed * 0.18
		var d := fut - player_pos
		var dist := d.length()
		if dist < 34.0:
			threat -= d.normalized() * (34.0 - dist) / 34.0 * (1.0 + b.radius * 0.2)
	var goal := Vector2(C.PF_W * 0.5, 300)
	if boss_active:
		goal.x = boss_pos.x
	elif not enemies.is_empty():
		goal.x = (enemies[0] as Enemy).pos.x
	var home := (goal - player_pos) / 60.0
	var v := threat * 3.0 + home.limit_length(0.6)
	if not items.is_empty() and threat.length() < 0.1:
		v += ((items[0] as Item).pos - player_pos).normalized() * 0.3
	return v.limit_length(1.0)
