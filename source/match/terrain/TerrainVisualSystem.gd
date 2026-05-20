extends Node

const HEIGHTMAP_SCALE := 5.0
const HEIGHTMAP_DIR := "res://assets/heightmaps/"

var _mesh_instance: MeshInstance3D
var _material: ShaderMaterial
var _height_img: Image = null
var _map_size_cached: Vector2 = Vector2(256.0, 256.0)
var height_ready: bool = false
var _terrain_collider: StaticBody3D = null


func _ready() -> void:
	add_to_group("terrain_visual_system")
	_mesh_instance = $GroundMesh
	await get_tree().process_frame
	await get_tree().process_frame
	var terrain_plane := get_node_or_null("../Map/Geometry/Terrain")
	if terrain_plane:
		terrain_plane.visible = false
	_build_mesh()
	_spawn_forest_trees()


func _build_mesh() -> void:
	var map_size := _get_map_size()
	var mesh_w := map_size.x + 4.0
	var mesh_h := map_size.y + 4.0

	var plane := PlaneMesh.new()
	plane.size = Vector2(mesh_w, mesh_h)
	plane.subdivide_width = 128
	plane.subdivide_depth = 128
	plane.center_offset = Vector3(map_size.x / 2.0, 0.0, map_size.y / 2.0)
	_mesh_instance.mesh = plane

	var color_img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for z in range(256):
		for x in range(256):
			var wx: float = (x + 0.5) / 256.0 * map_size.x
			var wz: float = (z + 0.5) / 256.0 * map_size.y
			var terrain_type := TerrainManager.get_terrain_type_at(Vector3(wx, 0.0, wz))
			color_img.set_pixel(x, z, _terrain_to_color(terrain_type))

	var height_img := _load_height_image()
	_box_blur_image(height_img, 3)
	_height_img = height_img
	_map_size_cached = map_size
	height_ready = true

	var color_texture := ImageTexture.create_from_image(color_img)
	var height_texture := ImageTexture.create_from_image(height_img)

	var shader := load("res://source/match/terrain/terrain_elevation.gdshader") as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("color_texture", color_texture)
	mat.set_shader_parameter("height_texture", height_texture)
	mat.set_shader_parameter("height_scale", HEIGHTMAP_SCALE)
	_mesh_instance.material_override = mat
	_material = mat

	_build_terrain_collider()

	print("[ISSUE-B2] GroundMesh global_origin=", _mesh_instance.global_transform.origin,
		" local_position=", _mesh_instance.position)

	GameLogger.info(GameLogger.Category.STARTUP, "TerrainVisualSystem generated", {
		"map_size": "%dx%d" % [map_size.x, map_size.y],
		"mesh_size": "%dx%d" % [mesh_w, mesh_h],
	})


func get_visual_height_at(world_pos: Vector3) -> float:
	if _height_img == null:
		return 0.0
	var u := clampf(world_pos.x / _map_size_cached.x, 0.0, 1.0)
	var v := clampf(world_pos.z / _map_size_cached.y, 0.0, 1.0)
	var fx := u * 255.0
	var fy := v * 255.0
	var px0 := int(fx)
	var py0 := int(fy)
	var px1 := mini(px0 + 1, 255)
	var py1 := mini(py0 + 1, 255)
	var tx := fx - float(px0)
	var ty := fy - float(py0)
	var h00 := _height_img.get_pixel(px0, py0).r
	var h10 := _height_img.get_pixel(px1, py0).r
	var h01 := _height_img.get_pixel(px0, py1).r
	var h11 := _height_img.get_pixel(px1, py1).r
	return lerp(lerp(h00, h10, tx), lerp(h01, h11, tx), ty) * HEIGHTMAP_SCALE



