class_name WaveSpawner
extends Node

signal foe_killed(gold_value: int)
signal foe_leaked(lives_lost: int)

var catalog: GameCatalog
var path: Path2D
var enemy_scene: PackedScene
var busy := false
var _generation := 0


func setup(game_catalog: GameCatalog, lane: Path2D, scene: PackedScene) -> void:
	catalog = game_catalog
	path = lane
	enemy_scene = scene


func launch(wave: Dictionary) -> void:
	if busy:
		return
	busy = true
	_generation += 1
	var generation := _generation
	var groups: Array = wave["groups"]
	for group_index in groups.size():
		var group: Dictionary = groups[group_index]
		var count := int(group["count"])
		var gap := float(group["gap"])
		var foe_id := str(group["id"])
		for i in count:
			if generation != _generation:
				busy = false
				return
			_spawn(foe_id)
			var more := group_index < groups.size() - 1 or i < count - 1
			if more:
				await get_tree().create_timer(gap).timeout
	if generation == _generation:
		busy = false


func cancel() -> void:
	_generation += 1
	busy = false


func _spawn(foe_id: String) -> void:
	if not catalog.enemies.has(foe_id):
		return
	var stats: Dictionary = (catalog.enemies[foe_id] as Dictionary).duplicate()
	var foe := enemy_scene.instantiate() as LaneEnemy
	foe.setup(stats)
	foe.killed.connect(func(gold_value: int) -> void: foe_killed.emit(gold_value))
	foe.leaked.connect(func(lives_lost: int) -> void: foe_leaked.emit(lives_lost))
	path.add_child(foe)
