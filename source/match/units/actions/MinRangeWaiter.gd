extends "res://source/match/units/actions/Action.gd"

const REFRESH_INTERVAL = 1.0 / 60.0 * 10.0

var _target_unit = null
var _min_range: float

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(target_unit, min_range: float):
	_target_unit = target_unit
	_min_range = min_range


func _ready():
	_target_unit.tree_exited.connect(_on_target_removed)
	var timer = Timer.new()
	timer.timeout.connect(_check_range)
	add_child(timer)
	timer.start(REFRESH_INTERVAL)


func _check_range():
	if not is_instance_valid(_target_unit) or not _target_unit.is_inside_tree():
		queue_free()
		return
	var dist = _unit.global_position_yless.distance_to(_target_unit.global_position_yless)
	if dist >= _min_range:
		queue_free()


func _on_target_removed():
	queue_free()
