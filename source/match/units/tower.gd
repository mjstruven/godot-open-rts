extends "res://source/match/units/Structure.gd"


func _ready():
	await super()
	add_to_group("towers")


func _unhandled_input(event):
	if (
		is_in_group("selected_units")
		and event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_U
	):
		var gm = find_child("GarrisonManager")
		if gm != null:
			gm.ungarrison_all()
		get_viewport().set_input_as_handled()


func _handle_unit_death():
	var gm = find_child("GarrisonManager")
	if gm != null:
		gm.kill_all_occupants()
	super()
