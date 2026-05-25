extends "res://source/match/units/actions/Action.gd"

const ChargingPhaseB = preload("res://source/match/units/actions/ChargingPhaseB.gd")

var _lane_start: Vector3
var _direction: Vector3
var _distance: float
var _phase_b_started: bool = false

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement = _unit.find_child("Movement")


func _init(lane_start: Vector3, direction: Vector3, distance: float):
	_lane_start = lane_start
	_direction = direction
	_distance = distance


func _ready():
	_movement.move(_lane_start)
	_movement.movement_finished.connect(_on_arrived)


func _exit_tree():
	if is_inside_tree() and not _phase_b_started:
		_movement.stop()


func _on_arrived():
	_movement.movement_finished.disconnect(_on_arrived)
	_phase_b_started = true
	_unit.action = ChargingPhaseB.new(_lane_start, _direction, _distance)
