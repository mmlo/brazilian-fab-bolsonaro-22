class_name Bullet
extends RefCounted
## One enemy bullet. Kept as a tiny typed object so hundreds update cheaply.

const SHAPES := ["orb", "rice", "big"]
const COLORS := ["pink", "orange", "violet", "cyan"]
const RADIUS := {"orb": 2.8, "rice": 2.2, "big": 6.0}

var pos := Vector2.ZERO
var angle := 0.0 # radians, 0 = right, PI/2 = down
var speed := 0.0
var accel := 0.0
var max_speed := 9999.0
var min_speed := 0.0
var curve := 0.0 # angular velocity, rad/s
var redirect_at := -1.0 # seconds; re-aim at the player once
var redirect_speed := 0.0
var shape := "orb"
var color := "pink"
var shape_idx := 0
var color_idx := 0
var radius := 2.8
var age := 0.0
var grazed := false
var dead := false

func setup(p: Vector2, a: float, s: float, sh: String, col: String) -> Bullet:
	pos = p
	angle = a
	speed = s
	shape = sh
	color = col
	shape_idx = SHAPES.find(sh)
	color_idx = COLORS.find(col)
	radius = RADIUS.get(sh, 2.8)
	return self
