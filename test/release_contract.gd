extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	assert(root.get_node_or_null("TweakControls") == null)
	var store := root.get_node("TuningStore")
	assert(not store.has_method("load_draft"))
	assert(root.get_node_or_null("TuningBridge") == null)
	assert(not ResourceLoader.exists("res://scripts/manus/preview/tuning_transport.gd"))
	var game = load("res://scenes/game.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	assert(game.tuning_player_speed == 350.0)
	assert(game.tuning_enemy_health == 0.5)
	var font := game.UI_FONT as FontVariation
	assert(font.base_font.get_font_name().begins_with("Exo 2"))
	assert(font.fallbacks.size() == 1 and (font.fallbacks[0] as FontVariation).base_font.get_font_name().begins_with("Noto Sans SC"))
	assert(not font.base_font.allow_system_fallback and not (font.fallbacks[0] as FontVariation).base_font.allow_system_fallback)
	game.spawn_enemy(0)
	assert(float(game.enemies[0].max_hp) == 1.5)
	game._start_boss(0)
	assert(game.boss_max_hp == 166.25)
	game.shoot_player()
	assert(game.bullets.size() > 0)
	for voice in [game.bgm_player, game.shoot_sfx, game.hit_sfx, game.explosion_sfx]:
		voice.stop()
	game.queue_free()
	await create_timer(0.5).timeout
	await process_frame
	print("[BULLET_HELL_RELEASE_PASS] source defaults, no developer controls or draft loader, gameplay runs")
	quit(0)
