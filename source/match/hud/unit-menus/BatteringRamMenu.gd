extends GridContainer

const Human = preload("res://source/match/players/human/Human.gd")
const LoadingIntoCrew = preload("res://source/match/units/actions/LoadingIntoCrew.gd")

const MAX_CREW := 4
const _CREWABLE = [
	"res://source/match/units/infantry.tscn",
	"res://source/match/units/archer.tscn",
]
const _CREW_RADIUS = 10.0

var units = []:
	set(value):
		units = value
		if is_node_ready():
			_refresh_neutral_state()


func _process(_delta):
	if not visible:
		return
	_refresh_neutral_state()


func _refresh_neutral_state() -> void:
	var is_neutral = not units.is_empty() and is_instance_valid(units[0]) and units[0].is_in_group("neutral_siege")
	for child in get_children():
		if child is Button and child.name != "CrewButton":
			child.disabled = is_neutral


func _on_unman_pressed():
	for u in units:
		if not is_instance_valid(u):
			continue
		var crew_mgr = u.find_child("CrewManager")
		if crew_mgr != null:
			crew_mgr.unman()


func _on_crew_pressed():
	var pressing_player = _get_pressing_player()
	if pressing_player == null:
		return
	for weapon in units:
		if not is_instance_valid(weapon):
			continue
		var crew_mgr = weapon.find_child("CrewManager")
		if crew_mgr == null:
			continue
		var needed = max(0, MAX_CREW - crew_mgr.crew_count())
		if needed <= 0:
			continue
		var candidates = _find_candidates(weapon, pressing_player, needed)
		if candidates.is_empty():
			MatchSignals.alert_message.emit(pressing_player, "No nearby units to crew")
			continue
		for foot in candidates:
			foot.action = LoadingIntoCrew.new(weapon)


func _find_candidates(weapon: Node, pressing_player: Node, needed: int) -> Array:
	var candidates: Array = []
	var pos = weapon.global_position
	var ground: Array = []
	for unit in get_tree().get_nodes_in_group("controlled_units"):
		if not is_instance_valid(unit) or unit.player != pressing_player:
			continue
		if unit.is_in_group("in_crew") or unit.is_in_group("garrisoned"):
			continue
		if not unit.get_script():
			continue
		if unit.get_script().resource_path.replace(".gd", ".tscn") not in _CREWABLE:
			continue
		if unit.global_position.distance_to(pos) > _CREW_RADIUS:
			continue
		ground.append(unit)
	ground.sort_custom(func(a, b):
		return a.global_position.distance_to(pos) < b.global_position.distance_to(pos)
	)
	for unit in ground:
		if candidates.size() >= needed:
			break
		candidates.append(unit)
	return candidates


func _get_pressing_player() -> Node:
	for p in get_tree().get_nodes_in_group("players"):
		if p is Human:
			return p
	return null
