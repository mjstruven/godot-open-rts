extends "res://source/match/units/actions/AutoAttacking.gd"

const Structure = preload("res://source/match/units/Structure.gd")
const RamAttackingWhileInRange = preload(
	"res://source/match/units/actions/RamAttackingWhileInRange.gd"
)


static func is_applicable(source_unit, target_unit):
	return (
		source_unit.attack_range != null
		and "player" in target_unit
		and source_unit.player != target_unit.player
		and target_unit.movement_domain in source_unit.attack_domains
		and (target_unit is Structure or target_unit.is_in_group("siege_units"))
	)


func _get_target_radius() -> float:
	var obstacle = _target_unit.find_child("MovementObstacle")
	if obstacle != null and obstacle.affect_navigation_mesh:
		return obstacle.radius
	return 0.0


func _effective_attack_range() -> float:
	return _unit.attack_range + _get_target_radius()


func _target_in_range():
	return (
		_unit.global_position_yless.distance_to(_target_unit.global_position_yless)
		<= _effective_attack_range()
	)


func _attack_or_move_closer():
	var effective_range = _effective_attack_range()
	_sub_action = (
		RamAttackingWhileInRange.new(_target_unit, effective_range)
		if _target_in_range()
		else FollowingToReachDistance.new(_target_unit, effective_range)
	)
	_sub_action.tree_exited.connect(_on_sub_action_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()
