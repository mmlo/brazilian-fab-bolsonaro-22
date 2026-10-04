extends SceneTree
## Automated full-stage run with the dodging bot (god mode records would-be hits).
## Prints per-section timings, score and difficulty indicators.
## Run: godot --headless --fixed-fps 60 --script test/playthrough.gd
var game: Node
var frames := 0
var last_state := ""
var last_phase := -2
var section_start := 0.0
var max_bullets := 0
var log_lines: Array[String] = []

func _initialize() -> void:
	root.get_node("AudioDirector").silent = true
	var sd := root.get_node("SaveData")
	sd.tutorial_done = true
	change_scene_to_file("res://scenes/game.tscn")

func _process(_delta: float) -> bool:
	if _quitting:
		return false
	frames += 1
	if game == null:
		game = current_scene
		if frames > 300:
			push_error("game scene failed to load")
			quit(1)
			return true
		if game != null and game.has_method("try_burst"):
			game.autoplay = true
			game.god_mode = true
		else:
			game = null
		return false
	if game.state == "tutorial" and game.tutorial_active:
		game.skip_tutorial()
	max_bullets = maxi(max_bullets, game.bullets.size())
	if frames % 600 == 0:
		print("frame %d state=%s t=%.1f bullets=%d particles=%d enemies=%d fps=%d" % [frames, game.state, game.run_time, game.bullets.size(), game.particles.size(), game.enemies.size(), Engine.get_frames_per_second()])
	var key := "%s/w%d/p%d" % [game.state, game.wave_idx, game.boss_phase]
	if key != last_state:
		log_lines.append("t=%6.1fs  %-26s score=%d chain=%d grazes=%d hits=%d bullets_peak=%d" % [game.run_time, key, game.score, game.chain, game.grazes, game.god_hits, max_bullets])
		last_state = key
		max_bullets = 0
	# Bot uses burst when crowded
	if game.energy >= 100.0 and game.bullets.size() > 70:
		game.try_burst()
	if game.state == "results":
		for l in log_lines:
			print(l)
		print("FINAL score=%d kills=%d grazes=%d max_chain=%d would_be_hits=%d bursts=%d time=%.1f" % [game.score, game.kills, game.grazes, game.max_chain, game.god_hits, game.bursts_used, game.run_time])
		print("[PLAYTHROUGH_PASS]")
		_cleanup_and_quit(0)
		return true
	if frames > 60 * 60 * 9:
		for l in log_lines:
			print(l)
		push_error("Playthrough did not finish in time; state=" + game.state)
		_cleanup_and_quit(1)
		return true
	return false

var _quitting := false
func _cleanup_and_quit(code: int) -> void:
	if _quitting:
		return
	_quitting = true
	root.get_node("AudioDirector").stop_all()
	if current_scene != null:
		current_scene.queue_free()
	game = null
	for i in range(8):
		await process_frame
	quit(code)
