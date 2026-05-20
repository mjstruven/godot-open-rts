extends "res://source/match/units/Unit.gd"

const RETARGET_INTERVAL = 2.0
const ARRIVAL_DISTANCE = 2.5

var target_train = null
var cargo_label: String = "Supply"
var _arrived := false
var _retarget_timer: float = 0.0


func _ready():
	await super()
	_update_destination()


func _process(delta):
	super._process(delta)
	if _arrived:
		return
	if not is_instance_valid(target_train):
		queue_free()
		return
	_retarget_timer += delta
	if _retarget_timer >= RETARGET_INTERVAL:
		_retarget_timer = 0.0
		_update_destination()
	if global_position.distance_to(target_train.global_position) <= ARRIVAL_DISTANCE:
		_arrived = true
		target_train.on_wagon_arrived(self)
		queue_free()


func _update_destination():
	if not is_instance_valid(target_train):
		return
	var mv = find_child("Movement")
	if mv != null:
		mv.move(target_train.global_position)
