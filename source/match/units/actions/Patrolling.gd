extends "res://source/match/units/actions/Action.gd"

const AutoAttacking = preload("res://source/match/units/actions/AutoAttacking.gd")
const ArcherAutoAttacking = preload("res://source/match/units/actions/ArcherAutoAttacking.gd")

const SCAN_INTERVAL = 1.0 / 60.0 * 10.0
const WAYPOINT_RADIUS = 1.2

var _waypoint_a: Vector3
var _waypoint_b: Vector3
var _going_to_b := true

var _scan_timer: Timer = null
var _sub_action = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement = _unit.find_child("Movement")


func _init(start: Vector3, dest: Vector3):
	_waypoint_a = start
	_waypoint_b = dest


func _ready():
	_scan_timer = Timer.new()
	_scan_timer.wait_time = SCAN_INTERVAL
	_scan_timer.timeout.connect(_on_scan_timer_timeout)
	add_child(_scan_timer)
	_scan_timer.start()
	_start_leg()


func _process(_delta):
	if _sub_action != null:
		return
	var dest = _waypoint_b if _going_to_b else _waypoint_a
	if _unit.global_position.distance_to(dest) <= WAYPOINT_RADIUS:
		_going_to_b = not _going_to_b
		_start_leg()


func _start_leg():
	_movement.move(_waypoint_b if _going_to_b else _waypoint_a)


func _on_scan_timer_timeout():
	if _sub_action != null:
		return
	var targets = _nearby_enemies()
	if targets.is_empty():
		return
	_movement.stop()
	var is_archer = _unit.get_script() and _unit.get_script().resource_path.get_file() == "archer.gd"
	var action_class = ArcherAutoAttacking if is_archer else AutoAttacking
	_sub_action = action_class.new(_pick_closest(targets))
	_sub_action.tree_exited.connect(_on_sub_action_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()


func _on_sub_action_finished():
	if not is_inside_tree():
		return
	_sub_action = null
	_unit.action_updated.emit()
	_start_leg()


func _nearby_enemies() -> Array:
	return get_tree().get_nodes_in_group("units").filter(
		func(u):
			return (
				u.player != _unit.player
				and not u.is_in_group("neutral_siege")
				and u.movement_domain in _unit.attack_domains
				and _unit.global_position_yless.distance_to(u.global_position_yless)
					<= _unit.sight_range
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
