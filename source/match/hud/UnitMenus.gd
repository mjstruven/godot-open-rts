extends PanelContainer

const Structure = preload("res://source/match/units/Structure.gd")

@onready var _generic_menu = find_child("GenericMenu")
@onready var _combat_menu = find_child("CombatMenu")
@onready var _formation_menu = find_child("FormationMenu")

var _focused_units: Array = []


func _ready():
	_reset_menus()
	MatchSignals.unit_focus_changed.connect(_on_unit_focus_changed)
	MatchSignals.formation_changed.connect(func(): _reset_menus())


func _on_unit_focus_changed(focused_controlled_units: Array):
	_focused_units = focused_controlled_units
	_reset_menus()


func _reset_menus():
	_hide_all_menus()
	_try_showing_any_menu()


func _hide_all_menus():
	_generic_menu.hide()
	_combat_menu.hide()
	_formation_menu.hide()


func _try_showing_any_menu():
	var selected = _focused_units.filter(func(u): return is_instance_valid(u))
	var combat_units = selected.filter(
		func(u): return u.attack_range != null and not u is Structure
	)
	if not combat_units.is_empty():
		_combat_menu.units = selected
		_combat_menu.show()
		_formation_menu.update_buttons()
		_formation_menu.show()
		return
	if selected.size() > 0:
		_generic_menu.units = selected
		_generic_menu.show()
