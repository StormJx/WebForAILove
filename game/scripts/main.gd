extends Node

const STATE_CAMP := 0
const STATE_BATTLE := 1
const STATE_RESULT := 2

const ENEMY_SCENE := preload("res://scenes/enemy.tscn")
const TOWER_SCENE := preload("res://scenes/tower.tscn")
const HERO_SCENE := preload("res://scenes/hero.tscn")

var state := STATE_CAMP
var catalog: GameCatalog
var save: SaveStore
var gold := 0
var lives := 0
var wave_index := 0
var launched := 0
var wave_resolved := true
var selected := -1
var built: Array = []
var result_win := false
var shop_open := false
var note := ""
var note_left := 0.0
var tokens_earned := 0

var world: Node2D
var path: Path2D
var fx: Node2D
var hero: Warden
var spawner: WaveSpawner
var hud: Hud
var spot_nodes: Array[BuildSpot] = []
var _top_bar := 52.0
var _bottom_bar := 168.0


func _ready() -> void:
	catalog = GameCatalog.load_all()
	save = SaveStore.load_file()
	_build_world()
	_build_hud()
	process_mode = Node.PROCESS_MODE_ALWAYS
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	spawner.process_mode = Node.PROCESS_MODE_PAUSABLE
	get_viewport().size_changed.connect(_layout)
	_layout()
	get_tree().create_timer(0.4).timeout.connect(_layout)
	note = "点「开始守闸」。"
	hud.refresh(ui_state())


func _process(delta: float) -> void:
	if note_left > 0.0:
		note_left -= delta
		if note_left <= 0.0:
			note = ""
	if not get_tree().paused and state == STATE_BATTLE:
		_check_outcome()
	if hud:
		hud.refresh(ui_state())


