extends GridContainer

const Human = preload("res://source/match/players/human/Human.gd")

const GrainMillUnit = preload("res://source/match/units/grain_mill.tscn")
const LumberMillUnit = preload("res://source/match/units/lumber_mill.tscn")
const StoneMillUnit = preload("res://source/match/units/stone_mill.tscn")
const HouseUnit = preload("res://source/match/units/house.tscn")
const ManorUnit = preload("res://source/match/units/manor.tscn")
const AcademyUnit = preload("res://source/match/units/academy.tscn")
const CommandPostUnit = preload("res://source/match/units/command_post.tscn")
const SiegeWorkshopUnit = preload("res://source/match/units/siege_workshop.tscn")

@onready var _grain_mill_btn = find_child("PlaceGrainMillButton")
@onready var _lumber_mill_btn = find_child("PlaceLumberMillButton")
@onready var _stone_mill_btn = find_child("PlaceStoneMillButton")
@onready var _house_btn = find_child("PlaceHouseButton")
@onready var _manor_btn = find_child("PlaceManorButton")
@onready var _academy_btn = find_child("PlaceTownCenterButton")
@onready var _command_post_btn = find_child("PlaceCommandPostButton")
@onready var _siege_workshop_btn = find_child("PlaceSiegeWorkshopButton")

var units: Array = []


func _process(_delta):
	if not visible:
		return
	var humans = get_tree().get_nodes_in_group("players").filter(func(p): return p is Human)
	if humans.is_empty():
		return
	var player = humans[0]
	_refresh_button(_grain_mill_btn, GrainMillUnit, player)
	_refresh_button(_lumber_mill_btn, LumberMillUnit, player)
	_refresh_button(_stone_mill_btn, StoneMillUnit, player)
	_refresh_button(_house_btn, HouseUnit, player)
	_refresh_button(_manor_btn, ManorUnit, player)
	_refresh_button(_academy_btn, AcademyUnit, player)
	_refresh_button(_command_post_btn, CommandPostUnit, player)
	_refresh_button(_siege_workshop_btn, SiegeWorkshopUnit, player)


func _refresh_button(btn: Button, scene: PackedScene, player):
	var cost = Constants.Match.Units.CONSTRUCTION_COSTS[scene.resource_path]
	btn.modulate = Color.WHITE if player.has_resources(cost) else Color(1, 0.3, 0.3, 1)


func _unhandled_input(event):
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_Q:
			_on_place_grain_mill_button_pressed()
			get_viewport().set_input_as_handled()
		KEY_W:
			_on_place_lumber_mill_button_pressed()
			get_viewport().set_input_as_handled()
		KEY_E:
			_on_place_stone_mill_button_pressed()
			get_viewport().set_input_as_handled()
		KEY_R:
			_on_place_town_center_button_pressed()
			get_viewport().set_input_as_handled()
		KEY_A:
			_on_place_command_post_button_pressed()
			get_viewport().set_input_as_handled()
		KEY_F:
			_on_place_siege_workshop_button_pressed()
			get_viewport().set_input_as_handled()
		KEY_S:
			_on_place_house_button_pressed()
			get_viewport().set_input_as_handled()
		KEY_D:
			_on_place_manor_button_pressed()
			get_viewport().set_input_as_handled()


func _on_place_grain_mill_button_pressed():
	MatchSignals.place_structure.emit(GrainMillUnit)


func _on_place_lumber_mill_button_pressed():
	MatchSignals.place_structure.emit(LumberMillUnit)


func _on_place_stone_mill_button_pressed():
	MatchSignals.place_structure.emit(StoneMillUnit)


func _on_place_house_button_pressed():
	MatchSignals.place_structure.emit(HouseUnit)


func _on_place_manor_button_pressed():
	MatchSignals.place_structure.emit(ManorUnit)


func _on_place_town_center_button_pressed():
	MatchSignals.place_structure.emit(AcademyUnit)


func _on_place_command_post_button_pressed():
	MatchSignals.place_structure.emit(CommandPostUnit)


func _on_place_siege_workshop_button_pressed():
	MatchSignals.place_structure.emit(SiegeWorkshopUnit)
