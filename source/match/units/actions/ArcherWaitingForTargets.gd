extends "res://source/match/units/actions/WaitingForTargets.gd"

const ArcherAutoAttacking = preload("res://source/match/units/actions/ArcherAutoAttacking.gd")


func _get_origin_yless() -> Vector3:
	if _unit.is_in_group("garrisoned") and _unit.has_meta("garrison_of"):
		return _unit.get_meta("garrison_of").global_position_yless
	return _unit.global_position_yless


func _get_units_to_attack():
	var origin = _get_origin_yless()
	var candidates = get_tree().get_nodes_in_group("units").filter(
		func(unit):
			return (
				unit.player != _unit.player
				and not unit.is_in_group("neutral_siege")
				and (
					unit.movement_domain in _unit.attack_domains
					or (_unit.is_in_group("garrisoned") and unit.is_in_group("structures"))
				)
				and origin.distance_to(unit.global_position_yless) <= _unit.sight_range
			)
	)
	return candidates


func _attack_unit(unit):
	_timer.timeout.disconnect(_on_timer_timeout)
	_sub_action = ArcherAutoAttacking.new(unit)
	_sub_action.tree_exited.connect(_on_attack_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()
