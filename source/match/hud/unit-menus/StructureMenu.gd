extends GridContainer

const Structure = preload("res://source/match/units/Structure.gd")

var unit = null


func _unhandled_input(event):
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_Q:
		_on_stop_construction_button_pressed()
		get_viewport().set_input_as_handled()


func _on_stop_construction_button_pressed():
	if is_instance_valid(unit) and unit is Structure and unit.is_under_construction():
		unit.cancel_construction()
