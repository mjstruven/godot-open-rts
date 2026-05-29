extends Node3D

const DOT_RADIUS := 0.08
const DOT_SPACING := 0.22
const DOT_HEIGHT := 2.5

var _dots: Array = []
var _mat_empty: StandardMaterial3D
var _mat_filled: StandardMaterial3D

@onready var _wall: Node3D = get_parent()


func _ready() -> void:
	top_level = true
	_mat_empty = StandardMaterial3D.new()
	_mat_empty.albedo_color = Color(0.3, 0.3, 0.3)
	_mat_empty.no_depth_test = true
	_mat_filled = StandardMaterial3D.new()
	_mat_filled.albedo_color = Color(1.0, 1.0, 1.0)
	_mat_filled.no_depth_test = true
	var mesh := SphereMesh.new()
	mesh.radius = DOT_RADIUS
	mesh.height = DOT_RADIUS * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	for row in range(2):
		for col in range(3):
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.position = Vector3(
				(col - 1) * DOT_SPACING,
				(0.5 - row) * DOT_SPACING,
				0.0
			)
			add_child(mi)
			_dots.append(mi)
	var gm = _wall.find_child("WallGarrisonManager")
	if gm != null:
		gm.garrison_changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if not is_instance_valid(_wall):
		return
	global_position = _wall.global_position + Vector3(0.0, DOT_HEIGHT, 0.0)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_transform.basis = camera.global_transform.basis


func _refresh() -> void:
	if _dots.is_empty():
		return
	var occupied: Array = []
	if is_instance_valid(_wall):
		var gm = _wall.find_child("WallGarrisonManager")
		if gm != null:
			occupied = gm.get_occupied_slot_indices()
	for i in range(_dots.size()):
		_dots[i].material_override = _mat_filled if i in occupied else _mat_empty
