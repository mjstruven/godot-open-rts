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
	var node = MouseClickAnimation.instantiate()
	node.global_transform = Transform3D(Basis(), Vector3(target_position.x, target_position.y + 0.3, target_position.z))
	add_child(node)
