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
@onready var _morale_row = find_child("MoraleRow")
@onready var _morale_val = find_child("MoraleVal")

var _current_unit = null
var _current_count: int = 0


func _ready():
	MatchSignals.unit_inspect_changed.connect(_on_unit_inspect_changed)
	MatchSignals.unit_damaged.connect(_on_unit_damaged)
	_clear_display()


func _on_unit_inspect_changed(focused_units: Array):
	var valid = focused_units.filter(func(u): return is_instance_valid(u))
	if valid.is_empty():
		_current_unit = null
		_current_count = 0
		_clear_display()
		return
	_current_unit = valid[0]
	_current_count = valid.size()
	_update_display(_current_unit, _current_count)


func _on_unit_damaged(unit):
	if not is_instance_valid(_current_unit):
		_current_unit = null
		return
	if unit == _current_unit:
		_update_display(_current_unit, _current_count)


func _clear_display():
	_unit_name_label.text = ""
	_tab_hint_label.hide()
	_hp_label.hide()
	_damage_row.hide()
	_atk_speed_row.hide()
	_atk_range_row.hide()
	_speed_row.hide()
	_sight_row.hide()
	_effect_row.hide()
	_cargo_row.hide()
	_morale_row.hide()


func _update_display(unit, count: int):
	var type_val = unit.get("type")
	var name_str = (type_val if type_val != null else unit.name).capitalize()
	if count > 1:
		name_str += " x%d" % count
	_unit_name_label.text = name_str
	_tab_hint_label.hide()

	_hp_label.show()
	if unit.hp != null and unit.hp_max != null:
		_hp_label.text = "HP: %d / %d" % [int(unit.hp), int(unit.hp_max)]
	else:
		_hp_label.text = "HP: —"

	_set_row(_damage_row, _damage_val, unit.attack_damage, "%d")
	_set_row(_atk_speed_row, _atk_speed_val, unit.attack_interval, "%.1fs")
	_set_row(_atk_range_row, _atk_range_val, unit.attack_range, "%.1f")
	var spd = unit.movement_speed
	_set_row(_speed_row, _speed_val, spd if spd > 0.0 else null, "%.2f")
	_set_row(_sight_row, _sight_val, unit.sight_range, "%.1f")
	_set_row(_effect_row, _effect_val, unit.effect_radius, "%.1f")
	_cargo_row.show()
	var cargo = unit.get("cargo_label")
	if cargo != null and cargo != "":
		_cargo_val.text = cargo
	else:
		_cargo_val.text = "—"

	_morale_row.show()
	_morale_val.text = "— (coming soon)"


func _set_row(row: Node, val_label: Label, value, fmt: String):
	row.show()
	if value != null and value > 0:
		val_label.text = fmt % value
	else:
		val_label.text = "—"