func _unhandled_input(event: InputEvent) -> void:
	if shop_open or state == STATE_CAMP or state == STATE_RESULT:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			_move_hero_screen(mouse.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.keycode:
			KEY_1:
				try_build(selected, "stone")
			KEY_2:
				try_build(selected, "frost")
			KEY_3:
				try_build(selected, "flame")
			KEY_Q:
				try_upgrade(0)
			KEY_E:
				try_upgrade(1)
			KEY_R:
				try_sell()
			KEY_F:
				try_ability()
			KEY_SPACE:
				try_wave()


func start_battle() -> void:
	_wipe_field()
	var bonus := GameCatalog.bonuses(save, catalog)
	gold = int(catalog.rules["gold"]) + int(bonus["gold"])
	lives = int(catalog.rules["lives"]) + int(bonus["lives"])
	wave_index = 0
	launched = 0
	wave_resolved = true
	selected = -1
	result_win = false
	shop_open = false
	tokens_earned = 0
	hero.place(catalog.hero_start, catalog.hero, float(bonus["hero_damage"]))
	state = STATE_BATTLE
	get_tree().paused = false
	_set_note("点圆垫造塔，准备好再出波。")
	_refresh_selection_visuals()


func return_to_camp() -> void:
	_wipe_field()
	state = STATE_CAMP
	shop_open = false
	selected = -1
	get_tree().paused = false
	_refresh_selection_visuals()
	_set_note("已回到营地。")


func try_build(index: int, tower_key: String) -> bool:
	if state != STATE_BATTLE or shop_open:
		_set_note("先开始守闸。")
		return false
	if index < 0 or index >= built.size():
		_set_note("先点一个圆垫。")
		return false
	if built[index] != null:
		_set_note("这里已经有塔，可以升级或出售。")
		return false
	if not catalog.towers.has(tower_key):
		return false
	var definition: Dictionary = catalog.towers[tower_key]
	var cost := int(definition["cost"])
	if gold < cost:
		_set_note("金币不足。")
		return false
	gold -= cost
	var tower := TOWER_SCENE.instantiate() as Sentry
	tower.position = catalog.spots[index]
	tower.z_index = 6
	tower.setup(definition)
	tower.spent = cost
	world.add_child(tower)
	built[index] = tower
	selected = index
	_refresh_selection_visuals()
	_set_note("建好了%s。" % definition["name"])
	return true


func try_upgrade(branch: int) -> bool:
	if state != STATE_BATTLE or shop_open:
		return false
	if selected < 0 or built[selected] == null:
		_set_note("先选中一座塔。")
		return false
	var tower := built[selected] as Sentry
	if branch < 0 or branch >= tower.branch_count():
		return false
	var info := tower.branch_info(branch)
	if info["locked"]:
		_set_note("这座塔已经走上另一条路线。")
		return false
	if info["done"]:
		_set_note("这条路线已经升满。")
		return false
	if gold < int(info["cost"]):
		_set_note("金币不足。")
		return false
	gold -= int(info["cost"])
	tower.apply_branch(branch)
	_set_note("升级：%s。" % info["name"])
	return true


func try_sell() -> bool:
	if state != STATE_BATTLE or shop_open:
		return false
	if selected < 0 or built[selected] == null:
		_set_note("没有可出售的塔。")
		return false
	var tower := built[selected] as Sentry
	var refund := tower.refund()
	gold += refund
	tower.queue_free()
	built[selected] = null
	_refresh_selection_visuals()
	_set_note("已出售，返还 %d。" % refund)
	return true


func try_wave() -> bool:
	if state != STATE_BATTLE or shop_open or get_tree().paused:
		return false
	if spawner.busy:
		_set_note("这一波还在过来。")
		return false
	if not wave_resolved:
		_set_note("先清掉渠上的敌人。")
		return false
	if wave_index >= catalog.waves.size():
		_set_note("没有下一波了。")
		return false
	var wave: Dictionary = catalog.waves[wave_index]
	wave_index += 1
	launched = wave_index
	wave_resolved = false
	spawner.launch(wave)
	_set_note("第 %d 波来了。" % launched)
	return true


func try_ability() -> bool:
	if state != STATE_BATTLE or shop_open or get_tree().paused:
		return false
	if not hero.cast():
		_set_note("断流还在准备。")
		return false
	_set_note("巡岸卫斩断了一段渠水。")
	return true


func save_progress() -> void:
	if save.write_file():
		_set_note("已写入存档。只含研究所和通关，不含本局生命与金币。")
	else:
		_set_note("存档失败。")


func load_progress() -> void:
	save = SaveStore.load_file()
	_set_note("已读入存档。本局生命和金币保持不变，研究所在下一局生效。")


func buy_meta(upgrade_id: String) -> void:
	for entry in catalog.meta:
		if str(entry["id"]) != upgrade_id:
			continue
		var levels: Array = entry["levels"]
		var rank := int(save.upgrades.get(upgrade_id, 0))
		if rank >= levels.size():
			_set_note("已经满级。")
			return
		var cost := int(levels[rank]["cost"])
		if save.tokens < cost:
			_set_note("徽记不足。")
			return
		save.tokens -= cost
		save.upgrades[upgrade_id] = rank + 1
		save.write_file()
		_set_note("买下了%s，下一局生效。" % entry["name"])
		return


func open_shop() -> void:
	shop_open = true
	if state == STATE_BATTLE:
		get_tree().paused = true


func close_shop() -> void:
	shop_open = false
	if state == STATE_BATTLE:
		get_tree().paused = false


func ui_state() -> Dictionary:
	var modal := ""
	if shop_open:
		modal = "shop"
	elif state == STATE_CAMP:
		modal = "camp"
	elif state == STATE_RESULT:
		modal = "result"
	return {
		"lives": lives if state != STATE_CAMP else int(catalog.rules["lives"]) + int(GameCatalog.bonuses(save, catalog)["lives"]),
		"gold": gold if state != STATE_CAMP else int(catalog.rules["gold"]) + int(GameCatalog.bonuses(save, catalog)["gold"]),
		"wave": _wave_label(),
		"tokens": save.tokens,
		"hint": _hint_text(),
		"status": note,
		"towers": _tower_buttons(),
		"branches": _branch_buttons(),
		"sell_text": _sell_text(),
		"sell_enabled": state == STATE_BATTLE and not shop_open and selected >= 0 and built[selected] != null,
		"ability_text": _ability_text(),
		"ability_enabled": state == STATE_BATTLE and not shop_open and not get_tree().paused and hero.ability_left <= 0.0,
		"wave_text": _wave_button_text(),
		"wave_enabled": state == STATE_BATTLE and not shop_open and not get_tree().paused and not spawner.busy and wave_resolved and wave_index < catalog.waves.size(),
		"camp_body": _camp_text(),
		"result_title": "水闸保住了" if result_win else "闸门失守",
		"result_body": _result_text(),
		"shop": _shop_rows(),
		"modal": modal,
	}


func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	var map := MapView.new()
	map.name = "Map"
	map.setup(catalog, UiStyle.font())
	world.add_child(map)
	path = Path2D.new()
	path.name = "Path"
	path.z_index = 8
	var curve := Curve2D.new()
	for point in catalog.path:
		curve.add_point(point)
	path.curve = curve
	world.add_child(path)
	for i in catalog.spots.size():
		var spot := BuildSpot.new()
		spot.position = catalog.spots[i]
		spot.z_index = 4
		spot.setup(i)
		spot.picked.connect(_on_spot)
		world.add_child(spot)
		spot_nodes.append(spot)
		built.append(null)
	hero = HERO_SCENE.instantiate() as Warden
	hero.name = "Hero"
	hero.z_index = 9
	hero.place(catalog.hero_start, catalog.hero, 0.0)
	world.add_child(hero)
	fx = Node2D.new()
	fx.name = "Fx"
	fx.z_index = 20
	fx.add_to_group("fx")
	world.add_child(fx)
	spawner = WaveSpawner.new()
	spawner.name = "Spawner"
	spawner.setup(catalog, path, ENEMY_SCENE)
	spawner.foe_killed.connect(_on_killed)
	spawner.foe_leaked.connect(_on_leaked)
	add_child(spawner)


func _build_hud() -> void:
	hud = Hud.new()
	hud.name = "Hud"
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.build(catalog)
	hud.start_pressed.connect(start_battle)
	hud.wave_pressed.connect(try_wave)
	hud.build_pressed.connect(func(key: String) -> void: try_build(selected, key))
	hud.upgrade_pressed.connect(try_upgrade)
	hud.sell_pressed.connect(try_sell)
	hud.ability_pressed.connect(try_ability)
	hud.save_pressed.connect(save_progress)
	hud.load_pressed.connect(load_progress)
	hud.shop_pressed.connect(open_shop)
	hud.shop_closed.connect(close_shop)
	hud.meta_buy.connect(buy_meta)
	hud.restart_pressed.connect(start_battle)
	hud.camp_pressed.connect(return_to_camp)
	add_child(hud)


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var insets := _safe_insets(viewport_size)
	if hud:
		hud.apply_insets(int(insets.x), int(insets.y), int(insets.z), int(insets.w))
	var area_pos := Vector2(insets.x, insets.y + _top_bar)
	var area_size := Vector2(
		viewport_size.x - insets.x - insets.z,
		viewport_size.y - insets.y - insets.w - _top_bar - _bottom_bar
	)
	area_size.x = maxf(area_size.x, 40.0)
	area_size.y = maxf(area_size.y, 40.0)
	var scale := minf(area_size.x / catalog.map_size.x, area_size.y / catalog.map_size.y)
	world.scale = Vector2(scale, scale)
	world.position = area_pos + (area_size - catalog.map_size * scale) * 0.5


func _safe_insets(viewport_size: Vector2) -> Vector4:
	var window_size := DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return Vector4(12, 8, 12, 10)
	var safe := DisplayServer.get_display_safe_area()
	var scale_x := viewport_size.x / float(window_size.x)
	var scale_y := viewport_size.y / float(window_size.y)
	var left := 0.0
	var top := 0.0
	var right := 0.0
	var bottom := 0.0
	var usable := safe.size.x > 0 and safe.size.y > 0 and safe.position.x >= -1 and safe.position.y >= -1 and safe.size.x <= window_size.x + 2 and safe.size.y <= window_size.y + 2
	if usable:
		left = safe.position.x * scale_x
		top = safe.position.y * scale_y
		right = maxf(window_size.x - safe.end.x, 0) * scale_x
		bottom = maxf(window_size.y - safe.end.y, 0) * scale_y
	left = clampf(left + 12.0, 12.0, viewport_size.x * 0.22)
	top = clampf(top + 8.0, 8.0, viewport_size.y * 0.2)
	right = clampf(right + 12.0, 12.0, viewport_size.x * 0.22)
	bottom = clampf(bottom + 10.0, 10.0, viewport_size.y * 0.24)
	return Vector4(left, top, right, bottom)


func _check_outcome() -> void:
	if lives <= 0:
		_finish(false)
		return
	if spawner.busy or wave_resolved or launched <= 0:
		return
	if _foe_count() > 0:
		return
	var wave: Dictionary = catalog.waves[launched - 1]
	gold += int(wave["reward"])
	var gain := int(wave["tokens"])
	save.tokens += gain
	tokens_earned += gain
	save.write_file()
	wave_resolved = true
	if launched >= catalog.waves.size():
		_set_note("第五波也拦住了。")
		_finish(true)
	else:
		_set_note("第 %d 波已被拦住，金币 +%d，徽记 +%d。" % [launched, int(wave["reward"]), gain])


func _finish(win: bool) -> void:
	if state == STATE_RESULT:
		return
	state = STATE_RESULT
	result_win = win
	spawner.cancel()
	if win:
		save.cleared = true
	save.write_file()
	selected = -1
	_refresh_selection_visuals()
	shop_open = false
	get_tree().paused = true
	if hud:
		hud.refresh(ui_state())


func _on_killed(gold_value: int) -> void:
	if state != STATE_BATTLE:
		return
	gold += gold_value


func _on_leaked(lives_lost: int) -> void:
	if state != STATE_BATTLE:
		return
	lives = maxi(lives - lives_lost, 0)
	_set_note("有人漏过了水闸。")
	if lives <= 0:
		_finish(false)


func _on_spot(index: int) -> void:
	if state != STATE_BATTLE or get_tree().paused:
		return
	selected = -1 if selected == index else index
	_refresh_selection_visuals()


func _move_hero_screen(screen_pos: Vector2) -> void:
	if state != STATE_BATTLE or get_tree().paused:
		return
	var local := world.to_local(screen_pos)
	if not Rect2(Vector2.ZERO, catalog.map_size).has_point(local):
		return
	local.x = clampf(local.x, 16, catalog.map_size.x - 16)
	local.y = clampf(local.y, 16, catalog.map_size.y - 16)
	hero.move_to(local)


func _wipe_field() -> void:
	spawner.cancel()
	for foe in path.get_children():
		path.remove_child(foe)
		foe.free()
	for shot in fx.get_children():
		fx.remove_child(shot)
		shot.free()
	for i in built.size():
		var tower = built[i]
		if tower != null and is_instance_valid(tower):
			world.remove_child(tower)
			tower.free()
		built[i] = null


func _refresh_selection_visuals() -> void:
	for i in spot_nodes.size():
		spot_nodes[i].set_selected(i == selected)
		spot_nodes[i].set_occupied(built[i] != null)
		if built[i] != null and is_instance_valid(built[i]):
			(built[i] as Sentry).show_range = i == selected


func _foe_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("foes"):
		var foe := node as LaneEnemy
		if foe != null and foe.alive:
			count += 1
	return count


func _set_note(text: String) -> void:
	note = text
	note_left = 3.2


func _wave_label() -> String:
	if state == STATE_CAMP:
		return "营地"
	if state == STATE_RESULT:
		return "结束"
	if launched <= 0:
		return "第 0/%d 波" % catalog.waves.size()
	var phase := "交战" if spawner.busy or not wave_resolved else "间歇"
	return "第 %d/%d 波 · %s" % [launched, catalog.waves.size(), phase]


func _hint_text() -> String:
	if state != STATE_BATTLE:
		return "底部按钮放在拇指够得到的位置。点空地移动巡岸卫。"
	if selected < 0:
		return "点圆垫选建造点，点渠边空地移动巡岸卫。1/2/3 造塔，空格出波。"
	if built[selected] == null:
		return "空位 %d。点下方石弩、霜坛或焰壶。同一座塔只能走一条升级路线。" % (selected + 1)
	return (built[selected] as Sentry).summary()


func _tower_buttons() -> Array:
	var buttons: Array = []
	var can_place := state == STATE_BATTLE and not shop_open and selected >= 0 and built[selected] == null
	for key in catalog.tower_order:
		var definition: Dictionary = catalog.towers[key]
		var cost := int(definition["cost"])
		buttons.append({
			"text": "%s\n%d" % [definition["name"], cost],
			"enabled": can_place and gold >= cost,
		})
	return buttons


func _branch_buttons() -> Array:
	if selected < 0 or built[selected] == null:
		return [
			{"text": "路线甲", "enabled": false},
			{"text": "路线乙", "enabled": false},
		]
	var tower := built[selected] as Sentry
	var buttons: Array = []
	for i in tower.branch_count():
		var info := tower.branch_info(i)
		var enabled: bool = state == STATE_BATTLE and not shop_open and not bool(info["locked"]) and not bool(info["done"]) and gold >= int(info["cost"])
		buttons.append({"text": info["text"], "enabled": enabled})
	return buttons


func _sell_text() -> String:
	if selected >= 0 and built[selected] != null:
		return "出售 %d" % (built[selected] as Sentry).refund()
	return "出售"


func _ability_text() -> String:
	if hero == null or hero.ability_left <= 0.05:
		return "断流"
	return "断流\n%d" % int(ceil(hero.ability_left))


func _wave_button_text() -> String:
	if wave_index >= catalog.waves.size():
		return "末波"
	return "出波 %d" % (wave_index + 1)


func _camp_text() -> String:
	var bonus := GameCatalog.bonuses(save, catalog)
	var clear_text := "已守住水闸" if save.cleared else "还没有通关"
	return "潮退之后，芦寇顺着旧渠摸向水闸。守住五波，并且还有生命，才算赢。\n石弩、霜坛、焰壶各有两条升级路线，一座塔只能选一条。\n巡岸卫会自己攻击，点地图空地让他换位置，断流可以减速一片。\n通关记录：%s。徽记 %d。下一局加成：金币 +%d，生命 +%d。\n生命和金币只在本局变化。保存 / 读取只处理研究所和通关结果。\n键位：1/2/3 造塔，Q/E 升级，R 出售，F 断流，空格出波。" % [clear_text, save.tokens, int(bonus["gold"]), int(bonus["lives"])]


func _result_text() -> String:
	if result_win:
		return "五波都拦住了，水闸还在。这一局得到徽记 %d。研究所里的购买已经写入存档。再守一次会重新计算生命和金币。" % tokens_earned
	return "生命耗尽，芦寇越过了水闸。这一局得到徽记 %d。已经买下的研究所等级还在；本局金币不会留下。" % tokens_earned


func _shop_rows() -> Array:
	var rows: Array = []
	for entry in catalog.meta:
		var id := str(entry["id"])
		var levels: Array = entry["levels"]
		var rank := int(save.upgrades.get(id, 0))
		var button := "已满"
		var enabled := false
		if rank < levels.size():
			var cost := int(levels[rank]["cost"])
			button = "购买 %d" % cost
			enabled = save.tokens >= cost
		rows.append({
			"id": id,
			"text": "%s  %d/%d  %s" % [entry["name"], rank, levels.size(), entry["blurb"]],
			"button": button,
			"enabled": enabled,
		})
	return rows
