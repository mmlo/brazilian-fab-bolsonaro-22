extends Node

func _ready() -> void:
	call_deferred("_run")

func _capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var dir := OS.get_environment("GAME_CAPTURE_DIR")
	if dir == "": dir = "user://captures"
	DirAccess.make_dir_recursive_absolute(dir)
	var image := get_viewport().get_texture().get_image()
	var result := image.save_png(dir.path_join(name + ".png"))
	assert(result == OK)

func _run() -> void:
	var title = load("res://scenes/title_screen.tscn").instantiate()
	add_child(title)
	await _capture("title")
	title.queue_free()
	await get_tree().process_frame
	var game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	game.phase = 1
	game.intro_timer = 0
	game._queue_formation(2)
	for i in range(game.enemies.size()):
		var enemy: Dictionary = game.enemies[i]
		enemy.pos.x = float(enemy.pos.x) - 500.0
		enemy.base_y = enemy.pos.y
		enemy.node.position = enemy.pos
		game.enemies[i] = enemy
	game.score = 1450
	game.energy = 100
	game.weapon_level = 2
	game._spawn_bone(Vector2(560, 185))
	game.shoot_player()
	game._show_dialogue("Tuan: W formation ahead! Bones upgrade your guns.", 9.0)
	await _capture("gameplay")
	game.bullets.clear()
	game.weapon_level = 1
	game._spawn_bone(game.player_pos)
	game._update_pickups(0.016)
	game.shoot_player()
	assert(game.weapon_level == 2)
	assert(game.weapon_upgrade_timer > 0.0)
	assert(not game.weapon_upgrade_is_max)
	await _capture("weapon_upgrade")
	game.bullets.clear()
	game._spawn_bone(game.player_pos)
	game._update_pickups(0.016)
	game.shoot_player()
	assert(game.weapon_level == game.MAX_WEAPON_LEVEL)
	assert(game.weapon_upgrade_is_max)
	assert(game.bullets.size() == 8)
	game._update_projectiles(0.34)
	await _capture("weapon_max")
	for enemy in game.enemies:
		enemy.node.queue_free()
	game.enemies.clear()
	game.enemy_bullets.clear()
	game.bullets.clear()
	game._queue_formation(0)
	for i in range(game.enemies.size()):
		var line_enemy: Dictionary = game.enemies[i]
		line_enemy.pos.x = 820.0 + i * 62.0
		line_enemy.base_y = 360.0
		line_enemy.node.position = line_enemy.pos
		game.enemies[i] = line_enemy
	game.invulnerable = 99.0
	for step in range(20):
		game._update_enemies(0.08)
		game._update_projectiles(0.08)
	game._show_dialogue("Tuan: Line formation sweeping! Watch the staggered shots.", 9.0)
	assert(absf(float(game.enemies[0].pos.y) - 360.0) > 120.0)
	assert(game.enemy_bullets.size() >= 4)
	var bullet_min_y := 9999.0
	var bullet_max_y := -9999.0
	for hostile_bullet in game.enemy_bullets:
		bullet_min_y = minf(bullet_min_y, float(hostile_bullet.pos.y))
		bullet_max_y = maxf(bullet_max_y, float(hostile_bullet.pos.y))
	assert(bullet_max_y - bullet_min_y > 70.0)
	await _capture("line_sweep")
	game.enemy_bullets.clear()
	game.energy = 100
	game._activate_laser()
	assert(game.laser_timer == 5.0)
	for i in range(7):
		game.enemy_bullets.append({"pos": Vector2(530 + i * 75, game.player_pos.y + (i % 3 - 1) * 42), "vel": Vector2.ZERO, "life": 2.0, "size": 7.0})
	game.enemy_bullets.append({"pos": Vector2(800, game.player_pos.y + 190), "vel": Vector2.ZERO, "life": 2.0, "size": 7.0})
	game._update_abilities(0.016)
	assert(game.enemy_bullets.size() == 1)
	await _capture("laser")
	game.laser_timer = 0.0
	game.energy = 100
	game._activate_shield()
	assert(game.shield_hits == 3)
	await _capture("shield")
	game._start_boss(0)
	game.boss_pos = Vector2(1090, 360)
	game.boss_sprite.position = game.boss_pos
	game.boss_hp = game.boss_max_hp * 0.72
	game._boss_volley()
	assert(game.enemy_bullets.size() == 3)
	await _capture("elite_barrage")
	game._start_boss(1)
	game.boss_pos = Vector2(1060, 360)
	game.boss_sprite.position = game.boss_pos
	game.player_pos = Vector2(190, 220)
	game._start_boss_laser()
	assert(game.boss_laser_warning > 0.0)
	await _capture("elite_laser_warning")
	game.boss_laser_warning = 0.0
	game.boss_laser_active = 0.72
	game._show_dialogue("Tuan: Laser firing! Stay outside the warning lane!", 9.0)
	await _capture("elite_laser_active")
	game._start_boss(2)
	game.boss_pos = Vector2(1065, 360)
	game.boss_sprite.position = game.boss_pos
	game.player_pos = Vector2(190, 360)
	game.boss_hp = game.boss_max_hp * 0.58
	game._boss_volley()
	game._update_projectiles(0.42)
	game._boss_volley()
	game._update_projectiles(0.36)
	game._boss_volley()
	game._update_projectiles(0.48)
	assert(game.enemy_bullets.size() == 22)
	await _capture("elite_geometry")
	game._start_boss(3)
	game.boss_pos = Vector2(1025, 360)
	game.boss_sprite.position = game.boss_pos
	game.boss_hp = game.boss_max_hp * 0.46
	game._boss_volley()
	game._update_projectiles(0.40)
	game._boss_volley()
	game._update_projectiles(0.34)
	game._boss_volley()
	game._update_projectiles(0.44)
	assert(game.enemy_bullets.size() == 30)
	game.player_pos = Vector2(190, 265)
	game._start_boss_laser()
	game._show_dialogue("Tuan: Final core! Mixed patterns and a charging laser!", 9.0)
	await _capture("boss_final")
	print("[DEBUG_CAPTURE_PASS] weapon_upgrade weapon_max star_fang doubled_formation three_elites final_boss tweak")
	for child in game.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	game.queue_free()
	await get_tree().create_timer(0.25).timeout
	get_tree().quit(0)
