extends "res://source/match/units/actions/Action.gd"

var _target_unit = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(target_unit):
	_target_unit = target_unit


func _ready():
	_target_unit.tree_exited.connect(_on_target_gone)
	_target_unit.constructed.connect(_on_target_gone)
	_unit.get_node("Sparkling").enable()


func _on_target_gone():
	queue_free()


func _exit_tree():
	_unit.get_node("Sparkling").disable()
	if is_instance_valid(_target_unit):
		if _target_unit.constructed.is_connected(_on_target_gone):
			_target_unit.constructed.disconnect(_on_target_gone)
		if _target_unit.tree_exited.is_connected(_on_target_gone):
			_target_unit.tree_exited.disconnect(_on_target_gone)


func _process(delta):
	if (
		not Utils.Match.Unit.Movement.units_adhere(_unit, _target_unit)
		or _target_unit.is_constructed()
	):
		queue_free()
		return
	_target_unit.construct(delta * Constants.Match.Units.STRUCTURE_CONSTRUCTING_SPEED)
