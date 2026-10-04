class_name StageData
extends RefCounted
## ------------------------------------------------------------------------
## STAGE 1 — espaço aéreo do Brasil. Pure data: edit freely to re-author the level.
##
## WAVES: each wave is a timeline of spawn events (seconds since wave start).
##   enemy   id from EnemyTypes          path   dive | curve | stop | sweep
##   x       0..1 across the playfield    count/gap  group size and spacing (s)
##   dx      x step per group member      mirror  also spawn a copy at 1 - x
##   speed   movement speed (px/s)        y       row for sweep paths (px)
##   stop_y/hold  for "stop" paths         turn/turn_at  deg/s and delay for "curve"
##   fire    a bullet pattern spec (see BulletPatterns) + interval/delay/shots
## A wave ends when its last event has spawned, the field is clear (or the
## wave's max_time is reached).
##
## THREAT COMMANDER: phases in order. Each phase lists emitters that fire independently.
##   emitter.origin  offset from the boss centre   emitter.interval  seconds
##   rage            multiplier for intervals once hp < rage_at
## ------------------------------------------------------------------------

const WAVES := [
	{
		"name_key": "wave.1.name",
		"max_time": 44.0,
		"events": [
			{"at": 1.0, "enemy": "drone", "path": "dive", "x": 0.28, "count": 5, "gap": 0.32, "speed": 78,
				"fire": {"pattern": "aimed", "count": 1, "speed": 78, "shape": "orb", "color": "pink", "delay": 0.9, "interval": 9, "shots": 1}},
			{"at": 4.0, "enemy": "drone", "path": "dive", "x": 0.72, "count": 5, "gap": 0.32, "speed": 78,
				"fire": {"pattern": "aimed", "count": 1, "speed": 78, "shape": "orb", "color": "pink", "delay": 0.9, "interval": 9, "shots": 1}},
			{"at": 7.5, "enemy": "lancer", "path": "curve", "x": 0.12, "count": 4, "gap": 0.45, "speed": 92, "angle": 80, "turn": -34, "turn_at": 0.8,
				"fire": {"pattern": "aimed", "count": 3, "spread": 26, "speed": 84, "shape": "rice", "color": "orange", "delay": 0.7, "interval": 1.6, "shots": 2}},
			{"at": 10.0, "enemy": "lancer", "path": "curve", "x": 0.88, "count": 4, "gap": 0.45, "speed": 92, "angle": 100, "turn": 34, "turn_at": 0.8,
				"fire": {"pattern": "aimed", "count": 3, "spread": 26, "speed": 84, "shape": "rice", "color": "orange", "delay": 0.7, "interval": 1.6, "shots": 2}},
			{"at": 13.5, "enemy": "frigate", "path": "stop", "x": 0.5, "stop_y": 72, "hold": 7.0, "speed": 40,
				"fire": {"pattern": "ring", "count": 14, "speed": 52, "rot_step": 9, "shape": "orb", "color": "violet", "delay": 1.0, "interval": 1.25, "shots": 7}},
			{"at": 15.0, "enemy": "drone", "path": "dive", "x": 0.12, "count": 4, "gap": 0.4, "speed": 96, "mirror": true,
				"fire": {"pattern": "aimed", "count": 1, "speed": 84, "shape": "orb", "color": "pink", "delay": 0.6, "interval": 9, "shots": 1}},
			{"at": 22.5, "enemy": "drone", "path": "dive", "x": 0.2, "count": 6, "gap": 0.18, "dx": 0.12, "speed": 86,
				"fire": {"pattern": "aimed", "count": 1, "speed": 86, "shape": "orb", "color": "pink", "delay": 0.8, "interval": 9, "shots": 1}},
			{"at": 25.0, "enemy": "lancer", "path": "curve", "x": 0.18, "count": 3, "gap": 0.5, "speed": 96, "angle": 78, "turn": -30, "turn_at": 0.9, "mirror": true,
				"fire": {"pattern": "aimed", "count": 3, "spread": 30, "speed": 88, "shape": "rice", "color": "orange", "delay": 0.6, "interval": 1.5, "shots": 2}},
			{"at": 29.0, "enemy": "frigate", "path": "stop", "x": 0.26, "stop_y": 60, "hold": 6.5, "speed": 40, "mirror": true,
				"fire": {"pattern": "aimed", "count": 5, "spread": 48, "speed": 70, "shape": "orb", "color": "orange", "layers": 2, "speed_step": 14, "delay": 1.0, "interval": 1.9, "shots": 4}},
		],
	},
	{
		"name_key": "wave.2.name",
		"max_time": 48.0,
		"events": [
			{"at": 1.0, "enemy": "lancer", "path": "sweep", "side": "left", "y": 46, "count": 6, "gap": 0.36, "speed": 88,
				"fire": {"pattern": "fixed", "angle": 90, "count": 1, "speed": 70, "shape": "rice", "color": "cyan", "delay": 0.5, "interval": 0.55, "shots": 6}},
			{"at": 4.5, "enemy": "lancer", "path": "sweep", "side": "right", "y": 78, "count": 6, "gap": 0.36, "speed": 88,
				"fire": {"pattern": "fixed", "angle": 90, "count": 1, "speed": 70, "shape": "rice", "color": "cyan", "delay": 0.5, "interval": 0.55, "shots": 6}},
			{"at": 8.5, "enemy": "frigate", "path": "stop", "x": 0.5, "stop_y": 80, "hold": 8.0, "speed": 40,
				"fire": {"pattern": "spiral", "arms": 3, "speed": 58, "spin": 13, "shape": "rice", "color": "violet", "delay": 1.0, "interval": 0.16, "shots": 44}},
			{"at": 9.5, "enemy": "drone", "path": "dive", "x": 0.08, "count": 5, "gap": 0.5, "speed": 70, "mirror": true,
				"fire": {"pattern": "aimed", "count": 1, "speed": 80, "shape": "orb", "color": "pink", "delay": 0.7, "interval": 1.8, "shots": 2}},
			{"at": 19.0, "enemy": "lancer", "path": "curve", "x": 0.5, "count": 6, "gap": 0.35, "speed": 100, "angle": 90, "turn": 42, "turn_at": 0.6,
				"fire": {"pattern": "aimed", "count": 3, "spread": 24, "speed": 92, "shape": "rice", "color": "orange", "delay": 0.5, "interval": 1.2, "shots": 2}},
			{"at": 21.0, "enemy": "lancer", "path": "curve", "x": 0.5, "count": 6, "gap": 0.35, "speed": 100, "angle": 90, "turn": -42, "turn_at": 0.6,
				"fire": {"pattern": "aimed", "count": 3, "spread": 24, "speed": 92, "shape": "rice", "color": "orange", "delay": 0.5, "interval": 1.2, "shots": 2}},
			{"at": 25.5, "enemy": "frigate", "path": "stop", "x": 0.22, "stop_y": 66, "hold": 7.0, "speed": 40, "mirror": true,
				"fire": {"pattern": "petal", "count": 10, "speed": 50, "curve": 26, "alternate": true, "shape": "orb", "color": "pink", "delay": 1.0, "interval": 1.5, "shots": 5}},
			{"at": 27.0, "enemy": "drone", "path": "dive", "x": 0.5, "count": 8, "gap": 0.45, "speed": 64, "drift": 40,
				"fire": {"pattern": "aimed", "count": 1, "speed": 76, "shape": "orb", "color": "cyan", "delay": 0.8, "interval": 2.0, "shots": 2}},
		],
	},
	{
		"name_key": "wave.3.name",
		"max_time": 56.0,
		"events": [
			{"at": 1.0, "enemy": "drone", "path": "dive", "x": 0.15, "count": 6, "gap": 0.22, "dx": 0.14, "speed": 90,
				"fire": {"pattern": "aimed", "count": 1, "speed": 90, "shape": "orb", "color": "pink", "delay": 0.6, "interval": 9, "shots": 1}},
			{"at": 3.5, "enemy": "drone", "path": "dive", "x": 0.85, "count": 6, "gap": 0.22, "dx": -0.14, "speed": 90,
				"fire": {"pattern": "aimed", "count": 1, "speed": 90, "shape": "orb", "color": "pink", "delay": 0.6, "interval": 9, "shots": 1}},
			{"at": 6.0, "enemy": "carrier", "path": "stop", "x": 0.5, "stop_y": 74, "hold": 20.0, "speed": 26,
				"fire": {"pattern": "spiral", "arms": 4, "speed": 56, "spin": 9, "shape": "orb", "color": "violet", "delay": 1.8, "interval": 0.2, "shots": 999},
				"fire2": {"pattern": "aimed", "count": 3, "spread": 30, "speed": 66, "shape": "big", "color": "pink", "delay": 2.8, "interval": 2.6, "shots": 999}},
			{"at": 10.0, "enemy": "lancer", "path": "sweep", "side": "left", "y": 150, "count": 4, "gap": 0.5, "speed": 70,
				"fire": {"pattern": "aimed", "count": 1, "speed": 80, "shape": "rice", "color": "orange", "delay": 0.8, "interval": 1.6, "shots": 2}},
			{"at": 16.0, "enemy": "lancer", "path": "sweep", "side": "right", "y": 130, "count": 4, "gap": 0.5, "speed": 70,
				"fire": {"pattern": "aimed", "count": 1, "speed": 80, "shape": "rice", "color": "orange", "delay": 0.8, "interval": 1.6, "shots": 2}},
			{"at": 28.0, "enemy": "frigate", "path": "stop", "x": 0.25, "stop_y": 64, "hold": 6.0, "speed": 44, "mirror": true,
				"fire": {"pattern": "ring", "count": 16, "speed": 56, "rot_step": 11, "shape": "rice", "color": "cyan", "delay": 0.9, "interval": 1.2, "shots": 5}},
			{"at": 31.0, "enemy": "drone", "path": "dive", "x": 0.1, "count": 8, "gap": 0.16, "dx": 0.11, "speed": 100,
				"fire": {"pattern": "aimed", "count": 1, "speed": 92, "shape": "orb", "color": "pink", "delay": 0.5, "interval": 9, "shots": 1}},
		],
	},
]

