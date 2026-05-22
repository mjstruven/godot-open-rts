extends "res://source/match/units/actions/WaitingForTargets.gd"

const Structure = preload("res://source/match/units/Structure.gd")
const MIN_CREW_TO_FUNCTION = 4


func _get_units_to_attack():
	var crew_mgr = _unit.find_child("CrewManager")
	if crew_mgr == null or crew_mgr.crew_count() < MIN_CREW_TO_FUNCTION:
		return []
	return get_tree().get_nodes_in_group("units").filter(
		func(u):
			return (
				u.player != _unit.player
				and u.movement_domain in _unit.attack_domains
				and (
					_unit.global_position_yless.distance_to(u.global_position_yless)
					<= _unit.sight_range
				)
				and (u is Structure or u.is_in_group("siege_units"))
			)
	)
