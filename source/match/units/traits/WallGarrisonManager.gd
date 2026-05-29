extends Node

signal garrison_changed

const FOOT_SOLDIER_PATHS = [
	"res://source/match/units/infantry.tscn",
	"res://source/match/units/archer.tscn",
]
const MAX_FOOT = 6

const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")
const StandingGround = preload("res://source/match/units/actions/StandingGround.gd")
const ArcherWaitingForTargets = preload(
	"res://source/match/units/actions/ArcherWaitingForTargets.gd"
)
const InfantryWaitingForTargetsInTower = preload(
	"res://source/match/units/actions/InfantryWaitingForTargetsInTower.gd"
)

var _garrisoned: Array = []
var _slots: Dictionary = {}  # index(0-5) -> unit

@onready var _wall = get_parent()


func garrison_count() -> int:
	return _garrisoned.size()


func get_garrisoned() -> Array:
	_garrisoned = _garrisoned.filter(func(u): return is_instance_valid(u))
	return _garrisoned.duplicate()


func _scene_path(unit) -> String:
	if not unit.get_script():
		return ""
	return unit.get_script().resource_path.replace(".gd", ".tscn")


func _is_foot(unit) -> bool:
	return _scene_path(unit) in FOOT_SOLDIER_PATHS


func _cleanup_dead() -> void:
	_garrisoned = _garrisoned.filter(func(u): return is_instance_valid(u))
	for idx in _slots.keys().duplicate():
		if not is_instance_valid(_slots[idx]):
			_slots.erase(idx)


func _assign_wall_slot(unit: Node) -> void:
	_cleanup_dead()
	var slots_node = _wall.find_child("WallGarrisonSlots")
	if slots_node == null:
		return
	for i in range(MAX_FOOT):
		if not _slots.has(i):
			_slots[i] = unit
			unit.global_position = slots_node.get_child(i).global_position
			return


func _release_slot(unit: Node) -> void:
	for idx in _slots.keys():
		if _slots[idx] == unit:
			_slots.erase(idx)
			return


func can_accept_unit(unit) -> bool:
	_cleanup_dead()
	if not _is_foot(unit):
		return false
	if unit in _garrisoned:
		return false
	return _garrisoned.size() < MAX_FOOT


func garrison_unit(unit: Node) -> void:
	if not can_accept_unit(unit):
		print("[WallGarrison] Rejected %s — full or type conflict" % unit.name)
		return
	unit.action_queue.clear()
	if unit.is_in_group("selected_units"):
		unit.remove_from_group("selected_units")
		MatchSignals.unit_deselected.emit(unit)
	if unit.is_in_group("in_formation"):
		for fc in get_tree().get_nodes_in_group("formation_controller"):
			if fc._group != null and unit in fc._group.members:
				fc._group.on_member_died(unit)
				break
	_garrison_direct(unit)
	garrison_changed.emit()


func _emit_garrison_changed() -> void:
	garrison_changed.emit()


func _garrison_direct(unit: Node) -> void:
	unit.add_to_group("garrisoned")
	unit.set_meta("garrison_of", _wall)
	_garrisoned.append(unit)
	if not unit.tree_exited.is_connected(_emit_garrison_changed):
		unit.tree_exited.connect(_emit_garrison_changed)
	_assign_wall_slot(unit)
	unit.reset_terrain_visual_offset()
	if unit.type == "infantry":
		unit.action = InfantryWaitingForTargetsInTower.new()
	elif unit.type == "archer":
		unit.action = ArcherWaitingForTargets.new()
	else:
		var sg_applicable = StandingGround.is_applicable(unit)
		unit.action = StandingGround.new() if sg_applicable else WaitingForTargets.new()
	print("[WallGarrison] %s entered wall (total=%d)" % [unit.name, _garrisoned.size()])


func get_foot_count() -> int:
	_cleanup_dead()
	return _garrisoned.size()


func get_occupied_slot_indices() -> Array:
	_cleanup_dead()
	return _slots.keys()


func ungarrison_unit(unit: Node) -> void:
	if not unit in _garrisoned:
		return
	_garrisoned.erase(unit)
	_release(unit)
	garrison_changed.emit()


func ungarrison_all() -> void:
	_garrisoned = _garrisoned.filter(func(u): return is_instance_valid(u))
	for unit in _garrisoned.duplicate():
		_release(unit)
	_garrisoned.clear()
	_slots.clear()
	garrison_changed.emit()


func kill_all_occupants() -> void:
	_garrisoned = _garrisoned.filter(func(u): return is_instance_valid(u))
	if not _garrisoned.is_empty():
		print("[WallGarrison] Wall destroyed with %d occupant(s)" % _garrisoned.size())
	for unit in _garrisoned.duplicate():
		if is_instance_valid(unit):
			unit.hp = 0
	_garrisoned.clear()
	_slots.clear()


func is_contested() -> bool:
	return false


func _release(unit: Node) -> void:
	if not is_instance_valid(unit):
		return
	if unit.tree_exited.is_connected(_emit_garrison_changed):
		unit.tree_exited.disconnect(_emit_garrison_changed)
	_release_slot(unit)
	unit.remove_from_group("garrisoned")
	if unit.has_meta("garrison_of"):
		unit.remove_meta("garrison_of")
	unit.action_queue.clear()
	unit.show()
	_set_interactive(unit, true)
	print("[WallGarrison] %s exited wall" % unit.name)


func _set_interactive(unit: Node, on: bool) -> void:
	var cs = unit.find_child("CollisionShape3D")
	if cs != null:
		cs.disabled = not on
	var tgt = unit.find_child("Targetability")
	if tgt != null:
		var ts = tgt.find_child("CollisionShape3D")
		if ts != null:
			ts.disabled = not on
