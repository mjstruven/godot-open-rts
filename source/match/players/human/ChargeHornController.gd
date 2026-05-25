extends Node

const HORN_DEBOUNCE_MS: int = 5000

@onready var _audio_player = find_child("AudioStreamPlayer")

var _horn_stream: AudioStream = null
var _last_horn_ms: int = 0


func _ready():
	_horn_stream = load("res://assets/sfx/Charge_Horn.mp3")
	if _horn_stream == null:
		push_warning("[ChargeHorn] res://assets/sfx/Charge_Horn.mp3 not found — horn will be silent")
	MatchSignals.charge_begun.connect(_on_charge_begun)


func _on_charge_begun(_unit):
	if _horn_stream == null:
		return
	var now = Time.get_ticks_msec()
	if now - _last_horn_ms < HORN_DEBOUNCE_MS:
		return
	_last_horn_ms = now
	_audio_player.stream = _horn_stream
	_audio_player.play()
