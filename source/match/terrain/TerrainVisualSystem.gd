extends Node

var _mesh_instance: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_mesh_instance = $GroundMesh
	await get_tree().process_frame
	await get_tree().process_frame
	var terrain_plane := get_node_or_null("../Map/Geometry/Terrain")
	if terrain_plane:
		terrain_plane.visible = false
	_build_mesh()


func _build_mesh() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(260.0, 260.0)
	plane.subdivide_width = 128
	plane.subdivide_depth = 128
	plane.center_offset = Vector3(128.0, 0.0, 128.0)
	_mesh_instance.mesh = plane

	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for z in range(256):
		for x in range(256):
			var terrain_type := TerrainManager.get_terrain_type_at(Vector3(x + 0.5, 0.0, z + 0.5))
			img.set_pixel(x, z, _terrain_to_color(terrain_type))
	var terrain_texture := ImageTexture.create_from_image(img)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = terrain_texture
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mesh_instance.material_override = mat
	_material = mat

	GameLogger.info(GameLogger.Category.STARTUP, "TerrainVisualSystem generated", {
		"texture_size": "256x256",
		"mesh_size": "260x260",
	})


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


