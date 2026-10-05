class_name Hud
extends CanvasLayer

signal start_pressed
signal wave_pressed
signal build_pressed(tower_key: String)
signal upgrade_pressed(branch: int)
signal sell_pressed
signal ability_pressed
signal save_pressed
signal load_pressed
signal shop_pressed
signal shop_closed
signal meta_buy(upgrade_id: String)
signal restart_pressed
signal select_pressed
signal next_pressed
signal level_pressed(index: int)

var _lives: Label
var _gold: Label
var _wave: Label
var _tokens: Label
var _hint: Label
var _status: Label
var _margin: MarginContainer
var _tower_buttons: Array[Button] = []
var _branch_buttons: Array[Button] = []
var _sell: Button
var _ability: Button
var _wave_button: Button
var _camp: Control
var _select: Control
var _shop: Control
var _result: Control
var _camp_title: Label
var _camp_body: Label
var _select_body: Label
var _result_title: Label
var _result_body: Label
var _next: Button
var _shop_rows: Dictionary = {}
var _level_buttons: Array[Button] = []
var _safe_margins: Array[MarginContainer] = []


func build(catalog: GameCatalog) -> void:
	layer = 20
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = UiStyle.font()
	theme.default_font_size = 16
	root.theme = theme
	add_child(root)

	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	_margin.add_child(column)

	column.add_child(_make_top())
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(_make_bottom(catalog))

	_camp = _make_camp()
	_select = _make_select()
	_shop = _make_shop(catalog)
	_result = _make_result()
	root.add_child(_camp)
	root.add_child(_select)
	root.add_child(_shop)
	root.add_child(_result)
	_camp.hide()
	_shop.hide()
	_result.hide()


func apply_insets(left: int, top: int, right: int, bottom: int) -> void:
	_apply_margin(_margin, left, top, right, bottom)
	for margin in _safe_margins:
		_apply_margin(margin, left, top, right, bottom)


func _apply_margin(margin: MarginContainer, left: int, top: int, right: int, bottom: int) -> void:
	if margin == null:
		return
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)


func refresh(state: Dictionary) -> void:
	_lives.text = "生命 %d" % int(state["lives"])
	_lives.add_theme_color_override("font_color", Color("e07a6a") if int(state["lives"]) <= 5 else Color("f4f0e4"))
	_gold.text = "金币 %d" % int(state["gold"])
	_wave.text = str(state["wave"])
	_tokens.text = "徽记 %d" % int(state["tokens"])
	_hint.text = str(state["hint"])
	_status.text = str(state["status"])
	var towers: Array = state["towers"]
	for i in _tower_buttons.size():
		_tower_buttons[i].text = str(towers[i]["text"])
		_tower_buttons[i].disabled = not bool(towers[i]["enabled"])
	var branches: Array = state["branches"]
	for i in _branch_buttons.size():
		_branch_buttons[i].text = str(branches[i]["text"])
		_branch_buttons[i].disabled = not bool(branches[i]["enabled"])
	_sell.text = str(state["sell_text"])
	_sell.disabled = not bool(state["sell_enabled"])
	_ability.text = str(state["ability_text"])
	_ability.disabled = not bool(state["ability_enabled"])
	_wave_button.text = str(state["wave_text"])
	_wave_button.disabled = not bool(state["wave_enabled"])
	_camp_title.text = str(state["camp_title"])
	_camp_body.text = str(state["camp_body"])
	_select_body.text = str(state["select_body"])
	_result_title.text = str(state["result_title"])
	_result_body.text = str(state["result_body"])
	_next.text = str(state["next_text"])
	_next.disabled = not bool(state["next_enabled"])
	_refresh_shop(state["shop"])
	_refresh_levels(state["levels"])
	var modal := str(state["modal"])
	_camp.visible = modal == "camp"
	_select.visible = modal == "select"
	_shop.visible = modal == "shop"
	_result.visible = modal == "result"


