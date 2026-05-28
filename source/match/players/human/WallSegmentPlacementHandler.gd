extends Node3D

const WallSectionGeo = preload(
	"res://source/match/units/structure-geometries/WallSectionGeometry.tscn"
)
const WallTowerGeo = preload(
	"res://source/match/units/structure-geometries/TowerGeometry.tscn"
)
const WallSectionUnit = preload("res://source/match/units/wall_section.tscn")
const WallTowerUnit = preload("res://source/match/units/wall_tower.tscn")

const WALL_SEGMENT_COST = {"stone": 150}
const ROTATION_STEP = 45.0
const WALL_OFFSET = 2.3

const BLUEPRINT_VALID_PATH = "res://source/match/resources/materials/blueprint_valid.material.tres"
const BLUEPRINT_INVALID_PATH = "res://source/match/resources/materials/blueprint_invalid.material.tres"

var _ghost: Node3D = null
var _rotation_deg: float = 0.0

@onready var _player = get_parent()
@onready var _match = find_parent("Match")


func _ready():
	MatchSignals.place_wall_segment.connect(_on_wall_segment_placement_request)


func _unhandled_input(event):
	if _ghost == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		get_viewport().set_input_as_handled()
		_try_place()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		get_viewport().set_input_as_handled()
		_cancel()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		get_viewport().set_input_as_handled()
		_rotate_by(ROTATION_STEP)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		get_viewport().set_input_as_handled()
		_rotate_by(-ROTATION_STEP)
		return
	if event.is_action_pressed("rotate_structure"):
		_rotate_by(ROTATION_STEP)
		return
	if event is InputEventMouseMotion:
		get_viewport().set_input_as_handled()
		_update_ghost_position()
		_update_ghost_color()


func _on_wall_segment_placement_request():
	if _ghost != null:
		return
	if get_tree().get_nodes_in_group("targeting_mode_active").size() > 0:
		return
	if get_tree().get_nodes_in_group("placement_active").size() > 0:
		return
	_create_ghost()


func _create_ghost():
	add_to_group("placement_active")
	_ghost = Node3D.new()
	add_child(_ghost)
	_rotation_deg = 0.0

	var tower_geo = WallTowerGeo.instantiate()
	_ghost.add_child(tower_geo)
	tower_geo.position = Vector3.ZERO

	var left_geo = WallSectionGeo.instantiate()
	_ghost.add_child(left_geo)
	left_geo.position = Vector3(-WALL_OFFSET, 0, 0)

	var right_geo = WallSectionGeo.instantiate()
	_ghost.add_child(right_geo)
	right_geo.position = Vector3(WALL_OFFSET, 0, 0)
	right_geo.rotation_degrees.y = 180.0

	_ghost.global_position = Vector3(-999, 0, -999)


func _update_ghost_position():
	if _ghost == null:
		return
	var mouse_pos_2d = get_viewport().get_mouse_position()
	var mouse_pos_3d = get_viewport().get_camera_3d().get_ray_intersection(mouse_pos_2d)
	if mouse_pos_3d == null:
		return
	var tvs = get_tree().get_first_node_in_group("terrain_visual_system")
	var visual_y: float = 0.0
	if tvs != null and tvs.height_ready:
		visual_y = tvs.get_visual_height_at(mouse_pos_3d)
	_ghost.global_position = Vector3(mouse_pos_3d.x, visual_y, mouse_pos_3d.z)


func _rotate_by(degrees: float):
	_rotation_deg += degrees
	_ghost.rotation_degrees.y = _rotation_deg


func _update_ghost_color():
	if _ghost == null:
		return
	var is_valid = _is_placement_valid()
	var mat = (
		preload(BLUEPRINT_VALID_PATH)
		if is_valid
		else preload(BLUEPRINT_INVALID_PATH)
	)
	for child in _ghost.find_children("*"):
		if "material_override" in child:
			child.material_override = mat


func _is_placement_valid() -> bool:
	if _ghost == null:
		return false
	if not _player.has_resources(WALL_SEGMENT_COST):
		return false
	if not Geometry2D.is_point_in_polygon(
		Vector2(_ghost.global_position.x, _ghost.global_position.z),
		_match.map.get_topdown_polygon_2d()
	):
		return false
	return true


func _try_place():
	if not _is_placement_valid():
		if _ghost != null and not _player.has_resources(WALL_SEGMENT_COST):
			MatchSignals.not_enough_resources_for_construction.emit(_player)
		return
	_player.subtract_resources(WALL_SEGMENT_COST)
	_spawn_segment()
	_cancel()


func _spawn_segment():
	var origin = _ghost.global_position
	origin.y = 0.0
	var basis = _ghost.global_transform.basis

	var tower = WallTowerUnit.instantiate()
	MatchSignals.setup_and_spawn_unit.emit(tower, Transform3D(basis, origin), _player)

	var left_offset = basis * Vector3(-WALL_OFFSET, 0, 0)
	var left = WallSectionUnit.instantiate()
	MatchSignals.setup_and_spawn_unit.emit(left, Transform3D(basis, origin + left_offset), _player)

	var right_offset = basis * Vector3(WALL_OFFSET, 0, 0)
	var right_basis = basis.rotated(Vector3.UP, PI)
	var right = WallSectionUnit.instantiate()
	MatchSignals.setup_and_spawn_unit.emit(right, Transform3D(right_basis, origin + right_offset), _player)


func _cancel():
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	remove_from_group("placement_active")
