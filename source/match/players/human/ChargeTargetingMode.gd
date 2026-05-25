extends Node3D

signal charge_area_confirmed(start_pos: Vector3, end_pos: Vector3, direction: Vector3, length: float)

const TILE_SIZE = 1.0
const MIN_LENGTH = 2.0 * TILE_SIZE
const MAX_LENGTH = 7.0 * TILE_SIZE
const LINE_THICKNESS = 0.12

enum _State { INACTIVE, WAITING_START, DRAGGING }

var _state: _State = _State.INACTIVE
var _start_point: Vector3 = Vector3.ZERO
var _mesh_instance: MeshInstance3D = null
var _line_material: StandardMaterial3D = null
var _arrow_image: Image = null


func _ready():
	_arrow_image = _build_arrow_image()
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = Color(1.0, 0.85, 0.1, 0.9)
	_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_material.render_priority = 2


func enter():
	if _state != _State.INACTIVE:
		return
	if get_tree().get_nodes_in_group("placement_active").size() > 0:
		return
	_state = _State.WAITING_START
	add_to_group("targeting_mode_active")
	DisplayServer.cursor_set_custom_image(_arrow_image, DisplayServer.CURSOR_ARROW, Vector2(15, 2))


func _input(event: InputEvent):
	if _state == _State.INACTIVE:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_cancel()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel()
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _state == _State.WAITING_START:
				var pos = _get_ground_pos(event.position)
				if pos != null:
					_start_point = pos
					_state = _State.DRAGGING
				get_viewport().set_input_as_handled()
				return
			if not event.pressed and _state == _State.DRAGGING:
				var pos = _get_ground_pos(event.position)
				_finalize(pos)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion and _state == _State.DRAGGING:
		var pos = _get_ground_pos(event.position)
		if pos != null:
			_update_visualization(pos)


func _cancel():
	_state = _State.INACTIVE
	_clear_visualization()
	remove_from_group("targeting_mode_active")
	DisplayServer.cursor_set_custom_image(null, DisplayServer.CURSOR_ARROW)


func _get_ground_pos(screen_pos: Vector2) -> Variant:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return null
	return camera.get_ray_intersection(screen_pos)


func _finalize(end_pos: Variant):
	if end_pos == null:
		_cancel()
		return
	var delta = Vector3(end_pos.x - _start_point.x, 0.0, end_pos.z - _start_point.z)
	var raw_length = delta.length()
	if raw_length < 0.001:
		_cancel()
		return
	var clamped_length = clampf(raw_length, MIN_LENGTH, MAX_LENGTH)
	var direction = delta.normalized()
	var final_end = _start_point + direction * clamped_length
	print("[Charge] start=%s end=%s dir=%s length=%.2f" % [
		_start_point, final_end, direction, clamped_length
	])
	charge_area_confirmed.emit(_start_point, final_end, direction, clamped_length)
	_cancel()


func _update_visualization(mouse_pos: Vector3):
	var delta = Vector3(mouse_pos.x - _start_point.x, 0.0, mouse_pos.z - _start_point.z)
	var raw_length = delta.length()
	if raw_length < 0.001:
		_clear_visualization()
		return
	var clamped_length = clampf(raw_length, MIN_LENGTH, MAX_LENGTH)
	var direction = delta.normalized()
	var elev = Vector3(0.0, 0.1, 0.0)
	var a = _start_point + elev
	var b = _start_point + direction * clamped_length + elev

	var perp = direction.cross(Vector3.UP) * (LINE_THICKNESS * 0.5)
	var im = ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	im.surface_add_vertex(a - perp)
	im.surface_add_vertex(a + perp)
	im.surface_add_vertex(b + perp)
	im.surface_add_vertex(a - perp)
	im.surface_add_vertex(b + perp)
	im.surface_add_vertex(b - perp)
	im.surface_end()

	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.material_override = _line_material
		add_child(_mesh_instance)
	_mesh_instance.mesh = im


func _clear_visualization():
	if _mesh_instance != null:
		_mesh_instance.queue_free()
		_mesh_instance = null


func _build_arrow_image() -> Image:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var white = Color(1.0, 1.0, 1.0, 1.0)
	var transparent = Color(0.0, 0.0, 0.0, 0.0)
	for x in range(32):
		for y in range(32):
			var filled = false
			# Shaft: 6px wide, rows 14..26
			if x >= 13 and x <= 18 and y >= 14 and y <= 26:
				filled = true
			# Arrowhead: apex at row 2, base width 20px at row 14
			elif y >= 2 and y <= 14:
				var hw = int(round(float(y - 2) / 12.0 * 9.0))
				if x >= 15 - hw and x <= 16 + hw:
					filled = true
			img.set_pixel(x, y, white if filled else transparent)
	# Dark outline pass for visibility on light backgrounds
	var result = img.duplicate()
	var outline = Color(0.0, 0.0, 0.0, 0.7)
	for x in range(32):
		for y in range(32):
			if img.get_pixel(x, y).a > 0.5:
				continue
			var near = false
			for dx in [-1, 0, 1]:
				if near:
					break
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var nx = x + dx
					var ny = y + dy
					if nx >= 0 and nx < 32 and ny >= 0 and ny < 32:
						if img.get_pixel(nx, ny).a > 0.5:
							near = true
							break
			if near:
				result.set_pixel(x, y, outline)
	return result
