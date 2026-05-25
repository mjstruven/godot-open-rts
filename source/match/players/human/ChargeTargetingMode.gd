extends Node3D

signal charge_area_confirmed(start_pos: Vector3, end_pos: Vector3, direction: Vector3, length: float)

const TILE_SIZE = 1.0
const MIN_LENGTH = 2.0 * TILE_SIZE
const MAX_LENGTH = 7.0 * TILE_SIZE
const LINE_Y_OFFSET = 0.5

enum _State { INACTIVE, WAITING_START, DRAGGING }

var _state: _State = _State.INACTIVE
var _start_point: Vector3 = Vector3.ZERO
var _locked_direction: Vector3 = Vector3(0.0, 0.0, 1.0)
var _last_mouse_3d: Variant = null
var _current_mouse_3d: Variant = null
var _current_dir_index: int = 6
var _charge_mesh: ImmediateMesh = null
var _charge_mesh_instance: MeshInstance3D = null
var _arrow_images: Array = []


func _ready():
	_build_arrow_images()
	_charge_mesh = ImmediateMesh.new()
	_charge_mesh_instance = MeshInstance3D.new()
	_charge_mesh_instance.mesh = _charge_mesh
	_charge_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.1, 0.9)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	_charge_mesh_instance.material_override = mat
	add_child(_charge_mesh_instance)


func _process(_delta):
	_charge_mesh.clear_surfaces()
	if _state != _State.DRAGGING or _current_mouse_3d == null:
		return
	var n = get_tree().get_nodes_in_group("selected_units").filter(
		func(u): return u.is_in_group("controlled_units") and u.get("type") == "cavalry" and _is_charge_ready(u)
	).size()
	if n == 0:
		return
	var to_mouse = Vector3(
		_current_mouse_3d.x - _start_point.x,
		0.0,
		_current_mouse_3d.z - _start_point.z
	)
	var clamped_dist = clampf(to_mouse.dot(_locked_direction), MIN_LENGTH, MAX_LENGTH)
	var perp = _locked_direction.cross(Vector3.UP)
	var elev = Vector3(0.0, LINE_Y_OFFSET, 0.0)
	for i in range(n):
		var lateral = perp * (i - (n - 1) * 0.5)
		var a = _start_point + lateral + elev
		var b = _start_point + lateral + _locked_direction * clamped_dist + elev
		_charge_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		_charge_mesh.surface_add_vertex(a)
		_charge_mesh.surface_add_vertex(b)
		_charge_mesh.surface_end()


func enter():
	if _state != _State.INACTIVE:
		return
	if get_tree().get_nodes_in_group("placement_active").size() > 0:
		return
	var available = get_tree().get_nodes_in_group("selected_units").filter(
		func(u): return u.is_in_group("controlled_units") and u.get("type") == "cavalry" and _is_charge_ready(u)
	)
	if available.is_empty():
		return
	_state = _State.WAITING_START
	_last_mouse_3d = null
	_current_mouse_3d = null
	add_to_group("targeting_mode_active")
	DisplayServer.cursor_set_custom_image(
		_arrow_images[_current_dir_index], DisplayServer.CURSOR_ARROW, Vector2(15, 15)
	)


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
					_current_mouse_3d = pos
					_state = _State.DRAGGING
				get_viewport().set_input_as_handled()
				return
			if not event.pressed and _state == _State.DRAGGING:
				_finalize(_get_ground_pos(event.position))
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion:
		if _state == _State.WAITING_START:
			_handle_waiting_motion(event)
		elif _state == _State.DRAGGING:
			_current_mouse_3d = _get_ground_pos(event.position)


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
	_current_mouse_3d = null
	remove_from_group("targeting_mode_active")
	DisplayServer.cursor_set_custom_image(null, DisplayServer.CURSOR_ARROW)


func _get_ground_pos(screen_pos: Vector2) -> Variant:
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return null
	return Plane(Vector3.UP, 0.0).intersects_ray(
		camera.project_ray_origin(screen_pos),
		camera.project_ray_normal(screen_pos)
	)


func _finalize(end_pos: Variant):
	if end_pos == null:
		_cancel()
		return
	var to_mouse = Vector3(end_pos.x - _start_point.x, 0.0, end_pos.z - _start_point.z)
	var clamped_dist = clampf(to_mouse.dot(_locked_direction), MIN_LENGTH, MAX_LENGTH)
	var final_end = _start_point + _locked_direction * clamped_dist
	var participants = get_tree().get_nodes_in_group("selected_units").filter(
		func(u): return u.is_in_group("controlled_units") and u.get("type") == "cavalry" and _is_charge_ready(u)
	)
	var cooldown_end_ms = Time.get_ticks_msec() + 60000
	for unit in participants:
		unit.set_meta("charge_cooldown_end_ms", cooldown_end_ms)
	print("[Charge] start=%s end=%s dir=%s length=%.2f participants=%d" % [
		_start_point, final_end, _locked_direction, clamped_dist, participants.size()
	])
	charge_area_confirmed.emit(_start_point, final_end, _locked_direction, clamped_dist)
	_cancel()


func _is_charge_ready(unit) -> bool:
	return (
		not unit.has_meta("charge_cooldown_end_ms")
		or Time.get_ticks_msec() >= unit.get_meta("charge_cooldown_end_ms")
	)


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
