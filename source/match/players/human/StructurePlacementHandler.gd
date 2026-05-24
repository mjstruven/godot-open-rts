extends Node3D

const Circle3D = preload("res://source/generic-scenes-and-nodes/3d/Circle3D.gd")

enum BlueprintPositionValidity {
	VALID,
	COLLIDES_WITH_OBJECT,
	NOT_NAVIGABLE,
	NOT_ENOUGH_RESOURCES,
	OUT_OF_MAP,
	NO_MILL_AT_LOCATION,
	WITHIN_CAPITAL_INFLUENCE,
	INVALID_TERRAIN_TYPE,
	TOO_CLOSE_TO_SAME_TYPE,
}

const ROTATION_BY_KEY_STEP = 45.0
const SAME_TYPE_EXCLUSION_RADIUS = Constants.Match.Units.CAPITAL_INFLUENCE_RADIUS
const ROTATION_DEAD_ZONE_DISTANCE = 0.1
const MANOR_SNAP_RADIUS = 10.0

const MATERIALS_ROOT = "res://source/match/resources/materials/"
const BLUEPRINT_VALID_PATH = MATERIALS_ROOT + "blueprint_valid.material.tres"
const BLUEPRINT_INVALID_PATH = MATERIALS_ROOT + "blueprint_invalid.material.tres"

var _active_blueprint_node = null
var _pending_structure_radius = null
var _pending_structure_navmap_rid = null
var _pending_structure_prototype = null
var _blueprint_rotating = false
var _placement_selections = []
var _exclusion_circles: Array = []

@onready var _player = get_parent()
@onready var _match = find_parent("Match")
@onready var _feedback_label = find_child("FeedbackLabel3D")


func _ready():
	_feedback_label.hide()
	MatchSignals.place_structure.connect(_on_structure_placement_request)


func _unhandled_input(event):
	if not _structure_placement_started():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_lmb_down_event(event)
	if event.is_action_pressed("rotate_structure"):
		_try_rotating_blueprint_by(ROTATION_BY_KEY_STEP)
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		_handle_lmb_up_event(event)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_handle_rmb_event(event)
	if event is InputEventMouseMotion:
		_handle_mouse_motion_event(event)


func _handle_lmb_down_event(_event):
	get_viewport().set_input_as_handled()
	_start_blueprint_rotation()


func _handle_lmb_up_event(_event):
	get_viewport().set_input_as_handled()
	var blueprint_position_validity = _calculate_blueprint_position_validity()
	if blueprint_position_validity == BlueprintPositionValidity.VALID:
		_finish_structure_placement()
	elif blueprint_position_validity == BlueprintPositionValidity.NOT_ENOUGH_RESOURCES:
		MatchSignals.not_enough_resources_for_construction.emit(_player)
	_finish_blueprint_rotation()


func _handle_rmb_event(event):
	get_viewport().set_input_as_handled()
	if event.pressed:
		_finish_blueprint_rotation()
		_cancel_structure_placement()


func _handle_mouse_motion_event(_event):
	get_viewport().set_input_as_handled()
	if _blueprint_rotation_started():
		_rotate_blueprint_towards_mouse_pos()
	else:
		_set_blueprint_position_based_on_mouse_pos()
	var blueprint_position_validity = _calculate_blueprint_position_validity()
	_update_feedback_label(blueprint_position_validity)
	_update_blueprint_color(blueprint_position_validity == BlueprintPositionValidity.VALID)


func _structure_placement_started():
	return _active_blueprint_node != null


func _blueprint_rotation_started():
	return _blueprint_rotating == true


func _calculate_blueprint_position_validity():
	if FeatureFlags.skip_placement_validation:
		return BlueprintPositionValidity.VALID
	if _active_bluprint_out_of_map():
		return BlueprintPositionValidity.OUT_OF_MAP
	if not _player_has_enough_resources():
		return BlueprintPositionValidity.NOT_ENOUGH_RESOURCES
	if _is_placing_manor():
		return _calculate_manor_placement_validity()
	if _is_placing_mill():
		if not TerrainManager.is_valid_mill_placement(
			_active_blueprint_node.global_position, _get_mill_type()
		):
			return BlueprintPositionValidity.INVALID_TERRAIN_TYPE
		if _too_close_to_same_type_mill():
			return BlueprintPositionValidity.TOO_CLOSE_TO_SAME_TYPE
	var placement_validity = Utils.Match.Unit.Placement.validate_agent_placement_position(
		_active_blueprint_node.global_position,
		_pending_structure_radius,
		get_tree().get_nodes_in_group("units") + get_tree().get_nodes_in_group("resource_units"),
		_pending_structure_navmap_rid
	)
	if placement_validity == Utils.Match.Unit.Placement.COLLIDES_WITH_AGENT:
		return BlueprintPositionValidity.COLLIDES_WITH_OBJECT
	if placement_validity == Utils.Match.Unit.Placement.NOT_NAVIGABLE:
		return BlueprintPositionValidity.NOT_NAVIGABLE
	return BlueprintPositionValidity.VALID


