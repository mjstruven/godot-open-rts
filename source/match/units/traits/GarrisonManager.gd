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
const MAX_FOOT = 4
const MAX_SIEGE = 1

const INFANTRY_PATH = "res://source/match/units/infantry.tscn"
const ARCHER_PATH = "res://source/match/units/archer.tscn"

const InfantryScene = preload("res://source/match/units/infantry.tscn")
const ArcherScene = preload("res://source/match/units/archer.tscn")

const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")
const StandingGround = preload("res://source/match/units/actions/StandingGround.gd")

var _garrisoned: Array = []
var _garrisoned_slots: Dictionary = {}
var _original_type: Dictionary = {}  # occupant → "infantry" | "archer"

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
	for u in _original_type.keys().duplicate():
		if not is_instance_valid(u):
			_original_type.erase(u)


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
	if _scene_path(unit) == INFANTRY_PATH:
		_swap_garrison_infantry(unit)
	else:
		_garrison_direct(unit)
	garrison_changed.emit()


func _garrison_direct(unit: Node) -> void:
	unit.add_to_group("garrisoned")
	unit.set_meta("garrison_of", _tower)
	_garrisoned.append(unit)
	_assign_roof_slot(unit)
	var sg_applicable = StandingGround.is_applicable(unit)
	unit.action = StandingGround.new() if sg_applicable else WaitingForTargets.new()
	_original_type[unit] = "archer"
	print("[Garrison] %s entered tower (total=%d)" % [unit.name, _garrisoned.size()])


func _swap_garrison_infantry(infantry: Node) -> void:
	var hp_fraction = float(infantry.hp) / float(infantry.hp_max)
	var archer_hp_max = Constants.Match.Units.DEFAULT_PROPERTIES[ARCHER_PATH]["hp_max"]
	var archer = ArcherScene.instantiate()
	MatchSignals.setup_and_spawn_unit.emit(archer, infantry.global_transform, infantry.player)
	archer.hp = clampi(roundi(hp_fraction * archer_hp_max), 1, archer_hp_max)
	archer.add_to_group("garrisoned")
	archer.set_meta("garrison_of", _tower)
	archer.action_queue.clear()
	_garrisoned.append(archer)
	_assign_roof_slot(archer)
	var sg_applicable = StandingGround.is_applicable(archer)
	archer.action = StandingGround.new() if sg_applicable else WaitingForTargets.new()
	_original_type[archer] = "infantry"
	infantry.queue_free()
	print("[Garrison] infantry→archer swap (hp %.0f%%) — total=%d" % [hp_fraction * 100, _garrisoned.size()])


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
			_original_type.erase(unit)
			unit.hp = 0
	_garrisoned.clear()
	_garrisoned_slots.clear()
	_original_type.clear()


func _release(unit: Node) -> void:
	if not is_instance_valid(unit):
		return
	var orig_type = _original_type.get(unit, "archer")
	_original_type.erase(unit)
	if orig_type == "infantry":
		_swap_release_archer(unit)
	else:
		_release_direct(unit)


func _release_direct(unit: Node) -> void:
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


func _swap_release_archer(archer: Node) -> void:
	var hp_fraction = float(archer.hp) / float(archer.hp_max)
	var infantry_hp_max = Constants.Match.Units.DEFAULT_PROPERTIES[INFANTRY_PATH]["hp_max"]
	var angle = randf() * TAU
	var offset = Vector3(cos(angle), 0.0, sin(angle)) * (_tower.radius + 1.5)
	var eject_pos = _tower.global_position + offset
	var infantry = InfantryScene.instantiate()
	MatchSignals.setup_and_spawn_unit.emit(infantry, Transform3D(Basis.IDENTITY, eject_pos), archer.player)
	infantry.hp = clampi(roundi(hp_fraction * infantry_hp_max), 1, infantry_hp_max)
	infantry.action = WaitingForTargets.new()
	_release_slot(archer)
	archer.remove_from_group("garrisoned")
	if archer.has_meta("garrison_of"):
		archer.remove_meta("garrison_of")
	archer.queue_free()
	print("[Garrison] archer→infantry swap eject (hp %.0f%%, %s)" % [hp_fraction * 100, infantry.name])


func _set_interactive(unit: Node, on: bool) -> void:
	var cs = unit.find_child("CollisionShape3D")
	if cs != null:
		cs.disabled = not on
	var tgt = unit.find_child("Targetability")
	if tgt != null:
		var ts = tgt.find_child("CollisionShape3D")
		if ts != null:
			ts.disabled = not on
