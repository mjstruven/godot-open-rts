extends PanelContainer

const Engineer = preload("res://source/match/units/engineer.gd")
const Academy = preload("res://source/match/units/academy.gd")
const Capital = preload("res://source/match/units/capital.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const SiegeWorkshop = preload("res://source/match/units/siege_workshop.gd")
const BatteringRam = preload("res://source/match/units/battering_ram.gd")
const SiegeTower = preload("res://source/match/units/siege_tower.gd")

@onready var _generic_menu = find_child("GenericMenu")
@onready var _engineer_menu = find_child("EngineerMenu")
@onready var _academy_menu = find_child("AcademyMenu")
@onready var _capital_menu = find_child("CapitalMenu")
@onready var _structure_menu = find_child("StructureMenu")
@onready var _combat_menu = find_child("CombatMenu")
@onready var _formation_menu = find_child("FormationMenu")
@onready var _siege_workshop_menu = find_child("SiegeWorkshopMenu")
@onready var _battering_ram_menu = find_child("BatteringRamMenu")
@onready var _siege_tower_menu = find_child("SiegeTowerMenu")

var _focused_units: Array = []
var _full_focused_units: Array = []
var _tab_index: int = 0
var _is_tab_emitting: bool = false


func _ready():
	_reset_menus()
	MatchSignals.unit_focus_changed.connect(_on_unit_focus_changed)
	MatchSignals.formation_changed.connect(func(): _reset_menus())


func _unhandled_input(event):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_TAB:
		_cycle_tab_subselection()
		get_viewport().set_input_as_handled()


func _on_unit_focus_changed(focused_controlled_units: Array):
	if not _is_tab_emitting:
		_full_focused_units = focused_controlled_units
		_tab_index = 0
	_focused_units = focused_controlled_units
	_reset_menus()


func _cycle_tab_subselection():
	var valid = _full_focused_units.filter(
		func(u): return is_instance_valid(u) and u.is_in_group("controlled_units")
	)
	if valid.is_empty():
		return

	var types: Array = []
	for u in valid:
		if u.type not in types:
			types.append(u.type)

	if types.size() <= 1:
		return  # nothing to cycle

	var cycle_size = 1 + types.size()  # [all, type0, type1, ...]
	_tab_index = (_tab_index + 1) % cycle_size

	var subset: Array
	if _tab_index == 0:
		subset = valid
	else:
		var t = types[_tab_index - 1]
		subset = valid.filter(func(u): return u.type == t)

	_is_tab_emitting = true
	MatchSignals.unit_focus_changed.emit(subset)
	_is_tab_emitting = false


func _reset_menus():
	_hide_all_menus()
	if _try_showing_any_menu():
		show()
	else:
		hide()


func _hide_all_menus():
	_generic_menu.hide()
	_engineer_menu.hide()
	_academy_menu.hide()
	_capital_menu.hide()
	_structure_menu.hide()
	_combat_menu.hide()
	_formation_menu.hide()
	_siege_workshop_menu.hide()
	_battering_ram_menu.hide()
	_siege_tower_menu.hide()


func _try_showing_any_menu():
	var selected_controlled_units = _focused_units.filter(func(u): return is_instance_valid(u))
	var selected_academies = selected_controlled_units.filter(func(u): return u is Academy)
	if (
		not selected_academies.is_empty()
		and selected_academies.size() == selected_controlled_units.size()
	):
		_academy_menu.units = selected_academies
		_academy_menu.show()
		return true
	var selected_capitals = selected_controlled_units.filter(func(u): return u is Capital)
	if (
		not selected_capitals.is_empty()
		and selected_capitals.size() == selected_controlled_units.size()
	):
		_capital_menu.units = selected_capitals
		_capital_menu.show()
		return true
	var selected_workshops = selected_controlled_units.filter(func(u): return u is SiegeWorkshop)
	if (
		not selected_workshops.is_empty()
		and selected_workshops.size() == selected_controlled_units.size()
	):
		_siege_workshop_menu.units = selected_workshops
		_siege_workshop_menu.show()
		return true
	var selected_rams = selected_controlled_units.filter(func(u): return u is BatteringRam)
	if (
		not selected_rams.is_empty()
		and selected_rams.size() == selected_controlled_units.size()
	):
		_battering_ram_menu.units = selected_rams
		_battering_ram_menu.show()
		return true
	var selected_towers = selected_controlled_units.filter(func(u): return u is SiegeTower)
	if (
		not selected_towers.is_empty()
		and selected_towers.size() == selected_controlled_units.size()
	):
		_siege_tower_menu.units = selected_towers
		_siege_tower_menu.show()
		return true
	if (
		selected_controlled_units.size() == 1
		and selected_controlled_units[0] is Structure
		and selected_controlled_units[0].is_under_construction()
	):
		_structure_menu.unit = selected_controlled_units[0]
		_structure_menu.show()
		return true
	var selected_engineers = selected_controlled_units.filter(func(u): return u is Engineer)
	if (
		not selected_engineers.is_empty()
		and selected_engineers.size() == selected_controlled_units.size()
	):
		_engineer_menu.units = selected_engineers
		_engineer_menu.show()
		return true
	var combat_units = selected_controlled_units.filter(
		func(u): return u.attack_range != null and not u is Structure
	)
	if not combat_units.is_empty():
		_combat_menu.units = selected_controlled_units
		_combat_menu.show()
		_formation_menu.update_buttons()
		_formation_menu.show()
		return true
	if selected_controlled_units.size() > 0:
		_generic_menu.units = selected_controlled_units
		_generic_menu.show()
		return true
	return false
