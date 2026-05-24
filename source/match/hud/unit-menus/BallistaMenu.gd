extends GridContainer

var units = []:
	set(value):
		units = value


func _on_attack_ground_pressed():
	MatchSignals.combat_command_requested.emit("attack_ground")
