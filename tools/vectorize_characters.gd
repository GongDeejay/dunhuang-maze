extends SceneTree
## godot --headless --path . --script tools/vectorize_characters.gd [-- --check]
## Lossless pixel-to-vector conversion; original PNGs are the design authority.

const NAMES := ["dj", "le", "mac", "mcking"]
const SOURCE_DIR := "res://assets/sprites/player/"
const OUTPUT_DIR := "res://assets/high_quality/player/"
const OUTPUT_SIZE := 256

func _init() -> void:
	var check_only := "--check" in OS.get_cmdline_user_args()
	for name in NAMES:
		var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_DIR + name + ".png"))
		if source == null:
			_fail("Missing source: " + name)
			return
		source.convert(Image.FORMAT_RGBA8)
		var svg := _vectorize(source)
		var path: String = OUTPUT_DIR + name + ".svg"
		if check_only:
			if FileAccess.get_file_as_string(path) != svg:
				_fail("Vector differs from original: " + name)
				return
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				_fail("Cannot write: " + path)
				return
			file.store_string(svg)
			file.close()
		# Verify SVG rendering, including transparency, against nearest-neighbor PNG.
		var rendered := Image.new()
		if rendered.load_svg_from_string(svg) != OK:
			_fail("Cannot render SVG: " + name)
			return
		source.resize(OUTPUT_SIZE, OUTPUT_SIZE, Image.INTERPOLATE_NEAREST)
		for y in OUTPUT_SIZE:
			for x in OUTPUT_SIZE:
				var expected := source.get_pixel(x, y)
				var actual := rendered.get_pixel(x, y)
				# SVG rasterization rounds premultiplied RGB for translucent pixels.
				# Compare visible color, allowing at most one 8-bit rounding step.
				var error := Vector3(expected.r, expected.g, expected.b) * expected.a - Vector3(actual.r, actual.g, actual.b) * actual.a
				if expected.a != actual.a or maxf(maxf(absf(error.x), absf(error.y)), absf(error.z)) > 1.01 / 255.0:
					_fail("Pixel mismatch: %s at %d,%d: %s vs %s" % [name, x, y, expected.to_html(true), actual.to_html(true)])
					return
		print("%s: %dx%d verified; exact alpha/geometry, visible RGB within 1/255 raster rounding" % [name, OUTPUT_SIZE, OUTPUT_SIZE])
	quit(0)

func _vectorize(source: Image) -> String:
	var paths := {}
	for y in source.get_height():
		var x := 0
		while x < source.get_width():
			var color := source.get_pixel(x, y)
			var end := x + 1
			while end < source.get_width() and source.get_pixel(end, y) == color:
				end += 1
			if color.a > 0.0:
				var key := color.to_html(true)
				paths[key] = paths.get(key, "") + "M%d %dh%dv1h%dZ" % [x, y, end - x, x - end]
			x = end
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" shape-rendering="crispEdges">\n' % [OUTPUT_SIZE, OUTPUT_SIZE, source.get_width(), source.get_height()]
	svg += '  <!-- Lossless vector of assets/sprites/player; preserve pixel geometry and palette. -->\n'
	for key in paths:
		var color := Color.html(key)
		var opacity := ' fill-opacity="%.9f"' % color.a if color.a < 1.0 else ""
		svg += '  <path fill="#%s"%s d="%s"/>\n' % [color.to_html(false), opacity, paths[key]]
	return svg + '</svg>\n'

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
