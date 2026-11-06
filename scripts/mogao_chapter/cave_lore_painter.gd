extends RefCounted
## Scene-bound original vector interpretations, not reproductions of historic murals.
static func shared_ears(c: Control) -> void:
	var m: CaveModel = c.model; var u: float = c.unit
	var gold := Color("ffdf91")
	var dim := Color("88765a")
	# The same center plate visibly branches to BOTH doors. Side plates each have a real use.
	for i in 3:
		var p: Vector2 = c.point(CaveModel.PLATES[i])
		var on := m.plate_active(i)
		var targets := [0, 1] if i == 1 else ([0] if i == 0 else [1])
		for g in targets:
			var gate: Vector2 = c.point(CaveModel.GATES[g])
			var rail := 2.35 if g == 0 else 3.65
			c.draw_polyline(PackedVector2Array([p, c.point(Vector2(rail, 2.7)), c.point(Vector2(rail, CaveModel.GATES[g].y)), gate]), gold if on else dim, 3 if on else 2, true)
		c.draw_set_transform(p, 0, Vector2(1, .65))
		c.draw_circle(Vector2.ZERO, u * .35, Color("728b71") if on else Color("756747"))
		c.draw_arc(Vector2.ZERO, u * .30, 0, TAU, 28, gold if on else Color("d4b881"), 2, true)
		# An ear-shaped inset ties the weight plate to the artwork, without colour-only clues.
		c.draw_polyline(PackedVector2Array([Vector2(-u * .1, u * .17), Vector2(-u * .12, -u * .10), Vector2(0, -u * .21), Vector2(u * .12, -u * .10), Vector2(u * .1, u * .17)]), gold if on else Color("b69c71"), 2, true)
		c.draw_set_transform(Vector2.ZERO)
	for i in 2:
		var g: Vector2 = c.point(CaveModel.GATES[i])
		for dx in [-.46, .46]: c.draw_line(g + Vector2(dx * u, u * .24), g + Vector2(dx * u, -u * .5), Color("715235"), maxf(4, u * .10), true)
		if c.gate_visual[i] < .99:
			var h: float = u * .65 * (1 - c.gate_visual[i])
			c.draw_rect(Rect2(g + Vector2(-u * .36, -u * .42), Vector2(u * .72, h)), Color("84613c"))
			for dx in [-.2, 0, .2]: c.draw_line(g + Vector2(dx * u, -u * .42), g + Vector2(dx * u, -u * .42 + h), Color("d4af6e"), 2, true)
	var art := Rect2(c.point(Vector2(.8, 1.1)) - Vector2.ONE * u * .72, Vector2.ONE * u * 1.44)
	c.draw_texture_rect(c.RABBITS, art, false)
	if m.plate_active(1):
		# Match the actual shared-ear endpoints in the existing 320x320 source SVG.
		var ears := PackedVector2Array()
		for v in [Vector2(160, 117), Vector2(197, 181), Vector2(123, 181), Vector2(160, 117)]: ears.append(art.position + v / 320 * art.size)
		c.draw_polyline(ears, gold, maxf(2, u * .05), true)
		c.draw_arc(art.get_center(), art.size.x * .48, 0, TAU, 48, gold, 2, true)

