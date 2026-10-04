extends Node

signal value_changed(id: String)

const Catalog = preload("res://scripts/tuning_defaults.gd")
const SCHEMA_VERSION := 1
var descriptors: Array[Dictionary] = Catalog.descriptors()
var requested: Dictionary = {}
var active: Dictionary = {}
var run_custom := false
var run_started := false

func enabled() -> bool:
	return OS.is_debug_build()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for entry in descriptors:
		requested[entry.id] = entry.default
		active[entry.id] = entry.default

func descriptor(id: String) -> Dictionary:
	for entry in descriptors:
		if entry.id == id:
			return entry
	return {}

func active_value(id: String) -> float:
	return float(active.get(id, 0.0))

func set_value(id: String, candidate: Variant) -> bool:
	return apply_preview_patch({id: candidate})


func reset_value(id: String) -> void:
	var entry := descriptor(id)
	if not entry.is_empty():
		set_value(id, entry.default)

func reset_all() -> void:
	for entry in descriptors:
		reset_value(entry.id)

func begin_run() -> void:
	run_started = true
	run_custom = false
	var changed: Array[String] = []
	for entry in descriptors:
		if not is_equal_approx(active[entry.id], requested[entry.id]): changed.append(entry.id)
		active[entry.id] = requested[entry.id]
		_mark_consumed(entry)
	for id: String in changed: value_changed.emit(id)

func apply_boundary(mode: String, ids: Array = []) -> void:
	for entry in descriptors:
		if entry.mode != mode or (not ids.is_empty() and entry.id not in ids):
			continue
		if not is_equal_approx(active[entry.id], requested[entry.id]):
			active[entry.id] = requested[entry.id]
			_mark_consumed(entry)
			value_changed.emit(entry.id)

func _mark_consumed(entry: Dictionary) -> void:
	if run_started and entry.integrity != "COSMETIC" and not is_equal_approx(active[entry.id], entry.default):
		run_custom = true

func deltas() -> Dictionary:
	var result := {}
	for entry in descriptors:
		if not is_equal_approx(requested[entry.id], entry.default):
			result[entry.id] = requested[entry.id]
	return result

func apply_preview_patch(patch: Dictionary) -> bool:
	if not enabled(): return false
	for id: String in patch:
		var entry := descriptor(id)
		var value: Variant = patch[id]
		if entry.is_empty() or not (value is int or value is float) or not is_finite(float(value)) or value < entry.min or value > entry.max: return false
	var changed: Array[String] = []
	for id: String in patch:
		if requested[id] == patch[id]: continue
		changed.append(id)
		requested[id] = patch[id]
		var entry := descriptor(id)
		if entry.mode == "LIVE" or not run_started:
			active[id] = patch[id]
			_mark_consumed(entry)
	for id: String in changed: value_changed.emit(id)
	return true
