extends Node3D

const DOT_RADIUS := 0.05
const DOT_SPACING := 0.15
const DOT_HEIGHT := 1.8

# 3x3 grid, indexed row-major (0=top-left, 8=bottom-right).
# Corner slots house foot soldiers; cross slots are occupied by siege.
const FOOT_INDICES := [0, 2, 6, 8]
const SIEGE_INDICES := [1, 3, 4, 5, 7]

var _dots: Array = []
var _mat_empty: StandardMaterial3D
var _mat_foot: StandardMaterial3D
var _mat_siege: StandardMaterial3D

@onready var _tower: Node3D = get_parent()


func _ready() -> void:
	top_level = true
	_build_materials()
	_build_dots()
	var gm = _tower.find_child("GarrisonManager")
	if gm != null:
		gm.garrison_changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	if not is_instance_valid(_tower):
		return
	global_position = _tower.global_position + Vector3(0.0, DOT_HEIGHT, 0.0)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_transform.basis = camera.global_transform.basis


func _build_materials() -> void:
	_mat_empty = StandardMaterial3D.new()
	_mat_empty.albedo_color = Color(0.3, 0.3, 0.3)
	_mat_empty.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_foot = StandardMaterial3D.new()
	_mat_foot.albedo_color = Color(1.0, 1.0, 1.0)
	_mat_foot.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_siege = StandardMaterial3D.new()
	_mat_siege.albedo_color = Color(0.9, 0.7, 0.1)
	_mat_siege.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _build_dots() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = DOT_RADIUS
	mesh.height = DOT_RADIUS * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	for row in range(3):
		for col in range(3):
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.position = Vector3(
				(col - 1) * DOT_SPACING,
				(1 - row) * DOT_SPACING,
				0.0
			)
			add_child(mi)
			_dots.append(mi)


func _refresh() -> void:
	var has_siege := false
	var foot_count := 0
	if is_instance_valid(_tower):
		var gm = _tower.find_child("GarrisonManager")
		if gm != null:
			has_siege = gm.has_siege()
			foot_count = gm.get_foot_count()
	for i in SIEGE_INDICES:
		_dots[i].material_override = _mat_siege if has_siege else _mat_empty
	for j in range(FOOT_INDICES.size()):
		_dots[FOOT_INDICES[j]].material_override = _mat_foot if j < foot_count else _mat_empty
