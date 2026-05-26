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

const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")
const StandingGround = preload("res://source/match/units/actions/StandingGround.gd")

var _garrisoned: Array = []
var _garrisoned_slots: Dictionary = {}
var _diag_timer: float = 0.0
var _garrisoned_action_callbacks: Dictionary = {}
var _diag_prev_action: Dictionary = {}
var _diag_prev_y: Dictionary = {}

@onready var _tower = get_parent()


func _physics_process(_delta: float) -> void:
	for u in _garrisoned:
		if not is_instance_valid(u):
			continue
		var cur_y: float = u.global_position.y
		var prev_y: float = _diag_prev_y.get(u, cur_y)
		if absf(cur_y - prev_y) > 0.1:
			var action_str = str(u.action) if u.action != null else "null"
			var mv = u.find_child("Movement")
			var nav_state = "no_movement"
			if mv != null:
				nav_state = "nav_finished=%s target=%s" % [mv.is_navigation_finished(), mv.target_position]
			print("[W45d2] y_jump | %s | %.3f->%.3f | action=%s | %s" % [
				u.name, prev_y, cur_y, action_str, nav_state
			])
		_diag_prev_y[u] = cur_y


func _process(delta: float) -> void:
	if _garrisoned.is_empty():
		return
	_diag_timer += delta
	if _diag_timer < 1.0:
		return
	_diag_timer = 0.0
	_garrisoned = _garrisoned.filter(func(u): return is_instance_valid(u))
	for u in _garrisoned:
		var action_str = str(u.action) if u.action != null else "null"
		var mv = u.find_child("Movement")
		var nav_state = "no_movement"
		if mv != null:
			nav_state = "nav_finished=%s target=%s" % [mv.is_navigation_finished(), mv.target_position]
		var in_formation = u.is_in_group("in_formation")
		print("[W45diag] tick | %s | pos=%s | in_garrisoned=%s | action=%s | in_formation=%s | %s" % [
			u.name, u.global_position, u.is_in_group("garrisoned"), action_str, in_formation, nav_state
		])


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
	print("[W45diag] _assign_roof_slot | %s | slots_node=%s" % [unit.name, slots_node])
	if slots_node == null:
		print("[W45diag] _assign_roof_slot | %s | EARLY RETURN — slots_node null, pos unchanged=%s" % [unit.name, unit.global_position])
		return
	var cat = _category(unit)
	if cat == "siege":
		var total = Vector3.ZERO
		var count = 0
		for slot in slots_node.get_children():
			total += slot.global_position
			count += 1
		var before = unit.global_position
		if count > 0:
			unit.global_position = total / count
		_garrisoned_slots[unit] = ""
		print("[W45diag] _assign_roof_slot | %s | siege center | before=%s after=%s" % [unit.name, before, unit.global_position])
	else:
		var used = _garrisoned_slots.values()
		for slot in slots_node.get_children():
			if slot.name not in used:
				var before = unit.global_position
				unit.global_position = slot.global_position
				_garrisoned_slots[unit] = slot.name
				print("[W45diag] _assign_roof_slot | %s | slot=%s | before=%s after=%s" % [unit.name, slot.name, before, unit.global_position])
				return
		print("[W45diag] _assign_roof_slot | %s | NO FREE SLOT FOUND" % unit.name)


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
	_garrisoned.append(unit)
	unit.add_to_group("garrisoned")
	unit.set_meta("garrison_of", _tower)
	unit.action_queue.clear()
	if unit.is_in_group("selected_units"):
		unit.remove_from_group("selected_units")
		MatchSignals.unit_deselected.emit(unit)
	_assign_roof_slot(unit)
	var sg_applicable = StandingGround.is_applicable(unit)
	unit.action = StandingGround.new() if sg_applicable else WaitingForTargets.new()
	print("[Garrison] %s entered tower (total=%d)" % [unit.name, _garrisoned.size()])
	print("[W45diag] garrison_unit | %s | in_garrisoned=%s | sg_applicable=%s | action=%s | final_pos=%s | in_formation=%s" % [
		unit.name, unit.is_in_group("garrisoned"), sg_applicable, unit.action, unit.global_position,
		unit.is_in_group("in_formation")
	])
	var cb = _on_garrisoned_action_changed.bind(unit)
	_garrisoned_action_callbacks[unit] = cb
	_diag_prev_action[unit] = unit.action
	_diag_prev_y[unit] = unit.global_position.y
	unit.action_changed.connect(cb)
	garrison_changed.emit()


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
	_garrisoned_action_callbacks.clear()
	_diag_prev_action.clear()
	_diag_prev_y.clear()


func _on_garrisoned_action_changed(new_action: Variant, unit: Node) -> void:
	var new_str = str(new_action) if new_action != null else "null"
	var prev = _diag_prev_action.get(unit, null)
	var prev_str = str(prev) if prev != null else "null"
	_diag_prev_action[unit] = new_action
	var mv = unit.find_child("Movement")
	var nav_state = "no_movement"
	if mv != null:
		nav_state = "nav_finished=%s target=%s" % [mv.is_navigation_finished(), mv.target_position]
	print("[W45d2] action_changed | %s | %s -> %s | y=%.3f | in_garrison=%s | in_formation=%s | %s" % [
		unit.name, prev_str, new_str,
		unit.global_position.y,
		unit.is_in_group("garrisoned"),
		unit.is_in_group("in_formation"),
		nav_state
	])


func _release(unit: Node) -> void:
	if not is_instance_valid(unit):
		return
	if unit in _garrisoned_action_callbacks:
		var cb = _garrisoned_action_callbacks[unit]
		if unit.action_changed.is_connected(cb):
			unit.action_changed.disconnect(cb)
		_garrisoned_action_callbacks.erase(unit)
	_diag_prev_action.erase(unit)
	_diag_prev_y.erase(unit)
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
