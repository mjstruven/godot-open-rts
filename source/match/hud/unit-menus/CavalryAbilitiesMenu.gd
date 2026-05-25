extends GridContainer

var units: Array = []

func _handle_charge_click():
	MatchSignals.combat_command_requested.emit("charge")
