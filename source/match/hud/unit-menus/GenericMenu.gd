extends GridContainer

const Structure = preload("res://source/match/units/Structure.gd")
const ConstructingAction = preload("res://source/match/units/actions/Constructing.gd")

var units = []


func _on_cancel_action_button_pressed():
	for unit in units:
		if unit.action is ConstructingAction:
			continue
		unit.action = null
