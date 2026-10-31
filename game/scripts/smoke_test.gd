extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: PackedStringArray = []
	var catalog := GameCatalog.load_all()
	var errors := catalog.validate()
	for err in errors:
		failures.append(err)

	if catalog.stages.size() != 4:
		failures.append("expected 4 stages, got %d" % catalog.stages.size())
	var seen_paths := {}
	for stage_number in catalog.stages.size():
		catalog.apply_stage(stage_number)
		if catalog.waves.size() != 5:
			failures.append("stage %d does not have 5 waves" % stage_number)
		var signature := str(catalog.path)
		if seen_paths.has(signature):
			failures.append("stage %d path is not unique" % stage_number)
		seen_paths[signature] = true
	catalog.apply_stage(0)

	var save := SaveStore.load_file()
	save.cleared = true
	save.mark_cleared("reed_gate", true)
	save.tokens = 12
	save.upgrades = {"rations": 1}
	if not save.write_file():
		failures.append("save write failed")
	var loaded := SaveStore.load_file()
	if not loaded.cleared or not loaded.is_cleared("reed_gate") or loaded.tokens != 12 or int(loaded.upgrades.get("rations", 0)) != 1:
		failures.append("save roundtrip mismatch %s" % loaded.to_dict())
	if not loaded.is_unlocked(1, ["reed_gate", "backwater", "narrow_bank", "night_tide"]):
		failures.append("clearing level 1 did not unlock level 2")
	if loaded.to_dict().has("gold") or loaded.to_dict().has("lives"):
		failures.append("save should not keep runtime lives or gold")

	var legacy_file := FileAccess.open(SaveStore.PATH, FileAccess.WRITE)
	legacy_file.store_string("{\"cleared\": true, \"tokens\": 1, \"upgrades\": {}}")
	legacy_file.close()
	var legacy := SaveStore.load_file()
	if not legacy.legacy_bool_clear:
		failures.append("old clear flag was not recognized")
	legacy.migrate_legacy("reed_gate")
	if not legacy.is_cleared("reed_gate") or not legacy.is_unlocked(1, ["reed_gate", "backwater"]):
		failures.append("old clear flag did not unlock the next level")

	var fresh := SaveStore.new()
	fresh.write_file()

	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		failures.append("main scene failed to load")
		_finish(failures)
		return
	var main = packed.instantiate()
	root.add_child(main)
	await process_frame
	if main.catalog == null or main.catalog.waves.size() != 5:
		failures.append("main did not load five waves")

	Engine.time_scale = 12.0
	main.start_battle()
	main.hero.position = Vector2(24, 180)
	main.hero.moving = false
	var idle_lives: int = main.lives
	if not main.try_wave():
		failures.append("could not launch an empty defense")
	var guard := 0
	while guard < 8000 and main.state == main.STATE_BATTLE and (main.spawner.busy or not main.wave_resolved):
		guard += 1
		await process_frame
	if main.lives >= idle_lives and main.state == main.STATE_BATTLE:
		failures.append("undefended wave 1 did not leak")

	main.start_battle()
	var plan := [
		[1, "stone"],
		[2, "frost"],
		[3, "flame"],
		[0, "stone"],
		[4, "flame"],
		[5, "frost"],
	]
	guard = 0
	while guard < 20000 and main.state == main.STATE_BATTLE:
		guard += 1
		_scripted_turn(main, plan)
		await process_frame
	if main.state != main.STATE_RESULT or not main.result_win:
		failures.append("scripted defense lost lives=%s launched=%s resolved=%s" % [main.lives, main.launched, main.wave_resolved])
	elif not main.save.cleared or not main.save.is_cleared("reed_gate"):
		failures.append("win did not persist level 1 clear")
	elif not main.save.is_unlocked(1, main.catalog.stage_ids()):
		failures.append("level 2 stayed locked after level 1")
	if main.enter_stage(2):
		failures.append("level 3 unlocked before level 2 was cleared")
	if not main.enter_stage(1):
		failures.append("level 2 did not open after level 1")
	else:
		main.start_battle()
		main.hero.position = Vector2(8, 8)
		main.hero.moving = false
		var level2_lives: int = main.lives
		if main.catalog.stage_id != "backwater":
			failures.append("entered the wrong level")
		elif not main.try_wave():
			failures.append("could not launch level 2")
		else:
			guard = 0
			while guard < 8000 and main.state == main.STATE_BATTLE and (main.spawner.busy or not main.wave_resolved):
				guard += 1
				await process_frame
			if main.lives >= level2_lives and main.state == main.STATE_BATTLE:
				failures.append("undefended level 2 did not leak")
	Engine.time_scale = 1.0

	_finish(failures)


func _scripted_turn(main, plan: Array) -> void:
	if main.hero.ability_left <= 0.0 and main.get_tree().get_nodes_in_group("foes").size() > 0:
		main.try_ability()
	for step in plan:
		var index: int = step[0]
		var key: String = step[1]
		if main.built[index] == null and main.gold >= int(main.catalog.towers[key]["cost"]):
			main.try_build(index, key)
	if main.built[1] != null:
		var stone: Sentry = main.built[1]
		if stone.branch_index < 0 or (stone.branch_index == 0 and stone.branch_level < 2):
			if main.gold >= 40:
				main.selected = 1
				main.try_upgrade(0)
	var towers := 0
	for tower in main.built:
		if tower != null:
			towers += 1
	if main.wave_resolved and not main.spawner.busy and (main.launched > 0 or towers >= 2):
		main.try_wave()


func _finish(failures: PackedStringArray) -> void:
	if failures.is_empty():
		print("SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("SMOKE_FAIL %d" % failures.size())
		quit(1)
