extends PanelContainer

const Human = preload("res://source/match/players/human/Human.gd")

# 15 cargo × 4 wagons/min (1 per 15s) = 60 per mill per minute
const WAGON_RATE = 60
# 23 cargo × 4 wagons/min = 92 food per manor per minute
const MANOR_WAGON_RATE = 92


const WARNING_SECONDS_THRESHOLD = 60.0
const UPDATE_INTERVAL = 0.5

var _player = null
var _elapsed_seconds = 0.0
var _flash_timer = 0.0
var _update_timer = UPDATE_INTERVAL

@onready var _food_stock  = find_child("FoodStockLabel")
@onready var _food_income = find_child("FoodIncomeLabel")
@onready var _food_expend = find_child("FoodExpendLabel")
@onready var _food_net    = find_child("FoodNetLabel")
@onready var _food_block  = find_child("FoodBlock")

@onready var _wood_stock  = find_child("WoodStockLabel")
@onready var _wood_income = find_child("WoodIncomeLabel")
@onready var _wood_expend = find_child("WoodExpendLabel")
@onready var _wood_net    = find_child("WoodNetLabel")
@onready var _wood_block  = find_child("WoodBlock")

@onready var _stone_stock  = find_child("StoneStockLabel")
@onready var _stone_income = find_child("StoneIncomeLabel")
@onready var _stone_expend = find_child("StoneExpendLabel")
@onready var _stone_net    = find_child("StoneNetLabel")
@onready var _stone_block  = find_child("StoneBlock")

@onready var _gold_stock  = find_child("GoldStockLabel")
@onready var _gold_income = find_child("GoldIncomeLabel")
@onready var _gold_expend = find_child("GoldExpendLabel")
@onready var _gold_net    = find_child("GoldNetLabel")
@onready var _gold_block  = find_child("GoldBlock")

@onready var _civ_label   = find_child("CivLabel")
@onready var _mil_label   = find_child("MilLabel")
@onready var _acd_label   = find_child("AcdLabel")
@onready var _timer_label = find_child("TimerLabel")


func _ready():
	await MatchSignals.match_started
	var human_players = get_tree().get_nodes_in_group("players").filter(
		func(p): return p is Human
	)
	if not human_players.is_empty():
		_player = human_players[0]


func _process(delta):
	if _player == null:
		return

	_elapsed_seconds += delta
	_timer_label.text = _format_time(_elapsed_seconds)

	_flash_timer += delta
	if _flash_timer >= 1.0:
		_flash_timer = 0.0

	_update_timer += delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0
	_update_display()


func _update_display():
	var all_units = get_tree().get_nodes_in_group("units").filter(
		func(u): return u.player == _player
	)

	var grain_mills  = _count_mills("grain_mill.gd",  all_units)
	var manor_count  = _count_mills("manor.gd",        all_units)
	var lumber_mills = _count_mills("lumber_mill.gd",  all_units)
	var stone_mills  = _count_mills("stone_mill.gd",   all_units)

	var food_in  = grain_mills * WAGON_RATE + manor_count * MANOR_WAGON_RATE + _building_income_per_min("food", all_units)
	var wood_in  = lumber_mills * WAGON_RATE + _building_income_per_min("wood", all_units)
	var stone_in = stone_mills * WAGON_RATE + _building_income_per_min("stone", all_units)
	var gold_in  = _building_income_per_min("gold", all_units)

	var food_ex = _upkeep_per_min("food", all_units)
	var gold_ex = _upkeep_per_min("gold", all_units)

	_set_resource_block(
		_food_stock, _food_income, _food_expend, _food_net, _food_block,
		int(_player.food), food_in, food_ex
	)
	_set_resource_block(
		_wood_stock, _wood_income, _wood_expend, _wood_net, _wood_block,
		int(_player.wood), wood_in, 0
	)
	_set_resource_block(
		_stone_stock, _stone_income, _stone_expend, _stone_net, _stone_block,
		int(_player.stone), stone_in, 0
	)
	_set_resource_block(
		_gold_stock, _gold_income, _gold_expend, _gold_net, _gold_block,
		int(_player.gold), gold_in, gold_ex
	)

	_food_income.tooltip_text = _income_tooltip("food", [
		["Grain Mills", grain_mills, WAGON_RATE],
		["Manors", manor_count, MANOR_WAGON_RATE],
	], all_units)
	_wood_income.tooltip_text = _income_tooltip("wood", [["Lumber Mills", lumber_mills, WAGON_RATE]], all_units)
	_stone_income.tooltip_text = _income_tooltip("stone", [["Stone Mills", stone_mills, WAGON_RATE]], all_units)
	_gold_income.tooltip_text = _income_tooltip("gold", [], all_units)
	_food_expend.tooltip_text = _upkeep_breakdown_tooltip("food", all_units)
	_gold_expend.tooltip_text = _upkeep_breakdown_tooltip("gold", all_units)

	var pop = get_tree().get_nodes_in_group("population_units").filter(
		func(u): return u.player == _player
	).size()
	var capitals = get_tree().get_nodes_in_group("capitals").filter(
		func(u): return u.player == _player and u.is_constructed()
	).size()
	var houses = get_tree().get_nodes_in_group("houses").filter(
		func(u): return u.player == _player and u.is_constructed()
	).size()
	var manors = get_tree().get_nodes_in_group("manors").filter(
		func(u): return u.player == _player and u.is_constructed()
	).size()
	var cap = mini(
		capitals * Constants.Match.Units.POPULATION_PER_CAPITAL
		+ houses * Constants.Match.Units.POPULATION_PER_HOUSE
		+ manors * Constants.Match.Units.POPULATION_PER_MANOR,
		Constants.Match.Units.POPULATION_CAP_MAX
	)
	var military = all_units.filter(func(u):
		var p = u.get_script().resource_path
		return p.ends_with("infantry.gd") or p.ends_with("archer.gd") or p.ends_with("cavalry.gd")
	).size()
	_civ_label.text = "Pop: %d/%d" % [pop, cap]
	if cap > 0 and pop >= cap:
		_civ_label.modulate = Color.RED
	elif cap > 0 and pop >= cap * 0.9:
		_civ_label.modulate = Color.YELLOW
	else:
		_civ_label.modulate = Color.WHITE
	_mil_label.text = "Mil: %d" % military
	_acd_label.text = "Hse: %d Mnr: %d" % [houses, manors]