func _is_placing_manor() -> bool:
	return (
		_pending_structure_prototype != null
		and _pending_structure_prototype.resource_path.ends_with("manor.tscn")
	)


func _is_placing_mill() -> bool:
	if _pending_structure_prototype == null:
		return false
	var path = _pending_structure_prototype.resource_path
	return (
		path.ends_with("grain_mill.tscn")
		or path.ends_with("lumber_mill.tscn")
		or path.ends_with("stone_mill.tscn")
	)


func _get_mill_type() -> String:
	if _pending_structure_prototype == null:
		return ""
	var path = _pending_structure_prototype.resource_path
	if path.ends_with("grain_mill.tscn"):
		return "grain_mill"
	if path.ends_with("lumber_mill.tscn"):
		return "lumber_mill"
	if path.ends_with("stone_mill.tscn"):
		return "stone_mill"
	return ""


func _calculate_manor_placement_validity():
	var pos = _active_blueprint_node.global_position
	if not _has_player_mill_at(pos):
		return BlueprintPositionValidity.NO_MILL_AT_LOCATION
	if _within_capital_influence(pos):
		return BlueprintPositionValidity.WITHIN_CAPITAL_INFLUENCE
	return BlueprintPositionValidity.VALID


func _has_player_mill_at(pos: Vector3) -> bool:
	for mill in get_tree().get_nodes_in_group("mills"):
		if mill.player != _player or not mill.is_constructed():
			continue
		var dist = (mill.global_position * Vector3(1, 0, 1)).distance_to(pos * Vector3(1, 0, 1))
		if dist <= mill.radius + 1.0:
			return true
	return false


func _get_same_type_exclusion_radius() -> float:
	if _get_mill_type() == "grain_mill":
		return CultivationManager.GRAIN_MILL_EXCLUSION_RADIUS
	return SAME_TYPE_EXCLUSION_RADIUS


func _too_close_to_same_type_mill() -> bool:
	var mill_type: String = _get_mill_type()
	if mill_type.is_empty():
		return false
	var pos: Vector3 = _active_blueprint_node.global_position
	var exclusion_r := _get_same_type_exclusion_radius()
	for mill in get_tree().get_nodes_in_group("mills"):
		if not mill.is_constructed():
			continue
		if mill.type != mill_type:
			continue
		var dist: float = (mill.global_position * Vector3(1, 0, 1)).distance_to(pos * Vector3(1, 0, 1))
		if dist < exclusion_r:
			return true
	return false


func _within_capital_influence(pos: Vector3) -> bool:
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.player != _player:
			continue
		if not unit.get_script().resource_path.ends_with("capital.gd"):
			continue
		if not unit.has_method("is_constructed") or not unit.is_constructed():
			continue
		var dist = (unit.global_position * Vector3(1, 0, 1)).distance_to(pos * Vector3(1, 0, 1))
		if dist <= Constants.Match.Units.CAPITAL_INFLUENCE_RADIUS:
			return true
	return false


func _player_has_enough_resources():
	var construction_cost = Constants.Match.Units.CONSTRUCTION_COSTS[
		_pending_structure_prototype.resource_path
	]
	return _player.has_resources(construction_cost)


func _active_bluprint_out_of_map():
	return not Geometry2D.is_point_in_polygon(
		Vector2(
			_active_blueprint_node.global_transform.origin.x,
			_active_blueprint_node.global_transform.origin.z
		),
		_match.map.get_topdown_polygon_2d()
	)


