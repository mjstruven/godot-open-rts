extends "res://source/match/units/actions/AutoAttacking.gd"

const ArcherAttackingWhileInRange = preload(
	"res://source/match/units/actions/ArcherAttackingWhileInRange.gd"
)
const SuppressedAttacking = preload(
	"res://source/match/units/actions/SuppressedAttacking.gd"
)
const MinRangeWaiter = preload("res://source/match/units/actions/MinRangeWaiter.gd")
const FollowingToReachDistanceLocal = preload(
	"res://source/match/units/actions/FollowingToReachDistance.gd"
)

const MIN_RANGE = 1.0


func _attack_or_move_closer():
	var dist = _unit.global_position_yless.distance_to(_target_unit.global_position_yless)
	if dist < MIN_RANGE:
		_sub_action = MinRangeWaiter.new(_target_unit, MIN_RANGE)
	elif dist <= _unit.attack_range and _unit.is_in_group("suppress_armed"):
		_sub_action = SuppressedAttacking.new(_target_unit)
	elif dist <= _unit.attack_range:
		_sub_action = ArcherAttackingWhileInRange.new(_target_unit)
	else:
		_sub_action = FollowingToReachDistanceLocal.new(_target_unit, _unit.attack_range)
	_sub_action.tree_exited.connect(_on_sub_action_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()
