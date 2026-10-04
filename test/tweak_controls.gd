extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(OS.get_user_data_dir().contains("ManusLocaleAcceptance-"), "Use isolated test storage")
	AudioServer.set_bus_mute(0, true)
	var store := root.get_node("TuningStore")
	store.reset_all()
	store.begin_run()
	assert(not store.set_value("missing", 1.0))
	assert(not store.set_value("player_speed", NAN))
	assert(not store.set_value("player_speed", "fast"))
	store.set_value("bgm_volume_db", -12.0)
	assert(not store.run_custom)
	store.set_value("boss_health", 3.0)
	assert(store.active_value("boss_health") == 1.75 and not store.run_custom)
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	store.reset_all()
	store.begin_run()
	store.set_value("boss_health", 3.0)
	game._start_boss(0)
	assert(game.boss_max_hp == 285.0 and store.run_custom)
	store.reset_all()
	assert(store.run_custom)
	store.begin_run()
	assert(not store.run_custom)
	store.set_value("enemy_health", 2.0)
	assert(store.active_value("enemy_health") == 0.5)
	game.spawn_enemy(0)
	assert(float(game.enemies[0].max_hp) == 6.0 and store.run_custom)
	store.set_value("fire_delay", 0.2)
	game.shoot_player()
	assert(is_equal_approx(game.fire_timer, 0.2))
	store.reset_all()
	for voice in [game.bgm_player, game.shoot_sfx, game.hit_sfx, game.explosion_sfx]:
		voice.stop()
	game.queue_free()
	await create_timer(0.25).timeout
	await process_frame
	await process_frame
	print("[TWEAK_CONTROLS_PASS] boundaries, cosmetics and sticky integrity")
	quit(0)
