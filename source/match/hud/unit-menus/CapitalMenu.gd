extends GridContainer

const EngineerScene = preload("res://source/match/units/engineer.tscn")
const SupplyTrainScene = preload("res://source/match/units/supply_train.tscn")
const FlagCommanderScene = preload(
	"res://source/match/units/flag_commander/flag_commander.tscn"
)
const MercenaryScene = preload("res://source/match/units/mercenary.tscn")
const MERCENARY_BATCH_SIZE = 5

var units = []:
	set(value):
		units = value
		if is_node_ready():
			_refresh_fc_button()

@onready var _fc_btn = find_child("ProduceFlagCommanderButton")


func _ready():
	MatchSignals.unit_died.connect(func(_u): _refresh_fc_button())
	MatchSignals.unit_production_finished.connect(func(_u, _p): _refresh_fc_button())
	MatchSignals.unit_production_started.connect(func(_u, _p): _refresh_fc_button())
	_refresh_fc_button()


func _on_produce_engineer_button_pressed():
	var available = units.filter(func(u): return u.is_constructed())
	if available.is_empty():
		return
	var target = available.reduce(func(a, b):
		return a if a.production_queue.size() <= b.production_queue.size() else b
	)
	target.production_queue.produce(EngineerScene)


func _on_produce_supply_train_button_pressed():
	var available = units.filter(func(u): return u.is_constructed())
	if available.is_empty():
		return
	var player = available[0].player
	var existing = get_tree().get_nodes_in_group("supply_trains").filter(
		func(u): return u.player == player
	).size()
	if existing >= Constants.Match.Units.SUPPLY_TRAIN_BUILD_LIMIT:
		return
	var target = available.reduce(func(a, b):
		return a if a.production_queue.size() <= b.production_queue.size() else b
	)
	target.production_queue.produce(SupplyTrainScene)


func _on_hire_mercenary_button_pressed():
	var available = units.filter(func(u): return u.is_constructed())
	if available.is_empty():
		return
	var player = available[0].player
	var cost = Constants.Match.Units.PRODUCTION_COSTS[MercenaryScene.resource_path]
	if not player.has_resources(cost):
		return
	var target = available.reduce(func(a, b):
		return a if a.production_queue.size() <= b.production_queue.size() else b
	)
	player.subtract_resources(cost)
	target.production_queue.produce(MercenaryScene, false, MERCENARY_BATCH_SIZE)


func _on_produce_flag_commander_button_pressed():
	var available = units.filter(func(u): return u.is_constructed())
	if available.is_empty():
		return
	var player = available[0].player
	if _flag_commander_count(player) >= Constants.Match.Units.FLAG_COMMANDER_LIMIT:
		return
	var target = available.reduce(func(a, b):
		return a if a.production_queue.size() <= b.production_queue.size() else b
	)
	target.production_queue.produce(FlagCommanderScene)


func _flag_commander_count(player) -> int:
	var field_count = get_tree().get_nodes_in_group("flag_commanders").filter(
		func(u): return is_instance_valid(u) and u.player == player
	).size()
	var queued_count = 0
	for capital in get_tree().get_nodes_in_group("capitals"):
		if not is_instance_valid(capital) or capital.player != player:
			continue
		var pq = capital.find_child("ProductionQueue")
		if pq == null:
			continue
		for elem in pq.get_elements():
			if (
				elem.unit_prototype != null
				and elem.unit_prototype.resource_path
				== FlagCommanderScene.resource_path
			):
				queued_count += 1
	return field_count + queued_count


func _refresh_fc_button():
	if not is_instance_valid(_fc_btn):
		return
	if units.is_empty():
		_fc_btn.disabled = true
		return
	var player = units[0].player
	var count = _flag_commander_count(player)
	if count >= Constants.Match.Units.FLAG_COMMANDER_LIMIT:
		_fc_btn.disabled = true
		_fc_btn.tooltip_text = "Flag Commander — already active (1/1)"
	else:
		_fc_btn.disabled = false
		_fc_btn.tooltip_text = "Flag Commander | 30s | 150 gold [E]"
