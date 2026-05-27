extends Node

signal crew_changed(new_count)

@export var capacity: int = 4
@export var slot_radius: float = 0.8

const CREWABLE_SCENE_PATHS = [
	"res://source/match/units/infantry.tscn",
	"res://source/match/units/archer.tscn",
]
const Human = preload("res://source/match/players/human/Human.gd")

# Each entry: { engineer: Node, original_player: Node, on_died: Callable }
# "engineer" key kept for API compatibility — now holds the locked infantry/archer unit.
var _crew: Array = []

@onready var _unit = get_parent()


func crew_count() -> int:
	return _crew.size()


func is_full() -> bool:
	return _crew.size() >= capacity


func can_accept_unit(unit) -> bool:
	if is_full():
		return false
	if not unit.get_script():
		return false
	var scene_path = unit.get_script().resource_path.replace(".gd", ".tscn")
	return scene_path in CREWABLE_SCENE_PATHS


func load_unit(unit: Node) -> void:
	if not can_accept_unit(unit):
		return
	var original_player = unit.player

	if unit.is_in_group("selected_units"):
		unit.remove_from_group("selected_units")
		MatchSignals.unit_deselected.emit(unit)

	if unit.is_in_group("in_formation"):
		for fc in get_tree().get_nodes_in_group("formation_controller"):
			if fc._group != null and unit in fc._group.members:
				fc._group.on_member_died(unit)
				break

	# Lock the unit in place: group/control state must be set BEFORE action=null so that
	# infantry/archer _on_action_changed(null) sees "in_crew" and skips auto-reinit.
	unit.action_queue.clear()
	unit.remove_from_group("controlled_units")
	unit.remove_from_group("adversary_units")
	unit.add_to_group("in_crew")
	unit.action = null
	var movement = unit.find_child("Movement")
	if movement != null:
		movement.stop()

	# Rigidly attach: reparent to siege weapon so the unit moves with it automatically.
	var slot_index = _crew.size()
	unit.reparent(_unit, false)
	unit.position = _get_slot_offset(slot_index)

	# _claim_ownership must run before connecting tree_exited or appending to _crew.
	# If the weapon is neutral, _claim_ownership reparents it, which fires tree_exited on
	# all children (including this crew unit). With no connection yet, that fires harmlessly.
	_claim_ownership(original_player)

	unit.set_meta("crew_siege_unit", _unit)

	var on_died_callable = _on_engineer_died.bind(unit)
	unit.tree_exited.connect(on_died_callable)
	_crew.append({
		"engineer": unit,
		"original_player": original_player,
		"on_died": on_died_callable,
	})
	crew_changed.emit(_crew.size())
	print("[Crew] %s locked to %s (slot %d, total=%d)" % [unit.name, _unit.name, slot_index, _crew.size()])


func abandon() -> void:
	var to_restore = _crew.filter(func(e): return is_instance_valid(e.get("engineer")))
	_crew.clear()

	# Disconnect callbacks and unlock crew BEFORE releasing weapon ownership,
	# so crew nodes leave the weapon's subtree before it becomes neutral.
	for entry in to_restore:
		var unit = entry.get("engineer")
		if not is_instance_valid(unit):
			continue
		var callable = entry.get("on_died")
		if callable and unit.tree_exited.is_connected(callable):
			unit.tree_exited.disconnect(callable)
		if unit.has_meta("crew_siege_unit"):
			unit.remove_meta("crew_siege_unit")
		_unlock_crew_unit(entry)

	_release_ownership()
	crew_changed.emit(0)
	print("[Crew] %s abandoned — %d crew unlocked" % [_unit.name, to_restore.size()])


func get_all_engineers() -> Array:
	return _crew.map(func(e): return e.get("engineer")).filter(func(e): return is_instance_valid(e))


func _get_slot_offset(slot_index: int) -> Vector3:
	# Rear/side arc (45°–135°): all positive Z, clear of the forward firing line
	var angles = [PI / 4.0, PI * 5.0 / 12.0, PI * 7.0 / 12.0, PI * 3.0 / 4.0]
	var angle = angles[slot_index % angles.size()]
	return Vector3(cos(angle) * slot_radius, 0.0, sin(angle) * slot_radius)


func _unlock_crew_unit(entry: Dictionary) -> void:
	var unit = entry.get("engineer")
	if not is_instance_valid(unit):
		return
	var original_player = entry.get("original_player")
	# Reparent back to player hierarchy, preserving world position.
	var new_parent = original_player if is_instance_valid(original_player) else _unit.get_parent()
	unit.reparent(new_parent, true)
	# Restore group membership and player control.
	unit.remove_from_group("in_crew")
	if is_instance_valid(original_player) and original_player is Human:
		unit.add_to_group("controlled_units")
	elif is_instance_valid(original_player):
		unit.add_to_group("adversary_units")
	# Place near the weapon.
	var r = (_unit.radius if _unit.radius != null else 1.0) + 1.5
	var angle = randf() * TAU
	unit.global_position = _unit.global_position + Vector3(cos(angle), 0.0, sin(angle)) * r
	unit.action_queue.clear()
	unit.action = null
	print("[Crew] %s unlocked from %s" % [unit.name, _unit.name])


func _on_engineer_died(engineer: Node) -> void:
	var was_in_crew = _crew.any(func(e): return e.get("engineer") == engineer)
	if not was_in_crew:
		return
	_crew = _crew.filter(func(e): return e.get("engineer") != engineer)
	if _crew.is_empty() and not _unit.is_queued_for_deletion():
		_release_ownership()
	crew_changed.emit(_crew.size())


func _claim_ownership(new_player: Node) -> void:
	if not _unit.is_in_group("neutral_siege"):
		return
	_unit.remove_from_group("neutral_siege")
	if _unit.is_in_group("controlled_units"):
		_unit.remove_from_group("controlled_units")
	if _unit.is_in_group("adversary_units"):
		_unit.remove_from_group("adversary_units")
	if new_player is Human:
		_unit.add_to_group("controlled_units")
	else:
		_unit.add_to_group("adversary_units")
	var mv = _unit.find_child("Movement")
	if mv != null:
		mv.avoidance_enabled = true
	if _unit.player != new_player and _unit.is_inside_tree():
		_unit.reparent(new_player, true)
	if _unit.has_method("refresh_player_color"):
		_unit.refresh_player_color()
	var match_node = _unit.find_parent("Match")
	if match_node != null and new_player in match_node.visible_players:
		_unit.add_to_group("revealed_units")


func _release_ownership() -> void:
	_unit.add_to_group("neutral_siege")
	if _unit.is_in_group("controlled_units"):
		_unit.remove_from_group("controlled_units")
	if _unit.is_in_group("adversary_units"):
		_unit.remove_from_group("adversary_units")
	if _unit.is_in_group("revealed_units"):
		_unit.remove_from_group("revealed_units")
	if _unit.is_in_group("selected_units"):
		_unit.remove_from_group("selected_units")
		MatchSignals.unit_deselected.emit(_unit)
	if _unit.has_method("reset_player_color"):
		_unit.reset_player_color()
	var mv = _unit.find_child("Movement")
	if mv != null:
		mv.avoidance_enabled = false
	var match_node = _unit.find_parent("Match")
	if match_node != null:
		var neutral_parent = match_node.find_child("Players", false)
		if neutral_parent != null and _unit.get_parent() != neutral_parent and _unit.is_inside_tree():
			_unit.reparent(neutral_parent, true)