func _build_terrain_collider() -> void:
	print("[P2.1] building terrain collider...")

	if _terrain_collider != null and is_instance_valid(_terrain_collider):
		_terrain_collider.queue_free()
		_terrain_collider = null

	const GRID_SIZE: int = 129
	const LAYER_TERRAIN_SURFACE: int = 16  # physics layer 5 ("TerrainSurface")

	var map_data: PackedFloat32Array = PackedFloat32Array()
	map_data.resize(GRID_SIZE * GRID_SIZE)
	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var wx: float = float(x) / float(GRID_SIZE - 1) * _map_size_cached.x
			var wz: float = float(z) / float(GRID_SIZE - 1) * _map_size_cached.y
			map_data[z * GRID_SIZE + x] = get_visual_height_at(Vector3(wx, 0.0, wz))

	print("[P2.1] map_data size=", map_data.size(),
		" sample[0]=", map_data[0],
		" sample[mid]=", map_data[GRID_SIZE * GRID_SIZE / 2],
		" sample[last]=", map_data[map_data.size() - 1])

	var shape: HeightMapShape3D = HeightMapShape3D.new()
	shape.map_width = GRID_SIZE
	shape.map_depth = GRID_SIZE
	shape.map_data = map_data

	print("[P2.1] shape map_width=", shape.map_width,
		" map_depth=", shape.map_depth,
		" map_data.size()=", shape.map_data.size())

	var cell_size_x: float = _map_size_cached.x / float(GRID_SIZE - 1)
	var cell_size_z: float = _map_size_cached.y / float(GRID_SIZE - 1)

	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	cs.transform = Transform3D(
		Basis.IDENTITY.scaled(Vector3(cell_size_x, 1.0, cell_size_z)),
		Vector3.ZERO
	)

	print("[P2.1] cs.shape=", cs.shape,
		" cs.transform.basis.x.length()=", cs.transform.basis.x.length(),
		" cs.transform.basis.z.length()=", cs.transform.basis.z.length())

	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = LAYER_TERRAIN_SURFACE
	body.collision_mask = 0
	body.transform = Transform3D(
		Basis.IDENTITY,
		Vector3(_map_size_cached.x / 2.0, 0.0, _map_size_cached.y / 2.0)
	)
	body.add_child(cs)
	add_child(body)
	_terrain_collider = body

	print("[P2.1] body.collision_layer=", body.collision_layer,
		" body.global_position=", body.global_position,
		" body.get_parent()=", body.get_parent(),
		" body.is_inside_tree()=", body.is_inside_tree())
	print("[P2.1] body.get_child_count()=", body.get_child_count(),
		" child[0]=", body.get_child(0),
		" child[0].shape=", (body.get_child(0) as CollisionShape3D).shape)
	var cs_global: Transform3D = cs.global_transform
	print("[P2.1] cs.global_transform origin=", cs_global.origin,
		" basis.x=", cs_global.basis.x,
		" basis.y=", cs_global.basis.y,
		" basis.z=", cs_global.basis.z)
	print("[P2.1] terrain collider built: ", _terrain_collider)

	# Check physics space registration
	var body_space_rid: RID = PhysicsServer3D.body_get_space(body.get_rid())
	var world_space_rid: RID = get_viewport().world_3d.space
	print("[P2.1] body_space_rid.is_valid()=", body_space_rid.is_valid(),
		" matches_world_space=", (body_space_rid == world_space_rid))

	# Immediate self-test raycast — may fail if physics hasn't ticked yet
	_self_test_raycast("immediate")

	# Deferred self-test — runs after next physics step
	call_deferred("_self_test_raycast", "deferred")

	GameLogger.info(GameLogger.Category.STARTUP, "Terrain surface collider built", {
		"grid": "%dx%d" % [GRID_SIZE, GRID_SIZE],
		"layer": 5,
		"cell_size": "%.3fx%.3f" % [cell_size_x, cell_size_z],
	})


func _self_test_raycast(label: String) -> void:
	var cx: float = _map_size_cached.x / 2.0
	var cz: float = _map_size_cached.y / 2.0
	var space: PhysicsDirectSpaceState3D = get_viewport().world_3d.direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(cx, 50.0, cz), Vector3(cx, -10.0, cz)
	)
	query.collision_mask = 16
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		print("[P2.1] self-test (", label, "): NO HIT — collider not queryable")
	else:
		print("[P2.1] self-test (", label, "): HIT at ", result["position"],
			" collider=", result.get("collider"))


