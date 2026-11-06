class_name HomewardScenery
extends ValleyScenery
## Render-only dressing for the cave and the existing return path. No collision or navigation.
const BEACON := Vector3(56, 8.8, 56)
var return_markers: MeshInstance3D
var marker_positions: Array[Vector3] = []
var light_material: ShaderMaterial
var beacon_material: StandardMaterial3D
var prop_materials: Dictionary = {}

static func cave_weight(pos: Vector3) -> float:
	return smoothstep(40.0, 47.0, pos.x) * (1.0 - smoothstep(14.0, 20.0, pos.z))

func build() -> void:
	# The portal follows the real west-to-east approach. Its sides stay beyond the floor boundary.
	# The arch it replaces faced south and put visual posts across the approach.
	var stone := Color("77716c")
	for z in [1.5, 18.5]:
		rock(_builder(Vector3(45, 0, z)), Vector3(45, 0, z), Vector3(1.15, 4.9, 0.7), stone)
	var roof := _builder(Vector3(45, 4, 10))
	_quad(roof, Vector3(43.7, 4.8, 1.5), Vector3(43.7, 4.8, 18.5), Vector3(45.5, 3.8, 17), Vector3(45.5, 3.8, 3), stone)
	_quad(roof, Vector3(45.5, 3.8, 3), Vector3(45.5, 3.8, 17), Vector3(58.5, 4.5, 17), Vector3(58.5, 4.5, 3), stone.darkened(0.17))
	# Small signs of waiting, tucked beside the child rather than scattered on the walking line.
	_box(Vector3(53.1, 0.045, 8), Vector3(1.5, 0.025, 1.2), Color("887261"))
	_box(Vector3(53.55, 0.24, 7.65), Vector3(0.35, 0.46, 0.24), Color("63766f"))
	_box(Vector3(53.55, 0.5, 7.65), Vector3(0.18, 0.08, 0.18), Color("aa946f"))
	_box(Vector3(50.9, 0.22, 7.7), Vector3(0.28, 0.42, 0.28), Color("c39455"), true)
	_light_pool(Vector3(52, 0.075, 8), Vector2(4, 3.4))
	# Amber tower windows read from any approach; no real-time lights or shadows are added.
	for side in [-1, 1]:
		_box(BEACON + Vector3(side * 1.51, 0, 0), Vector3(0.025, 1.1, 0.8), Color("f3cc76"), true)
		_box(BEACON + Vector3(0, 0, side * 1.51), Vector3(0.8, 1.1, 0.025), Color("f3cc76"), true)
	# A small open awning frames the family without replacing or covering their original art.
	var cloth := _builder(Vector3(56, 3.5, 54))
	_quad(cloth, Vector3(51.3, 3.1, 50.8), Vector3(56, 3.9, 51.2), Vector3(56, 3.9, 55), Vector3(51.3, 3.1, 55), Color("a66b4e"))
	_quad(cloth, Vector3(56, 3.9, 51.2), Vector3(60.7, 3.1, 50.8), Vector3(60.7, 3.1, 55), Vector3(56, 3.9, 55), Color("b6835b"))
	for x in [51.3, 60.7]:
		_box(Vector3(x, 1.55, 55), Vector3(0.1, 3.1, 0.1), Color("78624b"))
		_box(Vector3(x, 1.2, 51.5), Vector3(0.3, 0.45, 0.3), Color("eac079"), true)
	_box(Vector3(60, 0.25, 54.5), Vector3(1.6, 0.5, 0.45), Color("9b7757"))
	_light_pool(Vector3(56, 0.08, 52), Vector2(9, 6))
	_build_return_markers()
	finish()

func _box(pos: Vector3, size: Vector3, color: Color, luminous: bool = false) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	triangle_count += 12
	instance.position = pos
	var key := color.to_html() + str(luminous)
	if not prop_materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 1.0
		if luminous: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		prop_materials[key] = mat
	instance.material_override = prop_materials[key]
	add_child(instance)

func _light_pool(pos: Vector3, size: Vector2) -> void:
	if light_material == null:
		light_material = ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = "shader_type spatial; render_mode unshaded, blend_add, depth_draw_never; void fragment(){ vec2 p=(UV-vec2(0.5))*2.0; float a=pow(max(0.0,1.0-dot(p,p)),2.0); ALBEDO=vec3(0.8,0.39,0.08); ALPHA=a*0.22; }"
		light_material.shader = shader
	var pool := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	pool.mesh = plane
	triangle_count += 2
	pool.material_override = light_material
	pool.position = pos
	add_child(pool)

func _build_return_markers() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	marker_positions = [Vector3(53.35, 1.6, 20), Vector3(53.35, 1.6, 28), Vector3(53.35, 1.6, 36), Vector3(53.35, 1.6, 43), Vector3(56, 1.6, 47)]
	for p in marker_positions:
		# A hanging, notched ribbon is recognisable by silhouette as well as colour.
		_quad(tool, p + Vector3(-0.035, -1.6, 0.03), p + Vector3(0.035, -1.6, 0.03), p + Vector3(0.035, 0.13, 0.03), p + Vector3(-0.035, 0.13, 0.03), Color("826b53"))
		var a := p + Vector3(-0.14, 0, 0)
		var b := p + Vector3(0.26, 0, 0)
		var c := p + Vector3(0.26, -0.7, 0)
		var d := p + Vector3(0.06, -0.53, 0)
		var e := p + Vector3(-0.14, -0.7, 0)
		_tri(tool, a, b, d, Color("ebc17b"))
		_tri(tool, b, c, d, Color("ebc17b"))
		_tri(tool, a, d, e, Color("dba963"))
	return_markers = MeshInstance3D.new()
	return_markers.mesh = tool.commit()
	beacon_material = StandardMaterial3D.new()
	beacon_material.vertex_color_use_as_albedo = true
	beacon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return_markers.material_override = beacon_material
	return_markers.hide()
	add_child(return_markers)

func reveal_return() -> void:
	return_markers.show()
