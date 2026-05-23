extends "res://source/match/units/actions/AutoAttacking.gd"

const BallistaAttackingWhileInRange = preload(
	"res://source/match/units/actions/BallistaAttackingWhileInRange.gd"
)

const BALLISTA_MIN_RANGE = 5.0


static func is_applicable(source_unit, target_unit) -> bool:
	var ecm = source_unit.find_child("ExternalCrewManager")
	if ecm == null or ecm.crew_count() < 2:
		return false
	return (
		source_unit.attack_range != null
		and "player" in target_unit
		and source_unit.player != target_unit.player
		and not target_unit.is_in_group("neutral_siege")
		and target_unit.get_meta("crew_siege_unit", null) != source_unit
		and target_unit.movement_domain in source_unit.attack_domains
	)


func _target_in_range() -> bool:
	var dist = _unit.global_position_yless.distance_to(_target_unit.global_position_yless)
	return dist >= BALLISTA_MIN_RANGE and dist <= _unit.attack_range


func _attack_or_move_closer():
	var dist = _unit.global_position_yless.distance_to(_target_unit.global_position_yless)
	if dist < BALLISTA_MIN_RANGE:
		queue_free()
		return
	_sub_action = (
		BallistaAttackingWhileInRange.new(_target_unit)
		if _target_in_range()
		else FollowingToReachDistance.new(_target_unit, _unit.attack_range * 0.9)
	)
	_sub_action.tree_exited.connect(_on_sub_action_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()