const BOSS := {
	"name_key": "boss.name",
	"title_key": "boss.title",
	"phases": [
		{
			"name_key": "boss.phase1",
			"hp": 1450.0, "time": 60.0, "sprite": "boss_p1", "move": "sway", "rage_at": 0.0, "rage": 1.0,
			"emitters": [
				{"origin": Vector2(0, 14), "interval": 0.95, "delay": 0.6,
					"fire": {"pattern": "petal", "count": 18, "speed": 54, "curve": 24, "alternate": true, "shape": "orb", "color": "pink"}},
				{"origin": Vector2(-62, 20), "interval": 2.3, "delay": 1.6,
					"fire": {"pattern": "aimed", "count": 5, "spread": 36, "speed": 96, "shape": "rice", "color": "orange"}},
				{"origin": Vector2(62, 20), "interval": 2.3, "delay": 2.75,
					"fire": {"pattern": "aimed", "count": 5, "spread": 36, "speed": 96, "shape": "rice", "color": "orange"}},
			],
		},
		{
			"name_key": "boss.phase2",
			"hp": 1750.0, "time": 62.0, "sprite": "boss_p2", "move": "hover", "rage_at": 0.35, "rage": 0.82,
			"emitters": [
				{"origin": Vector2(0, 12), "interval": 0.1, "delay": 0.8,
					"fire": {"pattern": "spiral", "arms": 5, "speed": 64, "spin": 10.5, "shape": "rice", "color": "violet"}},
				{"origin": Vector2(0, 12), "interval": 0.2, "delay": 1.4,
					"fire": {"pattern": "spiral", "arms": 3, "speed": 46, "spin": -19, "shape": "orb", "color": "cyan"}},
				{"origin": Vector2(0, 30), "interval": 3.2, "delay": 3.0,
					"fire": {"pattern": "aimed", "count": 3, "spread": 22, "speed": 72, "shape": "big", "color": "pink"}},
			],
		},
		{
			"name_key": "boss.phase3",
			"hp": 2100.0, "time": 75.0, "sprite": "boss_p3", "move": "figure8", "rage_at": 0.3, "rage": 0.78,
			"emitters": [
				{"origin": Vector2(0, 10), "interval": 1.25, "delay": 0.8,
					"fire": {"pattern": "ring", "count": 22, "speed": 18, "accel": 70, "max_speed": 105, "rot_step": 7.5, "shape": "big", "color": "orange"}},
				{"origin": Vector2(0, 10), "interval": 2.6, "delay": 2.0,
					"fire": {"pattern": "ring", "count": 12, "speed": 80, "accel": -110, "min_speed": 0.0, "redirect_at": 1.1, "redirect_speed": 92, "shape": "rice", "color": "violet"}},
				{"origin": Vector2(-70, 26), "interval": 0.24, "delay": 3.0,
					"fire": {"pattern": "curtain", "count": 2, "speed": 70, "amp": 40, "freq": 1.6, "shape": "rice", "color": "pink"}},
				{"origin": Vector2(70, 26), "interval": 0.24, "delay": 3.0,
					"fire": {"pattern": "curtain", "count": 2, "speed": 70, "amp": 40, "freq": -1.6, "shape": "rice", "color": "pink"}},
			],
		},
	],
}
