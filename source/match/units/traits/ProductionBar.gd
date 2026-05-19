@tool
extends Node3D

@export var size = Vector2(200, 6):
	set(value):
		size = value
		var bar = find_child("ActualBar")
		if bar != null:
			bar.texture.width = size.x
			bar.texture.height = size.y

@onready var _actual_bar = find_child("ActualBar")
@onready var _unit = get_parent()
var _toggle = null
var _queue = null


func _ready():
	if Engine.is_editor_hint():
		return
	hide()
	_toggle = _unit.find_child("ProductionToggle")
	_queue = _unit.find_child("ProductionQueue")


func _process(_delta):
	if Engine.is_editor_hint():
		return
	var progress = _get_progress()
	if progress < 0.0:
		if visible:
			hide()
		return
	if not visible:
		show()
	var snapped_progress = floor(progress * 10.0) / 10.0
	_actual_bar.texture.gradient.set_offset(1, snapped_progress)


func _get_progress() -> float:
	if _toggle != null and not _toggle.active_scene_path.is_empty():
		return _toggle.get_progress()
	if _queue != null and _queue.size() > 0:
		return _queue.get_elements()[0].progress()
	return -1.0
