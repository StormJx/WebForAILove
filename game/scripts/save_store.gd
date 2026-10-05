class_name SaveStore
extends RefCounted

const PATH := "user://reedbank_save.json"

var cleared: bool = false
var tokens: int = 0
var upgrades: Dictionary = {}
var cleared_levels: Array = []
var legacy_bool_clear := false


static func load_file() -> SaveStore:
	var store := SaveStore.new()
	if not FileAccess.file_exists(PATH):
		return store
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return store
	store.tokens = int(parsed.get("tokens", 0))
	var raw = parsed.get("upgrades", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for key in raw.keys():
			store.upgrades[str(key)] = int(raw[key])
	var levels = parsed.get("cleared_levels", null)
	if typeof(levels) == TYPE_ARRAY:
		for level_id in levels:
			var id := str(level_id)
			if id != "" and not store.cleared_levels.has(id):
				store.cleared_levels.append(id)
		store.cleared = bool(parsed.get("cleared", false)) or store.cleared_levels.size() > 0
	elif bool(parsed.get("cleared", false)):
		store.cleared = true
		store.legacy_bool_clear = true
	return store


func migrate_legacy(first_level_id: String) -> void:
	if not legacy_bool_clear:
		return
	mark_cleared(first_level_id, true)
	legacy_bool_clear = false


func is_cleared(level_id: String) -> bool:
	return cleared_levels.has(level_id)


func mark_cleared(level_id: String, is_first := false) -> void:
	if level_id != "" and not cleared_levels.has(level_id):
		cleared_levels.append(level_id)
	if is_first:
		cleared = true


func is_unlocked(index: int, ids: Array) -> bool:
	if index <= 0:
		return true
	if index >= ids.size():
		return false
	return is_cleared(str(ids[index - 1]))


func write_file() -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	var body := {
		"cleared": cleared,
		"cleared_levels": cleared_levels.duplicate(),
		"tokens": tokens,
		"upgrades": upgrades.duplicate(),
	}
	file.store_string(JSON.stringify(body, "\t"))
	return true


func to_dict() -> Dictionary:
	return {
		"cleared": cleared,
		"cleared_levels": cleared_levels.duplicate(),
		"tokens": tokens,
		"upgrades": upgrades.duplicate(),
	}
