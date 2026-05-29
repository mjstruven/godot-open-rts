extends "res://source/match/units/Structure.gd"

var outer_end_capped: bool = true
var stair_side: int = 0


func _ready():
	await super()
	add_to_group("walls")
	_update_cap_visibility()
	_update_stair_visibility()
	var nav_body = find_child("WallTopNavBody")
	if nav_body != null:
		nav_body.add_to_group("wall_top_nav_input")
	var nav_region = find_child("WallTopNavRegion")
	if nav_region != null:
		nav_region.bake_navigation_mesh()


func _update_cap_visibility():
	var cap = find_child("OuterCap")
	if cap:
		cap.visible = outer_end_capped


func _update_stair_visibility():
	var inner = find_child("StairsInner")
	var outer_stair = find_child("StairsOuter")
	if inner:
		inner.visible = stair_side == 0
	if outer_stair:
		outer_stair.visible = stair_side == 1
