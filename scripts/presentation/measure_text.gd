extends RefCounted
## One layout pass for cards, popups, and logs.
## A number stays with the measure word after it, and closing punctuation stays off the next line.

const WORD_JOINER := "\u2060"
const NO_BREAK_SPACE := "\u00A0"
const UNITS: PackedStringArray = ["点体力", "伤害", "个人", "回合", "视野", "HP", "点", "片", "格", "步", "分", "秒", "下", "%"]
const LINE_START_MARKS := "。，、！？；：」』）〉》】〕〗｡､"


static func format_duration(seconds: float) -> String:
	var total := maxi(0, int(floor(seconds)))
	return "用时 %d 分 %d 秒" % [total / 60, total % 60]


static func bind_units(text: String) -> String:
	var source := text.replace(WORD_JOINER, "").replace(NO_BREAK_SPACE, " ")
	var out := ""
	var i := 0
	var count := source.length()
	while i < count:
		var code := source.unicode_at(i)
		if code < 0x30 or code > 0x39:
			out += source.substr(i, 1)
			i += 1
			continue
		var start := i
		i += 1
		while i < count and source.unicode_at(i) >= 0x30 and source.unicode_at(i) <= 0x39:
			i += 1
		var number := source.substr(start, i - start)
		var gap := i
		while gap < count and source.unicode_at(gap) == 0x20:
			gap += 1
		var unit := _unit_at(source, gap)
		if unit == "":
			out += number
			if i < count and source.unicode_at(i) != 0x0A:
				out += WORD_JOINER
			continue
		out += _glue(number + NO_BREAK_SPACE + unit)
		i = gap + unit.length()
	return out


static func layout_text(text: String, width: float, font: Font, font_size: int) -> String:
	var paragraphs := text.replace(WORD_JOINER, "").replace(NO_BREAK_SPACE, " ").split("\n", true)
	var lines: PackedStringArray = PackedStringArray()
	for para in paragraphs:
		if para.is_empty():
			lines.append("")
			continue
		var wrapped := _wrap_paragraph(bind_units(para), width, font, font_size)
		for line in wrapped.split("\n", false):
			lines.append(line)
	return "\n".join(lines)


static func wrapped_text(text: String, width: float, font: Font, font_size: int) -> String:
	return layout_text(text, width, font, font_size)


static func _wrap_paragraph(bound: String, width: float, font: Font, font_size: int) -> String:
	var atoms := _atoms(bound)
	if atoms.is_empty():
		return ""
	if width < 8.0 or font == null:
		return "".join(atoms)
	var lines: PackedStringArray = PackedStringArray()
	var current := ""
	var current_w := 0.0
	for atom in atoms:
		if atom == " ":
			if current.is_empty():
				continue
			var spaced := current_w + _width(" ", font, font_size)
			if spaced <= width + 0.01:
				current += " "
				current_w = spaced
			continue
		var aw := _width(atom, font, font_size)
		if current.is_empty() or current_w + aw <= width + 0.01:
			current += atom
			current_w += aw
			continue
		lines.append(current)
		current = atom
		current_w = aw
	if not current.is_empty():
		lines.append(current)
	return "\n".join(lines)


static func _atoms(bound: String) -> PackedStringArray:
	var atoms: PackedStringArray = PackedStringArray()
	var i := 0
	var count := bound.length()
	while i < count:
		var ch := bound.substr(i, 1)
		if ch == " ":
			atoms.append(" ")
			i += 1
			continue
		var atom := ch
		i += 1
		while i < count:
			if bound.unicode_at(i) == 0x2060:
				i += 1
				if i >= count:
					break
				atom += bound.substr(i, 1)
				i += 1
				continue
			var nxt := bound.substr(i, 1)
			if LINE_START_MARKS.contains(nxt):
				atom += nxt
				i += 1
				continue
			break
		atoms.append(atom.replace(WORD_JOINER, ""))
	return atoms


static func _glue(text: String) -> String:
	var out := ""
	for i in text.length():
		if i > 0:
			out += WORD_JOINER
		out += text.substr(i, 1)
	return out


static func _width(text: String, font: Font, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


static func _unit_at(text: String, index: int) -> String:
	for unit in UNITS:
		if text.substr(index, unit.length()) == unit:
			return unit
	return ""
