extends "res://source/match/units/Unit.gd"

const MIN_CREW_TO_FUNCTION = 4


func _ready():
	await super()
	add_to_group("siege_units")
	add_to_group("neutral_siege")
	var mv = find_child("Movement")
	if mv != null:
		mv.avoidance_enabled = false
	var crew_mgr = find_child("CrewManager")
	if crew_mgr != null:
		crew_mgr.crew_changed.connect(_on_crew_changed)


func _on_crew_changed(new_count: int) -> void:
	if new_count < MIN_CREW_TO_FUNCTION:
		action_queue.clear()
		action = null


func _set_action(action_node):
	if action_node != null:
		var crew_mgr = find_child("CrewManager")
		if crew_mgr != null and crew_mgr.crew_count() < MIN_CREW_TO_FUNCTION:
			action_node.queue_free()
			if is_in_group("controlled_units"):
				MatchSignals.alert_message.emit(player, "Must be crewed by at least 4")
			return
	super(action_node)


func _handle_unit_death():
	var crew_mgr = find_child("CrewManager")
	if crew_mgr != null:
		for unit in crew_mgr.get_all_crew():
			if is_instance_valid(unit):
				unit.hp = 0
	super()


func refresh_player_color():
	var geo = find_child("Geometry")
	if geo == null:
		return
	var mat = player.get_color_material() if is_instance_valid(player) else null
	for child in geo.find_children("*", "MeshInstance3D", true, false):
		child.material_override = mat


func reset_player_color():
	var geo = find_child("Geometry")
	if geo == null:
		return
	for child in geo.find_children("*", "MeshInstance3D", true, false):
		child.material_override = null
