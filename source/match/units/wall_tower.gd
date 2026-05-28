extends "res://source/match/units/tower.gd"

const WallSectionUnit = preload("res://source/match/units/wall_section.tscn")


func _ready():
	await super()
	add_to_group("wall_towers")


func _handle_unit_death():
	var stub = WallSectionUnit.instantiate()
	stub.outer_end_capped = false
	stub.add_to_group("wall_tower_stubs")
	var t = global_transform
	t.origin.y = 0.0
	var tower_player = player
	MatchSignals.setup_and_spawn_unit.emit(stub, t, tower_player, false)
	var dark_mat = StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.15, 0.13, 0.11)
	stub._change_geometry_material(dark_mat)
	super()
