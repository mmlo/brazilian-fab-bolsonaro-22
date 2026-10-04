extends Node
## Central input map + device tracking. All bindings are registered here so they
## are easy to find and change. Touch controls feed the virtual_* fields.
signal device_changed(device: String)

const DEADZONE := 0.28

var device := "kb" # kb | pad | touch
var virtual_focus := false # held by the on-screen FOCUS button
var virtual_bomb := false # one-shot from the on-screen BURST button
var touch_seen := false

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bind("move_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("move_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("move_up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("move_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_bind("focus", [KEY_SHIFT, KEY_K], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_A], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_bind("bomb", [KEY_X, KEY_L, KEY_SPACE], [JOY_BUTTON_X, JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], [])
	_bind("skip_tutorial", [KEY_ENTER, KEY_TAB], [JOY_BUTTON_BACK], [])
	# Menu navigation also follows the left stick.
	_add_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_add_key("ui_accept", KEY_Z)
	_add_key("ui_cancel", KEY_BACKSPACE)

func _bind(action: String, keys: Array, buttons: Array, axes: Array) -> void:
	if InputMap.has_action(action):
		InputMap.erase_action(action)
	InputMap.add_action(action, 0.5)
	InputMap.action_set_deadzone(action, DEADZONE)
	for k: int in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b: int in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	for a: Array in axes:
		var ja := InputEventJoypadMotion.new()
		ja.axis = a[0]
		ja.axis_value = a[1]
		InputMap.action_add_event(action, ja)

func _add_axis(action: String, axis: int, value: float) -> void:
	if not InputMap.has_action(action):
		return
	var ja := InputEventJoypadMotion.new()
	ja.axis = axis
	ja.axis_value = value
	InputMap.action_add_event(action, ja)

func _add_key(action: String, key: int) -> void:
	if not InputMap.has_action(action):
		return
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)

func _input(event: InputEvent) -> void:
	var next := device
	if event is InputEventKey or (event is InputEventMouseButton and not _is_emulated_mouse(event)):
		next = "kb"
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		next = "pad"
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		next = "touch"
		touch_seen = true
	if next != device:
		device = next
		device_changed.emit(device)

func _is_emulated_mouse(event: InputEvent) -> bool:
	return touch_seen and event.device == -1

func move_vector() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down", DEADZONE)
	if v.length() > 1.0:
		v = v.normalized()
	return v

func focus_held() -> bool:
	return Input.is_action_pressed("focus") or virtual_focus

func consume_bomb() -> bool:
	if virtual_bomb:
		virtual_bomb = false
		return true
	return Input.is_action_just_pressed("bomb")

## Human-readable binding hint for the active device, e.g. "SHIFT" or "RB".
func hint(action: String) -> String:
	var table := {
		"kb": {"move": "WASD / ←↑↓→", "focus": "SHIFT", "bomb": "X", "pause": "ESC", "confirm": "ENTER / Z"},
		"pad": {"move": "L-STICK / D-PAD", "focus": "RB / A", "bomb": "X / B", "pause": "START", "confirm": "A"},
		"touch": {"move": I18n.t("hint.drag"), "focus": I18n.t("hint.focus_btn"), "bomb": I18n.t("hint.burst_btn"), "pause": "II", "confirm": I18n.t("hint.tap")},
	}
	return str((table.get(device, table["kb"]) as Dictionary).get(action, action))
