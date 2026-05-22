extends "res://source/match/units/actions/Action.gd"

const AttackingWhileInRange = preload("res://source/match/units/actions/AttackingWhileInRange.gd")

const SCAN_INTERVAL = 1.0 / 60.0 * 10.0

var _scan_timer: Timer = null
var _sub_action = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


static func is_applicable(unit) -> bool:
	return unit.attack_range != null


func _ready():
	_scan_timer = Timer.new()
	_scan_timer.wait_time = SCAN_INTERVAL
	_scan_timer.timeout.connect(_on_scan_timer_timeout)
	add_child(_scan_timer)
	_scan_timer.start()


func _on_scan_timer_timeout():
	if _sub_action != null:
		return
	var targets = _enemies_in_range()
	if targets.is_empty():
		return
	_sub_action = AttackingWhileInRange.new(_pick_closest(targets))
	_sub_action.tree_exited.connect(_on_sub_action_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()


func _on_sub_action_finished():
	if not is_inside_tree():
		return
	_sub_action = null
	_unit.action_updated.emit()


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
