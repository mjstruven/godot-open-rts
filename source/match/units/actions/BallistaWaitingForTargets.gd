extends "res://source/match/units/actions/WaitingForTargets.gd"

const BallistaAutoAttacking = preload(
	"res://source/match/units/actions/BallistaAutoAttacking.gd"
)

const MIN_RANGE = 3.0


func _get_units_to_attack():
	var ecm = _unit.find_child("ExternalCrewManager")
	if ecm == null or ecm.crew_count() < 2:
		return []
	return get_tree().get_nodes_in_group("units").filter(
		func(u):
			if u.player == _unit.player:
				return false
			if u.is_in_group("neutral_siege"):
				return false
			if u.is_in_group("walls"):
				return false
			if u.has_meta("crew_siege_unit") and u.get_meta("crew_siege_unit") == _unit:
				return false
			if u.movement_domain not in _unit.attack_domains:
				return false
			var dist = _unit.global_position_yless.distance_to(u.global_position_yless)
			return dist >= MIN_RANGE and dist <= _unit.sight_range
	)


func _attack_unit(unit):
	_timer.timeout.disconnect(_on_timer_timeout)
	_sub_action = BallistaAutoAttacking.new(unit)
	_sub_action.tree_exited.connect(_on_attack_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()
