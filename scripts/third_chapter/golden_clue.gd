class_name GoldenClue
extends Node3D
## A broad viewpoint interaction, not a precision aim test. No dynamic lights or timers.
const MARKER := Vector3(22.8, 1.4, 18.5)
# Keep the forgiving observation anchor, but set the decorative rock back into the alcove.
# Standing it beside the note filled the entire portrait camera with a pair of giant rocks.
const RELIEF_POSITION := Vector3(22.8, 1.4, 14.1)
var found := false
var glow: MeshInstance3D
var marks: Node3D
var trail: MultiMeshInstance3D
var reveal_progress := 0.0

func build(map: ThirdMap) -> void:
	var gold := StandardMaterial3D.new()
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.cull_mode = BaseMaterial3D.CULL_DISABLED
	gold.albedo_color = Color("e9bd61")
	# Grounded sandstone relief, not a floating postcard; like the original prop, render-only.
	# Keep the illustrated travel note in HTML; here the clue belongs to the landscape.
	var stone := StandardMaterial3D.new()
	stone.vertex_color_use_as_albedo = true
	stone.cull_mode = BaseMaterial3D.CULL_DISABLED
	stone.roughness = 1.0
	_relief([Vector2(-1.12, -1.34), Vector2(-0.13, -1.34), Vector2(0.02, -0.35), Vector2(-0.09, 0.5), Vector2(0.1, 1.55), Vector2(-0.81, 1.28), Vector2(-1.22, 0.3)], stone, Color("b78962"))
	_relief([Vector2(-0.03, -1.34), Vector2(1.12, -1.34), Vector2(1.31, 0.38), Vector2(0.88, 1.65), Vector2(0.2, 1.55), Vector2(0.01, 0.5), Vector2(0.12, -0.35)], stone, Color("cba477"))
	# A tapered seam, not a luminous rectangular sign. The broad interaction cone is unchanged.
	var seam := SurfaceTool.new()
	seam.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels: Array[Vector2] = [Vector2(-0.08, -1.32), Vector2(0.07, -0.35), Vector2(-0.04, 0.5), Vector2(0.15, 1.55)]
	for i in 3:
		var a := Vector3(levels[i].x - 0.025, levels[i].y * 0.75 - 0.335, 0.29)
		var b := Vector3(levels[i].x + 0.025, levels[i].y * 0.75 - 0.335, 0.29)
		var c := Vector3(levels[i + 1].x + 0.025, levels[i + 1].y * 0.75 - 0.335, 0.29)
		var d := Vector3(levels[i + 1].x - 0.025, levels[i + 1].y * 0.75 - 0.335, 0.29)
		_triangle(seam, a, b, c, Color.WHITE)
		_triangle(seam, a, c, d, Color.WHITE)
	glow = MeshInstance3D.new()
	glow.mesh = seam.commit()
	glow.material_override = gold
	glow.position = RELIEF_POSITION
	add_child(glow)
	var pool := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.3, 5.5)
	pool.mesh = plane
	pool.position = Vector3(MARKER.x, 0.08, 17.2)
	var pool_material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; render_mode unshaded, blend_add, depth_draw_never; void fragment(){ vec2 p=(UV-vec2(0.5))*2.0; float light=pow(max(0.0,1.0-dot(p,p)),2.0); ALBEDO=vec3(0.7,0.39,0.10); ALPHA=light*0.32; }"
	pool_material.shader = shader
	pool.material_override = pool_material
	add_child(pool)
	marks = Node3D.new()
	add_child(marks)
	for i in 4:
		var mark := MeshInstance3D.new()
		mark.mesh = _footprint()
		mark.material_override = gold
		mark.position = RELIEF_POSITION + Vector3(-0.37 + (i % 2) * 0.16, -0.8 + i * 0.29, 0.56)
		mark.rotation = Vector3(PI / 2, 0, -0.3)
		mark.scale = Vector3.ONE * 0.55
		marks.add_child(mark)
	marks.visible = false
	# One batched mesh for the whole local trail. It stays below the player's feet.
	trail = MultiMeshInstance3D.new()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	var footprint := _footprint()
	footprint.surface_set_material(0, gold)
	batch.mesh = footprint
	var points := map.clue_path()
	batch.instance_count = maxi(0, (points.size() - 1) * 4)
	var index := 0
	for i in range(1, points.size()):
		var start := ThirdMap.world(points[i - 1])
		var end := ThirdMap.world(points[i])
		var direction := (end - start).normalized()
		var sideways := Vector3(-direction.z, 0, direction.x)
		var basis := Basis(Vector3.UP, atan2(direction.x, direction.z))
		for j in 4:
			var p := start.lerp(end, (j + 0.5) / 4.0) + sideways * (0.18 if j % 2 == 0 else -0.18)
			p.y = 0.09
			batch.set_instance_transform(index, Transform3D(basis, p))
			index += 1
	trail.multimesh = batch
	trail.visible = false
	add_child(trail)

func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for vertex in [a, c, b]:
		tool.set_normal(normal)
		tool.set_color(color)
		tool.add_vertex(vertex)

func _relief(outline: Array[Vector2], material: Material, color: Color) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(-0.5 if outline[0].x < -0.5 else 0.6, 0, 0.55)
	for i in outline.size():
		var a := Vector3(outline[i].x, outline[i].y, 0.34)
		var next := outline[(i + 1) % outline.size()]
		var b := Vector3(next.x, next.y, 0.34)
		_triangle(tool, a, b, center, color.lightened(0.025 * (i % 3)))
		_triangle(tool, a, a - Vector3(0, 0, 0.4), b, color.darkened(0.18))
		_triangle(tool, b, a - Vector3(0, 0, 0.4), b - Vector3(0, 0, 0.4), color.darkened(0.18))
	var instance := MeshInstance3D.new()
	instance.mesh = tool.commit()
	instance.material_override = material
	instance.position = RELIEF_POSITION
	instance.position.y -= 0.335
	instance.scale.y = 0.75
	add_child(instance)

func _footprint() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var a := i * TAU / 8
		var b := (i + 1) * TAU / 8
		_triangle(tool, Vector3.ZERO, Vector3(cos(a) * 0.075, 0, sin(a) * 0.17), Vector3(cos(b) * 0.075, 0, sin(b) * 0.17), Color.WHITE)
	return tool.commit()

static func in_view(viewer: Vector3, forward: Vector3) -> bool:
	var offset := MARKER - viewer
	# A metre-wide left-side approach and ~83-degree cone are forgiving on touch.
	return viewer.x <= 23.6 and viewer.z >= 20.5 and offset.length() <= 6.0 and forward.dot(offset.normalized()) >= 0.75

func reveal() -> bool:
	if found: return false
	found = true
	trail.visible = true
	trail.multimesh.visible_instance_count = 4
	marks.visible = true
	return true

func advance(dt: float) -> void:
	# Called only by the active simulation: pauses, focus loss and ending freeze the reveal.
	if not found or reveal_progress >= 1.0: return
	reveal_progress = minf(1.0, reveal_progress + dt / 0.9)
	trail.multimesh.visible_instance_count = maxi(4, ceili(trail.multimesh.instance_count * reveal_progress))

func set_observable(value: bool) -> void:
	glow.visible = true
	glow.scale.x = 1.15 if value or found else 1.0
