extends Node3D

const MouseClickAnimation = preload("res://source/match/utils/MouseClickAnimation.tscn")


func _ready():
	MatchSignals.terrain_targeted.connect(_on_terrain_targeted)


func _on_terrain_targeted(target_position):
	if (
		get_tree()
		. get_nodes_in_group("selected_units")
		. filter(func(unit): return unit.is_in_group("controlled_units"))
		. is_empty()
	):
		return
	var tvs = get_tree().get_first_node_in_group("terrain_visual_system")
	var visual_y: float = (
		tvs.get_visual_height_at(target_position)
		if tvs != null and tvs.height_ready
		else target_position.y
	)
	var node = MouseClickAnimation.instantiate()
	node.global_transform = Transform3D(Basis(), Vector3(target_position.x, visual_y + 0.3, target_position.z))
	add_child(node)
