extends "res://source/match/units/Structure.gd"

var outer_end_capped: bool = true
var stair_side: int = 0


func _ready():
	await super()
	add_to_group("walls")
	_update_cap_visibility()
	var nav_body = find_child("WallTopNavBody")
	if nav_body != null:
		nav_body.add_to_group("wall_top_nav_input")
	var nav_region = find_child("WallTopNavRegion")
	if nav_region != null:
		nav_region.navigation_mesh = nav_region.navigation_mesh.duplicate()
		nav_region.bake_navigation_mesh()


func _handle_unit_death():
	var wgm = find_child("WallGarrisonManager")
	if wgm != null:
		wgm.kill_all_occupants()
	super()


func _update_cap_visibility():
	var cap = find_child("OuterCap", true, false)
	if cap:
		cap.visible = outer_end_capped
