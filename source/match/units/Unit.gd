extends Area3D

signal selected
signal deselected
signal hp_changed
signal action_changed(new_action)
signal action_updated

const MATERIAL_ALBEDO_TO_REPLACE = Color(0.99, 0.81, 0.48)
const MATERIAL_ALBEDO_TO_REPLACE_EPSILON = 0.05

var hp = null:
	set = _set_hp
var hp_max = null:
	set = _set_hp_max
var attack_damage = null
var attack_interval = null
var attack_range = null
var attack_domains = []
var effect_radius = null
var radius:
	get = _get_radius
var movement_domain:
	get = _get_movement_domain
var movement_speed:
	get = _get_movement_speed
var sight_range = null
var player:
	get:
		return get_parent()
var color:
	get:
		return player.color
var action = null:
	set = _set_action
var global_position_yless:
	get:
		return global_position * Vector3(1, 0, 1)
var type:
	get = _get_type

const _TERRAIN_HEIGHT_EXTENSION := 5.5

var action_queue: Array = []

var _action_locked = false
var _tvs = null
var _visual_ui_nodes: Array[Node3D]
var _visual_ui_base_y: Array[float]

# --- TEMPORARY DIAGNOSTICS — remove after investigation ---
static var _diag_unit_claimed: bool = false
var _is_diag_unit: bool = false
var _diag_frame: int = 0
var _diag_sec: float = 0.0
# ----------------------------------------------------------

@onready var _match = find_parent("Match")
@onready var _geometry = find_child("Geometry")


func _ready():
	if not _match.is_node_ready():
		await _match.ready
	_setup_color()
	_setup_default_properties_from_constants()
	assert(_safety_checks())
	_collect_visual_ui_nodes()
	_extend_collision_for_terrain_elevation()
	# Claim the first infantry unit for diagnostics.
	if not _diag_unit_claimed and type == "infantry":
		_is_diag_unit = true
		_diag_unit_claimed = true
		print("[DIAG] claimed unit: ", name, " (", type, ")")


func _process(delta: float) -> void:
	_update_visual_height()
	if _is_diag_unit:
		_diag(delta)


func _update_visual_height() -> void:
	if _tvs == null:
		_tvs = get_tree().get_first_node_in_group("terrain_visual_system")
	if _tvs == null or _geometry == null:
		return
	if not _tvs.height_ready:
		return
	var h: float = _tvs.get_visual_height_at(global_position)
	var offset: float = h - global_position.y
	(_geometry as Node3D).position.y = offset
	for i: int in range(_visual_ui_nodes.size()):
		var node: Node3D = _visual_ui_nodes[i]
		if is_instance_valid(node):
			node.position.y = _visual_ui_base_y[i] + offset


func _diag(delta: float) -> void:
	# First 10 frames: check whether root position is stable.
	if _diag_frame < 10:
		_diag_frame += 1
		print("[DIAG-FRAME] ", _diag_frame, " root=", global_position)
		return
	# After that: once per second — compare the three height sources.
	_diag_sec += delta
	if _diag_sec < 1.0:
		return
	_diag_sec = 0.0
	if _tvs == null:
		return
	var h: float = _tvs.get_visual_height_at(global_position)
	var geo_world_y: float = (_geometry as Node3D).global_position.y
	var geo_local_y: float = (_geometry as Node3D).position.y
	var ray_y: float = _diag_raycast_y()
	print("[DIAG] root=", global_position,
		" get_visual_h=", h,
		" geo_local_y=", geo_local_y,
		" geo_world_y=", geo_world_y,
		" raycast_y=", ray_y)


