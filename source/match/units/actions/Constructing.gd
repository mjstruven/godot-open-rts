extends "res://source/match/units/actions/Action.gd"

const Structure = preload("res://source/match/units/Structure.gd")
const MovingToUnit = preload("res://source/match/units/actions/MovingToUnit.gd")
const ConstructingWhileInRange = preload(
	"res://source/match/units/actions/ConstructingWhileInRange.gd"
)

var _target_unit = null
var _sub_action = null
var _queue: Array = []

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


static func is_applicable(source_unit, target_unit):
	return (
		source_unit.is_in_group("builders")
		and target_unit is Structure
		and not target_unit.is_constructed()
		and source_unit.player == target_unit.player
	)


func _init(target_unit):
	_target_unit = target_unit
	_target_unit.constructed.connect(_on_target_unit_constructed)


func _ready():
	_target_unit.builder_count += 1
	_construct_or_move_closer()


func _exit_tree():
	if is_instance_valid(_target_unit):
		_target_unit.builder_count = max(0, _target_unit.builder_count - 1)
		if _target_unit.constructed.is_connected(_on_target_unit_constructed):
			_target_unit.constructed.disconnect(_on_target_unit_constructed)


func enqueue(structure) -> void:
	if (
		is_instance_valid(structure)
		and structure is Structure
		and not structure.is_constructed()
		and is_instance_valid(_unit)
		and _unit.player == structure.player
	):
		_queue.append(structure)


func _construct_or_move_closer():
	_sub_action = (
		MovingToUnit.new(_target_unit)
		if not Utils.Match.Unit.Movement.units_adhere(_unit, _target_unit)
		else ConstructingWhileInRange.new(_target_unit)
	)
	_sub_action.tree_exited.connect(_on_sub_action_finished)
	add_child(_sub_action)
	_unit.action_updated.emit()


func _to_string():
	return "{0}({1})".format([super(), str(_sub_action) if _sub_action != null else ""])


func _on_sub_action_finished():
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if not is_instance_valid(_target_unit) or not _target_unit.is_inside_tree():
		queue_free()
		return
	_sub_action = null
	_construct_or_move_closer()


func _on_target_unit_constructed():
	if not is_inside_tree():
		return
	if _sub_action != null:
		_sub_action.tree_exited.disconnect(_on_sub_action_finished)
	while not _queue.is_empty():
		var next = _queue.pop_front()
		if (
			is_instance_valid(next)
			and next.is_inside_tree()
			and not next.is_constructed()
			and is_applicable(_unit, next)
		):
			var next_action = get_script().new(next)
			next_action._queue = _queue.duplicate()
			_unit.action = next_action
			return
	queue_free()
