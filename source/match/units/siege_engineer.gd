extends "res://source/match/units/Unit.gd"

const WANDER_RADIUS: float = 0.35
const WANDER_WAIT: float = 2.5

var _wait_timer: Timer = null
var _movement = null


func _ready():
	await super()
	add_to_group("population_units")
	_wait_timer = Timer.new()
	_wait_timer.one_shot = true
	_wait_timer.wait_time = WANDER_WAIT
	_wait_timer.timeout.connect(_pick_wander_destination)
	add_child(_wait_timer)
	_movement = find_child("Movement")
	if _movement != null:
		_movement.movement_finished.connect(_on_movement_finished)
	_pick_wander_destination()


func _pick_wander_destination():
	if _movement == null:
		return
	var siege_unit = get_meta("crew_siege_unit", null)
	var origin: Vector3
	if is_instance_valid(siege_unit):
		origin = siege_unit.global_position
	else:
		origin = global_position
	var angle: float = randf() * TAU
	var dist: float = randf_range(0.2, WANDER_RADIUS)
	_movement.move(origin + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist))


func _on_movement_finished():
	_wait_timer.start()
