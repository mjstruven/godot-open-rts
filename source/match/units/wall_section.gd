extends "res://source/match/units/Structure.gd"

var outer_end_capped: bool = true
var stair_side: int = 0


func _ready():
	await super()
	add_to_group("walls")
	_update_cap_visibility()
	print("[STAIR] _ready calling _update_stair_visibility on ", name)
	_update_stair_visibility()
	var nav_body = find_child("WallTopNavBody")
	if nav_body != null:
		nav_body.add_to_group("wall_top_nav_input")
	var nav_region = find_child("WallTopNavRegion")
	if nav_region != null:
		nav_region.navigation_mesh = nav_region.navigation_mesh.duplicate()
		nav_region.bake_navigation_mesh()


func _update_cap_visibility():
	var cap = find_child("OuterCap", true, false)
	if cap:
		cap.visible = outer_end_capped


func _update_stair_visibility():
	print("[STAIR] _update_stair_visibility called on ", name, " stair_side=", stair_side)
	var inner = find_child("StairsInner", true, false)
	var outer_stair = find_child("StairsOuter", true, false)
	print("[STAIR]   inner found: ", inner != null, " path: ", inner.get_path() if inner else "null")
	print("[STAIR]   outer found: ", outer_stair != null, " path: ", outer_stair.get_path() if outer_stair else "null")
	if inner:
		print("[STAIR]   inner.visible BEFORE: ", inner.visible)
		inner.visible = stair_side == 0
		print("[STAIR]   inner.visible AFTER: ", inner.visible)
	if outer_stair:
		print("[STAIR]   outer.visible BEFORE: ", outer_stair.visible)
		outer_stair.visible = stair_side == 1
		print("[STAIR]   outer.visible AFTER: ", outer_stair.visible)