func _update_feedback_label(blueprint_position_validity):
	_feedback_label.visible = (blueprint_position_validity != BlueprintPositionValidity.VALID)
	match blueprint_position_validity:
		BlueprintPositionValidity.COLLIDES_WITH_OBJECT:
			_feedback_label.text = tr("BLUEPRINT_COLLIDES_WITH_OBJECT")
		BlueprintPositionValidity.NOT_NAVIGABLE:
			_feedback_label.text = tr("BLUEPRINT_NOT_NAVIGABLE")
		BlueprintPositionValidity.NOT_ENOUGH_RESOURCES:
			_feedback_label.text = tr("BLUEPRINT_NOT_ENOUGH_RESOURCES")
		BlueprintPositionValidity.OUT_OF_MAP:
			_feedback_label.text = tr("BLUEPRINT_OUT_OF_MAP")
		BlueprintPositionValidity.NO_MILL_AT_LOCATION:
			_feedback_label.text = "Must be placed on a mill"
		BlueprintPositionValidity.WITHIN_CAPITAL_INFLUENCE:
			_feedback_label.text = "Too close to capital"
		BlueprintPositionValidity.INVALID_TERRAIN_TYPE:
			match _get_mill_type():
				"grain_mill":
					_feedback_label.text = "Grain Mills must be placed on Grassland"
				"lumber_mill":
					_feedback_label.text = "Lumber Mills must be placed adjacent to Forest (not inside)"
				"stone_mill":
					_feedback_label.text = "Stone Mills must be placed adjacent to Rocky terrain (not inside)"
		BlueprintPositionValidity.TOO_CLOSE_TO_SAME_TYPE:
			_feedback_label.text = "Too close to another %s" % _get_mill_type().replace("_", " ")


func _start_structure_placement(structure_prototype):
	if _structure_placement_started():
		return
	add_to_group("placement_active")
	_pending_structure_prototype = structure_prototype
	_active_blueprint_node = (
		load(Constants.Match.Units.STRUCTURE_BLUEPRINTS[structure_prototype.resource_path])
		. instantiate()
	)
	var blueprint_origin = Vector3(-999, 0, -999)
	var camera_direction_yless = (
		(get_viewport().get_camera_3d().project_ray_normal(Vector2(0, 0)) * Vector3(1, 0, 1))
		. normalized()
	)
	var rotate_towards = blueprint_origin + camera_direction_yless.rotated(Vector3.UP, PI * 0.75)
	_active_blueprint_node.global_transform = Transform3D(Basis(), blueprint_origin).looking_at(
		rotate_towards, Vector3.UP
	)
	add_child(_active_blueprint_node)
	var temporary_structure_instance = _pending_structure_prototype.instantiate()
	_pending_structure_radius = temporary_structure_instance.radius
	_pending_structure_navmap_rid = (
		find_parent("Match")
		. navigation
		. get_navigation_map_rid_by_domain(temporary_structure_instance.movement_domain)
	)
	temporary_structure_instance.free()
	_show_placement_range_circles()
	_show_same_type_exclusion_circles()


func _show_placement_range_circles():
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.is_in_group("mills"):
			continue
		if not ("effect_radius" in unit) or unit.effect_radius == null or unit.effect_radius <= 0.0:
			continue
		var sel = unit.find_child("Selection")
		if sel != null and sel.has_method("show_range_for_placement"):
			sel.show_range_for_placement()
			_placement_selections.append(sel)


func _hide_placement_range_circles():
	for sel in _placement_selections:
		if is_instance_valid(sel):
			sel.hide_range_for_placement()
	_placement_selections.clear()


func _show_same_type_exclusion_circles() -> void:
	if not _is_placing_mill():
		return
	var mill_type: String = _get_mill_type()
	var exclusion_r := _get_same_type_exclusion_radius()
	for mill in get_tree().get_nodes_in_group("mills"):
		if not mill.is_constructed() or mill.type != mill_type:
			continue
		var circle := Circle3D.new()
		circle.radius = exclusion_r
		circle.width = 3.0
		circle.color = Color.WHITE
		circle.render_priority = 3
		add_child(circle)
		circle.global_position = Vector3(mill.global_position.x, 0.1, mill.global_position.z)
		_exclusion_circles.append(circle)


func _hide_same_type_exclusion_circles() -> void:
	for circle in _exclusion_circles:
		if is_instance_valid(circle):
			circle.queue_free()
	_exclusion_circles.clear()


func _get_visual_height_at(pos: Vector3) -> float:
	var tvs = get_tree().get_first_node_in_group("terrain_visual_system")
	if tvs == null or not tvs.height_ready:
		return 0.0
	return tvs.get_visual_height_at(pos)


