extends PanelContainer

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
	MatchSignals.unit_focus_changed.connect(_on_unit_focus_changed)
	hide()


func _on_unit_focus_changed(focused_units: Array):
	var valid = focused_units.filter(func(u): return is_instance_valid(u))
	if valid.is_empty():
		hide()
		return
	show()
	_update_display(valid[0], valid.size())


func _update_display(unit, count: int):
	var type_val = unit.get("type")
	var name_str = (type_val if type_val != null else unit.name).capitalize()
	if count > 1:
		name_str += " x%d" % count
	_unit_name_label.text = name_str
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
