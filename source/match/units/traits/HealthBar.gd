@tool
extends Node3D

@export var size = Vector2(200, 20):
	set(value):
		size = value
		find_child("ActualBar").texture.width = size.x
		find_child("ActualBar").texture.height = size.y

@onready var _unit = get_parent()
@onready var _actual_bar = find_child("ActualBar")
@onready var _name_label = find_child("NameLabel")


func _ready():
	if Engine.is_editor_hint():
		return
	_name_label.text = _format_unit_name(_unit.type)
	_name_label.hide()
	_recalulate_bar_value()
	_set_bar_color()
	_unit.selected.connect(_on_unit_selected)
	_unit.deselected.connect(_on_unit_deselected)
	_unit.hp_changed.connect(_on_hp_changed)


func _set_bar_color():
	var color = Color.GREEN if _unit.is_in_group("controlled_units") else Color.RED
	_actual_bar.texture.gradient.set_color(0, color)


func _recalulate_bar_value():
	if _unit.hp == null or _unit.hp_max == null:
		return
	var raw_ratio = float(_unit.hp) / _unit.hp_max
	var new_value = floor(raw_ratio * 10.0) / 10.0 if not is_equal_approx(raw_ratio, 1.0) else 1.1
	_actual_bar.texture.gradient.set_offset(1, new_value)


func _on_unit_selected():
	_name_label.show()


func _on_unit_deselected():
	_name_label.hide()


func _on_hp_changed():
	_recalulate_bar_value()


func _format_unit_name(type: String) -> String:
	return " ".join(Array(type.split("_")).map(func(w): return w.capitalize()))
