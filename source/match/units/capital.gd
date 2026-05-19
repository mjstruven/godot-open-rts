extends "res://source/match/units/Structure.gd"


func _ready():
	await super()
	add_to_group("delivery_targets")
	add_to_group("capitals")
	effect_radius = Constants.Match.Units.CAPITAL_INFLUENCE_RADIUS
