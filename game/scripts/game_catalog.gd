class_name GameCatalog
extends RefCounted

var tower_order: Array = []
var towers: Dictionary = {}
var enemies: Dictionary = {}
var waves: Array = []
var hero: Dictionary = {}
var meta: Array = []
var rules: Dictionary = {}
var map_size := Vector2(800, 200)
var path: PackedVector2Array = PackedVector2Array()
var spots: PackedVector2Array = PackedVector2Array()
var hero_start := Vector2(400, 140)


static func load_all() -> GameCatalog:
	var catalog := GameCatalog.new()
	var towers_doc: Dictionary = _read("res://data/towers.json")
	var waves_doc: Dictionary = _read("res://data/waves.json")
	var hero_doc: Dictionary = _read("res://data/hero.json")
	var meta_doc: Dictionary = _read("res://data/meta.json")
	var map_doc: Dictionary = _read("res://data/map.json")
	catalog.tower_order = towers_doc.get("order", [])
	catalog.towers = towers_doc.get("towers", {})
	catalog.enemies = waves_doc.get("enemies", {})
	catalog.waves = waves_doc.get("waves", [])
	catalog.rules = {
		"lives": int(waves_doc.get("lives", 20)),
		"gold": int(waves_doc.get("gold", 150)),
	}
	catalog.hero = hero_doc
	catalog.meta = meta_doc.get("upgrades", [])
	var size: Array = map_doc.get("size", [800, 200])
	catalog.map_size = Vector2(float(size[0]), float(size[1]))
	catalog.path = _points(map_doc.get("path", []))
	catalog.spots = _points(map_doc.get("spots", []))
	var start: Array = map_doc.get("hero_start", [400, 140])
	catalog.hero_start = Vector2(float(start[0]), float(start[1]))
	return catalog


static func bonuses(save: SaveStore, catalog: GameCatalog) -> Dictionary:
	var gold := 0
	var lives := 0
	var hero_damage := 0.0
	for entry in catalog.meta:
		var rank := int(save.upgrades.get(str(entry["id"]), 0))
		var levels: Array = entry["levels"]
		for i in mini(rank, levels.size()):
			var level: Dictionary = levels[i]
			gold += int(level.get("gold", 0))
			lives += int(level.get("lives", 0))
			hero_damage += float(level.get("hero_damage", 0))
	return {"gold": gold, "lives": lives, "hero_damage": hero_damage}


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if tower_order.size() != 3 or towers.size() != 3:
		errors.append("expected 3 tower types")
	for key in tower_order:
		if not towers.has(key):
			errors.append("missing tower %s" % key)
			continue
		var branches: Array = towers[key].get("branches", [])
		if branches.size() != 2:
			errors.append("%s needs 2 branches" % key)
		for branch in branches:
			if (branch.get("levels", []) as Array).size() < 2:
				errors.append("%s branch %s needs 2 levels" % [key, branch.get("id", "?")])
	if waves.size() != 5:
		errors.append("expected 5 waves")
	for wave_index in waves.size():
		for group in waves[wave_index].get("groups", []):
			if not enemies.has(group.get("id", "")):
				errors.append("wave %d uses unknown enemy %s" % [wave_index + 1, group.get("id", "")])
	if path.size() < 2:
		errors.append("path is too short")
	if spots.size() < 5:
		errors.append("need at least 5 build spots")
	if hero.is_empty() or not hero.has("ability"):
		errors.append("hero data missing")
	if meta.size() < 1:
		errors.append("meta upgrades missing")
	return errors


static func _read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("无法读取 " + path)
		return {}
	return parsed


static func _points(raw: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for item in raw:
		points.append(Vector2(float(item[0]), float(item[1])))
	return points
