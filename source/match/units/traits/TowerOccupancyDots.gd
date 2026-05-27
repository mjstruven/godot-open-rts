extends Node3D

const DOT_RADIUS := 0.08
const DOT_SPACING := 0.22
# Mid-stem face (stem body spans y=0.3–3.1). no_depth_test on materials keeps dots
# visible even though they sit inside the stem geometry when billboarded.
const DOT_HEIGHT := 1.8

const SLOT_TO_INDEX := {
	"GarrisonSlot1": 0,
	"GarrisonSlot2": 1,
	"GarrisonSlot3": 2,
	"GarrisonSlot4": 3,
	"GarrisonSlot5": 4,
	"GarrisonSlot6": 5,
	"GarrisonSlot7": 6,
	"GarrisonSlot8": 7,
	"GarrisonSlot9": 8,
}

var _dots: Array = []
var _mat_empty: StandardMaterial3D
var _mat_filled: StandardMaterial3D

@onready var _tower: Node3D = get_parent()


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


func _refresh() -> void:
	if _dots.is_empty():
		return
	var has_siege := false
	var occupied_foot_slots: Array = []
	if is_instance_valid(_tower):
		var gm = _tower.find_child("GarrisonManager")
		if gm != null:
			has_siege = gm.has_siege()
			occupied_foot_slots = gm.get_occupied_foot_slots()
	if has_siege:
		for dot in _dots:
			dot.material_override = _mat_filled
	else:
		for slot_name in SLOT_TO_INDEX.keys():
			_dots[SLOT_TO_INDEX[slot_name]].material_override = \
				_mat_filled if slot_name in occupied_foot_slots else _mat_empty