func _set_blueprint_position_based_on_mouse_pos():
	var mouse_pos_2d = get_viewport().get_mouse_position()
	var mouse_pos_3d = get_viewport().get_camera_3d().get_ray_intersection(mouse_pos_2d)
	if mouse_pos_3d == null:
		return
	if _is_placing_manor():
		var snap = _find_nearest_player_mill(mouse_pos_3d)
		if snap != null:
			var snap_y := _get_visual_height_at(snap)
			_active_blueprint_node.global_transform.origin = Vector3(snap.x, snap_y, snap.z)
			_feedback_label.global_transform.origin = Vector3(snap.x, snap_y, snap.z)
			return
	var visual_y := _get_visual_height_at(mouse_pos_3d)
	_active_blueprint_node.global_transform.origin = Vector3(mouse_pos_3d.x, visual_y, mouse_pos_3d.z)
	_feedback_label.global_transform.origin = Vector3(mouse_pos_3d.x, visual_y, mouse_pos_3d.z)


func _find_nearest_player_mill(mouse_pos: Vector3):
	var nearest = null
	var nearest_dist = MANOR_SNAP_RADIUS
	for mill in get_tree().get_nodes_in_group("mills"):
		if mill.player != _player or not mill.is_constructed():
			continue
		var dist = (mill.global_position * Vector3(1, 0, 1)).distance_to(mouse_pos * Vector3(1, 0, 1))
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = mill
	return nearest.global_position if nearest != null else null


func _update_blueprint_color(blueprint_position_is_valid):
	var material_to_set = (
		preload(BLUEPRINT_VALID_PATH)
		if blueprint_position_is_valid
		else preload(BLUEPRINT_INVALID_PATH)
	)
	for child in _active_blueprint_node.find_children("*"):
		if "material_override" in child:
			child.material_override = material_to_set


func _cancel_structure_placement():
	if _structure_placement_started():
		_hide_placement_range_circles()
		_hide_same_type_exclusion_circles()
		_feedback_label.hide()
		_active_blueprint_node.queue_free()
		_active_blueprint_node = null
		remove_from_group("placement_active")


func _finish_structure_placement():
	if _player_has_enough_resources():
		var construction_cost = Constants.Match.Units.CONSTRUCTION_COSTS[
			_pending_structure_prototype.resource_path
		]
		_player.subtract_resources(construction_cost)
		var spawn_transform: Transform3D = _active_blueprint_node.global_transform
		spawn_transform.origin.y = 0.0
		MatchSignals.setup_and_spawn_unit.emit(
			_pending_structure_prototype.instantiate(),
			spawn_transform,
			_player
		)
		if Input.is_key_pressed(KEY_SHIFT):
			var proto = _pending_structure_prototype
			_cancel_structure_placement()
			_start_structure_placement(proto)
			return
	_cancel_structure_placement()


func _start_blueprint_rotation():
	_blueprint_rotating = true


func _try_rotating_blueprint_by(degrees):
	if not _structure_placement_started():
		return
	_active_blueprint_node.global_transform.basis = (
		_active_blueprint_node.global_transform.basis.rotated(Vector3.UP, deg_to_rad(degrees))
	)


func _rotate_blueprint_towards_mouse_pos():
	var mouse_pos_2d = get_viewport().get_mouse_position()
	var mouse_pos_3d = get_viewport().get_camera_3d().get_ray_intersection(mouse_pos_2d)
	if mouse_pos_3d == null:
		return
	var mouse_pos_yless = mouse_pos_3d * Vector3(1, 0, 1)
	var blueprint_pos_3d = _active_blueprint_node.global_transform.origin
	var blueprint_pos_yless = blueprint_pos_3d * Vector3(-999, 0, -999)
	if mouse_pos_yless.distance_to(blueprint_pos_yless) < ROTATION_DEAD_ZONE_DISTANCE:
		return
	var rotation_target = Vector3(mouse_pos_yless.x, blueprint_pos_3d.y, mouse_pos_yless.z)
	if rotation_target.is_equal_approx(_active_blueprint_node.global_transform.origin):
		return
	_active_blueprint_node.global_transform = _active_blueprint_node.global_transform.looking_at(
		rotation_target, Vector3.UP
	)


func _finish_blueprint_rotation():
	_blueprint_rotating = false


func _on_structure_placement_request(structure_prototype):
	if get_tree().get_nodes_in_group("targeting_mode_active").size() > 0:
		return
	_start_structure_placement(structure_prototype)
