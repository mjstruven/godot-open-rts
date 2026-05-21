extends Node3D

const DISMISS_DURATION: float = 15.0
const DISMISS_COOLDOWN: float = 60.0

const CivilianScene = preload("res://source/match/units/civilian.tscn")

var _is_dismissing: bool = false
var _dismiss_elapsed: float = 0.0
var _cooldown_elapsed: float = 0.0
var _button_blocked: bool = false

@onready var _unit = get_parent()
@onready var _bar = find_child("DismissBar")


func _ready() -> void:
	_bar.hide()


func _process(delta: float) -> void:
	if _is_dismissing:
		_dismiss_elapsed += delta
		_cooldown_elapsed += delta
		_update_bar()
		if _dismiss_elapsed >= DISMISS_DURATION:
			_complete_dismiss()
	elif _button_blocked:
		_cooldown_elapsed += delta
		if _cooldown_elapsed >= DISMISS_COOLDOWN:
			_button_blocked = false
			_cooldown_elapsed = 0.0


func start_dismiss() -> void:
	if _is_dismissing or _button_blocked:
		return
	_is_dismissing = true
	_dismiss_elapsed = 0.0
	_cooldown_elapsed = 0.0
	_bar.show()
	_update_bar()


func cancel_dismiss() -> void:
	if not _is_dismissing:
		return
	_is_dismissing = false
	_bar.hide()
	_button_blocked = true


func is_dismissing() -> bool:
	return _is_dismissing


func has_cooldown() -> bool:
	return _button_blocked


func _update_bar() -> void:
	var remaining: float = max(0.0, DISMISS_DURATION - _dismiss_elapsed)
	var ratio: float = remaining / DISMISS_DURATION
	_bar.texture.gradient.set_offset(1, ratio)


func _complete_dismiss() -> void:
	_is_dismissing = false
	_bar.hide()
	if not is_instance_valid(_unit):
		return
	if _unit.hp == null or _unit.hp <= 0:
		return
	var spawn_pos: Vector3 = _unit.global_position
	var player = _unit.player
	var civilian: Node = CivilianScene.instantiate()
	MatchSignals.setup_and_spawn_unit.emit(
		civilian, Transform3D(Basis(), spawn_pos), player
	)
	_unit.queue_free()
