extends GridContainer

var units = []:
	set(value):
		units = value


func _unhandled_input(event):
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_Q:
		_on_unman_pressed()
		get_viewport().set_input_as_handled()


func _on_unman_pressed():
	for u in units:
		if not is_instance_valid(u):
			continue
		var crew_mgr = u.find_child("CrewManager")
		if crew_mgr != null:
			crew_mgr.unman()
