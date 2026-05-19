extends Node

var _mesh_instance: MeshInstance3D


func _ready() -> void:
	_mesh_instance = $GroundMesh
	await get_tree().process_frame
	await get_tree().process_frame
	_build_mesh()


func _build_mesh() -> void:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = 42
	noise.frequency = 0.008
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5
	noise.fractal_lacunarity = 2.0

	const SIZE := 260.0
	const CENTER_X := 128.0
	const CENTER_Z := 128.0
	const SUBDIVISIONS := 128
	const HEIGHT_SCALE := 1.2

	var step := SIZE / SUBDIVISIONS
	var start_x := CENTER_X - SIZE * 0.5
	var start_z := CENTER_Z - SIZE * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Build all unique vertices indexed by (row * (SUBDIVISIONS+1) + col).
	for row in range(SUBDIVISIONS + 1):
		for col in range(SUBDIVISIONS + 1):
			var wx := start_x + col * step
			var wz := start_z + row * step
			var dist_from_center_x: float = abs(wx - CENTER_X) / CENTER_X
			var dist_from_center_z: float = abs(wz - CENTER_Z) / CENTER_Z
			var edge_dist: float = maxf(dist_from_center_x, dist_from_center_z)
			var falloff: float = 1.0 - smoothstep(0.7, 1.0, edge_dist)
			var wy: float = clampf(noise.get_noise_2d(wx, wz) * HEIGHT_SCALE * falloff, -0.5, 1.5)
			var terrain_type := TerrainManager.get_terrain_type_at(Vector3(wx, 0.0, wz))
			st.set_color(_terrain_to_vertex_color(terrain_type))
			st.set_uv(Vector2(float(col) / SUBDIVISIONS, float(row) / SUBDIVISIONS))
			st.add_vertex(Vector3(wx, wy, wz))

	# Two triangles per quad, wound counter-clockwise from above.
	for row in range(SUBDIVISIONS):
		for col in range(SUBDIVISIONS):
			var i00 := row * (SUBDIVISIONS + 1) + col
			var i10 := i00 + 1
			var i01 := i00 + (SUBDIVISIONS + 1)
			var i11 := i01 + 1
			st.add_index(i00)
			st.add_index(i01)
			st.add_index(i10)
			st.add_index(i10)
			st.add_index(i01)
			st.add_index(i11)

	st.generate_normals()
	_mesh_instance.mesh = st.commit()
	_mesh_instance.material_override = _build_material()

	const VERTEX_COUNT := (SUBDIVISIONS + 1) * (SUBDIVISIONS + 1)
	GameLogger.info(GameLogger.Category.STARTUP, "TerrainVisualSystem generated", {
		"vertices": VERTEX_COUNT,
		"mesh_size": "260x260",
	})


func _terrain_to_vertex_color(terrain_type: int) -> Color:
	match terrain_type:
		TerrainRegion.Type.GRASSLAND:
			return Color(1, 0, 0, 1)
		TerrainRegion.Type.FOREST:
			return Color(0, 1, 0, 1)
		TerrainRegion.Type.ROCKY:
			return Color(0, 0, 1, 1)
		TerrainRegion.Type.FERTILE_LAND:
			return Color(1, 1, 0, 1)
		TerrainRegion.Type.FORD:
			return Color(0, 1, 1, 1)
		TerrainRegion.Type.ELEVATED:
			return Color(1, 0, 1, 1)
	return Color(1, 0, 0, 1)


func _build_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://source/match/terrain/terrain_shader.gdshader")
	mat.set_shader_parameter("grassland_texture", _solid_texture(Color(0.55, 0.75, 0.35)))
	mat.set_shader_parameter("forest_texture", _solid_texture(Color(0.15, 0.45, 0.15)))
	mat.set_shader_parameter("rocky_texture",
		load("res://assets/textures/terrain/rocky-rugged-terrain_1_albedo.png"))
	mat.set_shader_parameter("fertile_texture", _solid_texture(Color(0.75, 0.62, 0.30)))
	mat.set_shader_parameter("ford_texture", _solid_texture(Color(0.45, 0.70, 0.85)))
	mat.set_shader_parameter("elevated_texture", _solid_texture(Color(0.62, 0.80, 0.40)))
	return mat


static func _solid_texture(color: Color) -> ImageTexture:
	var img := Image.create(4, 4, false, Image.FORMAT_RGB8)
	img.fill(color)
	return ImageTexture.create_from_image(img)
