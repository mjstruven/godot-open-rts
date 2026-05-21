extends GridContainer

const Human = preload("res://source/match/players/human/Human.gd")

const GrainMillUnit = preload("res://source/match/units/grain_mill.tscn")
const LumberMillUnit = preload("res://source/match/units/lumber_mill.tscn")
const StoneMillUnit = preload("res://source/match/units/stone_mill.tscn")
const HouseUnit = preload("res://source/match/units/house.tscn")
const ManorUnit = preload("res://source/match/units/manor.tscn")
const AcademyUnit = preload("res://source/match/units/academy.tscn")
const CommandPostUnit = preload("res://source/match/units/command_post.tscn")

@onready var _grain_mill_btn = find_child("PlaceGrainMillButton")
@onready var _lumber_mill_btn = find_child("PlaceLumberMillButton")
@onready var _stone_mill_btn = find_child("PlaceStoneMillButton")
@onready var _house_btn = find_child("PlaceHouseButton")
@onready var _manor_btn = find_child("PlaceManorButton")
@onready var _academy_btn = find_child("PlaceTownCenterButton")
@onready var _command_post_btn = find_child("PlaceCommandPostButton")
@onready var _dismiss_btn = find_child("DismissButton")

var units: Array = []:
	set(value):
		units = value
		if is_node_ready():
			_update_dismiss_button()

var _dismiss_poll_timer: Timer = null


func _ready():
	_update_dismiss_button()
	_dismiss_poll_timer = Timer.new()
	_dismiss_poll_timer.wait_time = 0.5
	_dismiss_poll_timer.timeout.connect(_update_dismiss_button)
	add_child(_dismiss_poll_timer)
	_dismiss_poll_timer.start()


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


func _get_dismissible_units() -> Array:
	return units.filter(func(u): return is_instance_valid(u) and u.find_child("Dismiss") != null)


func _on_dismiss_pressed():
	var dismissible = _get_dismissible_units()
	if dismissible.is_empty():
		return
	var any_dismissing = dismissible.any(func(u):
		var d = u.find_child("Dismiss")
		return d != null and d.is_dismissing()
	)
	if any_dismissing:
		for u in dismissible:
			var d = u.find_child("Dismiss")
			if d != null:
				d.cancel_dismiss()
	else:
		for u in dismissible:
			var d = u.find_child("Dismiss")
			if d != null:
				d.start_dismiss()
	_update_dismiss_button()


func _update_dismiss_button():
	if not is_instance_valid(_dismiss_btn):
		return
	var dismissible = _get_dismissible_units()
	if dismissible.is_empty():
		_dismiss_btn.disabled = true
		_dismiss_btn.modulate = Color(0.5, 0.5, 0.5)
		_dismiss_btn.tooltip_text = "Dismiss (no dismissible units selected)"
		return
	var any_dismissing = dismissible.any(func(u):
		var d = u.find_child("Dismiss")
		return d != null and d.is_dismissing()
	)
	var any_blocked = dismissible.any(func(u):
		var d = u.find_child("Dismiss")
		return d != null and d.has_cooldown()
	)
	if any_blocked and not any_dismissing:
		_dismiss_btn.disabled = true
		_dismiss_btn.modulate = Color(0.5, 0.5, 0.5)
		_dismiss_btn.tooltip_text = "Dismiss on cooldown (60s from first press)"
	elif any_dismissing:
		_dismiss_btn.disabled = false
		_dismiss_btn.modulate = Color(1.0, 0.5, 0.2)
		_dismiss_btn.tooltip_text = "Dismiss in progress — press to cancel"
	else:
		_dismiss_btn.disabled = false
		_dismiss_btn.modulate = Color.WHITE
		_dismiss_btn.tooltip_text = "Dismiss unit(s) — 15s countdown, then civilians spawn"
