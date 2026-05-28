extends "res://source/match/units/Structure.gd"

var outer_end_capped: bool = true


func _ready():
	await super()
	add_to_group("walls")
	_update_cap_visibility()


func _update_cap_visibility():
	var cap = find_child("OuterCap")
	if cap:
		cap.visible = outer_end_capped
