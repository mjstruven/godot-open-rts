extends PanelContainer

const Unit = preload("res://source/match/units/Unit.gd")

const GROUND_LEVEL_PLANE = Plane(Vector3.UP, 0)
const MINIMAP_PIXELS_PER_WORLD_METER = 2

# Minimap colors for each terrain type (always-visible tint above fog mask)
const TERRAIN_COLORS_MINIMAP = {
	0: Color(0.55, 0.75, 0.35, 1.0),  # GRASSLAND
	1: Color(0.15, 0.45, 0.15, 1.0),  # FOREST
	2: Color(0.55, 0.55, 0.50, 1.0),  # ROCKY
	3: Color(0.75, 0.62, 0.30, 1.0),  # FERTILE_LAND
	4: Color(0.45, 0.70, 0.85, 1.0),  # FORD
	5: Color(0.60, 0.78, 0.40, 1.0),  # ELEVATED
}

var _unit_to_corresponding_node_mapping = {}
var _camera_movement_active = false
var _units_layer: Node2D = null
var _indicator_width_calibrated := false

@onready var _match = find_parent("Match")
@onready var _camera_indicator = find_child("CameraIndicator")
@onready var _texture_rect = find_child("MinimapTextureRect")
@onready var _minimap_viewport: SubViewport = find_child("MinimapViewport")


func _ready():
	if not FeatureFlags.show_minimap:
		queue_free()
		return
	_remove_dummy_nodes()
	await _match.ready
	var viewport = find_child("MinimapViewport")
	viewport.size = _match.find_child("Map").size * MINIMAP_PIXELS_PER_WORLD_METER
	_setup_layers(viewport)
	_texture_rect.gui_input.connect(_on_gui_input)
	MatchSignals.match_started.connect(func(): _add_terrain_overlays(viewport), CONNECT_ONE_SHOT)


func _physics_process(_delta):
	_sync_real_units_with_minimap_representations()
	if not _indicator_width_calibrated:
		_calibrate_indicator_width()
	_update_camera_indicator()


func _remove_dummy_nodes():
	for dummy_node in find_children("EditorOnlyDummy*"):
		dummy_node.queue_free()


func _setup_layers(viewport: SubViewport) -> void:
	_units_layer = Node2D.new()
	_units_layer.name = "UnitsLayer"
	_units_layer.z_index = 3
	viewport.add_child(_units_layer)
	_camera_indicator.z_index = 4


func _calibrate_indicator_width() -> void:
	var vp_size := Vector2(_minimap_viewport.size)
	var rect_size: Vector2 = (_texture_rect as Control).size
	if vp_size.x <= 0.0 or rect_size.x <= 0.0:
		return
	var fit_scale := minf(rect_size.x / vp_size.x, rect_size.y / vp_size.y)
	_camera_indicator.width = 2.0 / fit_scale
	_indicator_width_calibrated = true


func _add_terrain_overlays(viewport: SubViewport) -> void:
	var regions = TerrainManager.get_regions()
	if regions.is_empty():
		return
	var map_size: Vector2 = _match.find_child("Map").size
	var img_w: int = int(map_size.x) * MINIMAP_PIXELS_PER_WORLD_METER
	var img_h: int = int(map_size.y) * MINIMAP_PIXELS_PER_WORLD_METER
	var img: Image = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
	const HALF: float = 5.0
	const FADE_START: float = 0.82
	for region in regions:
		var color: Variant = TERRAIN_COLORS_MINIMAP.get(region.terrain_type)
		if color == null:
			continue
		var t: Transform3D = region.global_transform
		var inv: Transform3D = t.affine_inverse()
		# World-space AABB of the rotated box
		var corners: Array[Vector3] = [
			t * Vector3(HALF, 0.0, HALF),
			t * Vector3(-HALF, 0.0, HALF),
			t * Vector3(HALF, 0.0, -HALF),
			t * Vector3(-HALF, 0.0, -HALF),
		]
		var min_wx: float = corners[0].x; var max_wx: float = corners[0].x
		var min_wz: float = corners[0].z; var max_wz: float = corners[0].z
		for c: Vector3 in corners:
			if c.x < min_wx: min_wx = c.x
			if c.x > max_wx: max_wx = c.x
			if c.z < min_wz: min_wz = c.z
			if c.z > max_wz: max_wz = c.z
		var px0: int = clamp(int(floor(min_wx * MINIMAP_PIXELS_PER_WORLD_METER)), 0, img_w - 1)
		var px1: int = clamp(int(ceil(max_wx * MINIMAP_PIXELS_PER_WORLD_METER)), 0, img_w)
		var pz0: int = clamp(int(floor(min_wz * MINIMAP_PIXELS_PER_WORLD_METER)), 0, img_h - 1)
		var pz1: int = clamp(int(ceil(max_wz * MINIMAP_PIXELS_PER_WORLD_METER)), 0, img_h)
		for pz: int in range(pz0, pz1):
			for px: int in range(px0, px1):
				var local: Vector3 = inv * Vector3(
					px / float(MINIMAP_PIXELS_PER_WORLD_METER), 0.0,
					pz / float(MINIMAP_PIXELS_PER_WORLD_METER))
				var d: float = max(abs(local.x) / HALF, abs(local.z) / HALF)
				if d > 1.0:
					continue
				var col: Color = color as Color
				var alpha: float = col.a
				if d > FADE_START:
					alpha *= 1.0 - (d - FADE_START) / (1.0 - FADE_START)
				var ex: Color = img.get_pixel(px, pz)
				var out_a: float = alpha + ex.a * (1.0 - alpha)
				if out_a < 0.001:
					continue
				img.set_pixel(px, pz, Color(
					(col.r * alpha + ex.r * ex.a * (1.0 - alpha)) / out_a,
					(col.g * alpha + ex.g * ex.a * (1.0 - alpha)) / out_a,
					(col.b * alpha + ex.b * ex.a * (1.0 - alpha)) / out_a,
					out_a))
	var texture := ImageTexture.create_from_image(img)
	var tex_rect := TextureRect.new()
	tex_rect.texture = texture
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.z_index = 2
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(tex_rect)


