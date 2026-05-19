extends "res://source/match/units/Unit.gd"

const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")

@onready var rally_ability = find_child("RallyAbility")


func _ready():
	await super()
	add_to_group("flag_commanders")
	action_changed.connect(_on_action_changed)
	action = WaitingForTargets.new()


func _on_action_changed(new_action):
	if new_action == null:
		action = WaitingForTargets.new()
