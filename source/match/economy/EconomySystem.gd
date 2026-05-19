extends Node3D

# Economy processes once per minute. All UPKEEP and BUILDING_INCOME values
# in MatchConstants are per-minute integers applied directly each tick.
const TICK_INTERVAL = 60.0

var _tick_timer = null


func _ready():
	_tick_timer = Timer.new()
	_tick_timer.wait_time = TICK_INTERVAL
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

	# Sum per-minute upkeep across all units
	var upkeep = {}
	for unit in all_units:
		var scene_path = unit.get_script().resource_path.replace(".gd", ".tscn")
		if scene_path in Constants.Match.Units.UPKEEP:
			for resource in Constants.Match.Units.UPKEEP[scene_path]:
				upkeep[resource] = upkeep.get(resource, 0) + Constants.Match.Units.UPKEEP[scene_path][resource]

	# Deficit flag set before deducting so HUD and penalties can react
	player.has_deficit = player.food < upkeep.get("food", 0)

	# Deduct upkeep — floor at 0 (no negative stockpiles)
	player.food = max(0, player.food - upkeep.get("food", 0))
	player.gold = max(0, player.gold - upkeep.get("gold", 0))

	# Apply per-minute building gold income for each constructed building
	for unit in all_units:
		if not unit.has_method("is_constructed") or not unit.is_constructed():
			continue
		var scene_path = unit.get_script().resource_path.replace(".gd", ".tscn")
		if scene_path in Constants.Match.Units.BUILDING_INCOME:
			for resource in Constants.Match.Units.BUILDING_INCOME[scene_path]:
				var income = Constants.Match.Units.BUILDING_INCOME[scene_path][resource]
				player.set(resource, player.get(resource) + income)
