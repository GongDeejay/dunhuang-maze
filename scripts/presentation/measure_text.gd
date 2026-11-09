extends RefCounted
## Keeps a number and the unit after it on one line, and formats level time.

const WORD_JOINER := "\u2060"
const NO_BREAK_SPACE := "\u00A0"
const UNITS: PackedStringArray = ["点体力", "伤害", "个人", "回合", "视野", "HP", "点", "步", "分", "秒", "下", "%"]


static func format_duration(seconds: float) -> String:
	var total := maxi(0, int(floor(seconds)))
	return "用时 %d 分 %d 秒" % [total / 60, total % 60]


static func bind_units(text: String) -> String:
	var out := ""
	var i := 0
	var count := text.length()
	while i < count:
		var code := text.unicode_at(i)
		if code < 0x30 or code > 0x39:
			out += text.substr(i, 1)
			i += 1
			continue
		var start := i
		i += 1
		while i < count and text.unicode_at(i) >= 0x30 and text.unicode_at(i) <= 0x39:
			i += 1
		var number := text.substr(start, i - start)
		var gap := i
		while gap < count and text.unicode_at(gap) == 0x20:
			gap += 1
		var unit := _unit_at(text, gap)
		if unit == "":
			out += number
			if i < count and text.unicode_at(i) != 0x0A:
				out += WORD_JOINER
			continue
		# Glue every character, including the visible space, so a label cannot
		# break "4" from "点体力" or split the unit itself.
		out += _glue(number + NO_BREAK_SPACE + unit)
		i = gap + unit.length()
	return out


static func _glue(text: String) -> String:
	var out := ""
	for i in text.length():
		if i > 0:
			out += WORD_JOINER
		out += text.substr(i, 1)
	return out


static func wrapped_text(text: String, width: float, font: Font, font_size: int) -> String:
	var paragraph := TextParagraph.new()
	paragraph.break_flags = TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_MANDATORY
	paragraph.direction = TextServer.DIRECTION_LTR
	paragraph.add_string(text, font, font_size)
	paragraph.width = width
	var lines: PackedStringArray = PackedStringArray()
	for line in paragraph.get_line_count():
		var span: Vector2i = paragraph.get_line_range(line)
		lines.append(text.substr(span.x, span.y - span.x))
	return "\n".join(lines)


static func _unit_at(text: String, index: int) -> String:
	for unit in UNITS:
		if text.substr(index, unit.length()) == unit:
			return unit
	return ""
