extends GridContainer

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
	for weapon in units:
		if not is_instance_valid(weapon):
			continue
		var crew_mgr = weapon.find_child("CrewManager")
		if crew_mgr == null:
			continue
		var needed = crew_mgr.capacity - crew_mgr.crew_count()
		if needed <= 0:
			continue
		var candidates = _nearby_foot(weapon, needed)
		if candidates.is_empty():
			MatchSignals.alert_message.emit(weapon.player, "Not enough nearby units to crew")
			continue
		for foot in candidates:
			foot.action = LoadingIntoCrew.new(weapon)


func _nearby_foot(weapon: Node, count: int) -> Array:
	var pos = weapon.global_position
	var found = []
	for unit in get_tree().get_nodes_in_group("controlled_units"):
		if not is_instance_valid(unit):
			continue
		if unit.is_in_group("in_crew") or unit.is_in_group("garrisoned"):
			continue
		if not unit.get_script():
			continue
		if unit.get_script().resource_path.replace(".gd", ".tscn") not in _CREWABLE:
			continue
		if unit.global_position.distance_to(pos) > _CREW_RADIUS:
			continue
		found.append(unit)
	found.sort_custom(func(a, b): return a.global_position.distance_to(pos) < b.global_position.distance_to(pos))
	return found.slice(0, count)
