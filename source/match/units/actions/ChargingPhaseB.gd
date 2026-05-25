extends "res://source/match/units/actions/Action.gd"

const Structure = preload("res://source/match/units/Structure.gd")
const CHARGE_SPEED_MULTIPLIER: float = 1.25
const TRAMPLE_RADIUS: float = 1.0

var _lane_start: Vector3
var _direction: Vector3
var _distance: float
var _charge_speed: float = 0.0
var _travelled: float = 0.0
var _map_size: Vector2 = Vector2(10000.0, 10000.0)
var _trampled: Dictionary = {}

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement = _unit.find_child("Movement")


func _init(lane_start: Vector3, direction: Vector3, distance: float):
	_lane_start = lane_start
	_direction = direction
	_distance = distance


func _ready():
	var match_node = _unit.find_parent("Match")
	if match_node != null and match_node.get("map") != null:
		_map_size = match_node.map.size
	_charge_speed = _movement.speed * CHARGE_SPEED_MULTIPLIER
	_movement.stop()
	_unit.add_to_group("charging")
	_unit.action_queue.clear()
	var look_target = _unit.global_position + _direction
	_unit.look_at(look_target, Vector3.UP)
	MatchSignals.charge_begun.emit(_unit)


func _physics_process(delta: float):
	var step = _direction * _charge_speed * delta
	_unit.global_position += step
	_travelled += step.length()
	for area in _unit.get_overlapping_areas():
		if area is Structure:
			queue_free()
			return
	var p = _unit.global_position
	if p.x < 0.0 or p.x > _map_size.x or p.z < 0.0 or p.z > _map_size.y:
		queue_free()
		return
	if _travelled >= _distance:
		queue_free()
		return
	_apply_trample()


func _apply_trample():
	var my_pos = _unit.global_position_yless
	for target in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(target) or target == _unit:
			continue
		if target is Structure:
			continue
		if target.hp == null or target.hp <= 0:
			continue
		if my_pos.distance_to(target.global_position_yless) > TRAMPLE_RADIUS:
			continue
		var tid: int = target.get_instance_id()
		if _trampled.has(tid):
			continue
		var dmg: int = _trample_damage_for(target)
		if dmg <= 0:
			continue
		_trampled[tid] = true
		if target.is_in_group("bolstering"):
			var reduced: int = int(dmg * 0.75)
			target.hp -= reduced
			if is_instance_valid(_unit) and _unit.hp != null and _unit.hp > 0:
				_unit.hp -= int(reduced * 0.5)
		else:
			target.hp -= dmg


func _trample_damage_for(target) -> int:
	if _unit.attack_damage == null:
		return 0
	if target.player == _unit.player:
		if target.get("type") == "cavalry" or target.is_in_group("flag_commanders"):
			return 0
	if target.get("type") == "cavalry":
		return int(_unit.attack_damage * 0.5)
	return _unit.attack_damage


func _exit_tree():
	if is_instance_valid(_unit):
		_unit.remove_from_group("charging")
