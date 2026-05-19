extends Node

signal toggled(scene_path)

var active_scene_path: String = ""
var _timer: Timer = null
@onready var _unit = get_parent()


func _ready():
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer)
	add_child(_timer)


func toggle(scene_path: String):
	if active_scene_path == scene_path:
		stop()
	else:
		_try_start(scene_path)


func stop():
	if active_scene_path.is_empty():
		return
	active_scene_path = ""
	_timer.stop()
	toggled.emit("")


func get_progress() -> float:
	if active_scene_path.is_empty() or _timer == null:
		return 0.0
	var total = Constants.Match.Units.PRODUCTION_TIMES.get(active_scene_path, 1.0)
	return (total - _timer.time_left) / total


func _try_start(scene_path: String):
	active_scene_path = scene_path
	_timer.start(Constants.Match.Units.PRODUCTION_TIMES[scene_path])
	toggled.emit(active_scene_path)


func _on_timer():
	var scene_path = active_scene_path
	if scene_path.is_empty():
		return
	if _is_at_population_cap():
		_timer.start(5.0)  # recheck in 5 seconds
		return
	_produce(scene_path)
	MatchSignals.unit_production_finished.emit(load(scene_path), _unit)
	_timer.start(Constants.Match.Units.PRODUCTION_TIMES[scene_path])


func _is_at_population_cap() -> bool:
	var player = _unit.player
	var pop = get_tree().get_nodes_in_group("population_units").filter(
		func(u): return u.player == player
	).size()
	var capitals = get_tree().get_nodes_in_group("capitals").filter(
		func(u): return u.player == player and u.is_constructed()
	).size()
	var houses = get_tree().get_nodes_in_group("houses").filter(
		func(u): return u.player == player and u.is_constructed()
	).size()
	var manors = get_tree().get_nodes_in_group("manors").filter(
		func(u): return u.player == player and u.is_constructed()
	).size()
	var cap = mini(
		capitals * Constants.Match.Units.POPULATION_PER_CAPITAL
		+ houses * Constants.Match.Units.POPULATION_PER_HOUSE
		+ manors * Constants.Match.Units.POPULATION_PER_MANOR,
		Constants.Match.Units.POPULATION_CAP_MAX
	)
	return cap > 0 and pop >= cap


func _produce(scene_path: String):
	var unit_scene = load(scene_path)
	var produced_unit = unit_scene.instantiate()
	var placement_position = (
		Utils
		. Match
		. Unit
		. Placement
		. find_valid_position_radially_yet_skip_starting_radius(
			_unit.global_position,
			_unit.radius,
			produced_unit.radius,
			0.1,
			Vector3(0, 0, 1),
			false,
			find_parent("Match").navigation.get_navigation_map_rid_by_domain(
				produced_unit.movement_domain
			),
			get_tree()
		)
	)
	MatchSignals.setup_and_spawn_unit.emit(
		produced_unit, Transform3D(Basis(), placement_position), _unit.player
	)
	var rally_point = _unit.find_child("RallyPoint")
	if rally_point != null:
		MatchSignals.navigate_unit_to_rally_point.emit(produced_unit, rally_point)
