extends "res://source/match/units/Unit.gd"


func _ready():
	await super()
	add_to_group("siege_units")
	add_to_group("neutral_siege")
	var mv = find_child("Movement")
	if mv != null:
		mv.avoidance_enabled = false
	var ecm = find_child("ExternalCrewManager")
	if ecm != null:
		ecm.crew_changed.connect(_on_crew_changed)


func _on_crew_changed(_new_count: int) -> void:
	pass


func _handle_unit_death():
	var ecm = find_child("ExternalCrewManager")
	if ecm != null:
		for eng in ecm.get_all_engineers():
			if is_instance_valid(eng):
				eng.hp = 0
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
