extends RefCounted
const Lore = preload("res://scripts/mogao_chapter/cave_lore_painter.gd")
## Lightweight vector scenery: no texture downloads or new engine features.
func paint(c: Control) -> void:
	var m: CaveModel = c.model
	var u: float = c.unit
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color("202a29"))
	var cave := Rect2(c.area.position + Vector2(2, 0), c.area.size - Vector2(4, 2))
	if cave.size.x > 940:
		cave.position.x += (cave.size.x - 940) / 2; cave.size.x = 940
	var stone := StyleBoxFlat.new(); stone.bg_color = Color("6a4f40")
	stone.corner_radius_top_left = int(minf(120, cave.size.x * .32)); stone.corner_radius_top_right = stone.corner_radius_top_left
	stone.corner_radius_bottom_left = 18; stone.corner_radius_bottom_right = 18
	c.draw_style_box(stone, cave)
	var inner := cave.grow(-maxf(8, u * .18))
	stone = stone.duplicate(); stone.bg_color = Color("443c32")
	stone.border_color = Color("927151"); stone.set_border_width_all(3)
	c.draw_style_box(stone, inner)
	# Uneven rock courses, recessed side niches and an arch crown break the board-like frame.
	for side in [-1, 1]:
		var edge := inner.position.x + 10 if side == -1 else inner.end.x - 10
		for i in 5:
			var y := inner.position.y + 52 + i * maxf(12, (inner.size.y - 90) / 5)
			c.draw_polyline(PackedVector2Array([Vector2(edge, y), Vector2(edge - side * 10, y + 8), Vector2(edge - side * 5, y + 21)]), Color("715a43"), 2, true)
		if cave.size.x > c.model.extent.x * u + 170:
			var niche := Rect2(Vector2(edge + 20 if side == -1 else edge - 110, inner.position.y + inner.size.y * .30), Vector2(90, inner.size.y * .38))
			var alcove := StyleBoxFlat.new(); alcove.bg_color = Color("292f29"); alcove.border_color = Color("9e7d50"); alcove.set_border_width_all(3)
			alcove.corner_radius_top_left = 45; alcove.corner_radius_top_right = 45
			c.draw_style_box(alcove, niche)
			c.draw_texture_rect(c.RABBITS if side == -1 else c.DEER, Rect2(niche.position + Vector2(12, 30), Vector2(66, 66)), false, Color("ad9569"))
			lantern(c, niche.get_center() + Vector2(0, 38), 9, .3)
	# Recessed rock ribs and an ochre/teal frieze suggest a cave, not floating islands.
	for side in [inner.position.x + 8, inner.end.x - 12]:
		c.draw_line(Vector2(side, inner.position.y + 38), Vector2(side, inner.end.y - 20), Color("806245"), 5, true)
	for i in 8:
		var x := lerpf(inner.position.x + 24, inner.end.x - 24, float(i) / 7)
		c.draw_line(Vector2(x - 5, inner.position.y + 12), Vector2(x, inner.position.y + 19), Color("c19b61"), 2, true)
		c.draw_line(Vector2(x, inner.position.y + 19), Vector2(x + 5, inner.position.y + 12), Color("8fada1"), 2, true)
	var pit := Rect2(c.point(Vector2(.5, 1.5)), Vector2((m.extent.x - 2) * u, (m.extent.y - 4) * u * .72))
	c.draw_rect(pit, Color("202b29"))
	for cell in m.land: tile(c, cell, false)
	if m.room == CaveModel.MIRROR_ROOM:
		_mirror_floor(c)
	if m.room == 1:
		for gate in m.gates(): tile(c, gate, false)
	if m.room == 2:
		# A faint silhouette explains the missing light without making the whole screen dark.
		for cell in CaveModel.LIGHT_PATH:
			if m.lit(): tile(c, cell, true)
			else:
				var p: Vector2 = c.point(cell)
				c.draw_line(p + Vector2(-u * .35, u * .25), p + Vector2(u * .35, u * .25), Color("485149"), 1, true)
	for i in m.bridges.size(): bridge(c, i)
	# Warm lamps flank the doorway and remain outside movement lanes.
	for cell in [Vector2(.4, m.extent.y - 2), Vector2(m.extent.x - 1.4, .6)]: lantern(c, c.point(cell), u * .13, .35)
	var motif: Vector2 = c.point(Vector2(1, 0)) if m.room == 0 else c.point(Vector2(1, 1))
	var tex: Texture2D = c.RABBITS if m.room < 2 else c.DEER
	if m.room == 2: motif = c.point(Vector2(1, 4))
	var motif_size := u * .9
	var plaque := StyleBoxFlat.new(); plaque.bg_color = Color("65513c"); plaque.border_color = Color("b8955f")
	plaque.set_border_width_all(2); plaque.set_corner_radius_all(int(u * .2))
	if m.room == 0:
		c.draw_style_box(plaque, Rect2(motif - Vector2(motif_size * .5, motif_size * .85), Vector2.ONE * motif_size))
		c.draw_texture_rect(tex, Rect2(motif - Vector2(motif_size * .43, motif_size * .78), Vector2.ONE * motif_size * .86), false, Color("d4ba80"))
	if m.room == 0 and not m.scarf:
		var p: Vector2 = c.point(m.goal)
		c.draw_line(p + Vector2(-u * .25, -u * .24), p + Vector2(u * .25, -u * .24), Color("ddbe85"), 4, true)
		c.draw_colored_polygon(PackedVector2Array([p + Vector2(-u * .08, -u * .32), p + Vector2(u * .22, -u * .25), p + Vector2(u * .12, u * .16), p + Vector2(-u * .02, u * .1)]), Color("72d5dc"))
	if m.room == 1: pressure(c)
	if m.room == 2: light_room(c)
	if m.room == 3:
		planks(c)
	if m.room == 4: light_bridge(c)
	if m is CaveNetwork:
		if m.room == 5: hub(c)
		for d in m.doors():
			var side_gate: bool = (m.room == 3 and d.cell == CaveModel.PLANK_WEST) or (m.room == 5 and d.cell == Vector2i(3, 0))
			if not (m.room == 3 and d.cell == m.goal) and not (side_gate and d.open):
				portal(c, c.point(d.cell), d.open)
			var p: Vector2 = c.point(d.cell) - Vector2(0, u * .94)
			if d.cell.y == int(m.extent.y) - 1: p = c.point(d.cell) + Vector2(0, u * .48)
			var label: String = d.label
			var font_size := 14 if u < 50 else 17
			var width: float = c.FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			c.draw_rect(Rect2(p - Vector2(width / 2 + 3, font_size), Vector2(width + 6, font_size + 4)), Color("202a29"))
			c.draw_string(c.FONT, p - Vector2(width / 2, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("f5dba8") if d.open else Color("b7aa91"))
		if m.room == 2: portal(c, c.point(m.exit_cell), m.rescued)
	else: portal(c, c.point(m.exit_cell), m.room != 2 or m.rescued)
	if m.room == 2 and not m.rescued: actor(c, c.point(m.goal), c.BROTHER, .85)


func paint_actors(c: Control, canvas: CanvasItem = null) -> void:
	var draw: CanvasItem = c if canvas == null else canvas
	var m: CaveModel = c.model
	var u: float = c.unit
	var player: Vector2 = c.point(m.visual_player())
	if m.room == 2 and m.rescued: actor(c, player + Vector2(-u * .35, -u * .12), c.BROTHER, .7, draw)
	actor(c, player, c.DAD, 1, draw)
	if m.scarf and not m.rescued:
		draw.draw_line(player + Vector2(u * .05, -u * .32), player + Vector2(u * .16, -u * .08), Color("72d5dc"), maxf(3, u * .07), true)
	if m.room in [2, 4] and m.lamp_held: lantern(c, player + Vector2(u * .3, -u * .22), u * .14, .7, draw)

func hub(c: Control) -> void:
	var u: float = c.unit
	var center: Vector2 = c.point(Vector2(3, 2))
	for offset in [Vector2(-1, 1), Vector2(1, 1), Vector2(0, -1)]:
		c.draw_line(center + Vector2(offset.x, offset.y * .72) * u * .7, center, Color("d2b06a"), 3, true)
	c.draw_circle(center, u * .16, Color("f2d58a") if c.model.secret else Color("90794e"))
	c.draw_texture_rect(c.RABBITS, Rect2(c.point(Vector2(3, 1)) - Vector2(u * .44, u * .62), Vector2.ONE * u * .88), false)
	c.draw_texture_rect(c.RABBITS, Rect2(c.point(Vector2(.9, 2.8)) - Vector2.ONE * u * .25, Vector2.ONE * u * .5), false, Color("e0cd9c"))
	lantern(c, c.point(Vector2(5, 2.8)), u * .13, .45)
	if c.model.secret:
		var p: Vector2 = c.point(Vector2(4, 1))
		c.draw_rect(Rect2(p - Vector2(u * .3, u * .48), Vector2(u * .6, u * .6)), Color("f0dbab"))
		for i in 4:
			var x: float = p.x + (i - 1.5) * u * .13
			c.draw_circle(Vector2(x, p.y - u * .3), u * .045, Color("647c78"))
			c.draw_line(Vector2(x, p.y - u * .24), Vector2(x, p.y - u * .1), Color("647c78"), 2, true)

func tile(c: Control, cell: Vector2, lit: bool) -> void:
	var u: float = c.unit
	var p: Vector2 = c.point(cell)
	var rect := Rect2(p - Vector2(u * .49, u * .35), Vector2(u * .98, u * .70))
	c.draw_rect(Rect2(rect.position + Vector2(0, u * .13), rect.size), Color("705439"))
	c.draw_rect(rect, Color("bd9b68") if lit else (Color("a78d68") if int(cell.x + cell.y) % 2 else Color("b49a72")))
	c.draw_line(rect.position + Vector2(3, 3), rect.position + Vector2(u - 5, 3), Color("d3ba86"), 1.5, true)
	if lit:
		for offset in [-.1, .1]:
			c.draw_circle(p + Vector2(offset * u, offset * u * .7), maxf(2, u * .065), Color("ffe3a1"))

func actor(c: Control, position: Vector2, sprite: Texture2D, scale: float, canvas: CanvasItem = null) -> void:
	var draw: CanvasItem = c if canvas == null else canvas
	var height := maxf(28, c.unit * .78) * scale
	draw.draw_set_transform(position, 0, Vector2(1, .35))
	draw.draw_circle(Vector2.ZERO, height * .3, Color(0, 0, 0, .3)); draw.draw_set_transform(Vector2.ZERO)
	draw.draw_texture_rect(sprite, Rect2(position - Vector2(height * .5, height * .85), Vector2.ONE * height), false)

func lantern(c: Control, p: Vector2, radius: float, strength: float, canvas: CanvasItem = null) -> void:
	var draw: CanvasItem = c if canvas == null else canvas
	for i in range(4, 0, -1): draw.draw_circle(p, radius * i * 1.8, Color(1, .67, .27, strength * .035))
	draw.draw_line(p + Vector2(0, radius), p + Vector2(0, radius * 1.8), Color("735338"), 3, true)
	draw.draw_style_box(lamp_style(), Rect2(p - Vector2.ONE * radius, Vector2.ONE * radius * 2))
	draw.draw_arc(p - Vector2(0, radius), radius * .7, PI, TAU, 12, Color("d6b276"), 2, true)
	draw.draw_line(p - Vector2(0, radius), p + Vector2(0, radius), Color("ffeab3"), 2, true)

func lamp_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new(); style.bg_color = Color("e7b665"); style.border_color = Color("966c39")
	style.set_border_width_all(2); style.set_corner_radius_all(4)
	return style

func portal(c: Control, p: Vector2, open: bool, canvas: CanvasItem = null) -> void:
	var draw: CanvasItem = c if canvas == null else canvas
	var u: float = c.unit
	# The first scarf must remain readable; its exit is shown only after collection.
	if c.model.room == 0 and not c.model.reached: return
	var rect := Rect2(p - Vector2(u * .38, u * .85), Vector2(u * .76, u))
	var style := StyleBoxFlat.new(); style.bg_color = Color("acb5a0") if open else Color("35443e")
	style.corner_radius_top_left = int(u * .38); style.corner_radius_top_right = int(u * .38)
	style.border_color = Color("d1b78b"); style.set_border_width_all(3)
	draw.draw_style_box(style, rect)
	if open: draw.draw_line(p + Vector2(0, -u * .5), p + Vector2(0, -u * .14), Color("fff0c2"), 4, true)
	else: draw.draw_line(p + Vector2(-u * .31, -u * .35), p + Vector2(u * .31, -u * .35), Color("b58b55"), maxf(4, u * .1), true)

func bridge(c: Control, index: int) -> void:
	var b: Dictionary = c.model.bridges[index]
	var center: Vector2 = c.point(b.pivot)
	var u: float = c.unit
	c.draw_circle(center + Vector2(0, u * .15), u * .35, Color("5d4a37"))
	c.draw_circle(center, u * .3, Color("997d51"))
	var corners := [Vector2(-1.49, -.32), Vector2(1.49, -.32), Vector2(1.49, .32), Vector2(-1.49, .32)]
	var polygon := PackedVector2Array()
	for v in corners:
		var r: Vector2 = v.rotated(c.model.angle(index)); polygon.append(center + Vector2(r.x, r.y * .72) * u)
	c.draw_colored_polygon(polygon, Color("ceac78") if c.model.room != 4 or c.model.lit() else Color("555b4f"))
	for n in range(-7, 8):
		var a := Vector2(n * .19, -.30).rotated(c.model.angle(index)); var z := Vector2(n * .19, .30).rotated(c.model.angle(index))
		c.draw_line(center + Vector2(a.x, a.y * .72) * u, center + Vector2(z.x, z.y * .72) * u, Color("96723e"), 2, true)

func pressure(c: Control) -> void:
	Lore.shared_ears(c)
	crate(c)

func crate(c: Control) -> void:
	var u: float = c.unit
	var b: Vector2 = c.point(c.model.visual_box())
	var rect := Rect2(b - Vector2(u * .35, u * .56), Vector2(u * .70, u * .68))
	c.draw_rect(rect, Color("90663c")); c.draw_rect(rect.grow(-2), Color("c19b60"), false, 2)
	c.draw_line(rect.position + Vector2(3, 3), rect.end - Vector2(3, 3), Color("735330"), 3, true)
	c.draw_line(Vector2(rect.end.x - 3, rect.position.y + 3), Vector2(rect.position.x + 3, rect.end.y - 3), Color("735330"), 3, true)

func planks(c: Control) -> void:
	var u: float = c.unit
	var niche: Vector2 = c.point(CaveModel.PLANK_NICHE)
	c.draw_circle(niche + Vector2(-u * .12, u * .08), maxf(2.0, u * .07), Color("6a5340"))
	c.draw_circle(niche + Vector2(u * .12, u * .12), maxf(1.5, u * .045), Color("6a5340"))

func light_bridge(c: Control) -> void:
	var m: CaveModel = c.model; var u: float = c.unit
	var p: Vector2 = c.point(CaveModel.STANDS[0])
	c.draw_circle(p, u * .3, Color("756747")); c.draw_arc(p, u * .27, 0, TAU, 24, Color("e0c58e"), 2, true)
	if not m.lamp_held: lantern(c, c.point(m.lamp) - Vector2(0, u * .2), u * .16, .8)
	if m.lit():
		c.draw_colored_polygon(PackedVector2Array([p, c.point(Vector2(2.4, 1.3)), c.point(Vector2(3.6, 1.3))]), Color(1, .83, .48, .12))
		for y in [2, 3, 4]:
			var a: Vector2 = c.point(Vector2(3, y))
			c.draw_polyline(PackedVector2Array([a + Vector2(-u * .12, .05 * u), a + Vector2(0, -.1 * u), a + Vector2(u * .12, .05 * u)]), Color("ffe3a1"), 3, true)

func light_room(c: Control) -> void:
	var m: CaveModel = c.model; var u: float = c.unit
	Lore.river(c)
	for i in 2:
		var p: Vector2 = c.point(CaveModel.STANDS[i])
		c.draw_circle(p, u * .31, Color("766449")); c.draw_arc(p, u * .27, 0, TAU, 24, Color("d0b77f"), 2, true)
		if i == 0:
			c.draw_polyline(PackedVector2Array([p + Vector2(-u * .18, u * .13), p - Vector2(0, u * .17), p + Vector2(u * .18, u * .13)]), Color("dfc48c"), 2, true)
		else:
			for dy in [-.08, .08]: c.draw_polyline(PackedVector2Array([p + Vector2(-u * .18, dy * u), p + Vector2(0, (dy + .07) * u), p + Vector2(u * .18, dy * u)]), Color("9dd2c7"), 2, true)
	if not m.lamp_held: lantern(c, c.point(m.lamp) - Vector2(0, u * .2), u * .16, .8)
	if m.lit():
		var p: Vector2 = c.point(CaveModel.STANDS[1])
		c.draw_colored_polygon(PackedVector2Array([p, c.point(Vector2(1.8, 1.3)), c.point(Vector2(5.6, 1.3))]), Color(1, .8, .4, .10 * c.light_visual))

func _mirror_floor(c: Control) -> void:
	var m: CaveModel = c.model
	var u: float = c.unit
	for mirror in CaveModel.MIRROR_DEFS:
		tile(c, mirror["cell"], false)
	tile(c, CaveModel.MIRROR_LAMP, false)
	tile(c, CaveModel.MIRROR_LOTUS, false)
	for cell in CaveModel.MIRROR_LIT_PATH:
		if m.lotus_lit():
			tile(c, cell, true)
		else:
			var p: Vector2 = c.point(cell)
			c.draw_line(p + Vector2(-u * .35, u * .25), p + Vector2(u * .35, u * .25), Color("485149"), 1, true)
	lantern(c, c.point(CaveModel.MIRROR_LAMP) + Vector2(0, -u * 0.15), u * 0.14, 0.55)


