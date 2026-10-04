extends SceneTree

var i18n: Node

var output := OS.get_environment("GAME_CAPTURE_DIR")


func _initialize() -> void:
	_run.call_deferred()


func _capture(node: CanvasItem, name: String) -> void:
	node.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	assert(result == OK)


func _run() -> void:
	i18n = root.get_node("I18n")
	assert(not output.is_empty(), "GAME_CAPTURE_DIR must point outside the source draft")
	assert(OS.get_user_data_dir().contains("ManusLocaleAcceptance-"), "Use an isolated acceptance user directory")
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(output)
	for locale: String in ["en", "zh-CN"]:
		i18n.set_locale(locale)
		var title = load("res://scenes/title_screen.tscn").instantiate()
		root.add_child(title)
		title.best_score = 18450
		await _capture(title, locale + "-title")
		title.queue_free()
		await process_frame
		var game = load("res://scenes/game.tscn").instantiate()
		root.add_child(game)
		game.set_process(false)
		game.phase = game.Phase.PLAYING
		game.score = 1450
		game.energy = 100
		game.weapon_level = 2
		game._queue_formation(2)
		for index: int in game.enemies.size():
			var enemy: Dictionary = game.enemies[index]
			enemy.pos.x = float(enemy.pos.x) - 500.0
			enemy.node.position = enemy.pos
			game.enemies[index] = enemy
		game._spawn_bone(Vector2(560, 185))
		game.shoot_player()
		await _capture(game, locale + "-gameplay")
		game.phase = game.Phase.PAUSED
		await _capture(game, locale + "-pause")
		game.phase = game.Phase.VICTORY
		game._show_dialogue("dialogue.victory", 99.0)
		await _capture(game, locale + "-victory")
		game.phase = game.Phase.DEFEAT
		game._show_dialogue("dialogue.defeat", 99.0)
		await _capture(game, locale + "-defeat")
		game.phase = game.Phase.PLAYING
		game._start_boss(2)
		game.boss_pos = Vector2(1065, 360)
		game.boss_sprite.position = game.boss_pos
		game._boss_volley()
		await _capture(game, locale + "-boss")
		for child in game.get_children():
			if child is AudioStreamPlayer or child == game.bgm_player:
				child.stop()
		game.queue_free()
		await create_timer(0.25).timeout
	print("[BULLET_HELL_LOCALIZATION_CAPTURE_PASS] 14 native EN/CN title/game/pause/results/tuning/boss captures")
	quit(0)
