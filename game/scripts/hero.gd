class_name Warden
extends Node2D

var display_name := "巡岸卫"
var damage := 10.0
var range_radius := 110.0
var cooldown := 0.5
var cooldown_left := 0.0
var move_speed := 200.0
var color := Color("2f6f7e")
var ability_damage := 30.0
var ability_radius := 80.0
var ability_cooldown := 8.0
var ability_left := 0.0
var ability_slow := 0.5
var ability_slow_time := 2.0
var ability_name := "断流"
var goal := Vector2.ZERO
var moving := false
var ring := 0.0
var facing := Vector2.RIGHT
var _sprite: Sprite2D


func setup(def: Dictionary) -> void:
	display_name = str(def.get("name", "巡岸卫"))
	damage = float(def["damage"])
	range_radius = float(def["range"])
	cooldown = float(def["cooldown"])
	move_speed = float(def.get("move_speed", 200))
	color = Color(str(def.get("color", "#2f6f7e")))
	var ability: Dictionary = def["ability"]
	ability_name = str(ability.get("name", "断流"))
	ability_damage = float(ability["damage"])
	ability_radius = float(ability["radius"])
	ability_cooldown = float(ability["cooldown"])
	ability_slow = float(ability["slow"])
	ability_slow_time = float(ability["slow_time"])
	_ensure_art()


func place(spot: Vector2, def: Dictionary, damage_bonus: float) -> void:
	setup(def)
	damage *= 1.0 + damage_bonus
	ability_damage *= 1.0 + damage_bonus
	position = spot
	goal = spot
	moving = false
	cooldown_left = 0.0
	ability_left = 0.0
	ring = 0.0


func move_to(point: Vector2) -> void:
	goal = point
	moving = true


func cast() -> bool:
	if ability_left > 0.0:
		return false
	ability_left = ability_cooldown
	ring = 0.35
	for node in get_tree().get_nodes_in_group("foes"):
		var foe := node as LaneEnemy
		if foe == null or not foe.alive:
			continue
		if position.distance_to(foe.map_pos()) <= ability_radius + foe.radius:
			foe.apply_damage(ability_damage)
			foe.apply_slow(ability_slow, ability_slow_time)
	return true


func _process(delta: float) -> void:
	if moving:
		var offset := goal - position
		var step := move_speed * delta
		if offset.length() <= step:
			position = goal
			moving = false
		else:
			facing = offset.normalized()
			position += facing * step
	if ability_left > 0.0:
		ability_left = maxf(ability_left - delta, 0.0)
	var drawing := ring > 0.0
	if ring > 0.0:
		ring = maxf(ring - delta, 0.0)
	cooldown_left -= delta
	if cooldown_left <= 0.0:
		var target := _nearest()
		if target != null:
			facing = target.map_pos() - position
			target.apply_damage(damage)
			cooldown_left = cooldown
	if facing.x > 1.0:
		_sprite.flip_h = false
	elif facing.x < -1.0:
		_sprite.flip_h = true
	if drawing:
		queue_redraw()


func _nearest() -> LaneEnemy:
	var best: LaneEnemy = null
	var best_dist := range_radius
	for node in get_tree().get_nodes_in_group("foes"):
		var foe := node as LaneEnemy
		if foe == null or not foe.alive:
			continue
		var dist := position.distance_to(foe.map_pos())
		if dist <= best_dist:
			best = foe
			best_dist = dist
	return best


func _ensure_art() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Body"
		_sprite.z_index = 1
		add_child(_sprite)
	ArtBank.plant(_sprite, ArtBank.HERO, 46.0)
	_sprite.position = Vector2(0, 8)


func _draw() -> void:
	if ring > 0.0:
		var radius := ability_radius * (1.0 - ring / 0.35)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(color, ring * 2.2), 3.0, true)
