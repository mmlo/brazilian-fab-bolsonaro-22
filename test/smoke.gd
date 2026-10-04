extends SceneTree
## Fast headless smoke test for Starveil Barrage.
## Run: godot --headless --path . --script test/smoke.gd   ->  prints [SMOKE_PASS]
const StageDataScript = preload("res://scripts/data/stage_1.gd")
const EnemyTypesScript = preload("res://scripts/data/enemy_types.gd")
const Patterns = preload("res://scripts/combat/bullet_patterns.gd")
const Cfg = preload("res://scripts/config/game_config.gd")

var failures: Array[String] = []

func _initialize() -> void:
	root.get_node("AudioDirector").silent = true
	call_deferred("_run")

func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

func _frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func _run() -> void:
	var save := root.get_node("SaveData")
	var backup := [save.best_score, save.best_rank, save.tutorial_done, save.clears, save.runs, save.best_chain]
	# ---- data integrity -------------------------------------------------
	_check(StageDataScript.WAVES.size() == 3, "stage has exactly 3 waves")
	_check(StageDataScript.BOSS["phases"].size() == 3, "boss has exactly 3 phases")
	var patterns_used := {}
	for w: Dictionary in StageDataScript.WAVES:
		for ev: Dictionary in w["events"]:
			_check(EnemyTypesScript.TYPES.has(ev["enemy"]), "wave enemy type exists: " + str(ev["enemy"]))
			if ev.has("fire"):
				patterns_used[ev["fire"]["pattern"]] = ev["fire"]
	var phase_patterns: Array = []
	for ph: Dictionary in StageDataScript.BOSS["phases"]:
		var names := {}
		for em: Dictionary in ph["emitters"]:
			names[em["fire"]["pattern"]] = true
			patterns_used[em["fire"]["pattern"]] = em["fire"]
		phase_patterns.append(names.keys())
	_check(phase_patterns[0] != phase_patterns[1] and phase_patterns[1] != phase_patterns[2], "each boss phase uses a different pattern mix")

	# ---- game scene --------------------------------------------------------
	save.tutorial_done = false
	change_scene_to_file("res://scenes/game.tscn")
	var game = null
	for i in range(60):
		await process_frame
		game = current_scene
		if game != null and game.has_method("try_burst"):
			break
	_check(game != null and game.has_method("try_burst"), "game scene loads")
	if game == null:
		_finish()
		return
	# every pattern referenced by data spawns bullets
	for name: String in patterns_used:
		var before: int = game.bullets.size()
		Patterns.fire(game, Vector2(135, 60), patterns_used[name], {})
		_check(game.bullets.size() > before, "pattern spawns bullets: " + name)
	game.bullets.clear()
	# intro -> first-run tutorial
	for i in range(600):
		if game.state != "intro":
			break
		await physics_frame
	_check(game.state == "tutorial" and game.tutorial_active, "first run opens the tutorial (state=%s)" % game.state)
	game.tut_moved = 999.0
	await _frames(90)
	_check(game.tut_step >= 1, "tutorial advances after moving")
	game.skip_tutorial()
	await _frames(5)
	_check(not game.tutorial_active and save.tutorial_done, "skipping the tutorial persists the flag")
	_check(game.state == "wave", "tutorial hands over to wave 1")
	# gamepad: left stick moves the ship and switches prompts to pad glyphs
	game.player_pos.x = 100.0
	var jm := InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_LEFT_X
	jm.axis_value = 1.0
	Input.parse_input_event(jm)
	await _frames(20)
	_check(game.player_pos.x > 120.0, "gamepad stick moves the ship (x=%.1f)" % game.player_pos.x)
	_check(root.get_node("GameInput").device == "pad", "gamepad input switches prompt device")
	jm = InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_LEFT_X
	jm.axis_value = 0.0
	Input.parse_input_event(jm)
	await _frames(3)
	# graze -> chain + energy + score
	game.bullets.clear()
	game.player_invuln = 0.0
	var e0: float = game.energy
	var s0: int = game.score
	var g0: int = game.grazes
	game.spawn_bullet(game.player_pos + Vector2(Cfg.PLAYER_HIT_RADIUS + 7.0, -30), PI * 0.5, 60.0, "orb", "pink", {})
	game.god_mode = true
	await _frames(50)
	_check(game.grazes > g0, "a close pass counts as graze")
	_check(game.energy > e0 and game.score > s0 and game.chain > 0, "graze feeds energy, score and chain")
	# burst clears bullets into score
	game.energy = Cfg.ENERGY_MAX
	for i in range(30):
		game.spawn_bullet(Vector2(20 + i * 7, 40), PI * 0.5, 30.0, "rice", "violet", {})
	var n_before: int = game.bullets.size()
	_check(game.try_burst(), "burst fires when the gauge is full")
	await _frames(90)
	_check(game.bullets.size() < n_before / 3, "burst clears the screen (%d -> %d)" % [n_before, game.bullets.size()])
	_check(game.energy < Cfg.ENERGY_MAX, "burst consumes energy")
	_check(not game.try_burst(), "burst is denied while empty")
	# pause freezes the simulation
	game.set_paused(true)
	var t0: float = game.run_time
	await _frames(20)
	_check(is_equal_approx(t0, game.run_time) and game.pause_menu.visible, "pause freezes play and shows the menu")
	game.set_paused(false)
	await _frames(5)
	_check(game.run_time > t0, "resume continues play")
	# results + local best
	save.best_score = 0
	var breakdown: Dictionary = game.compute_results(true)
	_check(breakdown["total"] >= Cfg.CLEAR_BONUS and str(breakdown["rank"]) in ["S", "A", "B", "C", "D"], "results compute totals and rank")
	_check(save.record_run(int(breakdown["total"]), str(breakdown["rank"]), 10, true) and save.best_score == int(breakdown["total"]), "new local best is recorded")
	_check(not save.record_run(1, "D", 1, false), "lower score is not a new best")
	# restore persisted state
	save.best_score = backup[0]; save.best_rank = backup[1]; save.tutorial_done = backup[2]
	save.clears = backup[3]; save.runs = backup[4]; save.best_chain = backup[5]
	save.save()
	_finish()

func _finish() -> void:
	if current_scene != null:
		current_scene.queue_free()
	root.get_node("AudioDirector").stop_all()
	for i in range(8):
		await process_frame
	if failures.is_empty():
		print("[SMOKE_PASS] data, patterns, tutorial, graze/chain/burst, pause, results and local best")
		quit(0)
	else:
		for f in failures:
			push_error(f)
		quit(1)
