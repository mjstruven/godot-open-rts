extends GridContainer

var units = []:
	set(value):
		units = value


func _on_unman_pressed():
	for u in units:
		if not is_instance_valid(u):
			continue
		var crew_mgr = u.find_child("CrewManager")
		if crew_mgr != null:
			crew_mgr.unman()
