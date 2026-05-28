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
const TOWER_MIN_RANGE = 2.0


func _get_origin_yless() -> Vector3:
	if _unit.is_in_group("garrisoned") and _unit.has_meta("garrison_of"):
		return _unit.get_meta("garrison_of").global_position_yless
	return _unit.global_position_yless


func _attack_or_move_closer():
	var eff_min = TOWER_MIN_RANGE if _unit.is_in_group("garrisoned") else MIN_RANGE
	var dist = _get_origin_yless().distance_to(_target_unit.global_position_yless)
	if dist < eff_min:
		_sub_action = MinRangeWaiter.new(_target_unit, eff_min)
	elif dist <= _unit.attack_range and _unit.is_in_group("suppress_armed"):
		_sub_action = SuppressedAttacking.new(_target_unit)
	elif dist <= _unit.attack_range:
		print("[TOWERATK] ArcherAutoAtt → attacking %s dist=%.1f" % [_target_unit.name, dist])
		_sub_action = ArcherAttackingWhileInRange.new(_target_unit)
	else:
		if (
			_unit.is_in_group("suppress_armed")
			or _unit.is_in_group("suppressing")
			or _unit.is_in_group("garrisoned")
		):
			print("[TOWERATK] ArcherAutoAtt out-of-range garrisoned, freeing dist=%.1f range=%.1f" % [dist, _unit.attack_range])
			queue_free()
			return
		_sub_action = FollowingToReachDistanceLocal.new(_target_unit, _unit.attack_range)
	_sub_action.tree_exited.connect(_on_sub_action_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()
