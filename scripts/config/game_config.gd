class_name GameConfig
extends RefCounted
## ------------------------------------------------------------------------
## STARVEIL BARRAGE — central gameplay configuration.
## Every number that shapes feel, difficulty and scoring lives here so the game
## can be re-tuned without touching the simulation. Stage content (waves, boss
## phases, bullet patterns) is data in `scripts/data/stage_1.gd`; enemy
## archetypes are in `scripts/data/enemy_types.gd`.
## Distances are logical playfield pixels (the playfield renders 2x).
## ------------------------------------------------------------------------

# --- Screen / playfield ------------------------------------------------------
const SCREEN := Vector2(1280, 720)
const PF_W := 270
const PF_H := 360
const PF_SCALE := 2
const PF_ORIGIN := Vector2(370, 0) # screen position of the playfield's top-left
const PF_MARGIN := 24.0 # bullets are culled this far outside the playfield

# --- Player ------------------------------------------------------------------
const PLAYER_SPEED := 150.0 # px/s normal flight
const PLAYER_FOCUS_SPEED := 64.0 # px/s while focus is held
const PLAYER_HIT_RADIUS := 1.8 # the true hitbox (drawn as the core dot)
const PLAYER_GRAZE_RADIUS := 15.0 # bullets passing inside this ring graze once
const PLAYER_START := Vector2(135, 318)
const PLAYER_BOUNDS := Rect2(8, 14, 254, 336)
const PLAYER_LIVES := 3
const RESPAWN_INVULN := 2.8
const DEATH_RESPAWN_DELAY := 0.85
const TOUCH_DRAG_GAIN := 0.62 # logical px moved per screen px of finger drag

# --- Player weapon -----------------------------------------------------------
const FIRE_INTERVAL := 0.075
const SHOT_SPEED := 540.0
const SHOT_DAMAGE := 1.0
const SPREAD_ANGLES := [-0.20, -0.09, 0.0, 0.09, 0.20] # unfocused fan (radians)
const FOCUS_OFFSETS := [-5.0, -1.6, 1.6, 5.0] # focused tight stream (x offsets)
const FOCUS_DAMAGE_MULT := 1.35
const OPTION_OFFSET := Vector2(15, 6) # side pods, unfocused
const OPTION_FOCUS_OFFSET := Vector2(8, 10)
const OPTION_DAMAGE := 0.6

# --- Burst (screen-clear super) ---------------------------------------------
const ENERGY_MAX := 100.0
const ENERGY_START := 30.0
const GRAZE_ENERGY := 2.2
const KILL_ENERGY := 1.0
const ENERGY_ITEM := 6.0
const BURST_DURATION := 0.9 # seconds for the shock ring to expand
const BURST_RADIUS := 420.0
const BURST_INVULN := 2.4
const BURST_ENEMY_DAMAGE := 80.0
const BURST_BOSS_DAMAGE := 70.0

# --- Scoring & chain ---------------------------------------------------------
const GRAZE_SCORE := 30
const CHAIN_WINDOW := 2.6 # seconds a chain survives without a kill or graze
const CHAIN_PER_MULT := 40 # chain links for +1.0x multiplier
const CHAIN_MULT_MAX := 6.0
const CHAIN_MILESTONES := [25, 50, 100, 150, 200, 300, 400, 500]
const SHARD_VALUE := 120 # star shard dropped by enemies (x multiplier)
const CONVERTED_SHARD_VALUE := 40 # shard made from a cancelled bullet
const ITEM_MAGNET_RADIUS := 42.0
const ITEM_FOCUS_MAGNET_RADIUS := 70.0
const ITEM_AUTOCOLLECT_Y := 96.0 # flying above this line vacuums every item
const ITEM_FALL_SPEED := 46.0
const BOSS_PHASE_BONUS := 30000
const BOSS_TIME_BONUS_PER_SEC := 800
const CLEAR_BONUS := 100000
const LIFE_BONUS := 50000
const RANKS := [[1800000, "S"], [1200000, "A"], [800000, "B"], [450000, "C"], [0, "D"]]

# --- Enemy / boss shared -----------------------------------------------------
const ENEMY_FIRE_MIN_Y := 8.0 # enemies only fire once inside the screen
const ENEMY_FIRE_MAX_Y := 250.0 # ...and stop firing when too close to the player zone
const BULLET_WARMUP := 0.12 # spawn flash; bullets are harmless while it plays
const BOSS_ENTRY_TIME := 2.6
const BOSS_PHASE_BREAK_TIME := 2.2

# --- Feel / presentation ------------------------------------------------------
const HITSTOP_BOSS_BREAK := 0.16
const HITSTOP_PLAYER_HIT := 0.12
const SHAKE_DECAY := 18.0
const MAX_PARTICLES_HIGH := 900
const MAX_PARTICLES_LOW := 320
