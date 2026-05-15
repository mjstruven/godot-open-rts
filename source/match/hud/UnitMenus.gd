extends PanelContainer

const Engineer = preload("res://source/match/units/engineer.gd")
const TownCenter = preload("res://source/match/units/town_center.gd")

@onready var _generic_menu = find_child("GenericMenu")
@onready var _engineer_menu = find_child("EngineerMenu")
@onready var _town_center_menu = find_child("TownCenterMenu")


func _ready():
	_reset_menus()
	MatchSignals.unit_selected.connect(func(_unit): _reset_menus())
	MatchSignals.unit_deselected.connect(func(_unit): _reset_menus())
	MatchSignals.unit_died.connect(func(_unit): _reset_menus())


func _reset_menus():
	_hide_all_menus()
	if _try_showing_any_menu():
		show()
	else:
		hide()


func _hide_all_menus():
	_generic_menu.hide()
	_engineer_menu.hide()
	_town_center_menu.hide()


func _try_showing_any_menu():
	var selected_controlled_units = get_tree().get_nodes_in_group("selected_units").filter(
		func(unit): return unit.is_in_group("controlled_units")
	)
	var selected_town_centers = selected_controlled_units.filter(func(u): return u is TownCenter)
	if (
		not selected_town_centers.is_empty()
		and selected_town_centers.size() == selected_controlled_units.size()
	):
		_town_center_menu.units = selected_town_centers
		_town_center_menu.show()
		return true
	if selected_controlled_units.size() == 1 and selected_controlled_units[0] is Engineer:
		_engineer_menu.show()
	if selected_controlled_units.size() > 0:
		_generic_menu.units = selected_controlled_units
		_generic_menu.show()
		return true
	return false