func _refresh_levels(rows: Array) -> void:
	for i in _level_buttons.size():
		if i >= rows.size():
			break
		_level_buttons[i].text = str(rows[i]["text"])
		_level_buttons[i].disabled = not bool(rows[i]["enabled"])


func _refresh_shop(rows: Array) -> void:
	for row in rows:
		var id := str(row["id"])
		if not _shop_rows.has(id):
			continue
		var widgets: Dictionary = _shop_rows[id]
		(widgets["label"] as Label).text = str(row["text"])
		var button := widgets["button"] as Button
		button.text = str(row["button"])
		button.disabled = not bool(row["enabled"])


func _make_top() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UiStyle.flat(Color(0.09, 0.12, 0.1, 0.92), Color(0.35, 0.4, 0.32), 8))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	_lives = _label("生命 0")
	_wave = _label("营地")
	_gold = _label("金币 0")
	_tokens = _label("徽记 0")
	_status = _label("")
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_lives)
	row.add_child(_wave)
	row.add_child(_gold)
	row.add_child(_tokens)
	row.add_child(_status)
	var save := _small_button("保存")
	var load := _small_button("读取")
	var shop := _small_button("研究所")
	save.pressed.connect(func() -> void: save_pressed.emit())
	load.pressed.connect(func() -> void: load_pressed.emit())
	shop.pressed.connect(func() -> void: shop_pressed.emit())
	row.add_child(save)
	row.add_child(load)
	row.add_child(shop)
	return panel


func _make_bottom(catalog: GameCatalog) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(0, 156)
	panel.add_theme_stylebox_override("panel", UiStyle.flat(Color(0.09, 0.12, 0.1, 0.94), Color(0.55, 0.48, 0.28), 12))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	_hint = _label("点圆垫建造，点空地移动巡岸卫。")
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hint)
	var towers := HBoxContainer.new()
	towers.add_theme_constant_override("separation", 6)
	box.add_child(towers)
	var colors := {
		"stone": Color("6b5a42"),
		"frost": Color("3d6a78"),
		"flame": Color("8a4b32"),
	}
	for key in catalog.tower_order:
		var button := Button.new()
		UiStyle.style_button(button, colors.get(key, Color("3e5346")))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tower_key := str(key)
		button.pressed.connect(func() -> void: build_pressed.emit(tower_key))
		towers.add_child(button)
		_tower_buttons.append(button)
	_ability = Button.new()
	UiStyle.style_button(_ability, Color("2f6f7e"))
	_ability.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability.pressed.connect(func() -> void: ability_pressed.emit())
	towers.add_child(_ability)
	_wave_button = Button.new()
	UiStyle.style_button(_wave_button, Color("3f6b45"))
	_wave_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wave_button.pressed.connect(func() -> void: wave_pressed.emit())
	towers.add_child(_wave_button)

	var routes := HBoxContainer.new()
	routes.add_theme_constant_override("separation", 6)
	box.add_child(routes)
	for branch in 2:
		var button := Button.new()
		UiStyle.style_button(button, Color("3e5346"))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var branch_index := branch
		button.pressed.connect(func() -> void: upgrade_pressed.emit(branch_index))
		routes.add_child(button)
		_branch_buttons.append(button)
	_sell = Button.new()
	UiStyle.style_button(_sell, Color("6a3d3d"))
	_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell.pressed.connect(func() -> void: sell_pressed.emit())
	routes.add_child(_sell)
	return panel


