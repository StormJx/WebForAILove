class_name MapView
extends Node2D

var map_size := Vector2(800, 200)
var path: PackedVector2Array = PackedVector2Array()
var ground := Color("6e8f58")
var start_label := "渠口"
var end_label := "水闸"
var _stage := 0
var _reeds: Array[Vector2] = []
var _ponds: Array[Vector2] = []
var _font: Font
var _labels: Node2D

const _PROP_SETS: Array = [
	["reed", "stake", "reed", "basket"],
	["willow", "basket", "willow", "stake"],
	["cairn", "reed", "cairn", "stake"],
	["lantern", "reed", "lantern", "cairn"],
]
const _BANK := [
	Color("8c9a3c"),
	Color("1e756f"),
	Color("9a7438"),
	Color("1a2c44"),
]


func setup(catalog: GameCatalog, text_font: Font) -> void:
	map_size = catalog.map_size
	path = catalog.path
	ground = catalog.ground
	start_label = catalog.start_label
	end_label = catalog.end_label
	_stage = catalog.stage_index
	_font = text_font
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_reeds.clear()
	_ponds.clear()
	for child in get_children():
		remove_child(child)
		child.free()
	_labels = null
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261005 + catalog.stage_index * 17
	for _i in 22:
		var point := Vector2(rng.randf_range(18, map_size.x - 18), rng.randf_range(12, map_size.y - 12))
		if _near_path(point) < 36.0:
			continue
		_reeds.append(point)
	for candidate in [Vector2(90, 24), Vector2(400, 18), Vector2(700, 180), Vector2(250, 180)]:
		if _near_path(candidate) > 52.0 and candidate.x < map_size.x and candidate.y < map_size.y:
			_ponds.append(candidate)
		if _ponds.size() >= 2:
			break
	_lay_water()
	_lay_props()
	_lay_markers()
	_labels = Node2D.new()
	_labels.name = "Labels"
	_labels.z_index = 3
	_labels.draw.connect(_draw_labels)
	add_child(_labels)
	queue_redraw()


func _near_path(point: Vector2) -> float:
	var best := 9999.0
	for i in maxi(path.size() - 1, 0):
		best = minf(best, _distance_to_segment(point, path[i], path[i + 1]))
	return best


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var span := b - a
	var denom := span.length_squared()
	var t := 0.0
	if denom > 0.001:
		t = clampf((point - a).dot(span) / denom, 0.0, 1.0)
	return point.distance_to(a.lerp(b, t))


func _bank() -> Color:
	return _BANK[clampi(_stage, 0, _BANK.size() - 1)]


func _tone() -> Color:
	var bank := _bank()
	return Color(bank.r * 0.72 + 0.18, bank.g * 0.72 + 0.2, bank.b * 0.72 + 0.16)


func _lay_water() -> void:
	if path.size() < 2:
		return
	var tex := ArtBank.WATER
	var thick := 34.0
	var tex_w := maxf(float(tex.get_width()), 1.0)
	var tex_h := maxf(float(tex.get_height()), 1.0)
	var sy := thick / tex_h
	var tile_w := tex_w * sy
	for i in path.size() - 1:
		var a: Vector2 = path[i]
		var b: Vector2 = path[i + 1]
		var delta := b - a
		var length := delta.length()
		if length < 1.0:
			continue
		var inset := minf(thick * 0.42, length * 0.2)
		var span := maxf(length - inset * 2.0, length * 0.5)
		var steps := maxi(int(ceil(span / tile_w)), 1)
		var step_len := span / float(steps)
		for s in steps:
			var along := inset + step_len * (float(s) + 0.5)
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.centered = true
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.position = a.lerp(b, along / length)
			sprite.rotation = delta.angle()
			sprite.scale = Vector2(step_len / tex_w, sy)
			sprite.modulate = _tone()
			sprite.z_index = 0
			add_child(sprite)


func _lay_props() -> void:
	var keys: Array = _PROP_SETS[_stage % _PROP_SETS.size()]
	var points: Array[Vector2] = []
	points.append_array(_reeds)
	points.append_array(_ponds)
	for i in points.size():
		var key := str(keys[i % keys.size()])
		var height := 30.0
		if key == "willow":
			height = 38.0
		elif key == "cairn" or key == "basket":
			height = 24.0
		_stand(points[i], key, height, i % 2 == 1)


func _lay_markers() -> void:
	if path.size() < 2:
		return
	var start: Vector2 = path[0]
	var finish: Vector2 = path[path.size() - 1]
	var out_dir := (path[1] - start).normalized()
	var in_dir := (finish - path[path.size() - 2]).normalized()
	_stand(start + Vector2(-out_dir.y, out_dir.x) * 22.0, "stake", 28.0, false)
	_stand(finish + Vector2(-in_dir.y, in_dir.x) * 22.0, "lantern", 32.0, false)


func _stand(at: Vector2, key: String, height: float, flip: bool) -> void:
	var sprite := Sprite2D.new()
	ArtBank.plant(sprite, ArtBank.prop_texture(key), height)
	sprite.position = at
	sprite.flip_h = flip
	sprite.modulate = _tone().darkened(0.08)
	sprite.z_index = 1
	add_child(sprite)


func _draw() -> void:
	var soil := _bank()
	var tile := 120.0
	var ink := Color(soil.r * 0.5, soil.g * 0.5, soil.b * 0.5, 1.0)
	var y := 0.0
	while y < map_size.y:
		var x := 0.0
		while x < map_size.x:
			draw_texture_rect(ArtBank.GROUND, Rect2(x, y, tile, tile), false, ink)
			x += tile - 1.0
		y += tile - 1.0
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(soil, 0.58))
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("1a241c"), false, 3.0)
	if _labels:
		_labels.queue_redraw()


func _draw_labels() -> void:
	if _font == null or path.size() < 2:
		return
	var start: Vector2 = path[0]
	var finish: Vector2 = path[path.size() - 1]
	_labels.draw_string(_font, start + Vector2(14, -16), start_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f4f1e4"))
	_labels.draw_string(_font, finish + Vector2(-8, -34), end_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f4f1e4"))
