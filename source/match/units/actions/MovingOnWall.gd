extends "res://source/match/units/actions/Action.gd"

const Moving = preload("res://source/match/units/actions/Moving.gd")
const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")

# Ground exit offset when garrison fails at arrival (same as LoadingIntoWallSection).
const FALLBACK_EXIT_Z = 2.3

var _target_wall = null
var _sub_action = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(target_wall):
	_target_wall = target_wall


func _ready():
	if not _unit.is_in_group("garrisoned") or not _unit.has_meta("garrison_of"):
		queue_free()
		return
	var source_wall = _unit.get_meta("garrison_of")
	if not is_instance_valid(source_wall) or not source_wall.is_in_group("walls"):
		queue_free()
		return
	if not is_instance_valid(_target_wall) or not _target_wall.is_inside_tree():
		queue_free()
		return
	var target_wgm = _target_wall.find_child("WallGarrisonManager")
	if target_wgm == null or not target_wgm.can_accept_unit(_unit):
		queue_free()
		return
	# Release from source wall slot (removes from "garrisoned" group, clears garrison_of meta).
	var source_wgm = source_wall.find_child("WallGarrisonManager")
	if source_wgm != null:
		source_wgm.ungarrison_unit(_unit)
	# Re-enter "garrisoned" group so terrain anchoring stays suppressed during walk.
	if not _unit.is_in_group("garrisoned"):
		_unit.add_to_group("garrisoned")
	_target_wall.tree_exited.connect(_on_target_removed)
	var target_top = _target_wall.global_transform * Vector3(0.0, 1.95, 0.0)
	_sub_action = Moving.new(target_top)
	_sub_action.tree_exited.connect(_on_move_finished)
	add_child(_sub_action)


func _on_move_finished():
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_sub_action = null
	if not is_instance_valid(_target_wall) or not _target_wall.is_inside_tree():
		_unit.remove_from_group("garrisoned")
		queue_free()
		return
	var target_wgm = _target_wall.find_child("WallGarrisonManager")
	var can_accept = target_wgm != null and target_wgm.can_accept_unit(_unit)
	if can_accept:
		# garrison_unit re-adds to "garrisoned", sets garrison_of meta, snaps to slot, assigns action.
		target_wgm.garrison_unit(_unit)
	else:
		# Target full on arrival: teleport down to ground near target wall.
		_unit.remove_from_group("garrisoned")
		_unit.global_position = _target_wall.global_transform * Vector3(0.0, 0.0, FALLBACK_EXIT_Z)
		_unit.reset_terrain_visual_offset()
		_unit.action = WaitingForTargets.new()
	queue_free()


func _on_target_removed():
	_check_target_valid.call_deferred()


func _check_target_valid():
	if not is_inside_tree():
		return
	if (
		not is_instance_valid(_target_wall)
		or not _target_wall.is_inside_tree()
		or _target_wall.is_queued_for_deletion()
	):
		_unit.remove_from_group("garrisoned")
		queue_free()
