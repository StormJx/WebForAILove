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
var stages: Array = []
var stage_index := 0
var stage_id := ""
var stage_name := ""
var stage_blurb := ""
var start_label := "渠口"
var end_label := "水闸"
var ground := Color("6e8f58")


static func load_all() -> GameCatalog:
	var catalog := GameCatalog.new()
	var towers_doc: Dictionary = _read("res://data/towers.json")
	var hero_doc: Dictionary = _read("res://data/hero.json")
	var meta_doc: Dictionary = _read("res://data/meta.json")
	var level_doc: Dictionary = _read("res://data/levels.json")
	catalog.tower_order = towers_doc.get("order", [])
	catalog.towers = towers_doc.get("towers", {})
	catalog.hero = hero_doc
	catalog.meta = meta_doc.get("upgrades", [])
	for entry in level_doc.get("levels", []):
		catalog.stages.append(_load_stage(entry))
	if catalog.stages.size() > 0:
		catalog.apply_stage(0)
	return catalog


static func _load_stage(entry: Dictionary) -> Dictionary:
	var map_doc: Dictionary = _read("res://data/%s" % str(entry.get("map", "")))
	var waves_doc: Dictionary = _read("res://data/%s" % str(entry.get("waves", "")))
	var size: Array = map_doc.get("size", [800, 200])
	var start: Array = map_doc.get("hero_start", [400, 140])
	return {
		"id": str(entry.get("id", "")),
		"name": str(entry.get("name", "关卡")),
		"blurb": str(entry.get("blurb", "")),
		"map_size": Vector2(float(size[0]), float(size[1])),
		"path": _points(map_doc.get("path", [])),
		"spots": _points(map_doc.get("spots", [])),
		"hero_start": Vector2(float(start[0]), float(start[1])),
		"rules": {
			"lives": int(waves_doc.get("lives", 20)),
			"gold": int(waves_doc.get("gold", 150)),
		},
		"enemies": waves_doc.get("enemies", {}),
		"waves": waves_doc.get("waves", []),
		"start_label": str(map_doc.get("start_label", "渠口")),
		"end_label": str(map_doc.get("end_label", "水闸")),
		"ground": Color(str(map_doc.get("ground", "#6e8f58"))),
	}


func apply_stage(index: int) -> void:
	stage_index = index
	var stage: Dictionary = stages[index]
	stage_id = str(stage["id"])
	stage_name = str(stage["name"])
	stage_blurb = str(stage["blurb"])
	map_size = stage["map_size"]
	path = stage["path"]
	spots = stage["spots"]
	hero_start = stage["hero_start"]
	rules = stage["rules"]
	enemies = stage["enemies"]
	waves = stage["waves"]
	start_label = str(stage["start_label"])
	end_label = str(stage["end_label"])
	ground = stage["ground"]


func stage_ids() -> Array:
	var ids: Array = []
	for stage in stages:
		ids.append(str(stage["id"]))
	return ids


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
	if stages.size() != 4:
		errors.append("expected 4 levels")
	var seen_paths: Dictionary = {}
	var seen_waves: Dictionary = {}
	for stage_number in stages.size():
		var stage: Dictionary = stages[stage_number]
		var stage_waves: Array = stage["waves"]
		if stage_waves.size() != 5:
			errors.append("level %d expected 5 waves" % (stage_number + 1))
		var stage_enemies: Dictionary = stage["enemies"]
		for wave_index in stage_waves.size():
			for group in stage_waves[wave_index].get("groups", []):
				if not stage_enemies.has(group.get("id", "")):
					errors.append("level %d wave %d uses unknown enemy %s" % [stage_number + 1, wave_index + 1, group.get("id", "")])
		var stage_path: PackedVector2Array = stage["path"]
		var stage_spots: PackedVector2Array = stage["spots"]
		if stage_path.size() < 2:
			errors.append("level %d path is too short" % (stage_number + 1))
		if stage_spots.size() < 5:
			errors.append("level %d needs at least 5 build spots" % (stage_number + 1))
		var path_key := str(stage_path)
		if seen_paths.has(path_key):
			errors.append("level %d reuses another level's path" % (stage_number + 1))
		seen_paths[path_key] = true
		var wave_key := str(stage_waves)
		if seen_waves.has(wave_key):
			errors.append("level %d reuses another level's waves" % (stage_number + 1))
		seen_waves[wave_key] = true
	if hero.is_empty() or not hero.has("ability"):
		errors.append("hero data missing")
	if meta.size() < 1:
		errors.append("meta upgrades missing")
	if stages.size() > 0:
		var first: Dictionary = stages[0]
		if str(first["id"]) != "reed_gate":
			errors.append("level 1 id changed")
		var first_path: PackedVector2Array = first["path"]
		var first_spots: PackedVector2Array = first["spots"]
		if first_path.is_empty() or first_path[0] != Vector2(20, 64) or first_spots.size() != 6:
			errors.append("level 1 path or build spots changed")
		if int(first["rules"]["lives"]) != 20 or int(first["rules"]["gold"]) != 175:
			errors.append("level 1 starting lives or gold changed")
		var first_waves: Array = first["waves"]
		if first_waves.size() > 0:
			var first_groups: Array = first_waves[0].get("groups", [])
			if first_groups.is_empty() or str(first_groups[0].get("id", "")) != "raider" or int(first_groups[0].get("count", 0)) != 8:
				errors.append("level 1 opening wave changed")
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
