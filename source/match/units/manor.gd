extends "res://source/match/units/Structure.gd"

# 15 cargo × 4 wagons/min × 1.5 bonus = 90/min; 22.5 rounds to 23
const FOOD_CARGO = 23
const WAGON_SPAWN_INTERVAL = 15.0

var _spawn_timer = null


func _ready():
	await super()
	add_to_group("manors")
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = WAGON_SPAWN_INTERVAL
	_spawn_timer.timeout.connect(_spawn_wagon)
	add_child(_spawn_timer)
	constructed.connect(_on_constructed_internal)


func _on_constructed_internal():
	_spawn_timer.start()


func _spawn_wagon():
	if not is_constructed():
		return
	var wagon = load("res://source/match/units/supply_wagon_auto.tscn").instantiate()
	wagon.cargo = {"food": FOOD_CARGO}
	MatchSignals.setup_and_spawn_unit.emit(
		wagon, global_transform.translated(_wagon_spawn_offset()), player
	)


func _wagon_spawn_offset() -> Vector3:
	var targets = get_tree().get_nodes_in_group("delivery_targets").filter(
		func(t): return t.player == player and t.is_constructed()
	)
	var direction = Vector3(1, 0, 0)
	if not targets.is_empty():
		targets.sort_custom(
			func(a, b):
				return global_position.distance_to(a.global_position) < global_position.distance_to(
					b.global_position
				)
		)
		var to_target = (targets[0].global_position - global_position) * Vector3(1, 0, 1)
		if to_target.length_squared() > 0.0:
			direction = to_target.normalized()
	return direction * (radius + 1.0)
