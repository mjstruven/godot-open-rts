extends "res://source/match/units/actions/AttackingWhileInRange.gd"

var _effective_range: float


func _init(target_unit, effective_range: float):
	super._init(target_unit)
	_effective_range = effective_range


func _teardown_if_out_of_range():
	if (
		_unit.global_position_yless.distance_to(_target_unit.global_position_yless)
		> _effective_range
	):
		queue_free()
		return true
	return false
