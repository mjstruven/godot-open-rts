extends "res://source/match/units/Unit.gd"


func _get_type():
	return "supply_wagon"

const RETARGET_INTERVAL = 5.0

var cargo = {}
var cargo_label: String:
	get:
		if cargo.is_empty():
			return ""
		return cargo.keys()[0].capitalize()

var _retarget_timer = null
var _delivery_target = null


func _ready():
	await super()
	_retarget_timer = Timer.new()
	_retarget_timer.wait_time = RETARGET_INTERVAL
	_retarget_timer.timeout.connect(_update_destination)
	add_child(_retarget_timer)
	_retarget_timer.start()
	_update_destination()


func _process(_delta):
	if _delivery_target == null or not is_instance_valid(_delivery_target):
		return
	var delivery_range = (_delivery_target.radius if _delivery_target.radius != null else 1.0) + 1.0
	if global_position.distance_to(_delivery_target.global_position) <= delivery_range:
		player.add_resources(cargo)
		queue_free()


func _update_destination():
	_delivery_target = _find_nearest_delivery_target()
	if _delivery_target == null:
		return
	find_child("Movement").move(_delivery_target.global_position)


func _find_nearest_delivery_target():
	var targets = get_tree().get_nodes_in_group("delivery_targets").filter(
		func(t): return t.player == player and t.is_constructed()
	)
	if targets.is_empty():
		return null
	targets.sort_custom(
		func(a, b):
			return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position)
	)
	return targets[0]
