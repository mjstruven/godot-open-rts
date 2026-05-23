extends "res://source/match/units/actions/WaitingForTargets.gd"

const TrebuchetAutoAttacking = preload(
	"res://source/match/units/actions/TrebuchetAutoAttacking.gd"
)
const Structure = preload("res://source/match/units/Structure.gd")

const TREB_MIN_RANGE = 7.0


func _get_units_to_attack():
	var ecm = _unit.find_child("ExternalCrewManager")
	if ecm == null or ecm.crew_count() < 2:
		return []
	if _unit.get_pack_state() != "UNPACKED":
		return []
	return get_tree().get_nodes_in_group("units").filter(
		func(u):
			if u.player == _unit.player:
				return false
			if u.is_in_group("neutral_siege"):
				return false
			if u.has_meta("crew_siege_unit") and u.get_meta("crew_siege_unit") == _unit:
				return false
			if u.movement_domain not in _unit.attack_domains:
				return false
			var dist = _unit.global_position_yless.distance_to(u.global_position_yless)
			return dist >= TREB_MIN_RANGE and dist <= _unit.sight_range
	)


func _on_timer_timeout():
	var units = _get_units_to_attack()
	if not units.is_empty():
		_attack_unit(_pick_best_target(units))


func _pick_best_target(units: Array) -> Node:
	var siege = units.filter(func(u): return u.is_in_group("siege_units"))
	if not siege.is_empty():
		return _pick_closest_unit(siege, _unit)
	var structs = units.filter(func(u): return u is Structure)
	if not structs.is_empty():
		return _pick_closest_unit(structs, _unit)
	return _pick_closest_unit(units, _unit)


func _attack_unit(unit):
	_timer.timeout.disconnect(_on_timer_timeout)
	_sub_action = TrebuchetAutoAttacking.new(unit)
	_sub_action.tree_exited.connect(_on_attack_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()
