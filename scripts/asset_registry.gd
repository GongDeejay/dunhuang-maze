class_name AssetRegistry
extends RefCounted
## 集中管理 sprite 路径与期望分辨率（Web 双端统一入口）

const HQ_PLAYER_DIR := "res://assets/high_quality/player/"
const LOW_PLAYER_DIR := "res://assets/sprites/player/"
const ITEM_DIR := "res://assets/sprites/item/"
const TERRAIN_DIR := "res://assets/sprites/terrain/"
const HEART_DIR := "res://assets/sprites/heart/"

const CELL_SPRITE_PX := 16
const HQ_CHARACTER_PX := 32
const HEART_PX := 18

const FAMILY_KEY_TO_SPRITE := {
	"family_1": "le",
	"family_2": "mac",
	"family_3": "mcking",
}

const PLAYER_SPRITE_NAMES := ["dj", "le", "mac", "mcking"]

const ART_SOURCE_MAP := {
	"dj": "res://assets/art/1.png",
	"le": "res://assets/art/2.png",
	"mac": "res://assets/art/3.png",
	"mcking": "res://assets/art/4.png",
}

const ITEM_TYPE_FILES := {
	"container": "pot.png",
	"heal": "scroll.png",
	"defense": "shield.png",
	"attack": "sword.png",
	"trap": "pot.png",
}

const TERRAIN_FILES := {
	"sand": "sand.png",
	"desert": "desert.png",
	"grotto": "hole/line.png",
	"oasis": "oasis/defult.png",
	"ancient_road": "road/line.png",
}

const TERRAIN_VARIANTS := {
	"ancient_road_cross": "road/cross.png",
	"ancient_road_cross_t": "road/cross_t.png",
	"ancient_road_cross_l": "road/cross_l.png",
	"grotto_cross": "hole/cross.png",
	"grotto_cross_t": "hole/cross_t.png",
	"grotto_cross_l": "hole/cross_l.png",
	"oasis_pond": "oasis/pond.png",
	"oasis_tree": "oasis/tree.png",
}


static func character_sprite_path(name: String, prefer_hq: bool = false) -> String:
	var low := LOW_PLAYER_DIR + name + ".png"
	if ResourceLoader.exists(low):
		return low
	if prefer_hq:
		var hq := HQ_PLAYER_DIR + name + ".png"
		if ResourceLoader.exists(hq):
			return hq
	return low


static func item_sprite_path(item_type: String) -> String:
	var file: String = ITEM_TYPE_FILES.get(item_type, "")
	if file.is_empty():
		return ""
	return ITEM_DIR + file


static func terrain_sprite_path(key: String) -> String:
	if TERRAIN_VARIANTS.has(key):
		return TERRAIN_DIR + TERRAIN_VARIANTS[key]
	var file: String = TERRAIN_FILES.get(key, "")
	if file.is_empty():
		return ""
	return TERRAIN_DIR + file


static func heart_paths() -> Dictionary:
	return {
		"full": HEART_DIR + "full.png",
		"empty": HEART_DIR + "empty.png",
	}
