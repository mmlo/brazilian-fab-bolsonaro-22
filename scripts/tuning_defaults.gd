class_name StarveilTuningDefaults
extends RefCounted
## Development Tweak catalog. Defaults mirror GameConfig; the simulation reads the
## active values through TuningStore so preview tuning applies at honest boundaries.

const PLAYER_SPEED := GameConfig.PLAYER_SPEED
const FOCUS_SPEED := GameConfig.PLAYER_FOCUS_SPEED
const HIT_RADIUS := GameConfig.PLAYER_HIT_RADIUS
const GRAZE_RADIUS := GameConfig.PLAYER_GRAZE_RADIUS
const GRAZE_ENERGY := GameConfig.GRAZE_ENERGY
const CHAIN_WINDOW := GameConfig.CHAIN_WINDOW
const ENEMY_HEALTH := 1.0
const ENEMY_BULLET_SPEED := 1.0
const BOSS_HEALTH := 1.0

static func descriptors() -> Array[Dictionary]:
	return [
		{"id": "player_speed", "label": "tuning.label.ship_speed", "category": "PLAYER", "type": "float", "default": PLAYER_SPEED, "min": 90, "max": 240, "step": 5, "mode": "LIVE", "unit": "px/s", "integrity": "GAMEPLAY"},
		{"id": "focus_speed", "label": "tuning.label.focus_speed", "category": "PLAYER", "type": "float", "default": FOCUS_SPEED, "min": 30, "max": 120, "step": 2, "mode": "LIVE", "unit": "px/s", "integrity": "GAMEPLAY"},
		{"id": "hit_radius", "label": "tuning.label.hit_radius", "category": "PLAYER", "type": "float", "default": HIT_RADIUS, "min": 0.8, "max": 5.0, "step": 0.1, "mode": "LIVE", "unit": "px", "integrity": "GAMEPLAY"},
		{"id": "graze_radius", "label": "tuning.label.graze_radius", "category": "SCORING", "type": "float", "default": GRAZE_RADIUS, "min": 6, "max": 30, "step": 1, "mode": "LIVE", "unit": "px", "integrity": "GAMEPLAY"},
		{"id": "graze_energy", "label": "tuning.label.graze_energy", "category": "SCORING", "type": "float", "default": GRAZE_ENERGY, "min": 0.5, "max": 8, "step": 0.1, "mode": "LIVE", "unit": "%", "integrity": "GAMEPLAY"},
		{"id": "chain_window", "label": "tuning.label.chain_window", "category": "SCORING", "type": "float", "default": CHAIN_WINDOW, "min": 1, "max": 6, "step": 0.1, "mode": "LIVE", "unit": "s", "integrity": "GAMEPLAY"},
		{"id": "enemy_health", "label": "tuning.label.enemy_health", "category": "ENEMIES", "type": "float", "default": ENEMY_HEALTH, "min": 0.3, "max": 3, "step": 0.1, "mode": "NEXT_SPAWN", "unit": "x", "integrity": "GAMEPLAY"},
		{"id": "enemy_bullet_speed", "label": "tuning.label.bullet_speed", "category": "ENEMIES", "type": "float", "default": ENEMY_BULLET_SPEED, "min": 0.5, "max": 1.8, "step": 0.05, "mode": "NEXT_ATTACK", "unit": "x", "integrity": "GAMEPLAY"},
		{"id": "boss_health", "label": "tuning.label.boss_health", "category": "ENEMIES", "type": "float", "default": BOSS_HEALTH, "min": 0.3, "max": 3, "step": 0.1, "mode": "NEXT_BOSS", "unit": "x", "integrity": "GAMEPLAY"},
	]