func _get_map_size() -> Vector2:
	var map_node := get_node_or_null("../Map")
	if map_node == null:
		GameLogger.info(GameLogger.Category.STARTUP,
				"TerrainVisualSystem: no Map node found, defaulting to 256x256")
		return Vector2(256.0, 256.0)
	return Vector2(map_node.size)


func _load_height_image() -> Image:
	var flat := Image.create(256, 256, false, Image.FORMAT_RF)

	var map_node := get_node_or_null("../Map")
	if map_node == null:
		GameLogger.info(GameLogger.Category.STARTUP,
				"TerrainVisualSystem: no Map node found, using flat heightmap")
		return flat

	var scene_path: String = map_node.scene_file_path
	if scene_path.is_empty():
		GameLogger.info(GameLogger.Category.STARTUP,
				"TerrainVisualSystem: Map has no scene_file_path, using flat heightmap")
		return flat

	var map_name: String = scene_path.get_file().get_basename()
	var heightmap_path: String = HEIGHTMAP_DIR + map_name + ".png"

	if not FileAccess.file_exists(heightmap_path):
		GameLogger.info(GameLogger.Category.STARTUP,
				"TerrainVisualSystem: no heightmap found, using flat", {
					"looked_for": heightmap_path,
				})
		return flat

	var src_img := Image.load_from_file(heightmap_path)
	if src_img == null:
		GameLogger.info(GameLogger.Category.STARTUP,
				"TerrainVisualSystem: heightmap failed to load, using flat", {
					"path": heightmap_path,
				})
		return flat

	if src_img.get_width() != 256 or src_img.get_height() != 256:
		GameLogger.info(GameLogger.Category.STARTUP,
				"TerrainVisualSystem: heightmap wrong size — resizing to 256x256", {
					"path": heightmap_path,
					"original_size": "%dx%d" % [src_img.get_width(), src_img.get_height()],
				})
		src_img.resize(256, 256, Image.INTERPOLATE_BILINEAR)

	var height_img := Image.create(256, 256, false, Image.FORMAT_RF)
	for y in range(256):
		for x in range(256):
			var gray: float = src_img.get_pixel(x, y).r
			height_img.set_pixel(x, y, Color(gray, 0.0, 0.0))

	GameLogger.info(GameLogger.Category.STARTUP,
			"TerrainVisualSystem: heightmap loaded", {
				"path": heightmap_path,
				"height_scale": HEIGHTMAP_SCALE,
			})

	return height_img


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

		var printed_tree_diag: bool = (total_mmis > 0)
		for i in range(placed.size()):
			var scale: float = rng.randf_range(0.8, 1.4)
			var ground_y := get_visual_height_at(Vector3(placed[i].x, 0.0, placed[i].y))
			# Y = half-height * scale so tree base sits at ground level
			var pos := Vector3(placed[i].x, 1.75 * scale + gpos.y + ground_y, placed[i].y)
			var basis := Basis.IDENTITY.scaled(Vector3(scale, scale, scale))
			mm.set_instance_transform(i, Transform3D(basis, pos))
			if not printed_tree_diag:
				printed_tree_diag = true
				print("[ISSUE-B2] tree[0] xz=(", placed[i].x, ",", placed[i].y, ")",
					" gpos.y=", gpos.y,
					" ground_y(from heightmap)=", ground_y,
					" tree_base_y=", gpos.y + ground_y,
					" tree_center_y=", pos.y)

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


# DEPRECATED — replaced by PNG heightmap loading in _load_height_image().
# Kept as reference for per-type fallback values during transition.
#func _terrain_to_height(terrain_type: int) -> float:
#	match terrain_type:
#		TerrainRegion.Type.GRASSLAND:    return 0.0
#		TerrainRegion.Type.FOREST:       return 0.0
#		TerrainRegion.Type.ROCKY:        return 0.0
#		TerrainRegion.Type.FERTILE_LAND: return 0.0
#		TerrainRegion.Type.FORD:         return 0.0
#		TerrainRegion.Type.ELEVATED:     return 0.0
#	return 0.0


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
