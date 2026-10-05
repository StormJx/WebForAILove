class_name UiStyle
extends RefCounted

static var _font: Font

static func font() -> Font:
	if _font == null:
		if ResourceLoader.exists("res://fonts/ReedbankSans.otf"):
			_font = load("res://fonts/ReedbankSans.otf")
		else:
			var sys := SystemFont.new()
			sys.font_names = PackedStringArray([
				"PingFang SC",
				"Hiragino Sans GB",
				"Heiti SC",
				"Noto Sans CJK SC",
				"Noto Sans SC",
				"Source Han Sans SC",
				"Droid Sans Fallback",
				"sans-serif",
			])
			_font = sys
	return _font


static func flat(bg: Color, border: Color, radius: int = 10) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


static func style_button(button: Button, bg: Color) -> void:
	var border := bg.lightened(0.18)
	button.add_theme_stylebox_override("normal", flat(bg, border))
	button.add_theme_stylebox_override("hover", flat(bg.lightened(0.12), border))
	button.add_theme_stylebox_override("pressed", flat(bg.darkened(0.12), border))
	button.add_theme_stylebox_override("disabled", flat(Color(0.16, 0.18, 0.16, 0.72), Color(0.28, 0.3, 0.28)))
	button.add_theme_color_override("font_color", Color("f4f0e4"))
	button.add_theme_color_override("font_hover_color", Color("fffaf0"))
	button.add_theme_color_override("font_pressed_color", Color("f4f0e4"))
	button.add_theme_color_override("font_disabled_color", Color(0.75, 0.74, 0.68, 0.45))
	button.add_theme_font_override("font", font())
	button.add_theme_font_size_override("font_size", 15)
	button.custom_minimum_size = Vector2(86, 50)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER


static func style_label(label: Label, size: int = 16) -> void:
	label.add_theme_font_override("font", font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f4f0e4"))