func _diag_raycast_y() -> float:
	var space := get_world_3d().direct_space_state
	var from := Vector3(global_position.x, 500.0, global_position.z)
	var to := Vector3(global_position.x, -500.0, global_position.z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 16  # layer 5 = TerrainSurface collider
	var result := space.intersect_ray(query)
	if result.is_empty():
		return -999.0
	return (result["position"] as Vector3).y


func _collect_visual_ui_nodes() -> void:
	for child in get_children():
		if child == _geometry:
			continue
		if child is CollisionShape3D:
			continue
		if child is NavigationObstacle3D:
			continue
		if child is Node3D:
			var n: Node3D = child as Node3D
			_visual_ui_nodes.append(n)
			_visual_ui_base_y.append(n.position.y)


func _extend_collision_for_terrain_elevation() -> void:
	var cs := find_child("CollisionShape3D") as CollisionShape3D
	if cs == null or cs.shape == null:
		return
	var shape := cs.shape.duplicate()
	if shape is CylinderShape3D:
		(shape as CylinderShape3D).height += _TERRAIN_HEIGHT_EXTENSION
	elif shape is BoxShape3D:
		(shape as BoxShape3D).size.y += _TERRAIN_HEIGHT_EXTENSION
	elif shape is CapsuleShape3D:
		(shape as CapsuleShape3D).height += _TERRAIN_HEIGHT_EXTENSION
	else:
		return
	cs.position.y += _TERRAIN_HEIGHT_EXTENSION / 2.0
	cs.shape = shape as Shape3D


func is_revealing():
	return is_in_group("revealed_units") and visible


func _set_hp(value):
	var old_hp = hp
	hp = max(0, value)
	if old_hp != null and hp < old_hp:
		MatchSignals.unit_damaged.emit(self)
	hp_changed.emit()
	if hp == 0:
		_handle_unit_death()


func _set_hp_max(value):
	hp_max = value
	hp_changed.emit()


func _get_radius():
	if find_child("Movement") != null:
		return find_child("Movement").radius
	if find_child("MovementObstacle") != null:
		return find_child("MovementObstacle").radius
	return null


func _get_movement_domain():
	if find_child("Movement") != null:
		return find_child("Movement").domain
	if find_child("MovementObstacle") != null:
		return find_child("MovementObstacle").domain
	return null


func _get_movement_speed():
	if find_child("Movement") != null:
		return find_child("Movement").speed
	return 0.0


func _is_movable():
	return _get_movement_speed() > 0.0


func _setup_color():
	var material = player.get_color_material()
	Utils.Match.traverse_node_tree_and_replace_materials_matching_albedo(
		find_child("Geometry"),
		MATERIAL_ALBEDO_TO_REPLACE,
		MATERIAL_ALBEDO_TO_REPLACE_EPSILON,
		material
	)


func _set_action(action_node):
	if not is_inside_tree() or _action_locked:
		if action_node != null:
			action_node.queue_free()
		return
	_action_locked = true
	_teardown_current_action()
	action = action_node
	if action != null:
		var action_copy = action  # bind() performs copy itself, but lets force copy just in case
		action.tree_exited.connect(_on_action_node_tree_exited.bind(action_copy))
		add_child(action_node)
	_action_locked = false
	action_changed.emit(action)


func _get_type():
	var unit_script_path = get_script().resource_path
	var unit_file_name = unit_script_path.substr(unit_script_path.rfind("/") + 1)
	var unit_name = unit_file_name.split(".")[0]
	return unit_name


func _teardown_current_action():
	if action != null and action.is_inside_tree():
		action.queue_free()
		remove_child(action)  # triggers _on_action_node_tree_exited immediately


func _safety_checks():
	if movement_domain == Constants.Match.Navigation.Domain.AIR:
		assert(
			(
				radius < Constants.Match.Air.Navmesh.MAX_AGENT_RADIUS
				or is_equal_approx(radius, Constants.Match.Air.Navmesh.MAX_AGENT_RADIUS)
			),
			"Unit radius exceeds the established limit"
		)
	elif movement_domain == Constants.Match.Navigation.Domain.TERRAIN:
		assert(
			(
				not _is_movable()
				or (
					radius < Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS
					or is_equal_approx(radius, Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS)
				)
			),
			"Unit radius exceeds the established limit"
		)
	return true


func _handle_unit_death():
	tree_exited.connect(func(): MatchSignals.unit_died.emit(self))
	queue_free()


func _setup_default_properties_from_constants():
	var default_properties = Constants.Match.Units.DEFAULT_PROPERTIES[
		get_script().resource_path.replace(".gd", ".tscn")
	]
	for property in default_properties:
		set(property, default_properties[property])


func queue_action(entry: Dictionary):
	action_queue.append(entry)
	if action == null:
		_drain_action_queue()


func _drain_action_queue():
	if not action_queue.is_empty():
		action_queue.pop_front()["create"].call()


func _on_action_node_tree_exited(action_node):
	assert(action_node == action, "unexpected action released")
	action = null
	if not _action_locked:
		_drain_action_queue()
