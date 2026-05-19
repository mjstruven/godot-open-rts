extends PanelContainer

const Human = preload("res://source/match/players/human/Human.gd")
const CIVILIANS_MAX = 20
const CIVILIAN_FOOD_COST = 10

# Morale states
const STATE_HIGH = "High"
const STATE_GOOD = "Good"
const STATE_LOW = "Low"
const STATE_CRITICAL = "Critical"

var _player = null

@onready var _morale_state_label = find_child("MoraleStateLabel")
@onready var _morale_score_label = find_child("MoraleScoreLabel")
@onready var _morale_factor_label = find_child("MoraleFactorLabel")


func _ready():
	await MatchSignals.match_started
	var human_players = get_tree().get_nodes_in_group("players").filter(
		func(p): return p is Human
	)
	if human_players.is_empty():
		return
	_player = human_players[0]


func _process(_delta):
	if _player == null:
		return
	_update_morale()


func _update_morale():
	var score = 100
	var top_factor = ""
	var worst = 0

	# food deficit
	var all_units = get_tree().get_nodes_in_group("units").filter(
		func(u): return u.player == _player
	)
	var food_expend = 0
	for unit in all_units:
		var path = unit.get_script().resource_path.replace(".gd", ".tscn")
		if path in Constants.Match.Units.UPKEEP:
			food_expend += Constants.Match.Units.UPKEEP[path].get("food", 0) * 60
	if food_expend > 0 and _player.food < food_expend / 60.0 * 30.0:
		var penalty = 30
		score -= penalty
		if penalty > worst:
			worst = penalty
			top_factor = "Food shortage"

	# civilians below max
	var civilians = mini(int(_player.food) / CIVILIAN_FOOD_COST, CIVILIANS_MAX)
	if civilians < CIVILIANS_MAX / 2:
		var penalty = 20
		score -= penalty
		if penalty > worst:
			worst = penalty
			top_factor = "Low population"

	# wood/stone low
	if _player.wood < 50:
		var penalty = 10
		score -= penalty
		if penalty > worst:
			worst = penalty
			top_factor = "Low wood"
	if _player.stone < 50:
		var penalty = 10
		score -= penalty
		if penalty > worst:
			worst = penalty
			top_factor = "Low stone"

	# military strength
	var military = all_units.filter(func(u):
		var p = u.get_script().resource_path
		return p.ends_with("infantry.gd") or p.ends_with("archer.gd") or p.ends_with("cavalry.gd")
	).size()
	if military == 0:
		var penalty = 15
		score -= penalty
		if penalty > worst:
			worst = penalty
			top_factor = "No military"

	score = clampi(score, 0, 100)
	var state = STATE_HIGH
	if score < 25:
		state = STATE_CRITICAL
		_morale_state_label.modulate = Color(0.9, 0.1, 0.1, 1)
	elif score < 50:
		state = STATE_LOW
		_morale_state_label.modulate = Color(0.9, 0.5, 0.1, 1)
	elif score < 75:
		state = STATE_GOOD
		_morale_state_label.modulate = Color(0.8, 0.8, 0.2, 1)
	else:
		_morale_state_label.modulate = Color(0.2, 0.9, 0.2, 1)

	_morale_state_label.text = state
	_morale_score_label.text = "%d / 100" % score
	_morale_factor_label.text = top_factor if not top_factor.is_empty() else "All good"


