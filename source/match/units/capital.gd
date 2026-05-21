extends "res://source/match/units/Structure.gd"

@export var is_win_condition_building: bool = false


func _ready():
	await super()
	add_to_group("delivery_targets")
	add_to_group("capitals")
	effect_radius = Constants.Match.Units.CAPITAL_INFLUENCE_RADIUS
