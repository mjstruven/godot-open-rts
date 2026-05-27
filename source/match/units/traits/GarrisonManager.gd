extends Node

signal garrison_changed

const FOOT_SOLDIER_PATHS = [
	"res://source/match/units/infantry.tscn",
	"res://source/match/units/archer.tscn",
]
const SIEGE_PATHS = [
	"res://source/match/units/ballista.tscn",
	"res://source/match/units/trebuchet.tscn",
]
const MAX_FOOT = 9
const MAX_SIEGE = 1

const InertAction = preload("res://source/match/units/actions/Action.gd")
const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")
const StandingGround = preload("res://source/match/units/actions/StandingGround.gd")

var _garrisoned: Array = []
var _garrisoned_slots: Dictionary = {}

@onready var _tower = get_parent()


func garrison_count() -> int:
	return _garrisoned.size()


func get_garrisoned() -> Array:
	_garrisoned = _garrisoned.filter(func(u): return is_instance_valid(u))
	return _garrisoned.duplicate()


func _scene_path(unit) -> String:
	if not unit.get_script():
		return ""
	return unit.get_script().resource_path.replace(".gd", ".tscn")


func _category(unit) -> String:
	var p = _scene_path(unit)
	if p in FOOT_SOLDIER_PATHS:
		return "foot"
	if p in SIEGE_PATHS:
		return "siege"
	return ""


func _cleanup_dead() -> void:
	_garrisoned = _garrisoned.filter(func(u): return is_instance_valid(u))
	for u in _garrisoned_slots.keys().duplicate():
		if not is_instance_valid(u):
			_garrisoned_slots.erase(u)


func _assign_roof_slot(unit: Node) -> void:
	_cleanup_dead()
	var slots_node = _tower.find_child("GarrisonSlots")
	if slots_node == null:
		return
	var cat = _category(unit)
	if cat == "siege":
		var total = Vector3.ZERO
		var count = 0
		for slot in slots_node.get_children():
			total += slot.global_position
			count += 1
		if count > 0:
			unit.global_position = total / count
		_garrisoned_slots[unit] = ""
	else:
		var used = _garrisoned_slots.values()
		for slot in slots_node.get_children():
			if slot.name not in used:
				unit.global_position = slot.global_position
				_garrisoned_slots[unit] = slot.name
				return


func _release_slot(unit: Node) -> void:
	_garrisoned_slots.erase(unit)


func can_accept_unit(unit) -> bool:
	_cleanup_dead()
	var cat = _category(unit)
	if cat == "":
		return false
	if unit in _garrisoned:
		return false
	if cat == "foot":
		if _garrisoned.any(func(u): return _category(u) == "siege"):
			return false
		return _garrisoned.size() < MAX_FOOT
	if cat == "siege":
		return _garrisoned.is_empty()
	return false


func garrison_unit(unit: Node) -> void:
	if not can_accept_unit(unit):
		print("[Garrison] Rejected %s — full or type conflict" % unit.name)
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


func _garrison_direct(unit: Node) -> void:
	unit.add_to_group("garrisoned")
	unit.set_meta("garrison_of", _tower)
	_garrisoned.append(unit)
	_assign_roof_slot(unit)
	unit.reset_terrain_visual_offset()
	var ecm = unit.find_child("ExternalCrewManager")
	if ecm != null:
		var engineers = ecm.get_all_engineers()
		for eng in engineers:
			if is_instance_valid(eng):
				eng.add_to_group("garrisoned")
				eng.reset_terrain_visual_offset()
		print("[Garrison] %s crew on roof (%d engineers)" % [unit.name, engineers.size()])
	if unit.type == "infantry":
		unit.action = InertAction.new()
	else:
		var sg_applicable = StandingGround.is_applicable(unit)
		unit.action = StandingGround.new() if sg_applicable else WaitingForTargets.new()
	print("[Garrison] %s entered tower (total=%d)" % [unit.name, _garrisoned.size()])


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
	garrison_changed.emit()


func kill_all_occupants() -> void:
	_garrisoned = _garrisoned.filter(func(u): return is_instance_valid(u))
	if not _garrisoned.is_empty():
		print("[Garrison] Tower destroyed with %d occupant(s)" % _garrisoned.size())
	for unit in _garrisoned.duplicate():
		if is_instance_valid(unit):
			unit.hp = 0
	_garrisoned.clear()
	_garrisoned_slots.clear()


func _release(unit: Node) -> void:
	if not is_instance_valid(unit):
		return
	var ecm = unit.find_child("ExternalCrewManager")
	if ecm != null:
		for eng in ecm.get_all_engineers():
			if is_instance_valid(eng):
				eng.remove_from_group("garrisoned")
	_release_slot(unit)
	unit.remove_from_group("garrisoned")
	if unit.has_meta("garrison_of"):
		unit.remove_meta("garrison_of")
	unit.action_queue.clear()
	unit.show()
	_set_interactive(unit, true)
	var angle = randf() * TAU
	var offset = Vector3(cos(angle), 0.0, sin(angle)) * (_tower.radius + 1.5)
	unit.global_position = _tower.global_position + offset
	unit.action = WaitingForTargets.new()
	print("[Garrison] %s exited tower" % unit.name)


func _set_interactive(unit: Node, on: bool) -> void:
	var cs = unit.find_child("CollisionShape3D")
	if cs != null:
		cs.disabled = not on
	var tgt = unit.find_child("Targetability")
	if tgt != null:
		var ts = tgt.find_child("CollisionShape3D")
		if ts != null:
			ts.disabled = not on
