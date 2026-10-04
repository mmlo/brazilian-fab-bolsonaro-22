extends Node
## Local progress: best score/rank, tutorial flag and run counters.
const PATH := "user://starveil_save.cfg"

var best_score := 0
var best_rank := ""
var best_chain := 0
var tutorial_done := false
var clears := 0
var runs := 0

func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		best_score = int(cfg.get_value("progress", "best_score", 0))
		best_rank = str(cfg.get_value("progress", "best_rank", ""))
		best_chain = int(cfg.get_value("progress", "best_chain", 0))
		tutorial_done = bool(cfg.get_value("progress", "tutorial_done", false))
		clears = int(cfg.get_value("progress", "clears", 0))
		runs = int(cfg.get_value("progress", "runs", 0))

## Records a finished run. Returns true when it set a new best score.
func record_run(score: int, rank: String, max_chain: int, cleared: bool) -> bool:
	runs += 1
	if cleared:
		clears += 1
	best_chain = maxi(best_chain, max_chain)
	var is_best := score > best_score
	if is_best:
		best_score = score
		best_rank = rank
	save()
	return is_best

func mark_tutorial_done() -> void:
	if not tutorial_done:
		tutorial_done = true
		save()

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "best_score", best_score)
	cfg.set_value("progress", "best_rank", best_rank)
	cfg.set_value("progress", "best_chain", best_chain)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("progress", "clears", clears)
	cfg.set_value("progress", "runs", runs)
	cfg.save(PATH)
