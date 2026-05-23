extends "res://source/match/units/Unit.gd"


func _ready():
	await super()
	add_to_group("population_units")
	remove_from_group("controlled_units")
	var movement = find_child("Movement")
	if movement != null:
		movement.stop()
