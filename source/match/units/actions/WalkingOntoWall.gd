extends "res://source/match/units/actions/Action.gd"

const Moving = preload("res://source/match/units/actions/Moving.gd")

# Perpendicular offset from wall body: half-extent (0.8 m) + 1.5 m clearance.
const APPROACH_LOCAL_Z = 2.3

var _wall_section = null
var _clicked_world_pos: Vector3
var _sub_action = null

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(wall_section, clicked_world_pos: Vector3):
	_wall_section = wall_section
	_clicked_world_pos = clicked_world_pos


func _ready():
	if _unit.is_in_group("on_wall") or _unit.is_in_group("garrisoned"):
		queue_free()
		return
	if not is_instance_valid(_wall_section) or not _wall_section.is_inside_tree():
		queue_free()
		return
	_wall_section.tree_exited.connect(_on_wall_removed)
	_sub_action = Moving.new(_compute_approach_position())
	_sub_action.tree_exited.connect(_on_approach_finished)
	add_child(_sub_action)


func _compute_approach_position() -> Vector3:
	var local_unit: Vector3 = _wall_section.global_transform.affine_inverse() * _unit.global_position
	var side_z := -APPROACH_LOCAL_Z if local_unit.z < 0.0 else APPROACH_LOCAL_Z
	var result: Vector3 = _wall_section.global_transform * Vector3(0.0, 0.0, side_z)
	return result


func _compute_wall_top_position() -> Vector3:
	var local_click: Vector3 = _wall_section.global_transform.affine_inverse() * _clicked_world_pos
	var clamped_x := clampf(local_click.x, -1.4, 1.4)
	var result: Vector3 = _wall_section.global_transform * Vector3(clamped_x, 1.95, 0.0)
	return result


func _on_approach_finished():
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_sub_action = null
	if not is_instance_valid(_wall_section) or not _wall_section.is_inside_tree():
		queue_free()
		return
	_unit.global_position = _compute_wall_top_position()
	_unit.reset_terrain_visual_offset()
	_unit.add_to_group("on_wall")
	var mv = _unit.find_child("Movement")
	if mv != null:
		mv.avoidance_enabled = true
	queue_free()


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
