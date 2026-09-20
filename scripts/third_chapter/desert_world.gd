class_name DesertWorld
extends Node3D
## Small meshes, shared materials, one sun. No external models or textures.
var gate: StaticBody3D
var child_sprite: Sprite3D
var scorpion_sprite: Node3D
var materials: Dictionary = {}
var rock_transforms: Array[Transform3D] = []

func material(color: Color) -> StandardMaterial3D:
	if materials.has(color): return materials[color]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	materials[color] = mat
	return mat

func build(map: ThirdMap) -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("637f99")
	sky_mat.sky_horizon_color = Color("f1ccaa")
	sky_mat.ground_horizon_color = Color("e6b582")
	sky_mat.ground_bottom_color = Color("b88456")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("a6b4cd")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("dcad83")
	env.fog_density = 0.007
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, -38, 0)
	sun.light_color = Color("ffe0aa")
	sun.light_energy = 1.4
	sun.shadow_enabled = false
	add_child(sun)
	var ground := _box(Vector3(32, -0.3, 32), Vector3(180, 0.5, 180), Color("ce9d64"), true)
	var sand := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = "shader_type spatial; varying vec3 p; void vertex(){ p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; } void fragment(){ float r=sin(p.x*5.0+sin(p.z*0.6)*2.0); ALBEDO=vec3(0.76,0.55,0.32)*(1.0+r*0.045); ROUGHNESS=1.0; }"
	sand.shader = shader
	ground.get_child(0).material_override = sand
	# Large, low-poly dunes frame the small playable space.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7303
	for i in 28:
		var angle := float(i) / 28.0 * TAU
		var center := Vector3(30 + cos(angle) * 65, -3, 30 + sin(angle) * 65)
		var dune := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radial_segments = 12
		mesh.rings = 5
		mesh.radius = 1
		mesh.height = 2
		dune.mesh = mesh
		dune.position = center
		dune.scale = Vector3(rng.randf_range(14, 24), rng.randf_range(6, 13), rng.randf_range(12, 22))
		dune.material_override = material(Color("d2a16b") if i % 2 == 0 else Color("b78669"))
		add_child(dune)
	for cell: Vector2i in map.floor_cells:
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if map.floor_cells.has(cell + direction): continue
			var center := ThirdMap.world(cell) + Vector3(direction.x, 0, direction.y) * ThirdMap.CELL * 0.5
			var h := rng.randf_range(0.8, 1.5) if cell.y >= 11 else rng.randf_range(3.2, 5.0)
			center.y = h * 0.5
			var size := Vector3(0.65, h, 4.4) if direction.x != 0 else Vector3(4.4, h, 0.65)
			var wall := _box(center, size, Color("b57d58"), true)
			wall.get_child(0).hide()
			# Broad faceted sandstone, with a low boundary around the open arrival area.
			var basis := Basis.IDENTITY.scaled(size * Vector3(0.7, 0.5, 0.7))
			rock_transforms.append(Transform3D(basis, center))
		if cell.y < 5 or cell.x < 3:
			_box(ThirdMap.world(cell) + Vector3(0, -0.02, 0), Vector3(3.95, 0.07, 3.95), Color("bda987"), false)
	# Cave roof and portal: a dark enclosure followed by an open skyline.
	_box(Vector3(52, 4.8, 8), Vector3(13, 0.6, 15), Color("776e70"), false)
	_arch(ThirdMap.world(Vector2i(12, 3)), Color("8e7870"))
	_arch(ThirdMap.world(Vector2i(3, 10)), Color("b78759"))
	gate = _box(ThirdMap.world(ThirdMap.GATE) + Vector3(0, 1.65, 0), Vector3(4, 3.3, 0.6), Color("aa7f54"), true) as StaticBody3D
	# Tower is visible above local walls and consistently identifies the camp.
	var tower := ThirdMap.world(ThirdMap.CAMP) + Vector3(0, 0, 4)
	_box(tower + Vector3(0, 5, 0), Vector3(3, 10, 3), Color("bc8052"), false)
	_box(tower + Vector3(0, 10.2, 0), Vector3(4, 0.6, 4), Color("f4d69b"), false)
	_label("营地", tower + Vector3(0, 11.7, 0), Color("fff0c0"))
	_label("← 避风古道     风沙近路 →", ThirdMap.world(ThirdMap.FORK) + Vector3(0, 2.2, -1.6), Color("fff0ca"))
	_box(ThirdMap.world(ThirdMap.FORK) + Vector3(0, 1, -1.65), Vector3(0.18, 2, 0.18), Color("79593d"), false)
	_label("壁画 · 留下的旅行手记", ThirdMap.world(ThirdMap.RELIC) + Vector3(0, 2, 0), Color("f0dbaa"))
	_box(ThirdMap.world(ThirdMap.RELIC) + Vector3(0, 0.55, 0), Vector3(1.4, 1.1, 0.8), Color("716657"), false)
	_label("弟弟", ThirdMap.world(ThirdMap.CHILD) + Vector3(0, 2.5, 0), Color("fff2bd"))
	child_sprite = _character("mcking", ThirdMap.world(ThirdMap.CHILD), 1.65)
	_character("le", ThirdMap.world(ThirdMap.CAMP) + Vector3(-2, 0, 0), 1.9)
	_character("mac", ThirdMap.world(ThirdMap.CAMP) + Vector3(2, 0, 0), 1.85)
	_label("妈妈和哥哥在这里等你们", ThirdMap.world(ThirdMap.CAMP) + Vector3(0, 2.8, 0), Color("fff2bd"))
	scorpion_sprite = Node3D.new()
	scorpion_sprite.position = ThirdMap.world(ThirdMap.SCORPION)
	add_child(scorpion_sprite)
	for part in [Vector3(0, 0.4, 0), Vector3(0, 0.65, 0.6), Vector3(0, 1.0, 0.8), Vector3(0, 1.25, 0.55)]:
		var segment := _box(scorpion_sprite.position + part, Vector3(0.7, 0.35, 0.5), Color("805036"), false)
		segment.reparent(scorpion_sprite)
	for side in [-1, 1]:
		for z in [-0.4, 0.0, 0.4]:
			var leg := _box(scorpion_sprite.position + Vector3(side * 0.65, 0.2, z), Vector3(0.9, 0.12, 0.12), Color("805036"), false)
			leg.reparent(scorpion_sprite)
	_label("沙蝎 · 抬尾时后退", ThirdMap.world(ThirdMap.SCORPION) + Vector3(0, 2.0, 0), Color("ffdca0"))
	# Footprints create readable direction without revealing the entire route.
	for z in range(37, 53, 2):
		for side in [-0.22, 0.22]:
			_box(Vector3(12 + side, 0.015, z + side), Vector3(0.2, 0.04, 0.5), Color("aa7e52"), false)
	var rocks := MultiMeshInstance3D.new()
	var rock_batch := MultiMesh.new()
	rock_batch.transform_format = MultiMesh.TRANSFORM_3D
	var rock_mesh := CylinderMesh.new()
	rock_mesh.top_radius = 0.65
	rock_mesh.bottom_radius = 1
	rock_mesh.radial_segments = 6
	rock_mesh.material = material(Color("b98a65"))
	rock_batch.mesh = rock_mesh
	rock_batch.instance_count = rock_transforms.size()
	for i in rock_transforms.size(): rock_batch.set_instance_transform(i, rock_transforms[i])
	rocks.multimesh = rock_batch
	add_child(rocks)
	_batch_static_boxes()

