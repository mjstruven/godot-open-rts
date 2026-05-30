extends "res://source/match/units/actions/Action.gd"

const Moving = preload("res://source/match/units/actions/Moving.gd")
const Structure = preload("res://source/match/units/Structure.gd")

const WALKWAY_Y = 1.95
const APPROACH_DISTANCE = 2.5  # Trigger elevator when unit XZ is within this distance of tower

var _target = null
var _hit_position: Vector3
var _target_wall_section = null
var _entry_tower = null
var _sub_action = null
var _entered_wall := false
var _walk_frame_count := 0

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")


func _init(target, hit_position: Vector3):
	_target = target
	_hit_position = hit_position


func _ready():
	if _unit.is_in_group("on_wall") or _unit.is_in_group("garrisoned"):
		queue_free()
		return
	if not is_instance_valid(_target) or not _target.is_inside_tree():
		queue_free()
		return
	# Resolve the target wall section.
	if _target.is_in_group("wall_towers"):
		_target_wall_section = _find_wall_section_near_point(_hit_position, _target)
	elif _target.is_in_group("walls"):
		_target_wall_section = _target
	else:
		queue_free()
		return
	if not is_instance_valid(_target_wall_section):
		_fail("No wall section found near target")
		return
	# Find nearest alive friendly tower to use as elevator entry.
	_entry_tower = _find_nearest_tower()
	if _entry_tower == null:
		_fail("No connected tower for wall access")
		return
	# Watch for target invalidation during the action.
	var watched: Array = []
	if is_instance_valid(_target):
		_target.tree_exited.connect(_on_target_invalidated)
		watched.append(_target)
	if is_instance_valid(_target_wall_section) and not (_target_wall_section in watched):
		_target_wall_section.tree_exited.connect(_on_target_invalidated)
		watched.append(_target_wall_section)
	if is_instance_valid(_entry_tower) and not (_entry_tower in watched):
		_entry_tower.tree_exited.connect(_on_target_invalidated)
	_start_approaching_tower()


func _find_wall_section_near_point(world_pos: Vector3, tower) -> Node:
	var seg_id = tower.get_meta("wall_segment_id", -1)
	if seg_id >= 0:
		var candidates: Array = []
		for ws in get_tree().get_nodes_in_group("walls"):
			if not is_instance_valid(ws) or not ws.is_inside_tree():
				continue
			if not (ws is Structure) or not ws.is_constructed():
				continue
			if ws.has_meta("wall_segment_id") and ws.get_meta("wall_segment_id") == seg_id:
				candidates.append(ws)
		if not candidates.is_empty():
			var best = null
			var best_dist := INF
			for ws in candidates:
				var d: float = Vector2(ws.global_position.x - world_pos.x, ws.global_position.z - world_pos.z).length()
				if d < best_dist:
					best_dist = d
					best = ws
			return best
	return _find_nearest_wall_section_xz(world_pos)


func _find_nearest_wall_section_xz(world_pos: Vector3) -> Node:
	var best = null
	var best_dist := INF
	for ws in get_tree().get_nodes_in_group("walls"):
		if not is_instance_valid(ws) or not ws.is_inside_tree():
			continue
		if not (ws is Structure) or not ws.is_constructed():
			continue
		var d: float = Vector2(ws.global_position.x - world_pos.x, ws.global_position.z - world_pos.z).length()
		if d < best_dist:
			best_dist = d
			best = ws
	return best


func _find_nearest_tower() -> Node:
	var unit_xz := Vector2(_unit.global_position.x, _unit.global_position.z)
	var best = null
	var best_dist := INF
	for wt in get_tree().get_nodes_in_group("wall_towers"):
		if not is_instance_valid(wt) or not wt.is_inside_tree():
			continue
		if not (wt is Structure) or not wt.is_constructed():
			continue
		if wt.player != _unit.player:
			continue
		var d: float = unit_xz.distance_to(Vector2(wt.global_position.x, wt.global_position.z))
		if d < best_dist:
			best_dist = d
			best = wt
	return best


