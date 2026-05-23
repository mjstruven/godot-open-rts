extends Node

signal crew_changed(new_count)

@export var capacity: int = 4
@export var slot_radius: float = 0.8

const CREWABLE_SCENE_PATHS = [
	"res://source/match/units/infantry.tscn",
	"res://source/match/units/archer.tscn",
]
const Human = preload("res://source/match/players/human/Human.gd")

# Each entry: { engineer: Node, original_scene: String, original_player: Node, on_died: Callable }
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
	MatchSignals.setup_and_spawn_unit.emit(engineer, Transform3D(Basis.IDENTITY, spawn_pos), original_player)

	# Rigidly attach: reparent engineer to siege unit so it moves with it automatically.
	var slot_index = _crew.size()
	engineer.reparent(_unit, false)
	engineer.position = _get_slot_offset(slot_index)
	_set_unit_interactive(engineer, false)

	# _claim_ownership must run before connecting tree_exited or appending to _crew.
	# If Ballista is neutral, _claim_ownership reparents the Ballista, which fires tree_exited on
	# all its children (including this engineer). With no connection established yet, the signal
	# fires harmlessly. If the connect+append were first, _on_engineer_died would fire mid-claim
	# and silently drop the entry from _crew, leaving an untracked ghost engineer.
	_claim_ownership(original_player)

	# Set meta after _claim_ownership so engineer.player resolves through the Ballista to the
	# real player node, not the neutral container. _ready() has already run (triggered
	# synchronously by setup_and_spawn_unit above), so _setup_color() is not affected.
	engineer.set_meta("crew_siege_unit", _unit)

	var on_died_callable = _on_engineer_died.bind(engineer)
	engineer.tree_exited.connect(on_died_callable)
	_crew.append({
		"engineer": engineer,
		"original_scene": original_scene,
		"original_player": original_player,
		"on_died": on_died_callable,
	})
	crew_changed.emit(_crew.size())


func abandon() -> void:
	var to_restore = _crew.filter(func(e): return is_instance_valid(e.get("engineer")))
	_crew.clear()

	# Detach engineers from all game systems before releasing Ballista ownership.
	# Order matters: _sync_unit reads engineer.player via crew_siege_unit meta, so meta must be
	# stripped and engineers removed from "units" before the Ballista becomes neutral.
	for entry in to_restore:
		var engineer = entry.get("engineer")
		if not is_instance_valid(engineer):
			continue
		var callable = entry.get("on_died")
		if callable and engineer.tree_exited.is_connected(callable):
			engineer.tree_exited.disconnect(callable)
		if engineer.has_meta("crew_siege_unit"):
			engineer.remove_meta("crew_siege_unit")
		engineer.remove_from_group("units")

	_release_ownership()

	for entry in to_restore:
		_restore_crew_unit(entry)

	crew_changed.emit(0)


func get_all_engineers() -> Array:
	return _crew.map(func(e): return e.get("engineer")).filter(func(e): return is_instance_valid(e))


func _set_unit_interactive(unit: Node, interactive: bool) -> void:
	var cs = unit.find_child("CollisionShape3D")
	if cs != null:
		cs.disabled = not interactive
	var targetability = unit.find_child("Targetability")
	if targetability != null:
		var ts = targetability.find_child("CollisionShape3D")
		if ts != null:
			ts.disabled = not interactive


func _get_slot_offset(slot_index: int) -> Vector3:
	# Rear/side arc (45°–135°): all positive Z, clear of the forward firing line
	var angles = [PI / 4.0, PI * 5.0 / 12.0, PI * 7.0 / 12.0, PI * 3.0 / 4.0]
	var angle = angles[slot_index % angles.size()]
	return Vector3(cos(angle) * slot_radius, 0.0, sin(angle) * slot_radius)


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
