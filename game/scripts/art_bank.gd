class_name ArtBank
extends RefCounted

const FOE := {
	"raider": preload("res://art/raider.png"),
	"runner": preload("res://art/runner.png"),
	"shell": preload("res://art/shell.png"),
	"boss": preload("res://art/boss.png"),
	"tide": preload("res://art/tide.png"),
}
const TOWER := {
	"bolt": preload("res://art/tower_stone.png"),
	"pulse": preload("res://art/tower_frost.png"),
	"splash": preload("res://art/tower_flame.png"),
}
const BOLT := {
	"bolt": preload("res://art/bolt_stone.png"),
	"pulse": preload("res://art/bolt_frost.png"),
	"splash": preload("res://art/bolt_flame.png"),
}
const PROP := {
	"reed": preload("res://art/prop_reed.png"),
	"willow": preload("res://art/prop_willow.png"),
	"basket": preload("res://art/prop_basket.png"),
	"stake": preload("res://art/prop_stake.png"),
	"lantern": preload("res://art/prop_lantern.png"),
	"cairn": preload("res://art/prop_cairn.png"),
}
const HERO := preload("res://art/hero.png")
const PAD := preload("res://art/pad.png")
const WATER := preload("res://art/water.png")
const GROUND := preload("res://art/ground.png")

const FOE_HEIGHT := {
	"raider": 38.0,
	"runner": 50.0,
	"shell": 34.0,
	"boss": 56.0,
	"tide": 42.0,
}
const TOWER_HEIGHT := {
	"bolt": 40.0,
	"pulse": 44.0,
	"splash": 42.0,
}


static func foe_texture(id: String) -> Texture2D:
	return FOE.get(id, FOE["raider"])


static func foe_height(id: String) -> float:
	return float(FOE_HEIGHT.get(id, 38.0))


static func tower_texture(kind: String) -> Texture2D:
	return TOWER.get(kind, TOWER["bolt"])


static func tower_height(kind: String) -> float:
	return float(TOWER_HEIGHT.get(kind, 40.0))


static func bolt_texture(kind: String) -> Texture2D:
	return BOLT.get(kind, BOLT["bolt"])


static func prop_texture(key: String) -> Texture2D:
	return PROP.get(key, PROP["reed"])


static func plant(sprite: Sprite2D, texture: Texture2D, display_height: float) -> void:
	sprite.texture = texture
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tex_h := maxf(float(texture.get_height()), 1.0)
	var scale := display_height / tex_h
	sprite.scale = Vector2(scale, scale)
	sprite.offset = Vector2(0, -tex_h * 0.5)


static func center(sprite: Sprite2D, texture: Texture2D, display_width: float) -> void:
	sprite.texture = texture
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tex_w := maxf(float(texture.get_width()), 1.0)
	var scale := display_width / tex_w
	sprite.scale = Vector2(scale, scale)
