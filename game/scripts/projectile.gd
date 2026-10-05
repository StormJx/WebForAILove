class_name Bolt
extends Node2D

var velocity := Vector2.ZERO
var damage := 1.0
var splash := 0.0
var burn_dps := 0.0
var burn_time := 0.0
var color := Color.WHITE
var age := 0.0
var hit_radius := 8.0
var spent := false


func launch(from: Vector2, to: Vector2, speed: float, hit_damage: float, splash_radius: float, ember_dps: float, ember_time: float, tint: Color) -> void:
	position = from
	var direction := to - from
	if direction.length_squared() < 1.0:
		direction = Vector2.RIGHT
	velocity = direction.normalized() * speed
	damage = hit_damage
	splash = splash_radius
	burn_dps = ember_dps
	burn_time = ember_time
	color = tint


func _process(delta: float) -> void:
	if spent:
		return
	var nxt := position + velocity * delta
	for node in get_tree().get_nodes_in_group("foes"):
		var foe := node as LaneEnemy
		if foe == null or not foe.alive:
			continue
		if _hits(position, nxt, foe.map_pos(), foe.radius + hit_radius):
			_impact(foe)
			return
	position = nxt
	age += delta
	if age > 1.6 or position.x < -80 or position.y < -80 or position.x > 900 or position.y > 320:
		queue_free()
	queue_redraw()


func _impact(foe: LaneEnemy) -> void:
	spent = true
	foe.apply_damage(damage)
	if burn_dps > 0.0:
		foe.apply_burn(burn_dps, burn_time)
	if splash > 0.0:
		var center := foe.map_pos()
		for node in get_tree().get_nodes_in_group("foes"):
			var other := node as LaneEnemy
			if other == null or other == foe or not other.alive:
				continue
			if other.map_pos().distance_to(center) <= splash + other.radius:
				other.apply_damage(damage)
				if burn_dps > 0.0:
					other.apply_burn(burn_dps, burn_time)
	queue_free()


func _hits(a: Vector2, b: Vector2, center: Vector2, radius: float) -> bool:
	var span := b - a
	var t := 0.0
	var denom := span.length_squared()
	if denom > 0.001:
		t = clampf((center - a).dot(span) / denom, 0.0, 1.0)
	return a.lerp(b, t).distance_to(center) <= radius


func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, color)
	draw_line(Vector2.ZERO, -velocity.normalized() * 10.0, Color(color, 0.7), 3.0)