func _count_mills(script_suffix: String, all_units: Array) -> int:
	return all_units.filter(func(u):
		return (
			u.get_script().resource_path.ends_with(script_suffix)
			and u.has_method("is_constructed")
			and u.is_constructed()
		)
	).size()


func _building_income_per_min(resource: String, all_units: Array) -> int:
	var total = 0
	for unit in all_units:
		if not unit.has_method("is_constructed") or not unit.is_constructed():
			continue
		var scene_path = unit.get_script().resource_path.replace(".gd", ".tscn")
		if scene_path in Constants.Match.Units.BUILDING_INCOME:
			total += Constants.Match.Units.BUILDING_INCOME[scene_path].get(resource, 0)
	return total


func _upkeep_per_min(resource: String, all_units: Array) -> int:
	var total = 0
	for unit in all_units:
		var scene_path = unit.get_script().resource_path.replace(".gd", ".tscn")
		if scene_path in Constants.Match.Units.UPKEEP:
			total += Constants.Match.Units.UPKEEP[scene_path].get(resource, 0)
	return total


func _set_resource_block(stock_lbl, inc_lbl, exp_lbl, net_lbl, block, stockpile, income, expend):
	stock_lbl.text = str(stockpile)
	inc_lbl.text = "+%d" % income
	exp_lbl.text = "-%d" % expend
	var net = income - expend
	net_lbl.text = "=%d" % net
	net_lbl.modulate = Color.GREEN if net >= 0 else Color.RED

	var warn = net < 0 and expend > 0 and stockpile < (float(expend) / 60.0) * WARNING_SECONDS_THRESHOLD
	if warn:
		block.modulate = Color(1.0, 0.3, 0.3, 1.0) if _flash_timer < 0.5 else Color.WHITE
	else:
		block.modulate = Color.WHITE


func _format_time(seconds: float) -> String:
	var s = int(seconds)
	return "%d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]


func _income_tooltip(resource: String, mill_sources: Array, all_units: Array) -> String:
	var lines = []
	for s in mill_sources:
		var count: int = s[1]
		if count > 0:
			lines.append("+%d from %s ×%d" % [count * s[2], s[0], count])
	var by_type: Dictionary = {}
	for unit in all_units:
		if not unit.has_method("is_constructed") or not unit.is_constructed():
			continue
		var scene_path = unit.get_script().resource_path.replace(".gd", ".tscn")
		if scene_path in Constants.Match.Units.BUILDING_INCOME:
			var rate = Constants.Match.Units.BUILDING_INCOME[scene_path].get(resource, 0)
			if rate > 0:
				if scene_path not in by_type:
					by_type[scene_path] = {"count": 0, "rate": rate}
				by_type[scene_path]["count"] += 1
	for scene_path in by_type:
		var entry = by_type[scene_path]
		var type_label = scene_path.get_file().replace(".tscn", "").capitalize()
		lines.append("+%d from %s ×%d" % [entry["count"] * entry["rate"], type_label, entry["count"]])
	return "\n".join(lines) if not lines.is_empty() else "No income"


func _upkeep_breakdown_tooltip(resource: String, all_units: Array) -> String:
	var by_type: Dictionary = {}
	for unit in all_units:
		var scene_path = unit.get_script().resource_path.replace(".gd", ".tscn")
		if scene_path in Constants.Match.Units.UPKEEP:
			var cost = Constants.Match.Units.UPKEEP[scene_path].get(resource, 0)
			if cost > 0:
				if scene_path not in by_type:
					by_type[scene_path] = {"count": 0, "rate": cost}
				by_type[scene_path]["count"] += 1
	var lines = []
	for scene_path in by_type:
		var entry = by_type[scene_path]
		var type_label = scene_path.get_file().replace(".tscn", "").capitalize()
		lines.append("-%d from %s ×%d" % [entry["count"] * entry["rate"], type_label, entry["count"]])
	return "\n".join(lines) if not lines.is_empty() else "No upkeep"
