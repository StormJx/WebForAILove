class_name MapView
extends Node2D

var map_size := Vector2(800, 200)
var path: PackedVector2Array = PackedVector2Array()
var ground := Color("6e8f58")
var start_label := "渠口"
var end_label := "水闸"
var _reeds: Array[Vector2] = []
var _ponds: Array[Vector2] = []
var _font: Font


func setup(catalog: GameCatalog, text_font: Font) -> void:
	map_size = catalog.map_size
	path = catalog.path
	ground = catalog.ground
	start_label = catalog.start_label
	end_label = catalog.end_label
	_font = text_font
	_reeds.clear()
	_ponds.clear()
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


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), ground)
	draw_rect(Rect2(Vector2(8, 8), map_size - Vector2(16, 16)), ground.lightened(0.08))
	for pond in _ponds:
		draw_circle(pond, 26, Color("6a9aa6"))
	if path.size() >= 2:
		draw_polyline(path, Color("cbb88a"), 34.0, true)
		draw_polyline(path, Color("7fa3b0"), 22.0, true)
		draw_polyline(path, Color("d5e6ec"), 4.0, true)
		var start: Vector2 = path[0]
		var finish: Vector2 = path[path.size() - 1]
		draw_circle(start, 8, Color("d07a4a"))
		draw_rect(Rect2(finish + Vector2(-6, -26), Vector2(22, 52)), Color("6e5344"))
		draw_rect(Rect2(finish + Vector2(-12, -30), Vector2(34, 8)), Color("d9d3c4"))
		if _font != null:
			draw_string(_font, start + Vector2(12, -10), start_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("243024"))
			draw_string(_font, finish + Vector2(-8, -36), end_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("243024"))
	for reed in _reeds:
		draw_line(reed, reed + Vector2(-3, -16), Color("23482c"), 2.0)
		draw_line(reed, reed + Vector2(4, -18), Color("2f6a3a"), 2.0)
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("243024"), false, 3.0)
