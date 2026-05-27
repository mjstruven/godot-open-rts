extends GridContainer

const Human = preload("res://source/match/players/human/Human.gd")
const LoadingIntoCrew = preload("res://source/match/units/actions/LoadingIntoCrew.gd")

const _CREWABLE = [
	"res://source/match/units/infantry.tscn",
	"res://source/match/units/archer.tscn",
]
const _CREW_RADIUS = 10.0

var units = []:
	set(value):
		units = value


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
		var min_crew_val = weapon.get("MIN_CREW_TO_FUNCTION")
		var min_crew: int = min_crew_val if min_crew_val != null else 1
		var needed := max(0, min_crew - crew_mgr.crew_count())
		if needed <= 0:
			continue
		var candidates = _find_candidates(weapon, pressing_player, needed)
		if candidates.size() < needed:
			MatchSignals.alert_message.emit(pressing_player, "Not enough nearby units to crew")
			continue
		var tower = weapon.get_meta("garrison_of") if weapon.has_meta("garrison_of") else null
		var gm: Node = tower.find_child("GarrisonManager") if is_instance_valid(tower) else null
		for foot in candidates:
			if foot.is_in_group("garrisoned") and gm != null:
				gm.ungarrison_unit(foot)
			foot.action = LoadingIntoCrew.new(weapon)


func _find_candidates(weapon: Node, pressing_player: Node, needed: int) -> Array:
	var candidates: Array = []
	if weapon.is_in_group("garrisoned") and weapon.has_meta("garrison_of"):
		var tower = weapon.get_meta("garrison_of")
		if is_instance_valid(tower):
			var gm = tower.find_child("GarrisonManager")
			if gm != null:
				for occupant in gm.get_garrisoned():
					if candidates.size() >= needed:
						break
					if not is_instance_valid(occupant) or occupant == weapon:
						continue
					if occupant.player != pressing_player:
						continue
					if occupant.is_in_group("in_crew"):
						continue
					if not occupant.get_script():
						continue
					if occupant.get_script().resource_path.replace(".gd", ".tscn") not in _CREWABLE:
						continue
					candidates.append(occupant)
	if candidates.size() < needed:
		var pos := weapon.global_position
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
			if unit not in candidates:
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