func _batch_static_boxes() -> void:
	# Render static rock/floor pieces in a handful of draws, not one draw per wall.
	# Keep physics shapes and the animated gate/scorpion separate.
	var groups: Dictionary = {}
	for node in find_children("*", "MeshInstance3D", true, false):
		if not node.visible or not node.mesh is BoxMesh or gate.is_ancestor_of(node) or scorpion_sprite.is_ancestor_of(node): continue
		var mat: Material = node.material_override
		if not groups.has(mat): groups[mat] = []
		groups[mat].append(node)
	for mat in groups:
		var instance := MultiMeshInstance3D.new()
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		var unit := BoxMesh.new()
		unit.size = Vector3.ONE
		unit.material = mat
		batch.mesh = unit
		batch.instance_count = groups[mat].size()
		for i in groups[mat].size():
			var node: MeshInstance3D = groups[mat][i]
			batch.set_instance_transform(i, node.global_transform.scaled_local(node.mesh.size))
			node.hide()
			node.queue_free()
		instance.multimesh = batch
		add_child(instance)

func _box(pos: Vector3, size: Vector3, color: Color, solid: bool) -> Node3D:
	var holder: Node3D = StaticBody3D.new() if solid else Node3D.new()
	holder.position = pos
	add_child(holder)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material(color)
	holder.add_child(mesh)
	if solid:
		var shape := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = size
		shape.shape = collision
		holder.add_child(shape)
	return holder

func _arch(pos: Vector3, color: Color) -> void:
	_box(pos + Vector3(-1.7, 2, 0), Vector3(0.5, 4, 0.7), color, false)
	_box(pos + Vector3(1.7, 2, 0), Vector3(0.5, 4, 0.7), color, false)
	_box(pos + Vector3(0, 4, 0), Vector3(4, 0.7, 0.8), color, false)

func _character(key: String, pos: Vector3, height: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = load(AssetRegistry.character_sprite_path(key, true))
	sprite.pixel_size = height / float(sprite.texture.get_height())
	sprite.position = pos + Vector3(0, height * 0.5, 0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	return sprite

func _label(text: String, pos: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = ThemeDB.fallback_font
	label.font_size = 48
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	add_child(label)

func open_gate() -> void:
	gate.visible = false
	gate.collision_layer = 0
	child_sprite.visible = false
	_character("mcking", ThirdMap.world(ThirdMap.CAMP), 1.65)
