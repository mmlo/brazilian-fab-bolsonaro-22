extends SceneTree
## Localization acceptance for Starveil Barrage.
## Run: godot --headless --path . --script test/localization.gd  -> [STARVEIL_LOCALIZATION_PASS]
const LocaleService := preload("res://autoload/i18n.gd")
const DYNAMIC_KEYS := ["tut.1.title", "tut.1.body", "tut.2.title", "tut.2.body", "tut.3.title", "tut.3.body",
	"tut.4.title", "tut.4.body", "tut.5.title", "tut.5.body", "pause.resume", "pause.restart", "pause.skip",
	"pause.settings", "pause.title_btn", "wave.1.name", "wave.2.name", "wave.3.name", "boss.phase1", "boss.phase2", "boss.phase3",
	"res.kills", "res.grazes", "res.max_chain", "res.phases", "res.misses", "res.clear_bonus", "res.life_bonus"]
var failures: Array[String] = []
var i18n: Node

func _initialize() -> void:
	_run.call_deferred()

func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

func _run() -> void:
	i18n = root.get_node("I18n")
	var had_saved := FileAccess.file_exists(LocaleService.SAVE_PATH)
	var saved_text := FileAccess.get_file_as_string(LocaleService.SAVE_PATH) if had_saved else ""
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/en.json"))
	var zh: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/zh-CN.json"))
	var ek := en.keys()
	var zk := zh.keys()
	ek.sort()
	zk.sort()
	_check(ek == zk and ek.size() >= 100, "EN/CN catalogs have identical keys (%d / %d)" % [ek.size(), zk.size()])
	var fonts: Array[Font] = [load("res://assets/template/fonts/ui_regular.tres"), load("res://assets/template/fonts/ui_bold.tres")]
	for key: String in ek:
		_check(_tokens(str(en[key])) == _tokens(str(zh.get(key, ""))), "placeholder parity: " + key)
		for ch: String in str(en[key]) + str(zh.get(key, "")):
			var code := ch.unicode_at(0)
			if code >= 32:
				for f: Font in fonts:
					_check(f.has_char(code), "bundled font glyph U+%04X in %s" % [code, key])
	# Every literal key referenced by game code exists
	var used := {}
	for key: String in DYNAMIC_KEYS:
		used[key] = true
	var re := RegEx.create_from_string("I18n\\.t\\(\"([a-z0-9_.]+)\"")
	for path: String in _gd_files("res://scripts") + _gd_files("res://autoload"):
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(path)):
			if not m.get_string(1).ends_with("."):
				used[m.get_string(1)] = true
	for key: String in used:
		_check(en.has(key), "key used by code exists in catalog: " + key)
	# Locale switching, persistence and fallback
		_check(i18n.set_locale("zh-CN") and i18n.t("pause.title") == "防空暂停", "Chinese resolves")
	_check(i18n.t("hud.phase", {"n": 2}) == "第 2 阶段", "Chinese placeholders render")
	_check(i18n.save_succeeded, "language choice persisted")
	var restarted := LocaleService.new()
	root.add_child(restarted)
	_check(restarted.get_locale() == "zh-CN", "saved Chinese survives restart")
	restarted.free()
	_check(not i18n.set_locale("xx") and i18n.get_locale() == "zh-CN", "unsupported locale is rejected")
	i18n.set_locale("en")
	restarted = LocaleService.new()
	root.add_child(restarted)
	_check(restarted.get_locale() == "en", "saved English wins over system language")
	restarted.free()
	var bad := ConfigFile.new()
	bad.set_value("language", "locale", "xx")
	bad.save(LocaleService.SAVE_PATH)
	restarted = LocaleService.new()
	root.add_child(restarted)
	_check(restarted.get_locale() == LocaleService.locale_for_system(OS.get_locale()), "invalid saved locale falls back to system language")
	restarted.free()
	_check(LocaleService.locale_for_system("zh_CN") == "zh-CN" and LocaleService.locale_for_system("en_US") == "en", "browser/system language auto-detect")
	i18n.set_locale("en")
	_check(i18n.t("pause.title") == "DEFESA PAUSADA" and i18n.t("tuning.label.ship_speed") == "Velocidade da aeronave", "English resolves")
	# restore
	if had_saved:
		var fa := FileAccess.open(LocaleService.SAVE_PATH, FileAccess.WRITE)
		fa.store_string(saved_text)
		fa.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LocaleService.SAVE_PATH))
	if failures.is_empty():
		print("[STARVEIL_LOCALIZATION_PASS] %d keys, glyphs, placeholders, code references, persistence and fallback" % ek.size())
		quit(0)
	else:
		for f in failures.slice(0, 40):
			push_error(f)
		quit(1)

func _tokens(value: String) -> PackedStringArray:
	var out := PackedStringArray()
	for m: RegExMatch in RegEx.create_from_string("\\{([A-Za-z0-9_]+)\\}").search_all(value):
		out.append(m.get_string(1))
	out.sort()
	return out

func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_gd_files(dir + "/" + sub))
	return out
