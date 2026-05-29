extends "res://source/match/units/actions/Action.gd"

const Moving = preload("res://source/match/units/actions/Moving.gd")

# Approach point: wall-body half-extent (0.8 m) + 1.5 m clearance = 2.3 m from wall centre
const APPROACH_LOCAL_Z = 2.3

var _wall_section = null
var _sub_action = null
var _garrisoned_successfully := false

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(wall_section):
	_wall_section = wall_section


func _ready():
	if _unit.is_in_group("garrisoned"):
		queue_free()
		return
	if not is_instance_valid(_wall_section) or not _wall_section.is_inside_tree():
		queue_free()
		return
	var wgm = _wall_section.find_child("WallGarrisonManager")
	if wgm == null or not wgm.reserve_slot(_unit):
		print("[LoadingIntoWallSection] %s: wall full or unit type rejected" % _unit.name)
		queue_free()
		return
	_wall_section.tree_exited.connect(_on_wall_removed)
	_sub_action = Moving.new(_compute_approach_position())
	_sub_action.tree_exited.connect(_on_approach_finished)
	add_child(_sub_action)


func _compute_approach_position() -> Vector3:
	# Project unit into wall local space to pick the nearer long side (local Z = ±0.8).
	var local_unit_z = (_wall_section.global_transform.affine_inverse() * _unit.global_position).z
	var side_z = -APPROACH_LOCAL_Z if local_unit_z < 0.0 else APPROACH_LOCAL_Z
	return _wall_section.global_transform * Vector3(0.0, 0.0, side_z)


func _on_approach_finished():
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_sub_action = null
	if not is_instance_valid(_wall_section) or not _wall_section.is_inside_tree():
		queue_free()
		return
	var wgm = _wall_section.find_child("WallGarrisonManager")
	if wgm == null:
		queue_free()
		return
	# garrison_unit consumes the reservation and handles slot assignment.
	wgm.garrison_unit(_unit)
	_garrisoned_successfully = true
	queue_free()


func _exit_tree():
	if _garrisoned_successfully:
		return
	if not is_instance_valid(_wall_section) or not _wall_section.is_inside_tree():
		return
	var wgm = _wall_section.find_child("WallGarrisonManager")
	if wgm != null:
		wgm.release_reservation(_unit)


func _on_wall_removed():
	_check_wall_valid.call_deferred()


func _check_wall_valid():
	if not is_inside_tree():
		return
	if (
		not is_instance_valid(_wall_section)
		or not _wall_section.is_inside_tree()
		or _wall_section.is_queued_for_deletion()
	):
		queue_free()
