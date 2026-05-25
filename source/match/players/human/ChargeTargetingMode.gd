extends Node3D

signal charge_area_confirmed(start_pos: Vector3, end_pos: Vector3, direction: Vector3, length: float)

const TILE_SIZE = 1.0
const MIN_LENGTH = 2.0 * TILE_SIZE
const MAX_LENGTH = 7.0 * TILE_SIZE
const LINE_THICKNESS = 0.12

enum _State { INACTIVE, WAITING_START, DRAGGING }

var _state: _State = _State.INACTIVE
var _start_point: Vector3 = Vector3.ZERO
var _locked_direction: Vector3 = Vector3(0.0, 0.0, 1.0)
var _last_mouse_3d: Variant = null
var _current_dir_index: int = 6
var _mesh_instance: MeshInstance3D = null
var _line_material: StandardMaterial3D = null
var _arrow_images: Array = []


func _ready():
	print("[CTM-DEBUG] ChargeTargetingMode _ready(), node=%s parent=%s" % [name, get_parent().name if get_parent() else "NO_PARENT"])
	_build_arrow_images()
	_line_material = StandardMaterial3D.new()
	_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_material.albedo_color = Color(1.0, 0.85, 0.1, 0.9)
	_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_material.render_priority = 2


func enter():
	print("[CTM-DEBUG] enter() called — state=%s" % _State.keys()[_state])
	if _state != _State.INACTIVE:
		print("[CTM-DEBUG] enter() bail: state not INACTIVE")
		return
	var placement_nodes = get_tree().get_nodes_in_group("placement_active")
	if placement_nodes.size() > 0:
		print("[CTM-DEBUG] enter() bail: placement_active has %d nodes" % placement_nodes.size())
		return
	_state = _State.WAITING_START
	_last_mouse_3d = null
	add_to_group("targeting_mode_active")
	DisplayServer.cursor_set_custom_image(
		_arrow_images[_current_dir_index], DisplayServer.CURSOR_ARROW, Vector2(15, 15)
	)
	print("[CTM-DEBUG] enter() complete — now in WAITING_START, arrow_images.size=%d" % _arrow_images.size())


func _input(event: InputEvent):
	# Log ALL mouse button events regardless of state so we know if _input is even firing
	if event is InputEventMouseButton:
		print("[CTM-DEBUG] _input mouse btn: button=%d pressed=%s state=%s" % [
			event.button_index, event.pressed, _State.keys()[_state]
		])

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
				print("[CTM-DEBUG] LMB press in WAITING_START — calling _get_ground_pos(%s)" % event.position)
				var pos = _get_ground_pos(event.position)
				print("[CTM-DEBUG] _get_ground_pos returned: %s" % str(pos))
				if pos != null:
					_start_point = pos
					_state = _State.DRAGGING
					print("[CTM-DEBUG] transitioned to DRAGGING, start_point=%s" % _start_point)
				else:
					print("[CTM-DEBUG] ground pos null — staying in WAITING_START")
				get_viewport().set_input_as_handled()
				return
			if not event.pressed and _state == _State.DRAGGING:
				print("[CTM-DEBUG] LMB release in DRAGGING — finalizing")
				_finalize(_get_ground_pos(event.position))
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion:
		if _state == _State.WAITING_START:
			_handle_waiting_motion(event)
		elif _state == _State.DRAGGING:
			var pos = _get_ground_pos(event.position)
			if pos != null:
				_update_visualization(pos)


func _handle_waiting_motion(event: InputEventMouseMotion) -> void:
	var curr_3d = _get_ground_pos(event.position)
	if curr_3d != null and _last_mouse_3d != null:
		var delta_3d = Vector3(curr_3d.x - _last_mouse_3d.x, 0.0, curr_3d.z - _last_mouse_3d.z)
		if delta_3d.length() > 0.05:
			_locked_direction = delta_3d.normalized()
	_last_mouse_3d = curr_3d

	var screen_delta: Vector2 = event.relative
	if screen_delta.length() > 2.0:
		var angle = atan2(screen_delta.y, screen_delta.x)
		var dir_idx = int(round(angle / (TAU / 8.0))) % 8
		if dir_idx < 0:
			dir_idx += 8
		if dir_idx != _current_dir_index:
			_current_dir_index = dir_idx
			DisplayServer.cursor_set_custom_image(
				_arrow_images[dir_idx], DisplayServer.CURSOR_ARROW, Vector2(15, 15)
			)


func _cancel():
	_state = _State.INACTIVE
	_clear_visualization()
	remove_from_group("targeting_mode_active")
	DisplayServer.cursor_set_custom_image(null, DisplayServer.CURSOR_ARROW)


