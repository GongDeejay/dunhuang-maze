class_name AssetRegistry
extends RefCounted
## 集中管理 sprite 路径与期望分辨率（Web 双端统一入口）

const HQ_PLAYER_DIR := "res://assets/high_quality/player/"
const LOW_PLAYER_DIR := "res://assets/sprites/player/"
const ITEM_DIR := "res://assets/sprites/item/"
const TERRAIN_DIR := "res://assets/sprites/terrain/"
const HEART_DIR := "res://assets/sprites/heart/"
const LANDMARK_DIR := "res://assets/sprites/landmark/"
const DECAL_DIR := "res://assets/sprites/decal/"
const MOGAO_DIR := "res://assets/sprites/mogao/"
const LORE_DIR := "res://assets/lore/"

const CELL_SPRITE_PX := 16
const HQ_CHARACTER_PX := 256
const HEART_PX := 18

const FAMILY_KEY_TO_SPRITE := {
	"family_1": "le",
	"family_2": "mac",
	"family_3": "mcking",
}

const PLAYER_SPRITE_NAMES := ["dj", "le", "mac", "mcking"]

const ART_SOURCE_MAP := {
	"dj": LOW_PLAYER_DIR + "dj.png",
	"le": LOW_PLAYER_DIR + "le.png",
	"mac": LOW_PLAYER_DIR + "mac.png",
	"mcking": LOW_PLAYER_DIR + "mcking.png",
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

const LANDMARK_FILES := {
	"beacon": "beacon.png",
	"beacon_lit": "beacon_lit.png",
	"stele": "stele.png",
	"stele_read": "stele_read.png",
	"caravan": "caravan.png",
	"caravan_searched": "caravan_searched.png",
}

const EXTRA_ITEM_FILES := {
	"bell": "bell.png",
	"fragment_1": "fragment_1.png",
	"fragment_2": "fragment_2.png",
	"fragment_3": "fragment_3.png",
	"water_skin": "water_skin.png",
	"water_skin_empty": "water_skin_empty.png",
}

const MOGAO_SPRITE_FILES := {
	"lotus_stand": "lotus_stand.png",
	"lotus_stand_lit": "lotus_stand_lit.png",
	"lamp_halo": "lamp_halo.png",
	"mirror_ne": "mirror_ne.png",
	"mirror_ne_lit": "mirror_ne_lit.png",
	"mirror_se": "mirror_se.png",
	"mirror_se_lit": "mirror_se_lit.png",
	"mirror_sw": "mirror_sw.png",
	"mirror_sw_lit": "mirror_sw_lit.png",
	"mirror_nw": "mirror_nw.png",
	"mirror_nw_lit": "mirror_nw_lit.png",
}

const FRAGMENT_SHEET := "mother_fragments.png"
const FRAGMENT_SHEET_REGIONS: Array[Rect2] = [
	Rect2(0, 0, 32, 64),
	Rect2(32, 0, 32, 64),
	Rect2(64, 0, 32, 64),
]
const FRAGMENT_DIM := Color(0.25, 0.22, 0.2, 1)
const MOTHER_SILHOUETTE_FILE := "mother_silhouette.png"
## Slot inside one maze cell. At cell_size 40 this is 25.6×25.6 px.
const FAMILY_SILHOUETTE_ORIGIN := Vector2(0.18, 0.12)
const FAMILY_SILHOUETTE_SIZE := Vector2(0.64, 0.64)
const FAMILY_SILHOUETTE_TEX_PX := 16
const FAMILY_SILHOUETTE_DARKEN := Color(0.16, 0.12, 0.08, 0.9)


static func character_sprite_path(name: String, prefer_hq: bool = false) -> String:
	if prefer_hq:
		var hq := HQ_PLAYER_DIR + name + ".svg"
		if ResourceLoader.exists(hq):
			return hq
	var low := LOW_PLAYER_DIR + name + ".png"
	if ResourceLoader.exists(low):
		return low
	return low


static func mother_silhouette_path() -> String:
	return LANDMARK_DIR + MOTHER_SILHOUETTE_FILE


## Dedicated art wins when the file exists. Otherwise the maze darkens le.png.
static func family_silhouette_source(dedicated_exists: Variant = null) -> Dictionary:
	var path := mother_silhouette_path()
	var exists := ResourceLoader.exists(path) if dedicated_exists == null else bool(dedicated_exists)
	if exists:
		return {"path": path, "darken": false, "nearest": true}
	return {"path": character_sprite_path("le", false), "darken": true, "nearest": true}


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


static func landmark_path(key: String) -> String:
	var file: String = LANDMARK_FILES.get(key, "")
	if file.is_empty():
		return ""
	return LANDMARK_DIR + file


static func decal_path(direction: String) -> String:
	return DECAL_DIR + "footprint_" + direction + ".png"


static func extra_item_path(key: String) -> String:
	var file: String = EXTRA_ITEM_FILES.get(key, "")
	if file.is_empty():
		return ""
	return ITEM_DIR + file


static func mogao_sprite_path(key: String) -> String:
	var file: String = MOGAO_SPRITE_FILES.get(key, "")
	if file.is_empty():
		return ""
	return MOGAO_DIR + file


static func fragment_sheet_path() -> String:
	return LORE_DIR + FRAGMENT_SHEET
