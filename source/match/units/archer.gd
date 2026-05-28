extends "res://source/match/units/Unit.gd"

const ArcherWaitingForTargets = preload(
	"res://source/match/units/actions/ArcherWaitingForTargets.gd"
)

var _base_attack_range := 0.0
var _base_sight_range := 0.0


func _ready():
	await super()
	_base_attack_range = attack_range
	_base_sight_range = sight_range
	add_to_group("population_units")
	action_changed.connect(_on_action_changed)
	action = ArcherWaitingForTargets.new()


func _process(delta: float) -> void:
	super(delta)
	var in_tower = is_in_group("garrisoned")
	attack_range = _base_attack_range + (2.0 if in_tower else 0.0)
	sight_range = _base_sight_range + (2.0 if in_tower else 0.0)


func _on_action_changed(new_action):
	if new_action == null and not is_in_group("in_crew"):
		action = ArcherWaitingForTargets.new()