func _get_ground_pos(screen_pos: Vector2) -> Variant:
	var camera = get_viewport().get_camera_3d()
	print("[CTM-DEBUG] _get_ground_pos: camera=%s (type=%s)" % [str(camera), camera.get_class() if camera else "N/A"])
	if camera == null:
		print("[CTM-DEBUG] _get_ground_pos: camera IS NULL")
		return null
	var ray_origin = camera.project_ray_origin(screen_pos)
	var ray_normal = camera.project_ray_normal(screen_pos)
	var result = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_normal)
	print("[CTM-DEBUG] _get_ground_pos: ray_origin=%s ray_normal=%s result=%s" % [ray_origin, ray_normal, str(result)])
	return result


func _finalize(end_pos: Variant):
	if end_pos == null:
		_cancel()
		return
	var to_mouse = Vector3(end_pos.x - _start_point.x, 0.0, end_pos.z - _start_point.z)
	var raw_dist = to_mouse.dot(_locked_direction)
	var clamped_dist = clampf(raw_dist, MIN_LENGTH, MAX_LENGTH)
	var final_end = _start_point + _locked_direction * clamped_dist
	print("[Charge] start=%s end=%s dir=%s length=%.2f" % [
		_start_point, final_end, _locked_direction, clamped_dist
	])
	charge_area_confirmed.emit(_start_point, final_end, _locked_direction, clamped_dist)
	_cancel()


func _update_visualization(mouse_3d: Vector3):
	var to_mouse = Vector3(mouse_3d.x - _start_point.x, 0.0, mouse_3d.z - _start_point.z)
	var raw_dist = to_mouse.dot(_locked_direction)
	var clamped_dist = clampf(raw_dist, MIN_LENGTH, MAX_LENGTH)
	var elev = Vector3(0.0, 0.1, 0.0)
	var a = _start_point + elev
	var b = _start_point + _locked_direction * clamped_dist + elev
	var perp = _locked_direction.cross(Vector3.UP) * (LINE_THICKNESS * 0.5)
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
		print("[CTM-DEBUG] _update_visualization: creating MeshInstance3D")
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.material_override = _line_material
		add_child(_mesh_instance)
	_mesh_instance.mesh = im


func _clear_visualization():
	if _mesh_instance != null:
		_mesh_instance.queue_free()
		_mesh_instance = null


func _build_arrow_images() -> void:
	var base = _build_up_arrow_image()
	for i in range(8):
		var degrees = (i * 45 + 90) % 360
		_arrow_images.append(_rotate_image(base, deg_to_rad(float(degrees))))


func _rotate_image(src: Image, angle: float) -> Image:
	var size = 32
	var cx = 15.5
	var cy = 15.5
	var result = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var cos_a = cos(-angle)
	var sin_a = sin(-angle)
	for oy in range(size):
		for ox in range(size):
			var dx = float(ox) - cx
			var dy = float(oy) - cy
			var sx = int(round(cx + dx * cos_a - dy * sin_a))
			var sy = int(round(cy + dx * sin_a + dy * cos_a))
			if sx >= 0 and sx < size and sy >= 0 and sy < size:
				result.set_pixel(ox, oy, src.get_pixel(sx, sy))
	return result


func _build_up_arrow_image() -> Image:
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var white = Color(1.0, 1.0, 1.0, 1.0)
	var transparent = Color(0.0, 0.0, 0.0, 0.0)
	for x in range(32):
		for y in range(32):
			var filled = false
			if x >= 13 and x <= 18 and y >= 14 and y <= 26:
				filled = true
			elif y >= 2 and y <= 14:
				var hw = int(round(float(y - 2) / 12.0 * 9.0))
				if x >= 15 - hw and x <= 16 + hw:
					filled = true
			img.set_pixel(x, y, white if filled else transparent)
	var result: Image = img.duplicate()
	var outline = Color(0.0, 0.0, 0.0, 0.7)
	for x in range(32):
		for y in range(32):
			if img.get_pixel(x, y).a > 0.5:
				continue
			var near = false
			for ddx in [-1, 0, 1]:
				if near:
					break
				for ddy in [-1, 0, 1]:
					if ddx == 0 and ddy == 0:
						continue
					var nx = x + ddx
					var ny = y + ddy
					if nx >= 0 and nx < 32 and ny >= 0 and ny < 32:
						if img.get_pixel(nx, ny).a > 0.5:
							near = true
							break
			if near:
				result.set_pixel(x, y, outline)
	return result
