extends "res://source/match/units/Unit.gd"

const WANDER_RADIUS: float = 5.0
const WANDER_WAIT: float = 2.0
const DESPAWN_DELAY: float = 5.0

var _origin: Vector3 = Vector3.ZERO
var _wait_timer: Timer = null
var _despawn_timer: Timer = null


func _ready():
	await super()
	remove_from_group("controlled_units")
	_origin = global_position
	_wait_timer = Timer.new()
	_wait_timer.one_shot = true
	_wait_timer.wait_time = WANDER_WAIT
	_wait_timer.timeout.connect(_pick_wander_destination)
	add_child(_wait_timer)
	_despawn_timer = Timer.new()
	_despawn_timer.one_shot = true
	_despawn_timer.wait_time = DESPAWN_DELAY
	_despawn_timer.timeout.connect(queue_free)
	add_child(_despawn_timer)
	find_child("Movement").movement_finished.connect(_on_movement_finished)
	_despawn_timer.start()
	_pick_wander_destination()


func _pick_wander_destination():
	var angle: float = randf() * TAU
	var dist: float = randf_range(0.3, WANDER_RADIUS)
	var offset: Vector3 = Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	find_child("Movement").move(_origin + offset)


func _on_movement_finished():
	_wait_timer.start()
