extends "res://source/match/units/actions/Action.gd"

const BolsterPhaseB = preload("res://source/match/units/actions/BolsterPhaseB.gd")

var _lane_start: Vector3
var _lane_end: Vector3
var _phase_b_started: bool = false

@onready var _unit = Utils.NodeEx.find_parent_with_group(self, "units")
@onready var _movement = _unit.find_child("Movement")


func _init(lane_start: Vector3, lane_end: Vector3):
	_lane_start = lane_start
	_lane_end = lane_end


func _ready():
	_movement.move(_lane_start)
	_movement.movement_finished.connect(_on_arrived)


func _exit_tree():
	if not _phase_b_started and is_instance_valid(_movement):
		_movement.stop()


func _on_arrived():
	_movement.movement_finished.disconnect(_on_arrived)
	_phase_b_started = true
	_unit.action = BolsterPhaseB.new(_lane_end)
