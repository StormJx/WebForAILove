class_name BuildSpot
extends Node2D

signal picked(index: int)

var index := 0
var selected := false
var occupied := false
var _sprite: Sprite2D
var _mark: Node2D


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
	_sprite = Sprite2D.new()
	_sprite.name = "Pad"
	_sprite.z_index = 0
	ArtBank.center(_sprite, ArtBank.PAD, 44.0)
	add_child(_sprite)
	_mark = Node2D.new()
	_mark.name = "Mark"
	_mark.z_index = 1
	_mark.draw.connect(_draw_mark)
	add_child(_mark)
	_tint_pad()


func set_selected(is_selected: bool) -> void:
	selected = is_selected
	_tint_pad()
	_mark.queue_redraw()


func set_occupied(is_occupied: bool) -> void:
	occupied = is_occupied
	_tint_pad()
	_mark.queue_redraw()


func _on_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			picked.emit(index)


func _tint_pad() -> void:
	if _sprite == null:
		return
	if selected:
		_sprite.modulate = Color("ffe7a8")
	elif occupied:
		_sprite.modulate = Color("d7e0cc")
	else:
		_sprite.modulate = Color.WHITE


func _draw_mark() -> void:
	if occupied:
		return
	var font := UiStyle.font()
	_mark.draw_string(font, Vector2(-5, 5), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("3a3328"))
