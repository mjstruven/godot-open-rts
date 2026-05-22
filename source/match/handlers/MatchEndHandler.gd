extends CanvasLayer

const Human = preload("res://source/match/players/human/Human.gd")

@onready var _victory_tile = find_child("Victory")
@onready var _defeat_tile = find_child("Defeat")
@onready var _finish_tile = find_child("Finish")


func _ready():
	if not FeatureFlags.handle_match_end:
		queue_free()
		return
	hide()
	_victory_tile.hide()
	_defeat_tile.hide()
	_finish_tile.hide()
	await find_parent("Match").ready
	MatchSignals.setup_and_spawn_unit.connect(_on_new_unit)
	for unit in get_tree().get_nodes_in_group("units"):
		unit.tree_exited.connect(_on_unit_tree_exited)
		_connect_win_condition_if_needed(unit, unit.player)


func _handle_defeat():
	_defeat_tile.show()
	_show()
	MatchSignals.match_finished_with_defeat.emit()


func _handle_victory():
	_victory_tile.show()
	_show()
	MatchSignals.match_finished_with_victory.emit()


func _handle_finish():
	_finish_tile.show()
	_show()


func _show():
	var match_node = find_parent("Match")
	if match_node != null:
		match_node.fog_of_war.reveal()
	show()
	get_tree().paused = true


func _on_new_unit(unit, _transform, player):
	unit.tree_exited.connect(_on_unit_tree_exited)
	_connect_win_condition_if_needed(unit, player)


func _connect_win_condition_if_needed(_unit, _player) -> void:
	# Capital-destruction win condition disabled (deferred — does not fire reliably).
	# Re-enable by uncommenting the two lines below when diagnosing.
	#if "is_win_condition_building" in unit and unit.is_win_condition_building:
	#	unit.tree_exited.connect(_on_win_condition_building_destroyed.bind(player))
	pass


func _on_win_condition_building_destroyed(owner_player) -> void:
	var match_node = find_parent("Match")
	if match_node != null:
		match_node.fog_of_war.reveal()
	if visible:
		return
	var human_players = get_tree().get_nodes_in_group("players").filter(
		func(p): return p is Human
	)
	if not human_players.is_empty() and owner_player == human_players[0]:
		_handle_defeat()
	elif not human_players.is_empty():
		_handle_victory()
	else:
		_handle_finish()


func _on_unit_tree_exited():
	if visible or not is_inside_tree():
		return
	var players = Utils.Set.new()
	for unit in get_tree().get_nodes_in_group("units"):
		players.add(unit.player)
	var human_players = get_tree().get_nodes_in_group("players").filter(
		func(player): return player is Human
	)
	if not human_players.is_empty() and not players.has(human_players[0]):
		_handle_defeat()
	elif not human_players.is_empty() and players.has(human_players[0]) and players.size() == 1:
		_handle_victory()
	elif players.size() == 1:
		_handle_finish()


func _on_exit_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://source/main-menu/Main.tscn")
