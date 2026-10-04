extends Node

signal locale_changed(locale: String)

const DEFAULT_LOCALE := "en"
const SAVE_PATH := "user://language.cfg"
const WEB_STORAGE_KEY := "starveil-barrage.locale"
const CATALOG_PATHS := {
	"en": "res://localization/en.json",
	"zh-CN": "res://localization/zh-CN.json",
}

var _catalogs: Dictionary = {}
var _locale := DEFAULT_LOCALE
var save_succeeded := true


func _ready() -> void:
	for locale: String in CATALOG_PATHS:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATHS[locale]))
		if not parsed is Dictionary:
			push_error("I18n: invalid catalog " + locale)
			return
		_catalogs[locale] = parsed
	_locale = _initial_locale()
	TranslationServer.set_locale(_locale)


func t(key: String, placeholders: Dictionary = {}) -> String:
	var active: Dictionary = _catalogs.get(_locale, {})
	var fallback: Dictionary = _catalogs.get(DEFAULT_LOCALE, {})
	var result := str(active.get(key, fallback.get(key, key)))
	for token: Variant in placeholders:
		result = result.replace("{%s}" % str(token), str(placeholders[token]))
	return result


func get_locale() -> String:
	return _locale


func set_locale(locale: String) -> bool:
	if not CATALOG_PATHS.has(locale):
		return false
	var config := ConfigFile.new()
	config.set_value("language", "locale", locale)
	save_succeeded = config.save(SAVE_PATH) == OK
	if save_succeeded and OS.has_feature("web"):
		JavaScriptBridge.eval("try { localStorage.setItem(%s, %s); } catch (_) {}" % [JSON.stringify(WEB_STORAGE_KEY), JSON.stringify(locale)])
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		save_succeeded = false
	_locale = locale
	TranslationServer.set_locale(_locale)
	locale_changed.emit(_locale)
	return true


func catalog_keys(locale: String) -> Array:
	return (_catalogs.get(locale, {}) as Dictionary).keys()


func _initial_locale() -> String:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		var saved := str(config.get_value("language", "locale", DEFAULT_LOCALE))
		if CATALOG_PATHS.has(saved):
			return saved
	if OS.has_feature("web"):
		var mirrored: Variant = JavaScriptBridge.eval("(() => { try { return localStorage.getItem(%s) || ''; } catch (_) { return ''; } })()" % JSON.stringify(WEB_STORAGE_KEY))
		if mirrored is String and CATALOG_PATHS.has(mirrored):
			return mirrored
	# No saved choice: follow the system language (the browser language on Web).
	return locale_for_system(OS.get_locale())


## Any Chinese system/browser locale selects Simplified Chinese; everything else English.
static func locale_for_system(system_locale: String) -> String:
	return "zh-CN" if system_locale.strip_edges().to_lower().begins_with("zh") else DEFAULT_LOCALE
