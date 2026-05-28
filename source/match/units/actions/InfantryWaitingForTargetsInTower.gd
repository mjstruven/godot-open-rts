extends "res://source/match/units/actions/WaitingForTargets.gd"

const InfantryThrowingRockWhileInRange = preload(
	"res://source/match/units/actions/InfantryThrowingRockWhileInRange.gd"
)
const MAX_RANGE = 2.0


func _ready():
	if not _unit.is_in_group("garrisoned"):
		queue_free()
		return
	super()


func _get_units_to_attack():
	return get_tree().get_nodes_in_group("units").filter(
		func(unit):
			return (
				unit.player != _unit.player
				and not unit.is_in_group("neutral_siege")
				and unit.movement_domain in _unit.attack_domains
				and _unit.global_position_yless.distance_to(unit.global_position_yless) <= MAX_RANGE
			)
	)


func _attack_unit(unit):
	_timer.timeout.disconnect(_on_timer_timeout)
	_sub_action = InfantryThrowingRockWhileInRange.new(unit)
	_sub_action.tree_exited.connect(_on_attack_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()
