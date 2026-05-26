extends GridContainer

var units = []:
	set(value):
		units = value


func _on_attack_ground_pressed():
	MatchSignals.combat_command_requested.emit("attack_ground")


func _on_abandon_pressed():
	for u in units:
		if not is_instance_valid(u):
			continue
		var ecm = u.find_child("ExternalCrewManager")
		if ecm != null:
			ecm.abandon()
