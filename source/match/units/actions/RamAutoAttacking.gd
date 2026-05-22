extends "res://source/match/units/actions/AutoAttacking.gd"

const Structure = preload("res://source/match/units/Structure.gd")


static func is_applicable(source_unit, target_unit):
	return (
		source_unit.attack_range != null
		and "player" in target_unit
		and source_unit.player != target_unit.player
		and target_unit.movement_domain in source_unit.attack_domains
		and (target_unit is Structure or target_unit.is_in_group("siege_units"))
	)
