extends GridContainer

var units: Array = []


func _process(_delta):
	if not visible:
		return
	var any_bolstering = units.any(func(u): return is_instance_valid(u) and u.is_in_group("bolstering"))
	var btn = get_node("BolsterButton")
	if any_bolstering:
		btn.text = "CNCL"
		btn.tooltip_text = "Cancel Bolster"
	else:
		btn.text = "BLT"
		btn.tooltip_text = "Bolster"


func _handle_bolster_click():
	var any_bolstering = units.any(func(u): return is_instance_valid(u) and u.is_in_group("bolstering"))
	if any_bolstering:
		MatchSignals.combat_command_requested.emit("cancel_bolster")
	else:
		MatchSignals.combat_command_requested.emit("bolster")
