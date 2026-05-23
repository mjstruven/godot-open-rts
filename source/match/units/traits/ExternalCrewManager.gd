extends Node

signal crew_changed(new_count)

@export var capacity: int = 4

const CREWABLE_SCENE_PATHS = [
	"res://source/match/units/infantry.tscn",
	"res://source/match/units/archer.tscn",
]
const Human = preload("res://source/match/players/human/Human.gd")

# Each entry: { engineer: Node, original_scene: String, original_player: Node }
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
	var original_scene = unit.get_script().resource_path.replace(".gd", ".tscn")
	var original_player = unit.player
	var spawn_pos = unit.global_position

	if unit.is_in_group("selected_units"):
		unit.remove_from_group("selected_units")
		MatchSignals.unit_deselected.emit(unit)
	unit.queue_free()

	var SiegeEngineerScene = load("res://source/match/units/siege_engineer.tscn")
	var engineer = SiegeEngineerScene.instantiate()
	engineer.set_meta("crew_siege_unit", _unit)
	MatchSignals.setup_and_spawn_unit.emit(engineer, Transform3D(Basis.IDENTITY, spawn_pos), original_player)

	_crew.append({
		"engineer": engineer,
		"original_scene": original_scene,
		"original_player": original_player,
	})
	engineer.tree_exited.connect(_on_engineer_died.bind(engineer))

	_claim_ownership(original_player)
	crew_changed.emit(_crew.size())


func abandon() -> void:
	var to_restore = _crew.filter(func(e): return is_instance_valid(e.get("engineer")))
	_crew.clear()
	_release_ownership()
	for entry in to_restore:
		_restore_crew_unit(entry)
	crew_changed.emit(0)


func get_all_engineers() -> Array:
	return _crew.map(func(e): return e.get("engineer")).filter(func(e): return is_instance_valid(e))


func _restore_crew_unit(entry: Dictionary) -> void:
	var engineer = entry.get("engineer")
	if is_instance_valid(engineer):
		engineer.queue_free()
	var original_scene_path: String = entry.get("original_scene", "")
	var original_player = entry.get("original_player")
	if original_scene_path.is_empty() or not is_instance_valid(original_player):
		return
	var original_scene = load(original_scene_path)
	if original_scene == null:
		return
	var restored = original_scene.instantiate()
	var r = (_unit.radius if _unit.radius != null else 1.0) + 1.5
	var angle = randf() * TAU
	var offset = Vector3(cos(angle), 0.0, sin(angle)) * r
	MatchSignals.setup_and_spawn_unit.emit(
		restored,
		Transform3D(Basis.IDENTITY, _unit.global_position + offset),
		original_player
	)


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
	if _unit.player != new_player:
		_unit.reparent(new_player, true)
	if _unit.has_method("refresh_player_color"):
		_unit.refresh_player_color()


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
	var match_node = _unit.find_parent("Match")
	if match_node != null:
		var neutral_parent = match_node.find_child("Players", false)
		if neutral_parent != null and _unit.get_parent() != neutral_parent:
			_unit.reparent(neutral_parent, true)
