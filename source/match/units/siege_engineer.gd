extends "res://source/match/units/Unit.gd"


func _ready():
	await super()
	add_to_group("population_units")
	add_to_group("in_crew")
	remove_from_group("controlled_units")
	var movement = find_child("Movement")
	if movement != null:
		movement.stop()
	call_deferred("_restore_selectability")


func _restore_selectability():
	var cs = find_child("CollisionShape3D")
	if cs != null:
		cs.disabled = false
