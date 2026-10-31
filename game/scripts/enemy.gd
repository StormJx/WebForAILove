class_name LaneEnemy
extends PathFollow2D

signal killed(gold_value: int)
signal leaked(lives_lost: int)

var foe_name := ""
var max_hp := 1.0
var hp := 1.0
var speed := 40.0
var gold_value := 1
var radius := 10.0
var color := Color.WHITE
var leak_lives := 1
var alive := true
var slow_factor := 1.0
var slow_time := 0.0
var burn_dps := 0.0
var burn_time := 0.0
var flash := 0.0
var travel := Vector2.ZERO
var foe_id := "raider"
var body_height := 38.0
var _sprite: Sprite2D
var _bar: Node2D


func setup(def: Dictionary) -> void:
	foe_id = str(def.get("id", "raider"))
	foe_name = str(def.get("name", ""))
	max_hp = float(def["hp"])
	hp = max_hp
	speed = float(def["speed"])
	gold_value = int(def["gold"])
	radius = float(def["radius"])
	color = Color(str(def["color"]))
	leak_lives = int(def["leak"])
	rotates = false
	loop = false
	if not is_in_group("foes"):
		add_to_group("foes")
	_ensure_art()


func map_pos() -> Vector2:
	return MapMath.of(self)


func apply_damage(amount: float) -> void:
	if not alive:
		return
	hp -= amount
	flash = 0.12
	if hp <= 0.0:
		_die()


func apply_slow(factor: float, duration: float) -> void:
	if not alive:
		return
	factor = clampf(factor, 0.18, 1.0)
	if slow_time <= 0.0 or factor < slow_factor:
		slow_factor = factor
	slow_time = maxf(slow_time, duration)


func apply_burn(dps: float, duration: float) -> void:
	if not alive or dps <= 0.0:
		return
	burn_dps = maxf(burn_dps, dps)
	burn_time = maxf(burn_time, duration)


func _process(delta: float) -> void:
	if not alive:
		return
	if flash > 0.0:
		flash = maxf(flash - delta, 0.0)
	if burn_time > 0.0:
		burn_time -= delta
		apply_damage(burn_dps * delta)
		if not alive:
			return
		if burn_time <= 0.0:
			burn_dps = 0.0
	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow_factor = 1.0
	var path_node := get_parent() as Path2D
	if path_node == null or path_node.curve == null:
		return
	var length := path_node.curve.get_baked_length()
	var before := position
	progress += speed * slow_factor * delta
	travel = position - before
	if travel.x > 1.2:
		_sprite.flip_h = false
	elif travel.x < -1.2:
		_sprite.flip_h = true
	_sprite.modulate = _tint()
	if progress >= length - 0.5:
		_leak()
	_bar.queue_redraw()


func _die() -> void:
	if not alive:
		return
	alive = false
	if is_in_group("foes"):
		remove_from_group("foes")
	killed.emit(gold_value)
	queue_free()


func _leak() -> void:
	if not alive:
		return
	alive = false
	if is_in_group("foes"):
		remove_from_group("foes")
	leaked.emit(leak_lives)
	queue_free()


func _ensure_art() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Body"
		_sprite.z_index = 1
		add_child(_sprite)
		_bar = Node2D.new()
		_bar.name = "Bar"
		_bar.z_index = 2
		_bar.draw.connect(_draw_bar)
		add_child(_bar)
	body_height = ArtBank.foe_height(foe_id)
	ArtBank.plant(_sprite, ArtBank.foe_texture(foe_id), body_height)
	_sprite.position = Vector2(0, radius * 0.65)


func _tint() -> Color:
	var tint := Color.WHITE
	if burn_time > 0.0:
		tint = Color("ffc2a2")
	elif slow_time > 0.0:
		tint = Color("d7eeff")
	if flash > 0.0:
		tint = tint.lerp(Color(1.7, 1.7, 1.7), clampf(flash * 6.0, 0.0, 1.0))
	return tint


func _draw_bar() -> void:
	var width := maxf(radius * 2.2, 18.0)
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	var top := _sprite.position.y - body_height - 6.0
	var bar := Vector2(-width * 0.5, top)
	_bar.draw_rect(Rect2(bar, Vector2(width, 3.0)), Color(0, 0, 0, 0.45))
	_bar.draw_rect(Rect2(bar, Vector2(width * ratio, 3.0)), Color("e7efe4"))
