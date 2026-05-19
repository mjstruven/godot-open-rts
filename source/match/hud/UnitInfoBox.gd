extends PanelContainer

var _selected_units: Array = []
var _tab_index: int = 0

@onready var _unit_name_label = find_child("UnitNameLabel")
@onready var _tab_hint_label = find_child("TabHintLabel")
@onready var _hp_label = find_child("HpLabel")
@onready var _damage_row = find_child("DamageRow")
@onready var _damage_val = find_child("DamageVal")
@onready var _atk_speed_row = find_child("AtkSpeedRow")
@onready var _atk_speed_val = find_child("AtkSpeedVal")
@onready var _atk_range_row = find_child("AtkRangeRow")
@onready var _atk_range_val = find_child("AtkRangeVal")
@onready var _speed_row = find_child("SpeedRow")
@onready var _speed_val = find_child("SpeedVal")
@onready var _sight_row = find_child("SightRow")
@onready var _sight_val = find_child("SightVal")
@onready var _effect_row = find_child("EffectRow")
@onready var _effect_val = find_child("EffectVal")
@onready var _cargo_row = find_child("CargoRow")
@onready var _cargo_val = find_child("CargoVal")


func _ready():
	MatchSignals.unit_selected.connect(_on_unit_selected)
	MatchSignals.unit_deselected.connect(_on_unit_deselected)
	MatchSignals.unit_died.connect(_on_unit_died)
	hide()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		if _unique_types().size() > 1:
			_tab_index = (_tab_index + 1) % _unique_types().size()
			_refresh()
			get_viewport().set_input_as_handled()


func _on_unit_selected(unit):
	if unit not in _selected_units:
		_selected_units.append(unit)
	_tab_index = 0
	_refresh()


func _on_unit_deselected(unit):
	_selected_units.erase(unit)
	_tab_index = mini(_tab_index, max(0, _unique_types().size() - 1))
	_refresh()


func _on_unit_died(unit):
	_selected_units.erase(unit)
	_tab_index = mini(_tab_index, max(0, _unique_types().size() - 1))
	_refresh()


func _unique_types() -> Array:
	var seen = {}
	var result = []
	for unit in _selected_units:
		if not is_instance_valid(unit):
			continue
		var t = unit.get_script().resource_path
		if t not in seen:
			seen[t] = true
			result.append(t)
	return result


func _refresh():
	_selected_units = _selected_units.filter(func(u): return is_instance_valid(u))
	var types = _unique_types()
	if types.is_empty():
		hide()
		MatchSignals.unit_focus_changed.emit([])
		return
	_tab_index = clampi(_tab_index, 0, types.size() - 1)
	var current_type = types[_tab_index]
	var units_of_type = _selected_units.filter(
		func(u): return u.get_script().resource_path == current_type
	)
	if units_of_type.is_empty():
		hide()
		MatchSignals.unit_focus_changed.emit([])
		return
	show()
	_update_display(units_of_type[0], units_of_type.size(), _tab_index + 1, types.size())
	var focused_controlled = units_of_type.filter(func(u): return u.is_in_group("controlled_units"))
	MatchSignals.unit_focus_changed.emit(focused_controlled)


func _update_display(unit, count: int, type_idx: int, type_total: int):
	var name_str = unit.type.capitalize()
	if count > 1:
		name_str += " x%d" % count
	_unit_name_label.text = name_str

	if type_total > 1:
		_tab_hint_label.text = "%d/%d Tab" % [type_idx, type_total]
		_tab_hint_label.show()
	else:
		_tab_hint_label.hide()

	if unit.hp != null and unit.hp_max != null:
		_hp_label.text = "HP: %d / %d" % [int(unit.hp), int(unit.hp_max)]
		_hp_label.show()
	else:
		_hp_label.hide()

	_set_row(_damage_row, _damage_val, unit.attack_damage, "%d")
	_set_row(_atk_speed_row, _atk_speed_val, unit.attack_interval, "%.1fs")
	_set_row(_atk_range_row, _atk_range_val, unit.attack_range, "%.1f")
	var spd = unit.movement_speed
	_set_row(_speed_row, _speed_val, spd if spd > 0.0 else null, "%.2f")
	_set_row(_sight_row, _sight_val, unit.sight_range, "%.1f")
	_set_row(_effect_row, _effect_val, unit.effect_radius, "%.1f")
	var cargo = unit.get("cargo_label")
	if cargo != null and cargo != "":
		_cargo_row.show()
		_cargo_val.text = cargo
	else:
		_cargo_row.hide()


func _set_row(row: Node, val_label: Label, value, fmt: String):
	var has_value = value != null and value > 0
	row.visible = has_value
	if has_value:
		val_label.text = fmt % value
