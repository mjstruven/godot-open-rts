extends "res://source/match/units/Structure.gd"


func _ready():
	await super()
	add_to_group("towers")
