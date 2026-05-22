extends "res://source/match/units/actions/Action.gd"

const AutoAttacking = preload("res://source/match/units/actions/AutoAttacking.gd")
const ArcherAutoAttacking = preload("res://source/match/units/actions/ArcherAutoAttacking.gd")

const SCAN_INTERVAL = 1.0 / 60.0 * 10.0

var _target_position: Vector3
var _scan_timer: Timer = null
var _sub_action = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement = _unit.find_child("Movement")


static func is_applicable(unit) -> bool:
	return unit.find_child("Movement") != null and unit.attack_range != null


func _init(target_position: Vector3):
	_target_position = target_position


func _ready():
	_movement.move(_target_position)
	_movement.movement_finished.connect(_on_movement_finished)
	_scan_timer = Timer.new()
	_scan_timer.wait_time = SCAN_INTERVAL
	_scan_timer.timeout.connect(_on_scan_timer_timeout)
	add_child(_scan_timer)
	_scan_timer.start()


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
	_movement.move(_target_position)


func _on_movement_finished():
	queue_free()


func _nearby_enemies() -> Array:
	return get_tree().get_nodes_in_group("units").filter(
		func(u):
			return (
				u.player != _unit.player
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
