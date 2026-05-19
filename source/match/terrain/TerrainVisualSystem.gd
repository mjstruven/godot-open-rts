extends Node

var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial


func _ready() -> void:
	_mesh_instance = $GroundMesh
	await get_tree().process_frame
	await get_tree().process_frame
	var terrain_plane := get_node_or_null("../Map/Geometry/Terrain")
	if terrain_plane:
		terrain_plane.visible = false
	_build_mesh()
	_spawn_forest_trees()


func _build_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(260.0, 260.0)
	plane.subdivide_width = 128
	plane.subdivide_depth = 128
	plane.center_offset = Vector3(128.0, 0.0, 128.0)
	_mesh_instance.mesh = plane

	var color_img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var height_img := Image.create(256, 256, false, Image.FORMAT_RF)
	for z in range(256):
		for x in range(256):
			var terrain_type := TerrainManager.get_terrain_type_at(Vector3(x + 0.5, 0.0, z + 0.5))
			color_img.set_pixel(x, z, _terrain_to_color(terrain_type))
			height_img.set_pixel(x, z, Color(_terrain_to_height(terrain_type), 0.0, 0.0))
	_box_blur_image(height_img, 3)

	var color_texture := ImageTexture.create_from_image(color_img)
	var height_texture := ImageTexture.create_from_image(height_img)

	var shader := load("res://source/match/terrain/terrain_elevation.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color_texture", color_texture)
	mat.set_shader_parameter("height_texture", height_texture)
	mat.set_shader_parameter("height_scale", 1.0)
	_mesh_instance.material_override = mat
	_material = mat

	GameLogger.info(GameLogger.Category.STARTUP, "TerrainVisualSystem generated", {
		"texture_size": "256x256",
		"mesh_size": "260x260",
	})


func _spawn_forest_trees() -> void:
	var total_mmis := 0
	var total_instances := 0
	for region in TerrainManager.get_regions():
		if region.terrain_type != TerrainRegion.Type.FOREST:
			continue
		var gpos: Vector3 = region.global_position
		var sx: float = region.global_transform.basis.x.length()
		var sz: float = region.global_transform.basis.z.length()
		var area: float = (10.0 * sx) * (10.0 * sz)
		var target_count: int = clampi(int(area / 8.0), 5, 60)

		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector2(gpos.x, gpos.z))

		var placed: Array[Vector2] = []
		var attempts := 0
		while placed.size() < target_count and attempts < target_count * 20:
			attempts += 1
			var tx: float = gpos.x + rng.randf_range(-5.0 * sx, 5.0 * sx)
			var tz: float = gpos.z + rng.randf_range(-5.0 * sz, 5.0 * sz)
			var p2d := Vector2(tx, tz)
			var ok := true
			for q: Vector2 in placed:
				if p2d.distance_to(q) < 1.2:
					ok = false
					break
			if ok:
				placed.append(p2d)

		var quad := QuadMesh.new()
		quad.size = Vector2(2.5, 3.5)

		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = quad
		mm.instance_count = placed.size()

		for i in range(placed.size()):
			var scale: float = rng.randf_range(0.8, 1.4)
			# Y = half-height * scale so tree base sits at ground level
			var pos := Vector3(placed[i].x, 1.75 * scale + gpos.y, placed[i].y)
			var basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
			mm.set_instance_transform(i, Transform3D(basis, pos))

		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _pick_tree_texture(rng)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.15
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

		total_mmis += 1
		total_instances += placed.size()

	GameLogger.info(GameLogger.Category.STARTUP, "Forest trees spawned", {
		"multimesh_nodes": total_mmis,
		"tree_instances": total_instances,
	})


func _pick_tree_texture(rng: RandomNumberGenerator) -> Texture2D:
	var roll: float = rng.randf()
	var pool: Array
	if roll < 0.55:
		pool = TerrainRegion._conifer_textures
	elif roll < 0.95:
		pool = TerrainRegion._deciduous_textures
	else:
		pool = TerrainRegion._bare_textures
	return pool[rng.randi() % pool.size()]


func _terrain_to_height(terrain_type: int) -> float:
	match terrain_type:
		TerrainRegion.Type.GRASSLAND:
			return 0.0
		TerrainRegion.Type.FOREST:
			return 0.3
		TerrainRegion.Type.ROCKY:
			return 0.8
		TerrainRegion.Type.FERTILE_LAND:
			return 0.0
		TerrainRegion.Type.FORD:
			return -0.5
		TerrainRegion.Type.ELEVATED:
			return 2.0
	return 0.0


func _box_blur_image(img: Image, passes: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for _pass in range(passes):
		var src := img.duplicate() as Image
		for y in range(h):
			for x in range(w):
				var sum := 0.0
				var count := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var sx := clampi(x + dx, 0, w - 1)
						var sy := clampi(y + dy, 0, h - 1)
						sum += src.get_pixel(sx, sy).r
						count += 1
				img.set_pixel(x, y, Color(sum / count, 0.0, 0.0))


func _terrain_to_color(terrain_type: int) -> Color:
	match terrain_type:
		TerrainRegion.Type.GRASSLAND:
			return Color(0.55, 0.75, 0.35)
		TerrainRegion.Type.FOREST:
			return Color(0.15, 0.45, 0.15)
		TerrainRegion.Type.ROCKY:
			return Color(0.55, 0.55, 0.50)
		TerrainRegion.Type.FERTILE_LAND:
			return Color(0.70, 0.65, 0.30)
		TerrainRegion.Type.FORD:
			return Color(0.45, 0.70, 0.85)
		TerrainRegion.Type.ELEVATED:
			return Color(0.50, 0.80, 0.28)
	return Color(0.55, 0.75, 0.35)
