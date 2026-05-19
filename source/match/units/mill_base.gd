extends "res://source/match/units/Structure.gd"

const WAGON_CARGO = {
	"res://source/match/units/grain_mill.tscn": {"food": 15},
	"res://source/match/units/lumber_mill.tscn": {"wood": 15},
	"res://source/match/units/stone_mill.tscn": {"stone": 15},
}
const WAGON_SPAWN_INTERVAL = 15.0
const LABORER_CAP = 8
const LABORER_SPAWN_INTERVAL = 30.0
const LABORER_PRODUCTION_PENALTY = 0.075
const LABORER_PRODUCTION_MINIMUM = 0.4

var _spawn_timer = null
var _laborer_timer = null
var _laborers: Array = []


func _ready():
	await super()
	add_to_group("mills")
	effect_radius = Constants.Match.Units.CAPITAL_INFLUENCE_RADIUS
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = WAGON_SPAWN_INTERVAL
	_spawn_timer.timeout.connect(_spawn_wagon)
	add_child(_spawn_timer)
	_spawn_timer.start()
	_laborer_timer = Timer.new()
	_laborer_timer.wait_time = LABORER_SPAWN_INTERVAL
	_laborer_timer.timeout.connect(_try_spawn_laborer)
	add_child(_laborer_timer)
	_laborer_timer.start()
	if is_constructed():
		_on_constructed()
	else:
		constructed.connect(_on_constructed)


func _get_production_multiplier() -> float:
	_laborers = _laborers.filter(func(l): return is_instance_valid(l))
	var missing = LABORER_CAP - _laborers.size()
	return maxf(LABORER_PRODUCTION_MINIMUM, 1.0 - missing * LABORER_PRODUCTION_PENALTY)


func _spawn_wagon():
	if not is_constructed():
		return
	var wagon_scene = load("res://source/match/units/supply_wagon_auto.tscn")
	var wagon = wagon_scene.instantiate()
	var scene_path = get_script().resource_path.replace(".gd", ".tscn")
	var base_cargo = WAGON_CARGO.get(scene_path, {})
	var multiplier = _get_production_multiplier()
	wagon.cargo = {}
	for resource in base_cargo:
		var amount: float
		if resource == "food" and type == "grain_mill":
			amount = float(CultivationManager.get_food_cargo(self))
		else:
			amount = float(base_cargo[resource])
		wagon.cargo[resource] = maxi(1, roundi(amount * multiplier))
	MatchSignals.setup_and_spawn_unit.emit(wagon, global_transform.translated(_wagon_spawn_offset()), player)


func _wagon_spawn_offset() -> Vector3:
	var targets = get_tree().get_nodes_in_group("delivery_targets").filter(
		func(t): return t.player == player and t.is_constructed()
	)
	var direction = Vector3(1, 0, 0)
	if not targets.is_empty():
		targets.sort_custom(
			func(a, b):
				return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
		)
		var to_target = (targets[0].global_position - global_position) * Vector3(1, 0, 1)
		if to_target.length_squared() > 0.0:
			direction = to_target.normalized()
	return direction * (radius + 1.0)


func _exit_tree():
	if type == "grain_mill":
		CultivationManager.unregister_mill(self)


func _on_constructed():
	for i in range(LABORER_CAP):
		_spawn_laborer(i)
	_cancel_nearby_same_type_under_construction()
	if type == "grain_mill":
		CultivationManager.register_mill(self)


func _cancel_nearby_same_type_under_construction():
	var my_type = type
	var my_pos = global_position * Vector3(1, 0, 1)
	var cancel_radius = (
		CultivationManager.GRAIN_MILL_EXCLUSION_RADIUS
		if my_type == "grain_mill"
		else Constants.Match.Units.CAPITAL_INFLUENCE_RADIUS
	)
	for mill in get_tree().get_nodes_in_group("mills").duplicate():
		if mill == self or not is_instance_valid(mill):
			continue
		if mill.type != my_type or not mill.is_under_construction():
			continue
		var dist = (mill.global_position * Vector3(1, 0, 1)).distance_to(my_pos)
		if dist < cancel_radius:
			mill.cancel_construction()


func _try_spawn_laborer():
	if not is_constructed():
		return
	_laborers = _laborers.filter(func(l): return is_instance_valid(l))
	if _laborers.size() >= LABORER_CAP:
		return
	_spawn_laborer(_laborers.size())


func _spawn_laborer(index: int = 0):
	var laborer_scene = load("res://source/match/units/laborer.tscn")
	var laborer = laborer_scene.instantiate()
	laborer.mill = self
	_laborers.append(laborer)
	var offset = _laborer_spawn_offset(index)
	MatchSignals.setup_and_spawn_unit.emit(laborer, global_transform.translated(offset), player)


func _laborer_spawn_offset(index: int) -> Vector3:
	var angle = index * (PI / 2.0)
	return Vector3(cos(angle), 0.0, sin(angle)) * (radius + 0.9)
