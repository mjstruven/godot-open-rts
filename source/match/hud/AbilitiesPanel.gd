extends PanelContainer

const Engineer = preload("res://source/match/units/engineer.gd")
const Academy = preload("res://source/match/units/academy.gd")
const Capital = preload("res://source/match/units/capital.gd")
const Structure = preload("res://source/match/units/Structure.gd")
const SiegeWorkshop = preload("res://source/match/units/siege_workshop.gd")
const BatteringRam = preload("res://source/match/units/battering_ram.gd")
const SiegeTower = preload("res://source/match/units/siege_tower.gd")
const Ballista = preload("res://source/match/units/ballista.gd")
const Trebuchet = preload("res://source/match/units/trebuchet.gd")

@onready var _engineer_menu = find_child("EngineerMenu")
@onready var _academy_menu = find_child("AcademyMenu")
@onready var _capital_menu = find_child("CapitalMenu")
@onready var _structure_menu = find_child("StructureMenu")
@onready var _siege_workshop_menu = find_child("SiegeWorkshopMenu")
@onready var _battering_ram_menu = find_child("BatteringRamMenu")
@onready var _siege_tower_menu = find_child("SiegeTowerMenu")
@onready var _ballista_menu = find_child("BallistaMenu")
@onready var _trebuchet_menu = find_child("TrebuchetMenu")
@onready var _archer_menu = find_child("ArcherAbilitiesMenu")
@onready var _commander_menu = find_child("CommanderAbilitiesMenu")


const _CELL_KEYS = {
	KEY_Q: 0, KEY_W: 1, KEY_E: 2, KEY_R: 3,
	KEY_A: 4, KEY_S: 5, KEY_D: 6, KEY_F: 7,
	KEY_Z: 8, KEY_X: 9, KEY_C: 10, KEY_V: 11
}


func _ready():
	MatchSignals.unit_focus_changed.connect(_on_unit_focus_changed)
	_hide_all_menus()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
		return
	var cell_index = _CELL_KEYS.get(event.keycode, -1)
	if cell_index < 0:
		return
	var btn = _get_abilities_cell_button(cell_index)
	if btn == null or btn.disabled:
		return
	_press_button(btn)
	get_viewport().set_input_as_handled()


func _get_abilities_cell_button(cell_index: int) -> Button:
	for menu in [
		_engineer_menu, _academy_menu, _capital_menu, _structure_menu,
		_siege_workshop_menu, _battering_ram_menu, _siege_tower_menu,
		_ballista_menu, _trebuchet_menu, _archer_menu, _commander_menu
	]:
		if menu.visible:
			return _get_grid_cell_button(menu, cell_index)
	return null


func _get_grid_cell_button(node: Node, cell_index: int) -> Button:
	var grid: Node = node
	if not node is GridContainer:
		grid = null
		for child in node.get_children():
			if child is GridContainer and child.visible:
				grid = child
				break
		if grid == null:
			return null
	if cell_index >= grid.get_child_count():
		return null
	var child = grid.get_child(cell_index)
	return child if child is Button else null


func _press_button(btn: Button) -> void:
	if btn.toggle_mode:
		btn.button_pressed = not btn.button_pressed
	else:
		btn.pressed.emit()


func _on_unit_focus_changed(focused_units: Array):
	_hide_all_menus()
	_try_showing_ability_menu(focused_units)


func _hide_all_menus():
	_engineer_menu.hide()
	_academy_menu.hide()
	_capital_menu.hide()
	_structure_menu.hide()
	_siege_workshop_menu.hide()
	_battering_ram_menu.hide()
	_siege_tower_menu.hide()
	_ballista_menu.hide()
	_trebuchet_menu.hide()
	_archer_menu.hide()
	_commander_menu.hide()


func _try_showing_ability_menu(focused_units: Array):
	if focused_units.is_empty():
		return
	var first = focused_units[0]
	if first is Academy:
		_academy_menu.units = focused_units
		_academy_menu.show()
	elif first is Capital:
		_capital_menu.units = focused_units
		_capital_menu.show()
	elif first is SiegeWorkshop:
		_siege_workshop_menu.units = focused_units
		_siege_workshop_menu.show()
	elif first is BatteringRam:
		_battering_ram_menu.units = focused_units
		_battering_ram_menu.show()
	elif first is SiegeTower:
		_siege_tower_menu.units = focused_units
		_siege_tower_menu.show()
	elif first is Ballista:
		_ballista_menu.units = focused_units
		_ballista_menu.show()
	elif first is Trebuchet:
		_trebuchet_menu.units = focused_units
		_trebuchet_menu.show()
	elif focused_units.size() == 1 and first is Structure and first.is_under_construction():
		_structure_menu.unit = first
		_structure_menu.show()
	elif first is Engineer:
		_engineer_menu.units = focused_units
		_engineer_menu.show()
	elif first.get("type") == "archer":
		_archer_menu.units = focused_units
		_archer_menu.show()
	elif first.get("type") == "flag_commander":
		_commander_menu.units = focused_units
		_commander_menu.show()
