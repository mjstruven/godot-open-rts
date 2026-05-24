extends GridContainer

const Structure = preload("res://source/match/units/Structure.gd")

var unit = null


func _on_stop_construction_button_pressed():
	if is_instance_valid(unit) and unit is Structure and unit.is_under_construction():
		unit.cancel_construction()
