class_name Sentry
extends Node2D

const BOLT_SCENE := preload("res://scenes/projectile.tscn")

var definition: Dictionary = {}
var kind := "bolt"
var display_name := ""
var range_radius := 100.0
var damage := 1.0
var cooldown := 1.0
var cooldown_left := 0.0
var projectile_speed := 400.0
var splash := 0.0
var slow := 1.0
var slow_time := 0.0
var burn_dps := 0.0
var burn_time := 0.0
var color := Color.WHITE
var branch_index := -1
var branch_level := 0
var spent := 0
var show_range := false
var aim := Vector2.RIGHT
var pulse := 0.0


func setup(def: Dictionary) -> void:
	definition = def
	kind = str(def.get("kind", "bolt"))
	display_name = str(def.get("name", "塔"))
	color = Color(str(def.get("color", "#ffffff")))
	_recompute()


func map_pos() -> Vector2:
	return MapMath.of(self)


func branch_count() -> int:
	return (definition.get("branches", []) as Array).size()


func branch_info(index: int) -> Dictionary:
	var branches: Array = definition["branches"]
	var branch: Dictionary = branches[index]
	var levels: Array = branch["levels"]
	var locked := branch_index >= 0 and branch_index != index
	var done := (branch_index == index and branch_level >= levels.size()) or (branch_index < 0 and false)
	if branch_index == index and branch_level >= levels.size():
		done = true
	var cost := 0
	if not locked and not done:
		var next_level := branch_level if branch_index == index else 0
		cost = int(levels[next_level]["cost"])
	var label := str(branch["name"])
	if locked:
		label = "%s\n锁定" % branch["name"]
	elif done:
		label = "%s\n已满" % branch["name"]
	else:
		label = "%s\n%d" % [branch["name"], cost]
	return {
		"text": label,
		"cost": cost,
		"locked": locked,
		"done": done,
		"blurb": str(branch.get("blurb", "")),
		"name": str(branch["name"]),
	}


func apply_branch(index: int) -> void:
	var info := branch_info(index)
	if info["locked"] or info["done"]:
		return
	if branch_index < 0:
		branch_index = index
	branch_level += 1
	spent += int(info["cost"])
	_recompute()


func refund() -> int:
	return int(round(float(spent) * 0.6))


func summary() -> String:
	var route := "尚未选路线"
	if branch_index >= 0:
		var branch: Dictionary = definition["branches"][branch_index]
		route = "%s %d/2" % [branch["name"], branch_level]
	var text := "%s  伤害 %d  间隔 %.2f  范围 %d  %s" % [display_name, int(round(damage)), cooldown, int(round(range_radius)), route]
	if kind == "pulse":
		text += "  减速 %.0f%%" % ((1.0 - slow) * 100.0)
	if splash > 0.0:
		text += "  爆炸 %d" % int(round(splash))
	if burn_dps > 0.0:
		text += "  灼烧 %d" % int(round(burn_dps))
	return text


func _recompute() -> void:
	range_radius = float(definition["range"])
	damage = float(definition["damage"])
	cooldown = float(definition["cooldown"])
	projectile_speed = float(definition.get("projectile_speed", 420))
	splash = float(definition.get("splash", 0))
	slow = float(definition.get("slow", 1))
	slow_time = float(definition.get("slow_time", 0))
	burn_dps = 0.0
	burn_time = 0.0
	if branch_index < 0:
		return
	var levels: Array = definition["branches"][branch_index]["levels"]
	var cooldown_mul := 1.0
	for i in mini(branch_level, levels.size()):
		var level: Dictionary = levels[i]
		damage += float(level.get("damage_add", 0))
		range_radius += float(level.get("range_add", 0))
		splash += float(level.get("splash_add", 0))
		slow += float(level.get("slow_add", 0))
		slow_time += float(level.get("slow_time_add", 0))
		if float(level.get("burn_dps", 0)) > 0.0:
			burn_dps += float(level["burn_dps"])
			burn_time += float(level.get("burn_time", 0))
		if level.has("cooldown_mul"):
			cooldown_mul *= float(level["cooldown_mul"])
	cooldown *= cooldown_mul
	slow = clampf(slow, 0.18, 1.0)


func _process(delta: float) -> void:
	if pulse > 0.0:
		pulse = maxf(pulse - delta, 0.0)
	cooldown_left -= delta
	if cooldown_left > 0.0:
		if show_range or pulse > 0.0:
			queue_redraw()
		return
	var target := _nearest()
	if target == null:
		if show_range:
			queue_redraw()
		return
	aim = target.map_pos() - map_pos()
	if kind == "pulse":
		_pulse()
	else:
		_shoot(target)
	cooldown_left = cooldown
	queue_redraw()


func _nearest() -> LaneEnemy:
	var best: LaneEnemy = null
	var best_dist := range_radius
	for node in get_tree().get_nodes_in_group("foes"):
		var foe := node as LaneEnemy
		if foe == null or not foe.alive:
			continue
		var dist := map_pos().distance_to(foe.map_pos())
		if dist <= best_dist:
			best = foe
			best_dist = dist
	return best


func _shoot(target: LaneEnemy) -> void:
	var fx := get_tree().get_first_node_in_group("fx") as Node2D
	if fx == null:
		return
	var aim_pos := target.map_pos()
	var lead := projectile_speed
	if lead > 1.0:
		var eta := map_pos().distance_to(aim_pos) / lead
		aim_pos += target.travel.normalized() * target.speed * target.slow_factor * eta * 0.85
	var bolt := BOLT_SCENE.instantiate() as Bolt
	fx.add_child(bolt)
	bolt.launch(map_pos(), aim_pos, projectile_speed, damage, splash, burn_dps, burn_time, color)


func _pulse() -> void:
	pulse = 0.28
	for node in get_tree().get_nodes_in_group("foes"):
		var foe := node as LaneEnemy
		if foe == null or not foe.alive:
			continue
		if map_pos().distance_to(foe.map_pos()) <= range_radius + foe.radius:
			foe.apply_damage(damage)
			foe.apply_slow(slow, slow_time)


func _draw() -> void:
	if show_range:
		draw_arc(Vector2.ZERO, range_radius, 0, TAU, 48, Color(color, 0.85), 1.5, true)
		draw_circle(Vector2.ZERO, range_radius, Color(color, 0.08))
	if pulse > 0.0:
		draw_arc(Vector2.ZERO, range_radius * (1.0 - pulse), 0, TAU, 40, Color(color, pulse * 2.0), 2.0, true)
	draw_circle(Vector2(0, 3), 16, Color(0, 0, 0, 0.2))
	match kind:
		"bolt":
			draw_rect(Rect2(Vector2(-12, -10), Vector2(24, 20)), color)
			var barrel := aim.normalized() * 16.0 if aim.length_squared() > 0.01 else Vector2(16, 0)
			draw_line(Vector2.ZERO, barrel, Color("4a3b2a"), 4.0)
		"pulse":
			draw_circle(Vector2.ZERO, 14, color)
			draw_arc(Vector2.ZERO, 8, 0, TAU, 16, Color("f4fbff"), 2.0, true)
		_:
			draw_circle(Vector2.ZERO, 13, color)
			draw_colored_polygon(PackedVector2Array([Vector2(-6, 4), Vector2(0, -14), Vector2(6, 4)]), Color("f3e1a6"))
	draw_arc(Vector2.ZERO, 15, 0, TAU, 20, Color(0.12, 0.1, 0.08, 0.7), 1.5, true)
