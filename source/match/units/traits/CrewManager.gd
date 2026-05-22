extends Node

@export var capacity: int = 12
const CREWABLE_SCENE_PATHS = [
	"res://source/match/units/infantry.tscn",
	"res://source/match/units/archer.tscn",
]

const Human = preload("res://source/match/players/human/Human.gd")
const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")

signal crew_changed(new_count)

var _crew: Array = []

@onready var _unit = get_parent()


func crew_count() -> int:
	return _crew.size()


func is_full() -> bool:
	return _crew.size() >= capacity


func can_accept_unit(unit) -> bool:
	if is_full():
		return false
	if unit in _crew:
		return false
	if not unit.get_script():
		return false
	var scene_path = unit.get_script().resource_path.replace(".gd", ".tscn")
	return scene_path in CREWABLE_SCENE_PATHS


func load_unit(unit: Node) -> void:
	if not can_accept_unit(unit):
		return
	_crew.append(unit)
	unit.add_to_group("in_crew")
	unit.set_meta("crew_of", _unit)
	if unit.is_in_group("selected_units"):
		unit.remove_from_group("selected_units")
		MatchSignals.unit_deselected.emit(unit)
	unit.hide()
	_set_unit_interactive(unit, false)
	_claim_ownership(unit.player)
	crew_changed.emit(_crew.size())


func unman() -> void:
	_crew = _crew.filter(func(u): return is_instance_valid(u))
	for crew_unit in _crew.duplicate():
		_release_crew_unit(crew_unit)
	_crew.clear()
	_release_ownership()
	crew_changed.emit(0)


func _release_ownership() -> void:
	_unit.add_to_group("neutral_siege")
	if _unit.is_in_group("controlled_units"):
		_unit.remove_from_group("controlled_units")
	if _unit.is_in_group("adversary_units"):
		_unit.remove_from_group("adversary_units")
	if _unit.is_in_group("selected_units"):
		_unit.remove_from_group("selected_units")
		MatchSignals.unit_deselected.emit(_unit)
	if _unit.has_method("reset_player_color"):
		_unit.reset_player_color()


func get_all_crew() -> Array:
	return _crew.duplicate()


func _release_crew_unit(unit: Node) -> void:
	if not is_instance_valid(unit):
		return
	unit.remove_from_group("in_crew")
	if unit.has_meta("crew_of"):
		unit.remove_meta("crew_of")
	unit.hp = unit.hp_max
	unit.show()
	_set_unit_interactive(unit, true)
	var angle = randf() * TAU
	var offset = Vector3(cos(angle), 0, sin(angle)) * (_unit.radius + 1.5)
	unit.global_position = _unit.global_position + offset
	if unit.action == null:
		unit.action = WaitingForTargets.new()


func _set_unit_interactive(unit: Node, interactive: bool) -> void:
	var cs = unit.find_child("CollisionShape3D")
	if cs != null:
		cs.disabled = not interactive
	var targetability = unit.find_child("Targetability")
	if targetability != null:
		var ts = targetability.find_child("CollisionShape3D")
		if ts != null:
			ts.disabled = not interactive


func _claim_ownership(new_player) -> void:
	if not _unit.is_in_group("neutral_siege"):
		return
	_unit.remove_from_group("neutral_siege")
	# Always update groups so re-claim after unman restores controlled/adversary membership
	if _unit.is_in_group("controlled_units"):
		_unit.remove_from_group("controlled_units")
	if _unit.is_in_group("adversary_units"):
		_unit.remove_from_group("adversary_units")
	if new_player is Human:
		_unit.add_to_group("controlled_units")
	else:
		_unit.add_to_group("adversary_units")
	var current_player = _unit.player
	if current_player == new_player:
		if _unit.has_method("refresh_player_color"):
			_unit.refresh_player_color()
		return
	# Reparent to the crewing player
	_unit.reparent(new_player, true)
	if _unit.has_method("refresh_player_color"):
		_unit.refresh_player_color()
