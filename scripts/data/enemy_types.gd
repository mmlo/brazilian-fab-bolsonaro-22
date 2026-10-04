class_name EnemyTypes
extends RefCounted
## Enemy archetypes. Waves in `stage_1.gd` reference these by id.
##   sprite     texture id (assets/art/<sprite>.png, plus <sprite>_flash.png)
##   hp         base hit points (x the enemy_health tuning multiplier)
##   radius     collision radius against player shots and the player's hitbox
##   score      points on kill (x chain multiplier)
##   shards     star shards dropped on kill
##   energy     cyan energy crystals dropped on kill
##   blast      explosion size: 0 small, 1 medium, 2 large
##   face_motion  rotate the sprite toward its heading

const TYPES := {
	"drone": {"sprite": "enemy_drone", "hp": 4.0, "radius": 8.0, "score": 300, "shards": 2, "energy": 0, "blast": 0, "face_motion": false},
	"lancer": {"sprite": "enemy_lancer", "hp": 11.0, "radius": 9.0, "score": 700, "shards": 3, "energy": 0, "blast": 0, "face_motion": true},
	"frigate": {"sprite": "enemy_frigate", "hp": 80.0, "radius": 16.0, "score": 4000, "shards": 12, "energy": 1, "blast": 1, "face_motion": false},
	"carrier": {"sprite": "enemy_carrier", "hp": 520.0, "radius": 26.0, "score": 20000, "shards": 30, "energy": 3, "blast": 2, "face_motion": false},
}

static func get_type(id: String) -> Dictionary:
	assert(TYPES.has(id), "Unknown enemy type: " + id)
	return TYPES[id]
