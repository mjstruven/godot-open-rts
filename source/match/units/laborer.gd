extends "res://source/match/units/Unit.gd"

const WANDER_RADIUS = 5.0
const WAIT_TIME = 2.0

var mill: Node3D = null

var _wait_timer: Timer = null


func _ready():
	await super()
	remove_from_group("controlled_units")
	_wait_timer = Timer.new()
	_wait_timer.one_shot = true
	_wait_timer.wait_time = WAIT_TIME
	_wait_timer.timeout.connect(_pick_wander_destination)
	add_child(_wait_timer)
	find_child("Movement").movement_finished.connect(_on_movement_finished)
	_pick_wander_destination()


func _pick_wander_destination():
	if not is_instance_valid(mill):
		return
	var angle = randf() * TAU
	var dist = randf_range(0.3, WANDER_RADIUS)
	var offset = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	find_child("Movement").move(mill.global_position + offset)


func _on_movement_finished():
	_wait_timer.start()
