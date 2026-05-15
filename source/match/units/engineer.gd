extends "res://source/match/units/Unit.gd"


func _ready():
	add_to_group("builders")
	await super()
