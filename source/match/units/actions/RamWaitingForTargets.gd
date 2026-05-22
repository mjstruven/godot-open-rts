extends "res://source/match/units/actions/WaitingForTargets.gd"

const Structure = preload("res://source/match/units/Structure.gd")
const RamAutoAttacking = preload("res://source/match/units/actions/RamAutoAttacking.gd")
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
					- _obstacle_radius_of(u)
					<= _unit.sight_range
				)
				and (u is Structure or u.is_in_group("siege_units"))
			)
	)


func _attack_unit(unit):
	_timer.timeout.disconnect(_on_timer_timeout)
	_sub_action = RamAutoAttacking.new(unit)
	_sub_action.tree_exited.connect(_on_attack_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()


func _obstacle_radius_of(unit) -> float:
	var obstacle = unit.find_child("MovementObstacle")
	if obstacle != null and obstacle.affect_navigation_mesh:
		return obstacle.radius
	return 0.0
