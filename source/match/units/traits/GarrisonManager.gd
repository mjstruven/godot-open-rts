extends Node

const FOOT_SOLDIER_PATHS = [
	"res://source/match/units/infantry.tscn",
	"res://source/match/units/archer.tscn",
]
const SIEGE_PATHS = [
	"res://source/match/units/ballista.tscn",
	"res://source/match/units/trebuchet.tscn",
]
const MAX_FOOT = 4
const MAX_SIEGE = 1

const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")

var _garrisoned: Array = []

@onready var _tower = get_parent()


func garrison_count() -> int:
	return _garrisoned.size()


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


func can_accept_unit(unit) -> bool:
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
	_garrisoned.append(unit)
	unit.add_to_group("garrisoned")
	unit.set_meta("garrison_of", _tower)
	unit.action_queue.clear()
	if unit.is_in_group("selected_units"):
		unit.remove_from_group("selected_units")
		MatchSignals.unit_deselected.emit(unit)
	unit.hide()
	_set_interactive(unit, false)
	print("[Garrison] %s entered tower (total=%d)" % [unit.name, _garrisoned.size()])
	var _cs = unit.find_child("CollisionShape3D")
	print("[GTrace] garrison_unit end: unit=%s visible=%s garrisoned=%s coll_disabled=%s" % [
		unit.name, str(unit.visible), str(unit.is_in_group("garrisoned")),
		str(_cs != null and _cs.disabled)
	])


func ungarrison_all() -> void:
	_garrisoned = _garrisoned.filter(func(u): return is_instance_valid(u))
	for unit in _garrisoned.duplicate():
		_release(unit)
	_garrisoned.clear()


func kill_all_occupants() -> void:
	_garrisoned = _garrisoned.filter(func(u): return is_instance_valid(u))
	if not _garrisoned.is_empty():
		print("[Garrison] Tower destroyed with %d occupant(s)" % _garrisoned.size())
	for unit in _garrisoned.duplicate():
		if is_instance_valid(unit):
			unit.hp = 0
	_garrisoned.clear()


func _release(unit: Node) -> void:
	if not is_instance_valid(unit):
		return
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
