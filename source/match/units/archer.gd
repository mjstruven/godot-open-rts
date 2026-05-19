extends "res://source/match/units/Unit.gd"

const ArcherWaitingForTargets = preload(
	"res://source/match/units/actions/ArcherWaitingForTargets.gd"
)


func _ready():
	await super()
	add_to_group("population_units")
	action_changed.connect(_on_action_changed)
	action = ArcherWaitingForTargets.new()


func _on_action_changed(new_action):
	if new_action == null:
		action = ArcherWaitingForTargets.new()
