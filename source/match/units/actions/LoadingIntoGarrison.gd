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
	_approach_or_garrison()


func _approach_or_garrison():
	var dist_needed = _unit.radius + _target.radius + Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS + 0.2
	var dist = _unit.global_position_yless.distance_to(_target.global_position_yless)
	if dist <= dist_needed:
		_enter_garrison()
	else:
		_sub_action = FollowingToReachDistance.new(_target, dist_needed)
		_sub_action.tree_exited.connect(_on_approach_finished)
		add_child(_sub_action)


func _on_approach_finished():
	if not is_inside_tree():
		return
	_sub_action = null
	_enter_garrison()


func _enter_garrison():
	if not is_instance_valid(_target):
		queue_free()
		return
	var gm = _target.find_child("GarrisonManager")
	var can = gm != null and gm.can_accept_unit(_unit)
	if can:
		gm.garrison_unit(_unit)
	else:
		print("[Garrison] %s arrived at tower but garrison full/conflicted — standing down" % _unit.name)
	queue_free()


func _on_target_removed():
	_check_target_still_valid.call_deferred()


func _check_target_still_valid():
	if not is_inside_tree():
		return
	if (
		not is_instance_valid(_target)
		or not _target.is_inside_tree()
		or _target.is_queued_for_deletion()
	):
		queue_free()