static func river(c: Control) -> void:
	var m: CaveModel = c.model; var u: float = c.unit
	var rect := Rect2(c.point(Vector2(.6, 1.8)), Vector2(5.8 * u, 1.65 * u))
	var t := maxf(0, m.deer_time)
	var fade := 1.0 - clampf((t - CaveModel.DEER_SECONDS) / .8, 0, 1)
	# After the rescue the mural recedes, leaving the real path and a small deer at its source.
	if fade <= 0:
		deer(c, c.point(Vector2(1.2, 3.4)), u * .8, 1.0)
		return
	var brightness := 1.0 if m.deer_seen else .78
	var back := Color("9b7152"); back.a = fade
	c.draw_rect(rect.grow(3), Color(.73, .56, .34, fade))
	c.draw_rect(rect, back)
	var w := rect.size.x; var h := rect.size.y; var p := rect.position
	c.draw_rect(Rect2(p + Vector2(w * .25, h * .12), Vector2(w * .52, h * .83)), Color(.24, .47, .48, fade * brightness))
	for row in 4:
		var wave := PackedVector2Array()
		for n in 13: wave.append(p + Vector2(w * (.26 + n * .041), h * (.28 + row * .17) + sin(n * .9) * h * .025))
		c.draw_polyline(wave, Color(.65, .78, .68, .6 * fade), 1.5, true)
	# Mountain/river signs on the two lamp stands correspond to the two depicted banks.
	c.draw_colored_polygon(PackedVector2Array([p + Vector2(w * .02, h * .5), p + Vector2(w * .11, h * .08), p + Vector2(w * .23, h * .5)]), Color(.30, .38, .31, fade))
	if m.bank_lit():
		c.draw_colored_polygon(PackedVector2Array([c.point(CaveModel.STANDS[1]), p + Vector2(w * .77, 0), p + Vector2(w, 0)]), Color(1, .84, .43, fade * .18))
		c.draw_rect(Rect2(p + Vector2(w * .78, 0), Vector2(w * .22, h)), Color(1, .8, .4, fade * .2))
	var x := .14
	if m.deer_time >= 0:
		if t < 1.1: x = lerpf(.14, .48, smoothstep(0, 1.1, t))
		elif t < 1.6: x = .48
		else: x = lerpf(.48, .87, smoothstep(1.6, CaveModel.DEER_SECONDS, t))
	var animal := p + Vector2(w * x, h * .64)
	var animal_size := minf(u * 1.15, w * .21)
	deer(c, animal, animal_size, fade * brightness)
	var aboard := m.deer_time >= 1.1
	var safe := m.deer_time >= CaveModel.DEER_SECONDS
	var person := p + Vector2(w * .50, h * .65)
	if aboard: person = animal + Vector2(-animal_size * .06, -animal_size * .40)
	if safe: person = p + Vector2(w * .94, h * .63)
	human(c, person, maxf(6, u * .22), fade, not aboard)
	# Light dots leave the painting and reach the first real stepping stone.
	if t > 2.7:
		var start := p + Vector2(w * .86, h * .68)
		var end: Vector2 = c.point(CaveModel.LIGHT_PATH[0])
		for i in 5:
			if t > 2.7 + i * .14: c.draw_circle(start.lerp(end, float(i + 1) / 5), maxf(2, u * .045), Color(1, .88, .54, fade))

static func human(c: Control, p: Vector2, scale: float, alpha: float, calling: bool) -> void:
	var ink := Color(.97, .85, .60, alpha)
	c.draw_circle(p - Vector2(0, scale), scale * .3, ink)
	c.draw_line(p - Vector2(0, scale * .6), p + Vector2(0, scale * .5), ink, 2, true)
	var arm := -scale * .8 if calling else 0.0
	c.draw_polyline(PackedVector2Array([p + Vector2(-scale * .6, arm), p, p + Vector2(scale * .6, -scale * .6)]), ink, 2, true)

static func deer(c: Control, p: Vector2, scale: float, alpha: float) -> void:
	c.draw_set_transform(p, 0, Vector2.ONE * scale)
	var body := PackedVector2Array([Vector2(-.46, -.12), Vector2(-.28, -.30), Vector2(.17, -.29), Vector2(.31, -.63), Vector2(.53, -.60), Vector2(.44, -.43), Vector2(.32, -.05), Vector2(.20, .02), Vector2(.16, .37), Vector2(.07, .37), Vector2(.08, .02), Vector2(-.22, -.02), Vector2(-.31, .37), Vector2(-.40, .37), Vector2(-.35, -.05)])
	c.draw_colored_polygon(body, Color(.89, .68, .36, alpha))
	c.draw_polyline(PackedVector2Array([Vector2(.34, -.61), Vector2(.27, -.87), Vector2(.20, -.91)]), Color(.42, .29, .17, alpha), .025, true)
	c.draw_polyline(PackedVector2Array([Vector2(.40, -.61), Vector2(.51, -.86), Vector2(.59, -.88)]), Color(.42, .29, .17, alpha), .025, true)
	c.draw_circle(Vector2(.45, -.54), .022, Color(.15, .19, .17, alpha))
	var colors := [Color("eee0bd"), Color("88b8a4"), Color("c4816c"), Color("deb75d"), Color("8aafb8"), Color("b797b5"), Color("eee0bd"), Color("88b8a4"), Color("c4816c")]
	for i in 9:
		var color: Color = colors[i]; color.a = alpha
		c.draw_circle(Vector2(-.25 + (i % 3) * .13, -.23 + (i / 3) * .075), .035, color)
	c.draw_set_transform(Vector2.ZERO)
