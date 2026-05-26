extends "res://source/match/units/Structure.gd"


func _ready():
	await super()
	add_to_group("towers")


func _handle_unit_death():
	var gm = find_child("GarrisonManager")
	if gm != null:
		gm.kill_all_occupants()
	super()
