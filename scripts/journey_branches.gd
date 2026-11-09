class_name JourneyBranches
extends RefCounted
## First-chapter side branches: carve, rewards, camp clue, footprint pulse.
## Numbers live on FirstJourney; this module only applies them.

const PULSE_BASE := 0.84
const PULSE_AMP := 0.12
const PULSE_PERIOD := 1.7
const BEACON_HINT := "烽燧照见远处：小地图上圈出了驼队与残碑"
const CLIFF_HINT := "崖坎太陡，绕到东边上去"
const COUNT_WORDS: PackedStringArray = ["", "一", "两", "三", "四"]


static func carve(journey, maze: MazeGenerator) -> void:
	journey._carve(maze, journey.BEACON_PATH, MazeGenerator.Terrain.SAND)
	var mouth: Vector2i = journey.BEACON_PATH[0]
	maze.terrain[mouth.y][mouth.x] = MazeGenerator.Terrain.DESERT
	journey._carve(maze, journey.CARAVAN_PATH, MazeGenerator.Terrain.ANCIENT_ROAD)
	journey._carve(maze, journey.STELE_PATH, MazeGenerator.Terrain.ANCIENT_ROAD)
	maze.landmarks[journey.BEACON] = {"symbol": "燧", "kind": "beacon", "discovered": true, "lit": false}
	maze.landmarks[journey.CARAVAN] = {"symbol": "驼", "kind": "caravan", "ghost": false, "searched": false}
	maze.landmarks[journey.STELE] = {"symbol": "碑", "kind": "stele", "read": false}
	for mark in journey.FOOTPRINTS:
		var cell: Vector2i = mark["at"]
		maze.landmarks[cell] = {
			"symbol": "",
			"kind": "footprint",
			"dir": mark["dir"],
			"pulse": mark["pulse"],
			"branch": mark["branch"],
		}


static func sync(journey, maze: MazeGenerator, pos: Vector2i) -> void:
	if not maze.landmarks.has(journey.CARAVAN):
		return
	var lure := false
	if not journey.caravan_found:
		for cell in journey.CARAVAN_GHOST:
			if cell == pos:
				lure = true
				break
	maze.landmarks[journey.CARAVAN]["ghost"] = lure


static func reward(journey, pos: Vector2i, maze: MazeGenerator, player: PlayerController) -> Dictionary:
	if pos == journey.BEACON:
		return _beacon(journey, maze, player)
	if pos == journey.CARAVAN:
		return _caravan(journey, maze, player)
	if pos == journey.STELE:
		return _stele(journey, maze)
	return {}


static func camp_card() -> Dictionary:
	return {
		"title": "驿站里的线索",
		"body": "驿卒：见过妈妈，她过了石门往北去了。\n先去北边找到她，再一起回来歇脚。",
		"button": "去北边找妈妈",
	}


static func grant_vision(journey, player: PlayerController, amount: int) -> int:
	var room: int = int(journey.VISION_BONUS_CAP) - int(journey.journey_vision)
	var grant := mini(amount, room)
	if grant <= 0:
		return 0
	journey.journey_vision += grant
	player.reveal_bonus += grant
	return grant


static func scaled_heal(base: int) -> int:
	var mult := float(DataLoader.get_difficulty().get("heal_multiplier", 1.0))
	return maxi(0, int(floor(float(base) * mult)))


static func tick(journey, delta: float, maze: MazeGenerator) -> void:
	if journey.silhouette_time <= 0.0:
		return
	journey.silhouette_time = maxf(0.0, journey.silhouette_time - delta)
	if maze.landmarks.has(journey.FAMILY):
		maze.landmarks[journey.FAMILY]["silhouette"] = journey.silhouette_time > 0.0


static func footprint_alpha(time_sec: float, pulsing: bool) -> float:
	if not pulsing:
		return 1.0
	return PULSE_BASE + PULSE_AMP * sin(time_sec * TAU / PULSE_PERIOD)


static func picture_count(journey) -> int:
	var count := 0
	for bit in journey.fragment_mask():
		if bit:
			count += 1
	return count


static func discovery_line(journey) -> String:
	var found: Array[String] = []
	if journey.mural_found:
		found.append("石窟壁画")
	if journey.beacon_found:
		found.append("烽燧驼铃")
	if journey.caravan_found:
		found.append("商队遗驼")
	if journey.stele_found:
		found.append("残碑留言")
	var line := ""
	if found.is_empty():
		line = "烽燧、驼队、残碑和石窟，可以留待下次探索。"
	else:
		line = "还发现了" + "、".join(found) + "。"
		var skipped: Array[String] = []
		if not journey.mural_found:
			skipped.append("石窟")
		if not journey.beacon_found:
			skipped.append("烽燧")
		if not journey.caravan_found:
			skipped.append("驼队")
		if not journey.stele_found:
			skipped.append("残碑")
		if not skipped.is_empty():
			line += "没走到的" + "、".join(skipped) + "，可以留待下次。"
	# 烽燧驼铃 is a discovery, but the settlement sheet has no picture for it.
	# The sentence counts only the fragment pictures that the card can show.
	var pictures := picture_count(journey)
	if pictures >= 1 and pictures < COUNT_WORDS.size():
		line += "\n妈妈说：这%s片画，就是我一路走来的样子。" % COUNT_WORDS[pictures]
	if journey.caravan_found and int(journey.water_skin) > 0:
		line += "\n水囊没喝完，留给了妈妈。"
	return line


static func _beacon(journey, maze: MazeGenerator, player: PlayerController) -> Dictionary:
	journey.beacon_found = true
	journey.bell_clue = true
	journey.silhouette_time = float(journey.SILHOUETTE_SECONDS)
	var mark: Dictionary = maze.landmarks.get(journey.FAMILY, {})
	mark["symbol"] = "妈"
	mark["kind"] = "family_silhouette"
	mark["discovered"] = false
	mark["silhouette"] = true
	maze.landmarks[journey.FAMILY] = mark
	if maze.landmarks.has(journey.BEACON):
		maze.landmarks[journey.BEACON]["lit"] = true
	grant_vision(journey, player, int(journey.BEACON_REVEAL))
	return {"body": BEACON_HINT, "kind": "hint"}


static func _caravan(journey, maze: MazeGenerator, _player: PlayerController) -> Dictionary:
	var amount := scaled_heal(int(journey.WATER_SKIN_HEAL))
	journey.caravan_found = true
	journey.water_skin = 1
	journey.fragments[2] = true
	if maze.landmarks.has(journey.CARAVAN):
		maze.landmarks[journey.CARAVAN]["searched"] = true
		maze.landmarks[journey.CARAVAN]["ghost"] = false
	return {
		"title": "商队遗驼",
		"body": "驼鞍上还挂着一只水囊，你把它系在腰间。\n需要时按 H（手机点“囊”）喝下，恢复 %d 点体力。\n旁边压着一块壁画残片，你也收好了。" % amount,
		"button": "收下水囊",
		"image": AssetRegistry.extra_item_path("water_skin"),
	}


static func _stele(journey, maze: MazeGenerator) -> Dictionary:
	journey.stele_found = true
	journey.fragments[3] = true
	if maze.landmarks.has(journey.STELE):
		maze.landmarks[journey.STELE]["read"] = true
	return {
		"title": "残碑小龛",
		"body": "碑脚有一行新刻的小字：\n“弟弟追着九色鹿的画跑远了，我进窟里找他。——哥哥”\n你收起一块壁画残片。",
		"button": "记下哥哥的字",
		"image": AssetRegistry.extra_item_path("fragment_3"),
		"image_caption": "非文物原图",
	}
