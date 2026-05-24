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


func _ready():
	MatchSignals.unit_focus_changed.connect(_on_unit_focus_changed)
	_hide_all_menus()


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
