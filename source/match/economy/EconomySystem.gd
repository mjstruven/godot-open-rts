extends Node3D

const CIVILIAN_FOOD_COST = 10
const CIVILIANS_MAX = 20
const GOLD_PER_CIVILIAN_PER_MIN = 1

var _tick_timer = null


func _ready():
	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.timeout.connect(_on_tick)
	add_child(_tick_timer)
	_tick_timer.start()


func _on_tick():
	for player in get_tree().get_nodes_in_group("players"):
		_process_player(player)


func _process_player(player):
	var all_units = get_tree().get_nodes_in_group("units").filter(
		func(u): return u.player == player
	)

	var upkeep = {"food": 0}
	for unit in all_units:
		var scene_path = unit.get_script().resource_path.replace(".gd", ".tscn")
		if scene_path in Constants.Match.Units.UPKEEP:
			for resource in Constants.Match.Units.UPKEEP[scene_path]:
				upkeep[resource] = upkeep.get(resource, 0) + Constants.Match.Units.UPKEEP[scene_path][resource]

	player.has_deficit = player.food < upkeep.get("food", 0)
	player.food = max(0, player.food - upkeep.get("food", 0))

	var civilians = mini(player.food / CIVILIAN_FOOD_COST, CIVILIANS_MAX)
	player.gold += civilians * GOLD_PER_CIVILIAN_PER_MIN
