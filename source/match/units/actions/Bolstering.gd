extends "res://source/match/units/actions/Action.gd"

const SCAN_INTERVAL = 1.0 / 60.0 * 10.0
const AttackingWhileInRange = preload("res://source/match/units/actions/AttackingWhileInRange.gd")

var _scan_timer: Timer = null
var _sub_action = null
var _marker: MeshInstance3D = null
var _original_speed: float = 0.0

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement = _unit.find_child("Movement")


func _ready():
	_unit.add_to_group("bolstering")
	if _movement != null:
		_original_speed = _movement.speed
		_movement.speed = _original_speed * 0.1
	_marker = _create_marker()
	_scan_timer = Timer.new()
	_scan_timer.wait_time = SCAN_INTERVAL
	_scan_timer.timeout.connect(_on_scan)
	add_child(_scan_timer)
	_scan_timer.start()


func _exit_tree():
	if is_instance_valid(_unit):
		_unit.remove_from_group("bolstering")
	if is_instance_valid(_movement) and _original_speed > 0.0:
		_movement.speed = _original_speed
	if is_instance_valid(_marker):
		_marker.queue_free()
		_marker = null


func _on_scan():
	if _sub_action != null:
		return
	var targets = _enemies_in_range()
	if targets.is_empty():
		return
	_sub_action = AttackingWhileInRange.new(_pick_closest(targets))
	_sub_action.tree_exited.connect(_on_sub_action_finished)
	add_child(_sub_action)


func _on_sub_action_finished():
	if not is_inside_tree():
		return
	_sub_action = null


func _enemies_in_range() -> Array:
	return get_tree().get_nodes_in_group("units").filter(
		func(u):
			return (
				u.player != _unit.player
				and not u.is_in_group("neutral_siege")
				and u.movement_domain in _unit.attack_domains
				and _unit.global_position_yless.distance_to(u.global_position_yless)
					<= _unit.attack_range
			)
	)


func _pick_closest(targets: Array):
	var best = targets[0]
	var best_d = _unit.global_position_yless.distance_to(best.global_position_yless)
	for t in targets:
		var d = _unit.global_position_yless.distance_to(t.global_position_yless)
		if d < best_d:
			best_d = d
			best = t
	return best


func _create_marker() -> MeshInstance3D:
	var marker = MeshInstance3D.new()
	var mesh = ImmediateMesh.new()
	marker.mesh = mesh
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.BLACK
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	marker.material_override = mat
	var s: float = 0.15
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	mesh.surface_add_vertex(Vector3(-s, 0.0, -s))
	mesh.surface_add_vertex(Vector3(s, 0.0, s))
	mesh.surface_end()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	mesh.surface_add_vertex(Vector3(-s, 0.0, s))
	mesh.surface_add_vertex(Vector3(s, 0.0, -s))
	mesh.surface_end()
	marker.position = Vector3(0.0, 0.0, 0.0)
	_unit.add_child(marker)
	return marker
