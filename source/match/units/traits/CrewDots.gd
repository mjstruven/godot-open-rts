extends Node3D

const Human = preload("res://source/match/players/human/Human.gd")

const DOT_SPACING := 0.18
const DOT_RADIUS := 0.05
const GAP_EVERY := 4
const GAP_EXTRA := 0.06
const DOTS_PER_ROW := 12
const ROW_SPACING := 0.16

@export var crew_count_public: bool = true
@export var dot_height: float = 1.15

var _dot_meshes: Array = []
var _mat_empty: StandardMaterial3D
var _mat_filled: StandardMaterial3D
var _parent_unit: Node3D


func _ready() -> void:
	var crew_mgr = get_parent().find_child("CrewManager")
	if crew_mgr == null:
		return
	_parent_unit = get_parent()
	top_level = true
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
	var num_rows: int = (cap + DOTS_PER_ROW - 1) / DOTS_PER_ROW
	for i in range(cap):
		var row: int = i / DOTS_PER_ROW
		var col: int = i % DOTS_PER_ROW
		var row_size: int = mini(DOTS_PER_ROW, cap - row * DOTS_PER_ROW)
		var last_col: int = row_size - 1
		var row_total_x: float = last_col * DOT_SPACING + (last_col / GAP_EVERY) * GAP_EXTRA
		var gap_off: float = (col / GAP_EVERY) * GAP_EXTRA
		var row_y: float = (float(num_rows - 1) * 0.5 - float(row)) * ROW_SPACING
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(col * DOT_SPACING + gap_off - row_total_x * 0.5, row_y, 0.0)
		add_child(mi)
		_dot_meshes.append(mi)
	crew_mgr.crew_changed.connect(_on_crew_changed)
	_update_dots(crew_mgr.crew_count())


func _process(_delta: float) -> void:
	if _parent_unit == null or not is_instance_valid(_parent_unit):
		return
	global_position = _parent_unit.global_position + Vector3(0.0, dot_height, 0.0)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_transform.basis = camera.global_transform.basis
	if not crew_count_public:
		visible = _parent_unit.is_in_group("controlled_units")


func _on_crew_changed(new_count: int) -> void:
	_update_dots(new_count)


func _update_dots(filled: int) -> void:
	for i in range(_dot_meshes.size()):
		_dot_meshes[i].material_override = _mat_filled if i < filled else _mat_empty