func _process(_delta):
	if _entered_wall:
		_walk_frame_count += 1
		if _walk_frame_count % 10 == 0 and _walk_frame_count <= 180:
			var nav_target := Vector3.ZERO
			var mv = _unit.find_child("Movement")
			if mv != null and "target_position" in mv:
				nav_target = mv.target_position
			print("[WALKING-ONTO-WALL] poll frame=", _walk_frame_count, " unit_pos=", _unit.global_position, " in_on_wall=", _unit.is_in_group("on_wall"), " nav_target=", nav_target)
		return
	if _sub_action == null:
		return  # No active approach sub-action
	if not is_instance_valid(_entry_tower) or not _entry_tower.is_inside_tree():
		return  # Tower gone; _check_valid will clean up
	var unit_xz := Vector2(_unit.global_position.x, _unit.global_position.z)
	var tower_xz := Vector2(_entry_tower.global_position.x, _entry_tower.global_position.z)
	if unit_xz.distance_to(tower_xz) <= APPROACH_DISTANCE:
		print("[WALKING-ONTO-WALL] proximity reached unit=", _unit.name, " dist=", unit_xz.distance_to(tower_xz))
		var sub = _sub_action
		_sub_action = null  # Prevent re-entry before tree_exited fires
		sub.queue_free()    # _on_approach_finished fires via sub.tree_exited


func _start_approaching_tower():
	print("[WALKING-ONTO-WALL] approach_tower unit=", _unit.name, " tower=", _entry_tower.name)
	var approach_pos: Vector3 = _entry_tower.global_transform.origin
	approach_pos.y = 0.0
	_sub_action = Moving.new(approach_pos)
	_sub_action.tree_exited.connect(_on_approach_finished)
	add_child(_sub_action)


func _on_approach_finished():
	print("[WALKING-ONTO-WALL] approach_finished unit=", _unit.name, " inside_tree=", is_inside_tree(), " queued=", is_queued_for_deletion(), " unit_groups=", _unit.get_groups())
	if not is_inside_tree() or is_queued_for_deletion():
		print("[WALKING-ONTO-WALL] queue_free: approach_finished guard (not in tree or queued) unit=", _unit.name)
		return
	_sub_action = null
	if not is_instance_valid(_entry_tower) or not _entry_tower.is_inside_tree():
		print("[WALKING-ONTO-WALL] queue_free: entry_tower invalid unit=", _unit.name)
		queue_free()
		return
	print("[WALKING-ONTO-WALL] elevator unit=", _unit.name, " tower=", _entry_tower.name)
	# Add "on_wall" BEFORE teleport so _update_visual_height early-returns and doesn't fight the position.
	_unit.add_to_group("on_wall")
	_entered_wall = true
	var walkway_pos: Vector3 = _entry_tower.global_transform * Vector3(0.0, WALKWAY_Y, 0.0)
	_unit.global_position = walkway_pos
	_unit.reset_terrain_visual_offset()
	var mv = _unit.find_child("Movement")
	if mv != null:
		mv.avoidance_enabled = true
	print("[WALKING-ONTO-WALL] post_teleport unit=", _unit.name, " pos=", _unit.global_position, " in_on_wall=", _unit.is_in_group("on_wall"))
	_start_wall_walk()


func _start_wall_walk():
	if not is_instance_valid(_target_wall_section) or not _target_wall_section.is_inside_tree():
		print("[WALKING-ONTO-WALL] queue_free: target_wall_section invalid in _start_wall_walk unit=", _unit.name)
		queue_free()
		return
	var target_pos: Vector3 = _target_wall_section.global_transform * Vector3(0.0, WALKWAY_Y, 0.0)
	print("[WALKING-ONTO-WALL] wall_walk unit=", _unit.name, " target=", _target_wall_section.name, " unit_pos=", _unit.global_position, " target_pos=", target_pos)
	_sub_action = Moving.new(target_pos)
	_sub_action.tree_exited.connect(_on_wall_walk_finished)
	add_child(_sub_action)


func _on_wall_walk_finished():
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_sub_action = null
	print("[WALKING-ONTO-WALL] complete unit=", _unit.name)
	queue_free()


func _exit_tree():
	print("[WALKING-ONTO-WALL] _exit_tree unit=", _unit.name if is_instance_valid(_unit) else "null", " entered_wall=", _entered_wall, " phase=", "wall" if _entered_wall else "ground")


func _fail(reason: String):
	print("[WALKING-ONTO-WALL] queue_free: fail reason=", reason, " unit=", _unit.name)
	MatchSignals.alert_message.emit(_unit.player, reason)
	queue_free()


func _on_target_invalidated():
	_check_valid.call_deferred()


func _check_valid():
	if not is_inside_tree():
		return
	var target_bad = not is_instance_valid(_target) or not _target.is_inside_tree()
	var section_bad = not is_instance_valid(_target_wall_section) or not _target_wall_section.is_inside_tree()
	var tower_bad = not is_instance_valid(_entry_tower) or not _entry_tower.is_inside_tree()
	print("[WALKING-ONTO-WALL] check_valid unit=", _unit.name, " target_bad=", target_bad, " section_bad=", section_bad, " tower_bad=", tower_bad)
	if target_bad or section_bad or tower_bad:
		if _entered_wall:
			_unit.remove_from_group("on_wall")
		queue_free()
