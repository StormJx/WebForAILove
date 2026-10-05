class_name SaveStore
extends RefCounted

const PATH := "user://reedbank_save.json"

var cleared: bool = false
var tokens: int = 0
var upgrades: Dictionary = {}


static func load_file() -> SaveStore:
	var store := SaveStore.new()
	if not FileAccess.file_exists(PATH):
		return store
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return store
	store.cleared = bool(parsed.get("cleared", false))
	store.tokens = int(parsed.get("tokens", 0))
	var raw = parsed.get("upgrades", {})
	if typeof(raw) == TYPE_DICTIONARY:
		for key in raw.keys():
			store.upgrades[str(key)] = int(raw[key])
	return store


func write_file() -> bool:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return false
	var body := {
		"cleared": cleared,
		"tokens": tokens,
		"upgrades": upgrades.duplicate(),
	}
	file.store_string(JSON.stringify(body, "\t"))
	return true


func to_dict() -> Dictionary:
	return {"cleared": cleared, "tokens": tokens, "upgrades": upgrades.duplicate()}