func _make_select() -> Control:
	var overlay := _overlay(0.45)
	var sheet := _sheet(overlay)
	var title := _label("选择关隘", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet.add_child(title)
	_select_body = _label("", 15)
	_select_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(_select_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	sheet.add_child(row)
	for index in 4:
		var button := Button.new()
		UiStyle.style_button(button, Color("31443a"))
		button.custom_minimum_size = Vector2(140, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var level_index := index
		button.pressed.connect(func() -> void: level_pressed.emit(level_index))
		row.add_child(button)
		_level_buttons.append(button)
	var shop := _small_button("研究所")
	shop.custom_minimum_size = Vector2(140, 48)
	shop.pressed.connect(func() -> void: shop_pressed.emit())
	sheet.add_child(shop)
	return overlay


func _make_camp() -> Control:
	var overlay := _overlay(0.5)
	var sheet := _sheet(overlay)
	_camp_title = _label("芦岸戍卫", 26)
	_camp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet.add_child(_camp_title)
	_camp_body = _label("", 15)
	_camp_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(_camp_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	sheet.add_child(row)
	var start := _small_button("开始守闸")
	start.custom_minimum_size = Vector2(140, 52)
	start.pressed.connect(func() -> void: start_pressed.emit())
	var back := _small_button("返回选关")
	back.custom_minimum_size = Vector2(140, 52)
	back.pressed.connect(func() -> void: select_pressed.emit())
	var shop := _small_button("研究所")
	shop.custom_minimum_size = Vector2(120, 52)
	shop.pressed.connect(func() -> void: shop_pressed.emit())
	row.add_child(start)
	row.add_child(back)
	row.add_child(shop)
	return overlay


func _make_shop(catalog: GameCatalog) -> Control:
	var overlay := _overlay()
	var panel := _card(overlay)
	var title := _label("研究所", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var intro := _label("徽记只在清波时增加。买下的等级会写入存档，下一局才生效。本局生命和金币不会被保存。", 14)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(420, 0)
	panel.add_child(intro)
	for entry in catalog.meta:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := _label("", 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var button := _small_button("购买")
		var upgrade_id := str(entry["id"])
		button.pressed.connect(func() -> void: meta_buy.emit(upgrade_id))
		row.add_child(label)
		row.add_child(button)
		panel.add_child(row)
		_shop_rows[upgrade_id] = {"label": label, "button": button}
	var close := _small_button("关闭")
	close.pressed.connect(func() -> void: shop_closed.emit())
	panel.add_child(close)
	return overlay


func _make_result() -> Control:
	var overlay := _overlay(0.55)
	var sheet := _sheet(overlay)
	_result_title = _label("", 26)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet.add_child(_result_title)
	_result_body = _label("", 15)
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sheet.add_child(_result_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	sheet.add_child(row)
	var again := _small_button("再守一次")
	again.custom_minimum_size = Vector2(120, 52)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.pressed.connect(func() -> void: restart_pressed.emit())
	_next = _small_button("下一关")
	_next.custom_minimum_size = Vector2(120, 52)
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.pressed.connect(func() -> void: next_pressed.emit())
	var back := _small_button("回到选关")
	back.custom_minimum_size = Vector2(120, 52)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(func() -> void: select_pressed.emit())
	var shop := _small_button("研究所")
	shop.custom_minimum_size = Vector2(110, 52)
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop.pressed.connect(func() -> void: shop_pressed.emit())
	row.add_child(again)
	row.add_child(_next)
	row.add_child(back)
	row.add_child(shop)
	return overlay


func _overlay(alpha: float = 0.62) -> Control:
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.05, 0.04, alpha)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	return dim


func _sheet(overlay: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(margin)
	_safe_margins.append(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UiStyle.flat(Color(0.11, 0.15, 0.12, 0.96), Color(0.62, 0.54, 0.32), 14))
	column.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


func _card(overlay: Control) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.flat(Color(0.11, 0.15, 0.12, 0.98), Color(0.62, 0.54, 0.32), 14))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(460, 0)
	panel.add_child(box)
	return box


func _label(text: String, size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	UiStyle.style_label(label, size)
	return label


func _small_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	UiStyle.style_button(button, Color("31443a"))
	button.custom_minimum_size = Vector2(72, 40)
	return button
