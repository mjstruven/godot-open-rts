extends "res://source/match/units/actions/Action.gd"

const Moving = preload("res://source/match/units/actions/Moving.gd")

# Same perpendicular offset as LoadingIntoWallSection: 1.5 m outside wall body (±0.8 m half-extent).
const EXIT_LOCAL_Z = 2.3

var _destination: Vector3
var _sub_action = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(destination: Vector3):
	_destination = destination


func _ready():
	if not _unit.is_in_group("garrisoned") or not _unit.has_meta("garrison_of"):
		queue_free()
		return
	var source_wall = _unit.get_meta("garrison_of")
	if not is_instance_valid(source_wall) or not source_wall.is_in_group("walls"):
		queue_free()
		return
	var wgm = source_wall.find_child("WallGarrisonManager")
	if wgm == null:
		queue_free()
		return
	# Release slot — removes from "garrisoned" group and clears garrison_of meta.
	wgm.ungarrison_unit(_unit)
	# Teleport to ground on the wall side nearest the destination.
	_unit.global_position = _compute_exit_position(source_wall)
	_unit.reset_terrain_visual_offset()
	# Walk to destination on ground navmesh.
	_sub_action = Moving.new(_destination)
	_sub_action.tree_exited.connect(_on_move_finished)
	add_child(_sub_action)


func _compute_exit_position(source_wall: Node3D) -> Vector3:
	var local_dest_z = (source_wall.global_transform.affine_inverse() * _destination).z
	var side_z = -EXIT_LOCAL_Z if local_dest_z < 0.0 else EXIT_LOCAL_Z
	return source_wall.global_transform * Vector3(0.0, 0.0, side_z)


func _on_move_finished():
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_sub_action = null
	queue_free()
