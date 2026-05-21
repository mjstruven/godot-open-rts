extends Node3D

const Unit = preload("res://source/match/units/Unit.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const Player = preload("res://source/match/players/Player.gd")
const Human = preload("res://source/match/players/human/Human.gd")

const Engineer = preload("res://source/match/units/engineer.tscn")
const Cavalry = preload("res://source/match/units/cavalry.tscn")
const Capital = preload("res://source/match/units/capital.tscn")
const House = preload("res://source/match/units/house.tscn")

# DEBUG: set to false to disable the DELETE-key instant-kill tool
const DEBUG_KILL_KEY_ENABLED = true

@export var settings: Resource = null

var map:
	set = _set_map,
	get = _get_map
var visible_player = null:
	set = _set_visible_player
var visible_players = null:
	set = _ignore,
	get = _get_visible_players

@onready var navigation = $Navigation
@onready var fog_of_war = $FogOfWar

@onready var _camera = $IsometricCamera3D
@onready var _players = $Players
@onready var _terrain = $Terrain


func _enter_tree():
	assert(settings != null, "match cannot start without settings, see examples in tests/manual/")
	assert(map != null, "match cannot start without map, see examples in tests/manual/")


func _ready():
	MatchSignals.setup_and_spawn_unit.connect(_setup_and_spawn_unit)
	await _setup_subsystems_dependent_on_map()
	_setup_players()
	_setup_player_units()
	visible_player = get_tree().get_nodes_in_group("players")[settings.visible_player]
	_move_camera_to_initial_position()
	if settings.visibility == settings.Visibility.FULL:
		fog_of_war.reveal()
	MatchSignals.match_started.emit()
	GameLogger.info(
		GameLogger.Category.STARTUP,
		"Terrain regions registered",
		{"count": TerrainManager.get_regions().size()}
	)


func _unhandled_input(event):
	if DEBUG_KILL_KEY_ENABLED and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_DELETE:
		for unit in get_tree().get_nodes_in_group("selected_units"):
			if is_instance_valid(unit) and unit.hp != null:
				unit.hp = 0
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		fog_of_war.reveal()
		var uv_handler = find_child("UnitVisibilityHandler")
		if uv_handler != null:
			uv_handler.visible = false
		var count = TerrainManager.get_regions().size()
		print("[TERRAIN] F1 reveal — %d terrain regions registered" % count)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_center_camera_on_selected_units()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.is_action_pressed("shift_selecting"):
			return
		MatchSignals.deselect_all_units.emit()


func _center_camera_on_selected_units():
	var selected = get_tree().get_nodes_in_group("selected_units")
	if selected.is_empty():
		return
	var pivot = Utils.Match.Unit.Movement.calculate_aabb_crowd_pivot_yless(selected)
	_camera.set_position_safely(pivot)


func _set_map(a_map):
	assert(get_node_or_null("Map") == null, "map already set")
	a_map.name = "Map"
	add_child(a_map)
	a_map.owner = self


func _ignore(_value):
	pass


func _get_map():
	return get_node_or_null("Map")


func _set_visible_player(player):
	_conceal_player_units(visible_player)
	_reveal_player_units(player)
	visible_player = player


func _get_visible_players():
	if settings.visibility == settings.Visibility.PER_PLAYER:
		return [visible_player]
	return get_tree().get_nodes_in_group("players")


func _setup_subsystems_dependent_on_map():
	_terrain.update_shape(map.find_child("Terrain").mesh)
	fog_of_war.resize(map.size)
	_recalculate_camera_bounding_planes(map.size)
	await navigation.setup(map)


func _recalculate_camera_bounding_planes(map_size: Vector2):
	_camera.bounding_planes[1] = Plane(-1, 0, 0, -map_size.x)
	_camera.bounding_planes[3] = Plane(0, 0, -1, -map_size.y)


func _setup_players():
	assert(
		_players.get_children().is_empty() or settings.players.is_empty(),
		"players can be defined either in settings or in scene tree, not in both"
	)
	if _players.get_children().is_empty():
		_create_players_from_settings()
	for node in _players.get_children():
		if node is Player:
			node.add_to_group("players")


func _create_players_from_settings():
	for player_settings in settings.players:
		var player_scene = Constants.Match.Player.CONTROLLER_SCENES[player_settings.controller]
		var player = player_scene.instantiate()
		player.color = player_settings.color
		player.food = 1000
		player.wood = 1000
		player.stone = 1000
		player.gold = 1000
		if player_settings.spawn_index_offset > 0:
			for _i in range(player_settings.spawn_index_offset):
				_players.add_child(Node.new())
		_players.add_child(player)


func _setup_player_units():
	var spawn_points = map.find_child("SpawnPoints").get_children()
	spawn_points.sort_custom(
		func(a, b): return (a.global_position.x + a.global_position.z) < (b.global_position.x + b.global_position.z)
	)
	var zigzag = _build_zigzag_indices(spawn_points.size())
	var player_num = 0
	for player in _players.get_children():
		if not player is Player:
			continue
		var predefined_units = player.get_children().filter(func(child): return child is Unit)
		if not predefined_units.is_empty():
			predefined_units.map(func(unit): _setup_unit_groups(unit, unit.player))
		else:
			_spawn_player_units(player, spawn_points[zigzag[player_num]].global_transform)
		player_num += 1


func _build_zigzag_indices(count: int) -> Array:
	var result = []
	var lo = 0
	var hi = count - 1
	while lo <= hi:
		result.append(lo)
		lo += 1
		if lo <= hi:
			result.append(hi)
			hi -= 1
	return result


func _spawn_player_units(player, spawn_transform):
	_setup_and_spawn_unit(Engineer.instantiate(), spawn_transform, player)
	_setup_and_spawn_unit(
		Engineer.instantiate(), spawn_transform.translated(Vector3(2, 0, 0)), player
	)
	_setup_and_spawn_unit(
		Engineer.instantiate(), spawn_transform.translated(Vector3(-2, 0, 0)), player
	)
	_setup_and_spawn_unit(
		Cavalry.instantiate(), spawn_transform.translated(Vector3(0, 0, 2)), player
	)
	_setup_and_spawn_unit(
		Cavalry.instantiate(), spawn_transform.translated(Vector3(2, 0, 2)), player
	)
	_setup_and_spawn_unit(
		Cavalry.instantiate(), spawn_transform.translated(Vector3(-2, 0, 2)), player
	)
	var capital_transform = spawn_transform.translated(Vector3(-4, 0, 2))
	_setup_and_spawn_unit(Capital.instantiate(), capital_transform, player, false)
	_setup_and_spawn_unit(House.instantiate(), capital_transform.translated(Vector3(0, 0, -6)), player, false)
	_setup_and_spawn_unit(House.instantiate(), capital_transform.translated(Vector3(-6, 0, 0)), player, false)
	_setup_and_spawn_unit(House.instantiate(), capital_transform.translated(Vector3(6, 0, 0)), player, false)


func _setup_and_spawn_unit(unit, a_transform, player, mark_structure_under_construction = true):
	unit.global_transform = a_transform
	if unit is Structure and mark_structure_under_construction:
		unit.mark_as_under_construction()
	_setup_unit_groups(unit, player)
	player.add_child(unit)
	MatchSignals.unit_spawned.emit(unit)


func _setup_unit_groups(unit, player):
	unit.add_to_group("units")
	if player == _get_human_player():
		unit.add_to_group("controlled_units")
	else:
		unit.add_to_group("adversary_units")
	if player in visible_players:
		unit.add_to_group("revealed_units")


func _get_human_player():
	var human_players = get_tree().get_nodes_in_group("players").filter(
		func(player): return player is Human
	)
	assert(human_players.size() <= 1, "more than one human player is not allowed")
	if not human_players.is_empty():
		return human_players[0]
	return null


func _move_camera_to_initial_position():
	var human_player = _get_human_player()
	if human_player != null:
		_move_camera_to_player_units_crowd_pivot(human_player)
	else:
		_move_camera_to_player_units_crowd_pivot(get_tree().get_nodes_in_group("players")[0])


func _move_camera_to_player_units_crowd_pivot(player):
	var player_units = get_tree().get_nodes_in_group("units").filter(
		func(unit): return unit.player == player
	)
	assert(not player_units.is_empty(), "player must have at least one initial unit")
	var crowd_pivot = Utils.Match.Unit.Movement.calculate_aabb_crowd_pivot_yless(player_units)
	_camera.set_position_safely(crowd_pivot)


func _reveal_player_units(player):
	if player == null:
		return
	for unit in get_tree().get_nodes_in_group("units").filter(
		func(a_unit): return a_unit.player == player
	):
		unit.add_to_group("revealed_units")


func _conceal_player_units(player):
	if player == null:
		return
	for unit in get_tree().get_nodes_in_group("units").filter(
		func(a_unit): return a_unit.player == player
	):
		unit.remove_from_group("revealed_units")
