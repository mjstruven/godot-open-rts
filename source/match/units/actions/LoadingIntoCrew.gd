extends "res://source/match/units/actions/Action.gd"

const FollowingToReachDistance = preload(
	"res://source/match/units/actions/FollowingToReachDistance.gd"
)

var _target = null
var _sub_action = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(target):
	_target = target


func _ready():
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		queue_free()
		return
	_target.tree_exited.connect(_on_target_removed)
	_approach_or_load()


func _approach_or_load():
	var load_dist = _unit.radius + _target.radius + 0.5
	var dist = _unit.global_position_yless.distance_to(_target.global_position_yless)
	if dist <= load_dist:
		_load_into_target()
	else:
		_sub_action = FollowingToReachDistance.new(_target, load_dist)
		_sub_action.tree_exited.connect(_on_approach_finished)
		add_child(_sub_action)


func _on_approach_finished():
	if not is_inside_tree():
		return
	_sub_action = null
	_load_into_target()


func _load_into_target():
	if not is_instance_valid(_target):
		queue_free()
		return
	var crew_mgr = _target.find_child("CrewManager")
	if crew_mgr != null and crew_mgr.can_accept_unit(_unit):
		crew_mgr.load_unit(_unit)
	queue_free()


func _on_target_removed():
	queue_free()
