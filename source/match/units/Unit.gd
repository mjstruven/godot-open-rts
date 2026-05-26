extends Area3D

signal selected
signal deselected
signal hp_changed
signal action_changed(new_action)
signal action_updated

const MATERIAL_ALBEDO_TO_REPLACE = Color(0.99, 0.81, 0.48)
const MATERIAL_ALBEDO_TO_REPLACE_EPSILON = 0.05
const DEATH_MARKER_FULL_DURATION = 5.0    # seconds at full opacity (tunable)
const DEATH_MARKER_FADE_DURATION = 5.0    # seconds to fade out (tunable)
const DEATH_MARKER_FULL_ALPHA = 0.75      # opacity while full (tunable)
const DEATH_MARKER_FADED_ALPHA = 0.0      # opacity at end of fade (tunable)
const DEATH_MARKER_COLOR_UNIT = Color(0.85, 0.0, 0.0)    # red — regular units
const DEATH_MARKER_COLOR_HEAVY = Color(0.0, 0.0, 0.0)    # black — siege and structures
const _ArcherAutoAttackingScript = preload(
	"res://source/match/units/actions/ArcherAutoAttacking.gd"
)

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
		if has_meta("crew_siege_unit"):
			return get_meta("crew_siege_unit").player
		return get_parent()
var color:
	get:
		if is_in_group("neutral_siege"):
			return Color.WHITE
		var p = player
		if not p.has_method("get_color_material"):
			return Color.WHITE
		return p.color
var action = null:
	set = _set_action
var global_position_yless:
	get:
		return global_position * Vector3(1, 0, 1)
var type:
	get = _get_type

var action_queue: Array = []

var _action_locked = false
var _tvs = null
var _visual_ui_nodes: Array[Node3D]
var _visual_ui_base_y: Array[float]
var _cs_base_y: float = 0.0

@onready var _match = find_parent("Match")
@onready var _geometry = find_child("Geometry")
@onready var _collision_shape = find_child("CollisionShape3D") as CollisionShape3D


func _ready():
	if not _match.is_node_ready():
		await _match.ready
	_setup_color()
	_setup_default_properties_from_constants()
	assert(_safety_checks())
	_collect_visual_ui_nodes()
	if _collision_shape != null:
		_cs_base_y = _collision_shape.position.y


func _process(_delta: float) -> void:
	_update_visual_height()


func _update_visual_height() -> void:
	if is_in_group("garrisoned"):
		return
	if _tvs == null:
		_tvs = get_tree().get_first_node_in_group("terrain_visual_system")
	if _tvs == null or _geometry == null:
		return
	if not _tvs.height_ready:
		return
	var h: float = _tvs.get_visual_height_at(global_position)
	var offset: float = h - global_position.y
	(_geometry as Node3D).position.y = offset
	if _collision_shape != null:
		_collision_shape.position.y = _cs_base_y + offset
	for i: int in range(_visual_ui_nodes.size()):
		var node: Node3D = _visual_ui_nodes[i]
		if is_instance_valid(node):
			node.position.y = _visual_ui_base_y[i] + offset


func reset_terrain_visual_offset() -> void:
	if _geometry != null:
		(_geometry as Node3D).position.y = 0.0
	if _collision_shape != null:
		_collision_shape.position.y = _cs_base_y
	for i: int in range(_visual_ui_nodes.size()):
		var node: Node3D = _visual_ui_nodes[i]
		if is_instance_valid(node):
			node.position.y = _visual_ui_base_y[i]


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
	if is_in_group("suppressing") and action_node != null:
		action_node.queue_free()
		return
	if is_in_group("suppress_armed") and action_node != null and not (action_node is _ArcherAutoAttackingScript):
		action_node.queue_free()
		return
	if is_in_group("charging") and action_node != null:
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


func _is_structure() -> bool:
	return false


func _handle_unit_death():
	_spawn_death_marker()
	tree_exited.connect(func(): MatchSignals.unit_died.emit(self))
	queue_free()


func _spawn_death_marker():
	if _match == null or not is_instance_valid(_match):
		return
	var r = radius
	if r == null or r <= 0.0:
		return
	var base_color: Color
	if is_in_group("siege_units") or _is_structure():
		base_color = DEATH_MARKER_COLOR_HEAVY
	else:
		base_color = DEATH_MARKER_COLOR_UNIT
	var full_color = Color(base_color.r, base_color.g, base_color.b, DEATH_MARKER_FULL_ALPHA)
	var faded_color = Color(base_color.r, base_color.g, base_color.b, DEATH_MARKER_FADED_ALPHA)
	var marker = MeshInstance3D.new()
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = r
	cylinder.bottom_radius = r
	cylinder.height = 0.01
	cylinder.radial_segments = 24
	marker.mesh = cylinder
	var mat = StandardMaterial3D.new()
	mat.albedo_color = full_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = false
	marker.material_override = mat
	_match.add_child(marker)
	if _tvs == null:
		_tvs = get_tree().get_first_node_in_group("terrain_visual_system")
	var ground_y = 0.0
	if _tvs != null and _tvs.height_ready:
		ground_y = _tvs.get_visual_height_at(global_position)
	marker.global_position = Vector3(global_position.x, ground_y + 0.005, global_position.z)
	var tween = _match.create_tween()
	tween.tween_interval(DEATH_MARKER_FULL_DURATION)
	tween.tween_property(mat, "albedo_color", faded_color, DEATH_MARKER_FADE_DURATION)
	tween.tween_callback(func(): if is_instance_valid(marker): marker.queue_free())


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
