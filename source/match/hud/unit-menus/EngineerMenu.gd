extends Control

const Human = preload("res://source/match/players/human/Human.gd")

const GrainMillUnit = preload("res://source/match/units/grain_mill.tscn")
const LumberMillUnit = preload("res://source/match/units/lumber_mill.tscn")
const StoneMillUnit = preload("res://source/match/units/stone_mill.tscn")
const HouseUnit = preload("res://source/match/units/house.tscn")
const ManorUnit = preload("res://source/match/units/manor.tscn")
const AcademyUnit = preload("res://source/match/units/academy.tscn")
const CommandPostUnit = preload("res://source/match/units/command_post.tscn")
const SiegeWorkshopUnit = preload("res://source/match/units/siege_workshop.tscn")
const TowerUnit = preload("res://source/match/units/tower.tscn")

@onready var _root_grid = find_child("RootGrid")
@onready var _economic_grid = find_child("EconomicGrid")
@onready var _military_grid = find_child("MilitaryGrid")
@onready var _fort_grid = find_child("FortGrid")

@onready var _grain_mill_btn = find_child("PlaceGrainMillButton")
@onready var _lumber_mill_btn = find_child("PlaceLumberMillButton")
@onready var _stone_mill_btn = find_child("PlaceStoneMillButton")
@onready var _house_btn = find_child("PlaceHouseButton")
@onready var _manor_btn = find_child("PlaceManorButton")
@onready var _academy_btn = find_child("PlaceAcademyButton")
@onready var _command_post_btn = find_child("PlaceCommandPostButton")
@onready var _siege_workshop_btn = find_child("PlaceSiegeWorkshopButton")
@onready var _tower_btn = find_child("PlaceTowerButton")

var units: Array = []:
	set(value):
		units = value
		if is_node_ready():
			_show_root()


func _ready():
	_show_root()


func _process(_delta):
	if not visible:
		return
	var humans = get_tree().get_nodes_in_group("players").filter(func(p): return p is Human)
	if humans.is_empty():
		return
	var player = humans[0]
	if _economic_grid.visible:
		_refresh_button(_grain_mill_btn, GrainMillUnit, player)
		_refresh_button(_lumber_mill_btn, LumberMillUnit, player)
		_refresh_button(_stone_mill_btn, StoneMillUnit, player)
		_refresh_button(_house_btn, HouseUnit, player)
		_refresh_button(_manor_btn, ManorUnit, player)
	elif _military_grid.visible:
		_refresh_button(_academy_btn, AcademyUnit, player)
		_refresh_button(_command_post_btn, CommandPostUnit, player)
		_refresh_button(_siege_workshop_btn, SiegeWorkshopUnit, player)
		_refresh_button(_tower_btn, TowerUnit, player)


func _refresh_button(btn: Button, scene: PackedScene, player):
	var cost = Constants.Match.Units.CONSTRUCTION_COSTS[scene.resource_path]
	btn.modulate = Color.WHITE if player.has_resources(cost) else Color(1, 0.3, 0.3, 1)


func _show_root():
	_root_grid.show()
	_economic_grid.hide()
	_military_grid.hide()
	_fort_grid.hide()


func _show_economic():
	_root_grid.hide()
	_economic_grid.show()
	_military_grid.hide()
	_fort_grid.hide()


func _show_military():
	_root_grid.hide()
	_economic_grid.hide()
	_military_grid.show()
	_fort_grid.hide()


func _show_fort():
	_root_grid.hide()
	_economic_grid.hide()
	_military_grid.hide()
	_fort_grid.show()


func _on_economic_pressed():
	_show_economic()


func _on_military_pressed():
	_show_military()


func _on_fort_pressed():
	_show_fort()


func _on_economic_back_pressed():
	_show_root()


func _on_military_back_pressed():
	_show_root()


func _on_fort_back_pressed():
	_show_root()


func _on_place_grain_mill_pressed():
	MatchSignals.place_structure.emit(GrainMillUnit)


func _on_place_lumber_mill_pressed():
	MatchSignals.place_structure.emit(LumberMillUnit)


func _on_place_stone_mill_pressed():
	MatchSignals.place_structure.emit(StoneMillUnit)


func _on_place_house_pressed():
	MatchSignals.place_structure.emit(HouseUnit)


func _on_place_manor_pressed():
	MatchSignals.place_structure.emit(ManorUnit)


func _on_place_academy_pressed():
	MatchSignals.place_structure.emit(AcademyUnit)


func _on_place_command_post_pressed():
	MatchSignals.place_structure.emit(CommandPostUnit)


func _on_place_siege_workshop_pressed():
	MatchSignals.place_structure.emit(SiegeWorkshopUnit)


func _on_place_tower_pressed():
	MatchSignals.place_structure.emit(TowerUnit)
