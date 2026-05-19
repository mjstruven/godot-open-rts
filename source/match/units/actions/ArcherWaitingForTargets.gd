extends "res://source/match/units/actions/WaitingForTargets.gd"

const ArcherAutoAttacking = preload("res://source/match/units/actions/ArcherAutoAttacking.gd")


func _attack_unit(unit):
	_timer.timeout.disconnect(_on_timer_timeout)
	_sub_action = ArcherAutoAttacking.new(unit)
	_sub_action.tree_exited.connect(_on_attack_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()
