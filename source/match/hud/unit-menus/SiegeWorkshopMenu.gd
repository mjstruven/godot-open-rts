extends GridContainer

const BatteringRamScene = preload("res://source/match/units/battering_ram.tscn")
const SiegeTowerScene = preload("res://source/match/units/siege_tower.tscn")

var units = []:
	set(value):
		units = value
		if is_node_ready():
			_refresh_buttons()

@onready var _ram_btn = find_child("ProduceBatteringRamButton")
@onready var _tower_btn = find_child("ProduceSiegeTowerButton")


func _ready():
	_refresh_buttons()


func _process(_delta):
	if not visible:
		return
	_refresh_buttons()


func _refresh_buttons():
	var available = units.filter(func(u): return is_instance_valid(u) and u.is_constructed())
	if available.is_empty():
		if is_instance_valid(_ram_btn):
			_ram_btn.modulate = Color(0.5, 0.5, 0.5)
		if is_instance_valid(_tower_btn):
			_tower_btn.modulate = Color(0.5, 0.5, 0.5)
		return
	var player = available[0].player
	if is_instance_valid(_ram_btn):
		var ram_cost = Constants.Match.Units.PRODUCTION_COSTS[BatteringRamScene.resource_path]
		_ram_btn.modulate = Color.WHITE if player.has_resources(ram_cost) else Color(1, 0.3, 0.3, 1)
	if is_instance_valid(_tower_btn):
		var tower_cost = Constants.Match.Units.PRODUCTION_COSTS[SiegeTowerScene.resource_path]
		_tower_btn.modulate = (
			Color.WHITE if player.has_resources(tower_cost) else Color(1, 0.3, 0.3, 1)
		)


func _unhandled_input(event):
	if not is_visible_in_tree():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_Q:
		_on_produce_battering_ram_pressed()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_W:
		_on_produce_siege_tower_pressed()
		get_viewport().set_input_as_handled()


func _on_produce_battering_ram_pressed():
	var available = units.filter(func(u): return is_instance_valid(u) and u.is_constructed())
	if available.is_empty():
		return
	var player = available[0].player
	var cost = Constants.Match.Units.PRODUCTION_COSTS[BatteringRamScene.resource_path]
	if not player.has_resources(cost):
		MatchSignals.not_enough_resources_for_production.emit(player)
		return
	var target = available.reduce(func(a, b):
		return a if a.production_queue.size() <= b.production_queue.size() else b
	)
	player.subtract_resources(cost)
	target.production_queue.produce(BatteringRamScene)


func _on_produce_siege_tower_pressed():
	var available = units.filter(func(u): return is_instance_valid(u) and u.is_constructed())
	if available.is_empty():
		return
	var player = available[0].player
	var cost = Constants.Match.Units.PRODUCTION_COSTS[SiegeTowerScene.resource_path]
	if not player.has_resources(cost):
		MatchSignals.not_enough_resources_for_production.emit(player)
		return
	var target = available.reduce(func(a, b):
		return a if a.production_queue.size() <= b.production_queue.size() else b
	)
	player.subtract_resources(cost)
	target.production_queue.produce(SiegeTowerScene)
