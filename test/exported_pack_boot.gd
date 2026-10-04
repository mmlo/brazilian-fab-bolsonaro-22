extends SceneTree
# Boot check for the EXPORTED pack: unlike editor/headless runs of the project
# directory, this sees only the resources that actually made it into
# dist/index.pck — exactly what the browser will load. It boots the project's
# configured main scene generically, so it keeps working after the game is
# rewritten. It is invoked by scripts/check-exported-pack.mjs.

const SETTLE_FRAMES := 5


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene_path: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene_path.is_empty():
		_fail("no main scene configured in project settings")
		return
	if not ResourceLoader.exists(main_scene_path):
		_fail("main scene missing from the exported PCK: " + main_scene_path)
		return
	var packed: PackedScene = load(main_scene_path) as PackedScene
	if packed == null:
		_fail("main scene did not load from the exported PCK: " + main_scene_path)
		return
	var node: Node = packed.instantiate()
	if node == null:
		_fail("main scene did not instantiate: " + main_scene_path)
		return
	root.add_child(node)
	for i in SETTLE_FRAMES:
		await process_frame
	if not node.is_inside_tree():
		_fail("main scene left the tree during boot")
		return
	var locale_service := root.get_node_or_null("I18n")
	if locale_service == null:
		_fail("localization autoload missing from the exported PCK")
		return
	for locale: String in ["en", "zh-CN"]:
		var catalog_path := "res://localization/%s.json" % locale
		if not FileAccess.file_exists(catalog_path) or not JSON.parse_string(FileAccess.get_file_as_string(catalog_path)) is Dictionary:
			_fail("localization catalog missing or invalid: " + catalog_path)
			return
	var previous_locale := String(locale_service.call("get_locale"))
	locale_service.call("set_locale", "zh-CN")
	if String(locale_service.call("t", "pause.title")) != "防卫暂停":
		_fail("packed Chinese UI copy did not resolve")
		return
	locale_service.call("set_locale", "en")
	if String(locale_service.call("t", "pause.title")) != "DEFENSE PAUSED":
		_fail("packed English UI copy did not resolve")
		return
	locale_service.call("set_locale", previous_locale)
	var font := load("res://assets/template/fonts/ui_regular.tres") as Font
	if font == null or not font.has_char("飞".unicode_at(0)) or not font.has_char("A".unicode_at(0)):
		_fail("packed font chain lacks English or Chinese UI glyphs")
		return
	print("[PCK_BOOT_PASS] main scene and EN/CN localization booted: " + main_scene_path)
	node.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error("[PCK_BOOT_FAIL] " + message)
	quit(1)
