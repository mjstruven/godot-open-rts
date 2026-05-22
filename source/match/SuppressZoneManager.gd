extends Node

const SUPPRESS_SLOW_PER_ZONE = 0.01
const SUPPRESS_SLOW_CAP = 0.10
const UPDATE_INTERVAL = 0.2

var _zones: Array = []


func _ready():
	var timer = Timer.new()
	timer.wait_time = UPDATE_INTERVAL
	timer.timeout.connect(_update_slows)
	add_child(timer)
	timer.start()


func register_zone(zone) -> void:
	if zone not in _zones:
		_zones.append(zone)


func unregister_zone(zone) -> void:
	_zones.erase(zone)
	if _zones.is_empty():
		_clear_all_suppress_slows()


func _clear_all_suppress_slows() -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		var movement = unit.find_child("Movement")
		if is_instance_valid(movement):
			movement.clear_speed_slow("suppress")


func _update_slows() -> void:
	_zones = _zones.filter(func(z): return is_instance_valid(z) and z.is_inside_tree())
	if _zones.is_empty():
		return
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit):
			continue
		var movement = unit.find_child("Movement")
		if not is_instance_valid(movement):
			continue
		var zone_count = 0
		var unit_pos_2d = Vector2(unit.global_position.x, unit.global_position.z)
		for zone in _zones:
			var info = zone.get_zone_info()
			if info.is_empty():
				continue
			var center_2d = Vector2(info["center"].x, info["center"].z)
			if unit_pos_2d.distance_to(center_2d) <= info["radius"]:
				zone_count += 1
		var suppress_slow = minf(SUPPRESS_SLOW_PER_ZONE * zone_count, SUPPRESS_SLOW_CAP)
		if suppress_slow > 0.0:
			movement.set_speed_slow("suppress", suppress_slow)
		else:
			movement.clear_speed_slow("suppress")
