extends "res://source/match/units/Unit.gd"

const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")
const InfantryWaitingForTargetsInTower = preload(
	"res://source/match/units/actions/InfantryWaitingForTargetsInTower.gd"
)


func _ready():
	await super()
	add_to_group("population_units")
	action_changed.connect(_on_action_changed)
	action = WaitingForTargets.new()


func _on_action_changed(new_action):
	print("[TOWERATK] infantry._on_action_changed new=%s garrisoned=%s" % [str(new_action), str(is_in_group("garrisoned"))])
	if new_action == null and not is_in_group("in_crew"):
		if is_in_group("garrisoned"):
			action = InfantryWaitingForTargetsInTower.new()
		else:
			action = WaitingForTargets.new()
