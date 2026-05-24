extends GridContainer

var units = []:
	set(value):
		units = value


func _unhandled_input(event):
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_E:
		_on_attack_ground_pressed()
		get_viewport().set_input_as_handled()


func _on_attack_ground_pressed():
	MatchSignals.combat_command_requested.emit("attack_ground")
