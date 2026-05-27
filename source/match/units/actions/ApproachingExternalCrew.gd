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
	var load_dist = _unit.radius + _target.radius + Constants.Match.Terrain.Navmesh.MAX_AGENT_RADIUS + 0.2
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
	print("[STEMTRACE] _load_into_target: foot=%s weapon=%s weapon_gpos=%s foot_gpos=%s" % [_unit.name, _target.name, _target.global_position.snapped(Vector3.ONE * 0.01), _unit.global_position.snapped(Vector3.ONE * 0.01)])
	var crew_mgr = _target.find_child("ExternalCrewManager")
	if crew_mgr != null and crew_mgr.can_accept_unit(_unit):
		crew_mgr.load_unit(_unit)
	queue_free()


func _on_target_removed():
	_check_target_still_alive.call_deferred()


func _check_target_still_alive():
	if not is_inside_tree():
		return
	if (
		not is_instance_valid(_target)
		or not _target.is_inside_tree()
		or _target.is_queued_for_deletion()
	):
		queue_free()