func _sync_real_units_with_minimap_representations():
	var units_synced = {}
	var units_to_sync = (
		get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("resource_units")
	)
	for unit in units_to_sync:
		if not unit.visible:
			continue
		units_synced[unit] = 1
		if not _unit_is_mapped(unit):
			_map_unit(unit)
		_sync_unit(unit)
	for mapped_unit in _unit_to_corresponding_node_mapping:
		if not mapped_unit in units_synced:
			_cleanup_mapping(mapped_unit)


func _unit_is_mapped(unit):
	return unit in _unit_to_corresponding_node_mapping


func _map_unit(unit):
	var dot = Polygon2D.new()
	dot.polygon = PackedVector2Array([
		Vector2(-1.5, -1.5), Vector2(1.5, -1.5),
		Vector2(1.5, 1.5), Vector2(-1.5, 1.5)
	])
	if not unit is Unit:
		dot.rotation_degrees = 45
	_units_layer.add_child(dot)
	_unit_to_corresponding_node_mapping[unit] = dot


func _sync_unit(unit):
	var unit_pos_3d = unit.global_transform.origin
	var unit_pos_2d = Vector2(unit_pos_3d.x, unit_pos_3d.z) * MINIMAP_PIXELS_PER_WORLD_METER
	_unit_to_corresponding_node_mapping[unit].position = unit_pos_2d
	_unit_to_corresponding_node_mapping[unit].color = (
		Color.WHITE
		if unit.is_in_group("neutral_siege")
		else (unit.player.color if unit is Unit else unit.color)
	)


func _cleanup_mapping(unit):
	_unit_to_corresponding_node_mapping[unit].queue_free()
	_unit_to_corresponding_node_mapping.erase(unit)


func _update_camera_indicator() -> void:
	var viewport = get_viewport()
	var camera = viewport.get_camera_3d()
	if camera == null:
		return
	var screen_corners := [
		Vector2.ZERO,
		Vector2(0, viewport.size.y),
		viewport.size,
		Vector2(viewport.size.x, 0),
		Vector2.ZERO,
	]
	var pts: Array[Vector2] = []
	for sc in screen_corners:
		var hit = GROUND_LEVEL_PLANE.intersects_ray(
			camera.project_ray_origin(sc),
			camera.project_ray_normal(sc)
		)
		if hit == null:
			return
		var hit_pos := hit as Vector3
		pts.append(Vector2(hit_pos.x, hit_pos.z) * MINIMAP_PIXELS_PER_WORLD_METER)
	for i in range(pts.size()):
		_camera_indicator.set_point_position(i, pts[i])


func _texture_rect_position_to_world_position(position_2d_within_texture_rect):
	assert(
		_texture_rect.stretch_mode == _texture_rect.STRETCH_KEEP_ASPECT_CENTERED,
		"world 3d position retrieval algorithm assumes 'STRETCH_KEEP_ASPECT_CENTERED'"
	)
	var texture_rect_size = _texture_rect.size
	var texture_size = _texture_rect.texture.get_size()
	var proportions = texture_rect_size / texture_size
	var scaling_factor = proportions.x if proportions.x < proportions.y else proportions.y
	var scaled_texture_size = texture_size * scaling_factor
	var scaled_texture_position_within_texture_rect = (
		(texture_rect_size - scaled_texture_size) / 2.0
	)
	var rect_containing_scaled_texture = Rect2(
		scaled_texture_position_within_texture_rect, scaled_texture_size
	)
	if rect_containing_scaled_texture.has_point(position_2d_within_texture_rect):
		var position_2d_within_minimap = (
			(position_2d_within_texture_rect - rect_containing_scaled_texture.position)
			/ scaling_factor
		)
		return position_2d_within_minimap / MINIMAP_PIXELS_PER_WORLD_METER
	return null


func _try_teleporting_camera_based_on_local_texture_rect_position(position_2d_within_texture_rect):
	var world_position_2d = _texture_rect_position_to_world_position(
		position_2d_within_texture_rect
	)
	if world_position_2d == null:
		return
	var world_position_3d = Vector3(world_position_2d.x, 0, world_position_2d.y)
	get_viewport().get_camera_3d().set_position_safely(world_position_3d)


func _issue_movement_action(position_2d_within_texture_rect):
	var world_position_2d = _texture_rect_position_to_world_position(
		position_2d_within_texture_rect
	)
	if world_position_2d == null:
		return
	# Use world position directly so right-click works even in unexplored fog areas.
	# Fall back to flat y=0 ground if the camera ray misses (e.g. point is off-screen).
	var world_position_3d = Vector3(world_position_2d.x, 0, world_position_2d.y)
	var camera = get_viewport().get_camera_3d()
	var ray_hit = camera.get_ray_intersection(camera.unproject_position(world_position_3d))
	MatchSignals.terrain_targeted.emit(ray_hit if ray_hit != null else world_position_3d)


func _on_gui_input(event):
	if event is InputEventMouseButton:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			_try_teleporting_camera_based_on_local_texture_rect_position(event.position)
			_camera_movement_active = true
		if not event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			_camera_movement_active = false
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_RIGHT:
			_issue_movement_action(event.position)
	elif event is InputEventMouseMotion and _camera_movement_active:
		_try_teleporting_camera_based_on_local_texture_rect_position(event.position)
