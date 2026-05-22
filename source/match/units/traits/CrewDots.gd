extends Node3D

const DOT_SPACING := 0.18
const DOT_RADIUS := 0.05
const GAP_EVERY := 4
const GAP_EXTRA := 0.06
const DOT_HEIGHT := 1.0

var _dot_meshes: Array = []
var _mat_empty: StandardMaterial3D
var _mat_filled: StandardMaterial3D


func _ready() -> void:
	var crew_mgr = get_parent().find_child("CrewManager")
	if crew_mgr == null:
		return
	var cap: int = crew_mgr.capacity
	_mat_empty = StandardMaterial3D.new()
	_mat_empty.albedo_color = Color(0.3, 0.3, 0.3)
	_mat_filled = StandardMaterial3D.new()
	_mat_filled.albedo_color = Color(1.0, 1.0, 1.0)
	var mesh := SphereMesh.new()
	mesh.radius = DOT_RADIUS
	mesh.height = DOT_RADIUS * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var last_i := cap - 1
	var total_x: float = last_i * DOT_SPACING + (last_i / GAP_EVERY) * GAP_EXTRA
	for i in range(cap):
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var gap_off: float = (i / GAP_EVERY) * GAP_EXTRA
		mi.position = Vector3(i * DOT_SPACING + gap_off - total_x * 0.5, DOT_HEIGHT, 0.0)
		add_child(mi)
		_dot_meshes.append(mi)
	crew_mgr.crew_changed.connect(_on_crew_changed)
	_update_dots(crew_mgr.crew_count())


func _on_crew_changed(new_count: int) -> void:
	_update_dots(new_count)


func _update_dots(filled: int) -> void:
	for i in range(_dot_meshes.size()):
		_dot_meshes[i].material_override = _mat_filled if i < filled else _mat_empty
