class_name BulletPatterns
extends RefCounted
const C := preload("res://scripts/config/game_config.gd")
## Bullet pattern library. A pattern spec is plain data (see stage_1.gd):
##   pattern  aimed | fixed | ring | spiral | petal | curtain | rain
##   shape    orb | rice | big          color  pink | orange | violet | cyan
##   speed    px/s; optional accel/max_speed/min_speed, redirect_at/redirect_speed
## `state` is a per-emitter Dictionary the pattern may use to remember rotation.
## `sink` must provide spawn_bullet(pos, angle, speed, shape, color, spec) and
## aim_angle(from) -> float (radians toward the player).

static func fire(sink: Object, origin: Vector2, spec: Dictionary, state: Dictionary) -> void:
	var shape: String = spec.get("shape", "orb")
	var color: String = spec.get("color", "pink")
	var speed: float = spec.get("speed", 60.0)
	var shots: int = int(state.get("fired", 0))
	state["fired"] = shots + 1
	match String(spec.get("pattern", "aimed")):
		"aimed":
			var count: int = spec.get("count", 1)
			var spread := deg_to_rad(spec.get("spread", 0.0))
			var layers: int = spec.get("layers", 1)
			var step: float = spec.get("speed_step", 12.0)
			var base: float = sink.aim_angle(origin)
			for layer in range(layers):
				for i in range(count):
					var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
					sink.spawn_bullet(origin, base + t * spread, speed + layer * step, shape, color, spec)
		"fixed":
			var count: int = spec.get("count", 1)
			var spread := deg_to_rad(spec.get("spread", 0.0))
			var base := deg_to_rad(spec.get("angle", 90.0))
			for i in range(count):
				var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
				sink.spawn_bullet(origin, base + t * spread, speed, shape, color, spec)
		"ring":
			var count: int = spec.get("count", 12)
			var rot := deg_to_rad(float(spec.get("rot_step", 0.0)) * shots)
			var base: float = sink.aim_angle(origin) if spec.get("aim", false) else PI * 0.5
			for i in range(count):
				sink.spawn_bullet(origin, base + rot + TAU * i / count, speed, shape, color, spec)
		"spiral":
			var arms: int = spec.get("arms", 3)
			var a: float = state.get("angle", randf() * TAU)
			for i in range(arms):
				sink.spawn_bullet(origin, a + TAU * i / arms, speed, shape, color, spec)
			state["angle"] = a + deg_to_rad(spec.get("spin", 10.0))
		"petal":
			# Curving rings that alternate direction: two passes weave into a flower.
			var count: int = spec.get("count", 16)
			var sign := -1.0 if spec.get("alternate", true) and shots % 2 == 1 else 1.0
			var curve := deg_to_rad(spec.get("curve", 24.0)) * sign
			var offset := (PI / count) * (shots % 2)
			var extra := spec.duplicate()
			extra["curve_rad"] = curve
			for i in range(count):
				sink.spawn_bullet(origin, PI * 0.5 + offset + TAU * i / count, speed, shape, color, extra)
		"curtain":
			# A pendulum sweep: each shot's angle swings with a sine over time.
			var count: int = spec.get("count", 2)
			var amp := deg_to_rad(spec.get("amp", 40.0))
			var freq: float = spec.get("freq", 1.5)
			var tt: float = state.get("t", 0.0)
			state["t"] = tt + 0.12
			var base := PI * 0.5 + sin(tt * freq * TAU * 0.5) * amp
			for i in range(count):
				sink.spawn_bullet(origin, base + (i - (count - 1) * 0.5) * 0.16, speed + i * 6.0, shape, color, spec)
		"rain":
			var count: int = spec.get("count", 3)
			for i in range(count):
				var p := Vector2(randf_range(10.0, C.PF_W - 10.0), -6.0)
				sink.spawn_bullet(p, PI * 0.5 + randf_range(-0.12, 0.12), speed * randf_range(0.8, 1.2), shape, color, spec)
		_:
			push_warning("Unknown bullet pattern: %s" % spec.get("pattern"))
