class_name BuildSpot
extends Node2D

signal picked(index: int)

var index := 0
var selected := false
var occupied := false


func setup(spot_index: int) -> void:
	index = spot_index
	var area := Area2D.new()
	area.input_pickable = true
	area.input_event.connect(_on_input)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26
	shape.shape = circle
	area.add_child(shape)
	add_child(area)


func set_selected(is_selected: bool) -> void:
	selected = is_selected
	queue_redraw()


func set_occupied(is_occupied: bool) -> void:
	occupied = is_occupied
	queue_redraw()


func _on_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			picked.emit(index)


func _draw() -> void:
	var fill := Color("efe6cf")
	if selected:
		fill = Color("f7e7a2")
	elif occupied:
		fill = Color("c9d3b4")
	draw_circle(Vector2(0, 2), 20, Color(0, 0, 0, 0.18))
	draw_circle(Vector2.ZERO, 18, fill)
	draw_arc(Vector2.ZERO, 18, 0, TAU, 24, Color("3e4a38"), 2.0, true)
	if not occupied:
		var font := UiStyle.font()
		draw_string(font, Vector2(-5, 5), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("3a3328"))
