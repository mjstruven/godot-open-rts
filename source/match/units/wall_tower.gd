extends "res://source/match/units/tower.gd"


func _ready():
	await super()
	add_to_group("wall_towers")


func _handle_unit_death():
	var match_node = find_parent("Match")
	if match_node != null:
		var rubble = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(1.6, 1.75, 1.6)
		rubble.mesh = box
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.33, 0.30)
		rubble.material_override = mat
		match_node.add_child(rubble)
		rubble.global_position = Vector3(global_position.x, 0.875, global_position.z)
	super()
